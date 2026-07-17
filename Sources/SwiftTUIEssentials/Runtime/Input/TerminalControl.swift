import Foundation
import CoreFoundation
import Dispatch
import Synchronization
import Terminal
import Termios

#if canImport(System)
import System
#else
import SystemPackage
#endif

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#else
#error("SwiftTUI requires Glibc or Darwin.")
#endif

enum TerminalInput: Equatable, Sendable {

    case quit

    case keyPress(KeyPress)

    case pointerPress(PointerPress)

    case pointerMotion(PointerMotion)

    case pointerScroll(PointerScroll)

    case focusIn

    case focusOut

    case none
}

/// Schedules a source that ends the current main-run-loop service pass.
///
/// Signaling is safe from the terminal worker. The block remains pending if it
/// is scheduled just before the runner enters the run loop, so no wakeup is
/// lost at the boundary between requesting input and waiting for an event.
nonisolated enum MainRunLoopWakeup {

    static func signal() {
        let mainRunLoop = CFRunLoopGetMain()
        CFRunLoopPerformBlock(
            mainRunLoop,
            RunLoop.Mode.default.rawValue as NSString
        ) {
            CFRunLoopStop(mainRunLoop)
        }
        CFRunLoopWakeUp(mainRunLoop)
    }
}

/// Wakes an idle terminal read without consuming bytes from terminal input.
///
/// The pipe contains at most one byte. Writers coalesce repeated wake requests,
/// and the input worker consumes the byte before it completes the interrupted
/// read. Closing the pipe is safe only after the worker has stopped.
nonisolated final class TerminalInputWakeup: Sendable {

    let readDescriptor: FileDescriptor

    private let writeDescriptor: FileDescriptor

    private let isPending = Mutex(false)

    init() throws {
        let descriptors = try FileDescriptor.pipe()
        readDescriptor = descriptors.readEnd
        writeDescriptor = descriptors.writeEnd
    }

    deinit {
        try? readDescriptor.close()
        try? writeDescriptor.close()
    }

    func signal() {
        let shouldWrite = isPending.withLock {
            guard !$0 else {
                return false
            }

            $0 = true
            return true
        }
        guard shouldWrite else {
            return
        }

        do {
            try writeDescriptor.writeAll([1])
        }
        catch {
            isPending.withLock { $0 = false }
        }
    }

    func consume() {
        var byte: UInt8 = 0
        _ = try? withUnsafeMutableBytes(of: &byte) {
            try unsafe readDescriptor.read(into: $0)
        }
        isPending.withLock { $0 = false }
    }
}

