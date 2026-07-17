import Foundation
import Testing
@testable import SwiftTUIEssentials

#if canImport(System)
import System
#else
import SystemPackage
#endif

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@Suite("Application Task Scheduling", .serialized)
struct AppRunnerTests {

    @Test
    func `a view task starts and redraws before and after suspension without input`() throws {
        try withPseudoTerminal { master, slave in
            let process = try startTestHost(scenario: "idle-task", terminal: slave)
            defer { stop(process) }
            let output = TerminalOutputReader(descriptor: master)

            #expect(output.waitFor("idle", process: process))
            #expect(output.waitFor("started", process: process))
            #expect(output.waitFor("resumed", process: process))
            #expect(waitForExit(process))
        }
    }

    @Test
    func `Return starts a task by ID and Escape requests cancellation while it is suspended`() throws {
        try withPseudoTerminal { master, slave in
            let process = try startTestHost(scenario: "cancellable-task", terminal: slave)
            defer { stop(process) }
            let output = TerminalOutputReader(descriptor: master)

            #expect(output.waitFor("ready", process: process))
            try master.writeAll("\u{001B}[<0;36;12M".utf8)
            #expect(output.waitFor("focused", process: process))
            try master.writeAll([13])
            #expect(output.waitFor("running", process: process))
            try master.writeAll([27])
            #expect(output.waitFor("stopped", process: process))
            #expect(waitForExit(process))
        }
    }

    @Test
    func `a long-press deadline expires without further terminal input`() throws {
        try withPseudoTerminal { master, slave in
            let process = try startTestHost(scenario: "long-press", terminal: slave)
            defer { stop(process) }
            let output = TerminalOutputReader(descriptor: master)

            #expect(output.waitFor("waiting", process: process))
            try master.writeAll("\u{001B}[<0;36;12M".utf8)
            #expect(output.waitFor("completed", process: process))
            #expect(waitForExit(process))
        }
    }

    @Test
    func `SIGWINCH redraws geometry with the resized PTY viewport`() throws {
        try withPseudoTerminal { master, slave in
            let process = try startTestHost(scenario: "resize", terminal: slave)
            defer { stop(process) }
            let output = TerminalOutputReader(descriptor: master)

            #expect(output.waitFor("80x24", process: process))
            try resizePseudoTerminal(slave, columns: 100, rows: 30)
            #expect(kill(process.processIdentifier, SIGWINCH) == 0)
            #expect(output.waitFor("100x30", process: process))
            try master.writeAll([TerminalControl.quitByte])
            #expect(waitForExit(process))
        }
    }

    @Test
    func `task termination restores terminal attributes and emits exit sequences once`() throws {
        try withPseudoTerminal { master, slave in
            let process = try startTestHost(scenario: "terminal-restoration", terminal: slave)
            defer { stop(process) }
            let output = TerminalOutputReader(descriptor: master)

            #expect(output.waitFor("host-ready", process: process))
            let original = try terminalAttributes(for: slave)
            try master.writeAll([10])
            #expect(output.waitFor("resumed", process: process))
            #expect(waitForExit(process))
            output.drain()

            let restored = try terminalAttributes(for: slave)
            #expect(original.c_iflag == restored.c_iflag)
            #expect(original.c_oflag == restored.c_oflag)
            #expect(original.c_cflag == restored.c_cflag)
            // The kernel can set PENDIN while switching a PTY back to canonical
            // mode. It is transient input bookkeeping rather than a raw-mode
            // setting owned by the session.
            #expect(
                original.c_lflag & ~tcflag_t(PENDIN)
                    == restored.c_lflag & ~tcflag_t(PENDIN)
            )
            #expect(controlCharactersMatch(original, restored))
            #expect(output.text.occurrences(of: TerminalControl.showCaretSequence) == 1)
            #expect(output.text.occurrences(of: TerminalControl.disableFocusReportingSequence) == 1)
            #expect(output.text.occurrences(of: TerminalControl.disablePointerTrackingSequence) == 1)
            #expect(output.text.occurrences(of: TerminalControl.exitAlternateScreenSequence) == 1)
        }
    }
}

private final class AppRunnerTestsBundleToken: NSObject {}