nonisolated enum TerminalControl {

    static let quitByte: UInt8 = 3

    private static let escapeSequenceByteTimeout: TimeInterval = 0.1

    static let clearScreenSequence = "\u{001B}[2J"

    static let hideCaretSequence = "\u{001B}[?25l"

    static let showCaretSequence = "\u{001B}[?25h"

    static let enterAlternateScreenSequence = "\u{001B}[?1049h"

    static let exitAlternateScreenSequence = "\u{001B}[?1049l"

    static let enablePointerTrackingSequence = "\u{001B}[?1003h\u{001B}[?1006h"

    static let disablePointerTrackingSequence = "\u{001B}[?1006l\u{001B}[?1003l"

    static let enableFocusReportingSequence = "\u{001B}[?1004h"

    static let disableFocusReportingSequence = "\u{001B}[?1004l"

    static let pasteFromClipboardSequence = "\u{001B}]52;c;?\u{001B}\\"

    static func copyToClipboardSequence(_ text: String) -> String {
        let payload = Data(text.utf8).base64EncodedString()
        return "\u{001B}]52;c;\(payload)\u{001B}\\"
    }

    static func caretPositionSequence(row: Int, column: Int) -> String {
        "\u{001B}[\(max(row, 1));\(max(column, 1))H"
    }

    static func sgrSequence(for style: TextStyle) -> String {
        var sequences: [String] = []
        if style.isBold {
            sequences.append(Terminal.SGR.style(.bold))
        }
        if style.isDim {
            sequences.append(Terminal.SGR.style(.dim))
        }
        if style.isItalic {
            sequences.append(Terminal.SGR.style(.italic))
        }
        if style.isUnderline {
            sequences.append(Terminal.SGR.style(.underline))
        }
        if style.isStrikethrough {
            sequences.append(Terminal.SGR.style(.strikethrough))
        }
        if let foregroundStyle = style.foregroundStyle {
            sequences.append(foregroundSGRSequence(for: foregroundStyle))
        }
        if let backgroundStyle = style.backgroundStyle {
            sequences.append(backgroundSGRSequence(for: backgroundStyle))
        }

        return sequences.joined()
    }

    static func resetSGRSequence(for style: TextStyle) -> String {
        var sequences: [String] = []
        if style.isBold {
            sequences.append(Terminal.SGR.resetStyle(.bold))
        }
        else if style.isDim {
            sequences.append(Terminal.SGR.resetStyle(.dim))
        }
        if style.isItalic {
            sequences.append(Terminal.SGR.resetStyle(.italic))
        }
        if style.isUnderline {
            sequences.append(Terminal.SGR.resetStyle(.underline))
        }
        if style.isStrikethrough {
            sequences.append(Terminal.SGR.resetStyle(.strikethrough))
        }
        if style.foregroundStyle != nil {
            sequences.append(Terminal.SGR.resetForegroundColor)
        }
        if style.backgroundStyle != nil {
            sequences.append(Terminal.SGR.resetBackgroundColor)
        }

        return sequences.joined()
    }

    private static func foregroundSGRSequence(for color: AnyColor) -> String {
        Terminal.SGR.foregroundColor(color)
    }

    private static func backgroundSGRSequence(for color: AnyColor) -> String {
        Terminal.SGR.backgroundColor(color)
    }

    static func currentTerminalSize(
        for descriptor: FileDescriptor = .standardOutput
    ) -> TerminalViewportSize {
        guard let size = try? Terminal.size(for: descriptor),
              size.columns > 0,
              size.rows > 0 else {
            return TerminalViewportSize(columns: 80, rows: 24)
        }

        return TerminalViewportSize(columns: size.columns, rows: size.rows)
    }

    static func readInput(timeout: TimeInterval? = nil) -> TerminalInput {
        readInput(timeout: timeout) {
            readByte(timeout: $0)
        }
    }

    static func readInput(
        timeout: TimeInterval? = nil,
        readByte: (TimeInterval?) -> UInt8?
    ) -> TerminalInput {
        guard let firstByte = readByte(timeout) else {
            return .none
        }

        return readInput(startingWith: firstByte, readByte: readByte)
    }

    private static func readInput(
        startingWith firstByte: UInt8,
        readByte: (TimeInterval?) -> UInt8?
    ) -> TerminalInput {
        var bytes = [firstByte]

        if firstByte == 27 {
            guard let nextByte = readByte(0) else {
                return input(for: bytes)
            }

            bytes.append(contentsOf: readEscapeSequenceBytes(
                startingWith: [nextByte],
                readByte: readByte
            ))
        }
        else {
            switch readUTF8ContinuationBytes(after: firstByte, readByte: readByte) {
            case .complete(let continuationBytes):
                bytes.append(contentsOf: continuationBytes)
            case .incomplete:
                return .none
            case .nextInput(let byte):
                return readInput(startingWith: byte, readByte: readByte)
            }
        }

        return input(for: bytes)
    }

    static func input(for byte: UInt8) -> TerminalInput {
        input(for: [byte])
    }

    static func input(for bytes: [UInt8]) -> TerminalInput {
        guard !bytes.isEmpty else {
            return .none
        }

        if bytes == [quitByte] {
            return .quit
        }

        if bytes == Array("\u{001B}[I".utf8) {
            return .focusIn
        }

        if bytes == Array("\u{001B}[O".utf8) {
            return .focusOut
        }

        if let pointerInput = pointerInput(for: bytes) {
            return pointerInput
        }

        if let keyPress = escapeSequenceInput(for: bytes) {
            return .keyPress(keyPress)
        }

        if bytes.count == 1,
           let keyPress = asciiInput(for: bytes[0]) {
            return .keyPress(keyPress)
        }

        if let string = String(bytes: bytes, encoding: .utf8),
           string.count == 1,
           let character = string.first {
            return .keyPress(
                KeyPress(
                    key: KeyEquivalent(character),
                    characters: string
                )
            )
        }

        return .none
    }

    static func write(
        _ output: String,
        to descriptor: FileDescriptor = .standardOutput
    ) {
        _ = try? descriptor.writeAll(output.utf8)
    }

    static func readByte(
        from descriptor: FileDescriptor = .standardInput,
        timeout: TimeInterval?,
        interruptedBy wakeup: TerminalInputWakeup? = nil
    ) -> UInt8? {
        guard waitForInput(
            on: descriptor,
            timeout: timeout,
            interruptedBy: wakeup
        ) else {
            return nil
        }

        var byte: UInt8 = 0
        let count = try? withUnsafeMutableBytes(of: &byte) {
            try unsafe descriptor.read(into: $0)
        }
        return count == 1 ? byte : nil
    }

    private static func waitForInput(
        on descriptor: FileDescriptor,
        timeout: TimeInterval?,
        interruptedBy wakeup: TerminalInputWakeup?
    ) -> Bool {
        var descriptors = [
            pollfd(
                fd: descriptor.rawValue,
                events: Int16(POLLIN),
                revents: 0
            )
        ]
        if let wakeup {
            descriptors.append(
                pollfd(
                    fd: wakeup.readDescriptor.rawValue,
                    events: Int16(POLLIN),
                    revents: 0
                )
            )
        }

        let milliseconds = timeout.map {
            max(Int32(($0 * 1_000).rounded(.up)), 0)
        } ?? -1
        let result = unsafe poll(&descriptors, nfds_t(descriptors.count), milliseconds)
        if result < 0, errno == EINTR {
            return false
        }

        guard result > 0 else {
            return false
        }

        let hasInput = descriptors[0].revents & Int16(POLLIN) != 0
        if descriptors.count > 1,
           descriptors[1].revents & Int16(POLLIN) != 0 {
            wakeup?.consume()
        }
        return hasInput
    }

    private static func readUTF8ContinuationBytes(
        after firstByte: UInt8,
        readByte: (TimeInterval?) -> UInt8?
    ) -> UTF8ContinuationReadResult {
        let count: Int
        switch firstByte {
        case 0b1100_0000...0b1101_1111:
            count = 1
        case 0b1110_0000...0b1110_1111:
            count = 2
        case 0b1111_0000...0b1111_0111:
            count = 3
        default:
            count = 0
        }

        guard count > 0 else {
            return .complete([])
        }

        var bytes: [UInt8] = []
        for _ in 0..<count {
            guard let byte = readByte(escapeSequenceByteTimeout) else {
                return .incomplete
            }

            guard isUTF8ContinuationByte(byte) else {
                return .nextInput(byte)
            }

            bytes.append(byte)
        }

        return .complete(bytes)
    }

    private static func readEscapeSequenceBytes(
        startingWith bytes: [UInt8],
        readByte: (TimeInterval?) -> UInt8?
    ) -> [UInt8] {
        var bytes = bytes
        if escapeSequenceIsComplete([27] + bytes) {
            return bytes
        }

        while bytes.count < 64,
              let byte = readByte(escapeSequenceByteTimeout) {
            bytes.append(byte)
            if escapeSequenceIsComplete([27] + bytes) {
                break
            }
        }

        return bytes
    }

    private static func isUTF8ContinuationByte(_ byte: UInt8) -> Bool {
        0b1000_0000...0b1011_1111 ~= byte
    }

    private enum UTF8ContinuationReadResult {

        case complete([UInt8])

        case incomplete

        case nextInput(UInt8)
    }

    static func escapeSequenceIsComplete(_ bytes: [UInt8]) -> Bool {
        guard bytes.first == 27 else {
            return false
        }

        guard bytes.count > 1 else {
            return true
        }

        switch bytes[1] {
        case 91:
            guard let final = bytes.dropFirst(2).first(where: { 0x40...0x7E ~= $0 }) else {
                return false
            }
            return bytes.last == final
        case 79:
            return bytes.count >= 3
        default:
            return true
        }
    }

    private static func escapeSequenceInput(for bytes: [UInt8]) -> KeyPress? {
        switch bytes {
        case [27]:
            return keyPress(for: .escape)
        case [27, 91, 65]:
            return keyPress(for: .upArrow)
        case [27, 91, 66]:
            return keyPress(for: .downArrow)
        case [27, 91, 67]:
            return keyPress(for: .rightArrow)
        case [27, 91, 68]:
            return keyPress(for: .leftArrow)
        case [27, 91, 49, 59, 50, 65]:
            return keyPress(for: .upArrow, modifiers: .shift)
        case [27, 91, 49, 59, 50, 66]:
            return keyPress(for: .downArrow, modifiers: .shift)
        case [27, 91, 49, 59, 50, 67]:
            return keyPress(for: .rightArrow, modifiers: .shift)
        case [27, 91, 49, 59, 50, 68]:
            return keyPress(for: .leftArrow, modifiers: .shift)
        case [27, 91, 49, 59, 50, 72]:
            return keyPress(for: .home, modifiers: .shift)
        case [27, 91, 49, 59, 50, 70]:
            return keyPress(for: .end, modifiers: .shift)
        case [27, 91, 72], [27, 79, 72], [27, 91, 49, 126], [27, 91, 55, 126]:
            return keyPress(for: .home)
        case [27, 91, 70], [27, 79, 70], [27, 91, 52, 126], [27, 91, 56, 126]:
            return keyPress(for: .end)
        case [27, 91, 53, 126]:
            return keyPress(for: .pageUp)
        case [27, 91, 54, 126]:
            return keyPress(for: .pageDown)
        case [27, 91, 51, 126]:
            return keyPress(for: .deleteForward)
        default:
            return nil
        }
    }

    private static func pointerInput(for bytes: [UInt8]) -> TerminalInput? {
        guard let string = String(bytes: bytes, encoding: .ascii),
              string.hasPrefix("\u{001B}[<"),
              let final = string.last,
              final == "M" || final == "m" else {
            return nil
        }

        let start = string.index(string.startIndex, offsetBy: 3)
        let body = string[start..<string.index(before: string.endIndex)]
        let parts = body.split(separator: ";")
        guard parts.count == 3,
              let encodedButton = Int(parts[0]),
              let column = Int(parts[1]),
              let row = Int(parts[2]) else {
            return nil
        }

        let modifiers = pointerModifiers(for: encodedButton)
        let buttonCode = encodedButton & ~0b11_1100
        let location = Point(
            column: max(column - 1, 0),
            row: max(row - 1, 0)
        )

        if encodedButton & 32 != 0 {
            return .pointerMotion(
                PointerMotion(
                    button: pointerButton(for: buttonCode, allowsNoButton: true),
                    location: location,
                    modifiers: modifiers
                )
            )
        }

        if let delta = pointerScrollDelta(for: buttonCode) {
            guard final == "M" else {
                return TerminalInput.none
            }
            return .pointerScroll(
                PointerScroll(
                    delta: delta,
                    location: location,
                    modifiers: modifiers
                )
            )
        }

        guard let button = pointerButton(for: buttonCode, allowsNoButton: false) else {
            return TerminalInput.none
        }
        return .pointerPress(
            PointerPress(
                button: button,
                location: location,
                modifiers: modifiers,
                phase: final == "M" ? .down : .up
            )
        )
    }

    private static func pointerButton(
        for buttonCode: Int,
        allowsNoButton: Bool
    ) -> PointerButton? {
        switch buttonCode {
        case 0:
            return .left
        case 1:
            return .middle
        case 2:
            return .right
        case 3 where allowsNoButton:
            return nil
        default:
            return .other(buttonCode)
        }
    }

    private static func pointerScrollDelta(
        for buttonCode: Int
    ) -> Size? {
        switch buttonCode {
        case 64:
            return Size(columns: 0, rows: -1)
        case 65:
            return Size(columns: 0, rows: 1)
        case 66:
            return Size(columns: 1, rows: 0)
        case 67:
            return Size(columns: -1, rows: 0)
        default:
            return nil
        }
    }

    private static func pointerModifiers(for encodedButton: Int) -> EventModifiers {
        var modifiers: EventModifiers = []
        if encodedButton & 4 != 0 {
            modifiers.insert(.shift)
        }
        if encodedButton & 8 != 0 {
            modifiers.insert(.option)
        }
        if encodedButton & 16 != 0 {
            modifiers.insert(.control)
        }
        return modifiers
    }

    private static func asciiInput(for byte: UInt8) -> KeyPress? {
        switch byte {
        case 8, 127:
            return keyPress(for: .delete)
        case 9:
            return keyPress(for: .tab)
        case 10, 13:
            return keyPress(for: .return)
        case 27:
            return keyPress(for: .escape)
        case 32:
            return keyPress(for: .space)
        case 1...7, 11...12, 14...26:
            let scalar = UnicodeScalar(byte + 96)
            let character = Character(scalar)
            return KeyPress(
                key: KeyEquivalent(character),
                characters: String(character),
                modifiers: .control
            )
        case 33...126:
            let scalar = UnicodeScalar(byte)
            let character = Character(scalar)
            return KeyPress(
                key: KeyEquivalent(character),
                characters: String(character)
            )
        default:
            return nil
        }
    }

    private static func keyPress(
        for key: KeyEquivalent,
        modifiers: EventModifiers = []
    ) -> KeyPress {
        KeyPress(
            key: key,
            characters: String(key.character),
            modifiers: modifiers
        )
    }
}

nonisolated final class TerminalIO {

    private static let clipboardResponsePrefix = Array("\u{001B}]52;c;".utf8)

    private static let clipboardResponseByteTimeout: TimeInterval = 0.1

    private let readTerminalByte: (TimeInterval?) -> UInt8?

    private let readInterruptibleTerminalByte: (TimeInterval?) -> UInt8?

    private let writeOutput: (String) -> Void

    private var pendingInputBytes: [UInt8] = []

    private var pendingInputOffset = 0

    init(
        readByte: @escaping (TimeInterval?) -> UInt8?,
        readInterruptibleByte: ((TimeInterval?) -> UInt8?)? = nil,
        write: @escaping (String) -> Void
    ) {
        self.readTerminalByte = readByte
        self.readInterruptibleTerminalByte = readInterruptibleByte ?? readByte
        self.writeOutput = write
    }

    func readInput(timeout: TimeInterval? = nil) -> TerminalInput {
        var isFirstRead = true
        return TerminalControl.readInput(timeout: timeout) {
            [self]
            timeout in

            let readByte = isFirstRead
                ? readInterruptibleTerminalByte
                : readTerminalByte
            isFirstRead = false
            return readBufferedByte(timeout: timeout, readByte: readByte)
        }
    }

    func copy(_ text: String) {
        writeOutput(TerminalControl.copyToClipboardSequence(text))
    }

    func paste() -> String? {
        writeOutput(TerminalControl.pasteFromClipboardSequence)
        return readClipboardResponse()
    }

    private func readClipboardResponse() -> String? {
        var candidate: [UInt8] = []
        while let byte = readTerminalByte(Self.clipboardResponseByteTimeout) {
            candidate.append(byte)
            while !Self.clipboardResponsePrefix.starts(with: candidate) {
                enqueueInput(candidate.removeFirst())
            }
            if candidate == Self.clipboardResponsePrefix {
                return readClipboardPayload()
            }
        }

        enqueueInput(candidate)
        return nil
    }

    private func readClipboardPayload() -> String? {
        var payload: [UInt8] = []
        while let byte = readTerminalByte(Self.clipboardResponseByteTimeout) {
            switch byte {
            case 7:
                return decodeClipboardPayload(payload)
            case 27:
                guard let terminator = readTerminalByte(Self.clipboardResponseByteTimeout),
                      terminator == 92 else {
                    return nil
                }
                return decodeClipboardPayload(payload)
            default:
                payload.append(byte)
            }
        }

        return nil
    }

    private func decodeClipboardPayload(_ payload: [UInt8]) -> String? {
        guard let encoded = String(bytes: payload, encoding: .ascii),
              let data = Data(base64Encoded: encoded) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func readBufferedByte(
        timeout: TimeInterval?,
        readByte: (TimeInterval?) -> UInt8?
    ) -> UInt8? {
        if pendingInputOffset < pendingInputBytes.count {
            let byte = pendingInputBytes[pendingInputOffset]
            pendingInputOffset += 1
            if pendingInputOffset == pendingInputBytes.count {
                pendingInputBytes.removeAll(keepingCapacity: true)
                pendingInputOffset = 0
            }
            return byte
        }

        return readByte(timeout)
    }

    private func enqueueInput(_ byte: UInt8) {
        pendingInputBytes.append(byte)
    }

    private func enqueueInput(_ bytes: [UInt8]) {
        pendingInputBytes.append(contentsOf: bytes)
    }
}

/// Serializes terminal input parsing away from the main actor.
///
/// The queue is the only execution context that accesses `io`. The mutex makes
/// that ownership visible to Swift's sendability checker, while `readState`
/// lets the main actor observe whether it must wake a blocking first-byte read
/// without waiting for the I/O mutex itself.
nonisolated final class TerminalInputWorker: Sendable {

    private struct ReadState {

        var isReading = false

        var isStopped = false
    }

    private let queue = DispatchQueue(label: "SwiftTUI.TerminalInput")

    private let io: Mutex<TerminalIO>

    private let readState = Mutex(ReadState())

    private let wakeup: TerminalInputWakeup

    init(
        inputDescriptor: FileDescriptor,
        outputDescriptor: FileDescriptor
    ) throws {
        let wakeup = try TerminalInputWakeup()
        self.wakeup = wakeup
        self.io = Mutex(
            TerminalIO(
                readByte: {
                    TerminalControl.readByte(
                        from: inputDescriptor,
                        timeout: $0
                    )
                },
                readInterruptibleByte: {
                    TerminalControl.readByte(
                        from: inputDescriptor,
                        timeout: $0,
                        interruptedBy: wakeup
                    )
                },
                write: {
                    TerminalControl.write($0, to: outputDescriptor)
                }
            )
        )
    }

    deinit {
        stop()
    }

    func requestInput(
        deliver: @escaping @Sendable (TerminalInput) -> Void
    ) {
        guard beginRead() else {
            return
        }

        queue.async {
            [self] in

            let input = io.withLock {
                $0.readInput()
            }
            guard finishRead() else {
                return
            }

            deliver(input)
        }
    }

    /// Reads buffered input without waiting behind an active asynchronous read.
    ///
    /// If another read owns the worker or the worker has stopped, this method
    /// returns `.none` instead of entering the serial queue.
    func readPendingInput() -> TerminalInput {
        guard beginRead() else {
            return .none
        }
        defer {
            _ = finishRead()
        }

        return queue.sync {
            io.withLock {
                $0.readInput(timeout: 0)
            }
        }
    }

    func paste() -> String? {
        interruptRead()
        return queue.sync {
            io.withLock {
                $0.paste()
            }
        }
    }

    func copy(_ text: String) {
        interruptRead()
        queue.sync {
            io.withLock {
                $0.copy(text)
            }
        }
    }

    func stop() {
        let shouldInterrupt = readState.withLock {
            guard !$0.isStopped else {
                return false
            }

            $0.isStopped = true
            return $0.isReading
        }
        if shouldInterrupt {
            wakeup.signal()
        }
        queue.sync {}
    }

    private func beginRead() -> Bool {
        readState.withLock {
            guard !$0.isReading, !$0.isStopped else {
                return false
            }

            $0.isReading = true
            return true
        }
    }

    private func finishRead() -> Bool {
        readState.withLock {
            $0.isReading = false
            return !$0.isStopped
        }
    }

    private func interruptRead() {
        let isReading = readState.withLock {
            $0.isReading && !$0.isStopped
        }
        if isReading {
            wakeup.signal()
        }
    }
}

final class TerminalSession {

    private let original: Termios

    private let raw: Termios

    private let inputDescriptor: FileDescriptor

    private let outputDescriptor: FileDescriptor

    private let inputWorker: TerminalInputWorker

    private let pendingInputs = Mutex<[TerminalInput]>([])

    private var previousWindowChangeHandler: (@convention(c) (Int32) -> Void)?

    private var windowChangeSource: (any DispatchSourceSignal)?

    private var isActive = false

    init(
        inputDescriptor: FileDescriptor = .standardInput,
        outputDescriptor: FileDescriptor = .standardOutput
    ) throws {
        let original = try Termios(readingFrom: inputDescriptor)
        var raw = original
        raw.makeRaw()
        self.original = original
        self.raw = raw
        self.inputDescriptor = inputDescriptor
        self.outputDescriptor = outputDescriptor
        self.inputWorker = try TerminalInputWorker(
            inputDescriptor: inputDescriptor,
            outputDescriptor: outputDescriptor
        )
    }

    func requestInput() {
        inputWorker.requestInput {
            [weak self]
            input in

            self?.pendingInputs.withLock {
                $0.append(input)
            }
            MainRunLoopWakeup.signal()
        }
    }

    func takeInput() -> TerminalInput? {
        pendingInputs.withLock {
            guard !$0.isEmpty else {
                return nil
            }

            return $0.removeFirst()
        }
    }

    func readPendingInput() -> TerminalInput {
        inputWorker.readPendingInput()
    }

    func currentTerminalSize() -> TerminalViewportSize {
        TerminalControl.currentTerminalSize(for: outputDescriptor)
    }

    func write(_ output: String) {
        TerminalControl.write(output, to: outputDescriptor)
    }

    func copy(_ text: String) {
        inputWorker.copy(text)
    }

    func paste() -> String? {
        inputWorker.paste()
    }

    func start() throws {
        guard !isActive else {
            return
        }

        try raw.apply(to: inputDescriptor, when: .now)
        previousWindowChangeHandler = signal(SIGWINCH, SIG_IGN)
        let windowChangeSource = DispatchSource.makeSignalSource(
            signal: SIGWINCH,
            queue: .main
        )
        windowChangeSource.setEventHandler {
            MainRunLoopWakeup.signal()
        }
        windowChangeSource.resume()
        self.windowChangeSource = windowChangeSource
        write(TerminalControl.enterAlternateScreenSequence)
        write(TerminalControl.enablePointerTrackingSequence)
        write(TerminalControl.enableFocusReportingSequence)
        write(TerminalControl.hideCaretSequence)
        isActive = true
    }

    func stopReading() {
        inputWorker.stop()
        pendingInputs.withLock {
            $0 = []
        }
    }

    func stop() {
        guard isActive else {
            return
        }

        stopReading()
        try? original.apply(to: inputDescriptor, when: .now)
        windowChangeSource?.cancel()
        windowChangeSource = nil
        if let previousWindowChangeHandler {
            _ = signal(SIGWINCH, previousWindowChangeHandler)
            self.previousWindowChangeHandler = nil
        }
        write(TerminalControl.showCaretSequence)
        write(TerminalControl.disableFocusReportingSequence)
        write(TerminalControl.disablePointerTrackingSequence)
        write(TerminalControl.exitAlternateScreenSequence)
        isActive = false
    }
}