private final class TerminalOutputReader {

    private let descriptor: FileDescriptor

    private var bytes: [UInt8] = []

    init(descriptor: FileDescriptor) {
        self.descriptor = descriptor
    }

    var text: String {
        String(decoding: bytes, as: UTF8.self)
    }

    func waitFor(
        _ expected: String,
        process: Process,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if text.contains(expected) {
                return true
            }
            if let byte = TerminalControl.readByte(from: descriptor, timeout: 0.05) {
                bytes.append(byte)
            }
            else if !process.isRunning {
                drain()
                return text.contains(expected)
            }
        }

        return text.contains(expected)
    }

    func drain() {
        while let byte = TerminalControl.readByte(from: descriptor, timeout: 0) {
            bytes.append(byte)
        }
    }
}

private func testHostURL() -> URL {
    Bundle(for: AppRunnerTestsBundleToken.self).bundleURL
        .deletingLastPathComponent()
        .appendingPathComponent("SwiftTUIAppRunnerTestHost")
}

private func startTestHost(
    scenario: String,
    terminal: FileDescriptor
) throws -> Process {
    let process = Process()
    process.executableURL = testHostURL()
    process.environment = ProcessInfo.processInfo.environment.merging(
        ["SWIFT_TUI_TEST_SCENARIO": scenario],
        uniquingKeysWith: { _, scenario in scenario }
    )
    let terminalHandle = FileHandle(
        fileDescriptor: terminal.rawValue,
        closeOnDealloc: false
    )
    process.standardInput = terminalHandle
    process.standardOutput = terminalHandle
    process.standardError = terminalHandle
    try process.run()
    return process
}

private func waitForExit(
    _ process: Process,
    timeout: TimeInterval = 5
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.01)
    }
    return !process.isRunning
}

private func stop(_ process: Process) {
    guard process.isRunning else {
        return
    }

    process.terminate()
    guard !waitForExit(process, timeout: 0.5) else {
        return
    }

    _ = kill(process.processIdentifier, SIGKILL)
    process.waitUntilExit()
}

private func withPseudoTerminal<Result>(
    columns: UInt16 = 80,
    rows: UInt16 = 24,
    _ body: (_ master: FileDescriptor, _ slave: FileDescriptor) throws -> Result
) throws -> Result {
    var master = CInt(-1)
    var slave = CInt(-1)
    var size = winsize(
        ws_row: rows,
        ws_col: columns,
        ws_xpixel: 0,
        ws_ypixel: 0
    )

    let result = unsafe openpty(&master, &slave, nil, nil, &size)
    guard result == 0 else {
        throw Errno(rawValue: errno)
    }

    let masterDescriptor = FileDescriptor(rawValue: master)
    let slaveDescriptor = FileDescriptor(rawValue: slave)
    defer {
        try? masterDescriptor.close()
        try? slaveDescriptor.close()
    }

    return try body(masterDescriptor, slaveDescriptor)
}

private func resizePseudoTerminal(
    _ descriptor: FileDescriptor,
    columns: UInt16,
    rows: UInt16
) throws {
    var size = winsize(
        ws_row: rows,
        ws_col: columns,
        ws_xpixel: 0,
        ws_ypixel: 0
    )
    guard unsafe ioctl(descriptor.rawValue, TIOCSWINSZ, &size) == 0 else {
        throw Errno(rawValue: errno)
    }
}

private func terminalAttributes(for descriptor: FileDescriptor) throws -> termios {
    var attributes = termios()
    guard unsafe tcgetattr(descriptor.rawValue, &attributes) == 0 else {
        throw Errno(rawValue: errno)
    }
    return attributes
}

private func controlCharactersMatch(_ lhs: termios, _ rhs: termios) -> Bool {
    var lhs = lhs
    var rhs = rhs
    return withUnsafeBytes(of: &lhs.c_cc) { lhsBytes in
        withUnsafeBytes(of: &rhs.c_cc) { rhsBytes in
            unsafe lhsBytes.elementsEqual(rhsBytes)
        }
    }
}

private extension String {

    func occurrences(of substring: String) -> Int {
        components(separatedBy: substring).count - 1
    }
}
