import Foundation
import Dispatch
import Observation
import Synchronization
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

#if canImport(System)
import System
#else
import SystemPackage
#endif

@Suite("Terminal I/O and Control")
struct TerminalIOAndControlTests {

    @Test
    func `terminal control sequences match alternate-screen, caret, and pointer-tracking protocols`() {
        #expect(TerminalControl.enterAlternateScreenSequence == "\u{001B}[?1049h")
        #expect(TerminalControl.hideCaretSequence == "\u{001B}[?25l")
        #expect(TerminalControl.showCaretSequence == "\u{001B}[?25h")
        #expect(TerminalControl.exitAlternateScreenSequence == "\u{001B}[?1049l")
        #expect(TerminalControl.enablePointerTrackingSequence == "\u{001B}[?1003h\u{001B}[?1006h")
        #expect(TerminalControl.disablePointerTrackingSequence == "\u{001B}[?1006l\u{001B}[?1003l")
        #expect(TerminalControl.enableFocusReportingSequence == "\u{001B}[?1004h")
        #expect(TerminalControl.disableFocusReportingSequence == "\u{001B}[?1004l")
    }

    @Test
    func `OSC 52 copy sequences Base64-encode UTF-8 text and the paste sequence requests clipboard contents`() {
        #expect(TerminalControl.copyToClipboardSequence("") == "\u{001B}]52;c;\u{001B}\\")
        #expect(
            TerminalControl.copyToClipboardSequence("A한")
                == "\u{001B}]52;c;Qe2VnA==\u{001B}\\"
        )
        #expect(TerminalControl.pasteFromClipboardSequence == "\u{001B}]52;c;?\u{001B}\\")
    }

    @Test
    func `terminal clipboard decodes OSC 52 responses terminated by BEL or ST`() {
        let expected = "A👨‍👩‍👧‍👦한"
        for terminator in ["\u{0007}", "\u{001B}\\"] {
            let probe = TerminalIOProbe(
                input: osc52ClipboardResponse(expected, terminator: terminator)
            )
            let terminal = probe.terminalIO()

            #expect(terminal.paste() == expected)
            #expect(probe.output == [TerminalControl.pasteFromClipboardSequence])
            #expect(probe.timeouts.allSatisfy { $0 == 0.1 })
        }
    }

    @Test
    func `terminal clipboard decodes OSC 52 responses longer than ordinary input escape sequences`() {
        let expected = String(repeating: "긴 clipboard text ", count: 512)
        let probe = TerminalIOProbe(input: osc52ClipboardResponse(expected))

        #expect(probe.terminalIO().paste() == expected)
    }

    @Test
    func `terminal clipboard returns nil after timeouts or malformed OSC 52 responses`() {
        let timeoutProbe = TerminalIOProbe(input: [])
        #expect(timeoutProbe.terminalIO().paste() == nil)
        #expect(timeoutProbe.timeouts == [0.1])

        let invalidBase64 = TerminalIOProbe(
            input: Array("\u{001B}]52;c;***\u{0007}".utf8)
        )
        #expect(invalidBase64.terminalIO().paste() == nil)

        let invalidUTF8Payload = Data([0xFF]).base64EncodedString()
        let invalidUTF8 = TerminalIOProbe(
            input: Array("\u{001B}]52;c;\(invalidUTF8Payload)\u{0007}".utf8)
        )
        #expect(invalidUTF8.terminalIO().paste() == nil)

        let incomplete = TerminalIOProbe(
            input: Array("\u{001B}]52;c;SGVsbG8=".utf8)
        )
        #expect(incomplete.terminalIO().paste() == nil)
    }

    @Test
    func `clipboard queries preserve unrelated key and pointer input for later reads`() {
        let pointerBytes = Array("\u{001B}[<0;2;3M".utf8)
        let response = osc52ClipboardResponse("clipboard")
        let probe = TerminalIOProbe(input: Array("a".utf8) + pointerBytes + response)
        let terminal = probe.terminalIO()

        #expect(terminal.paste() == "clipboard")
        #expect(
            terminal.readInput(timeout: 0)
                == .keyPress(KeyPress(key: "a", characters: "a"))
        )
        #expect(
            terminal.readInput(timeout: 0)
                == .pointerPress(
                    PointerPress(
                        button: .left,
                        location: Point(column: 1, row: 2),
                        phase: .down
                    )
                )
        )
    }

    @Test
    func `a timed-out clipboard query preserves a pending Escape key for later input`() {
        let probe = TerminalIOProbe(input: [27])
        let terminal = probe.terminalIO()

        #expect(terminal.paste() == nil)
        #expect(
            terminal.readInput(timeout: 0)
                == .keyPress(KeyPress(key: .escape, characters: "\u{001B}"))
        )
    }

    @Test
    func `an idle terminal read returns when interrupted without consuming later input`() throws {
        let input = try FileDescriptor.pipe()
        defer {
            try? input.readEnd.close()
            try? input.writeEnd.close()
        }
        let wakeup = try TerminalInputWakeup()
        let result = Mutex<[UInt8?]>([])
        let completed = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            result.withLock {
                $0.append(
                    TerminalControl.readByte(
                        from: input.readEnd,
                        timeout: nil,
                        interruptedBy: wakeup
                    )
                )
            }
            completed.signal()
        }

        Thread.sleep(forTimeInterval: 0.01)
        wakeup.signal()
        #expect(completed.wait(timeout: .now() + 1) == .success)
        #expect(result.withLock { $0.count == 1 && $0[0] == nil })

        try input.writeEnd.writeAll([97])
        #expect(TerminalControl.readByte(from: input.readEnd, timeout: 0) == 97)
    }

    @Test
    func `a clipboard query interrupts the idle reader and preserves unrelated pending input`() throws {
        let input = try FileDescriptor.pipe()
        let output = try FileDescriptor.pipe()
        defer {
            try? input.readEnd.close()
            try? input.writeEnd.close()
            try? output.readEnd.close()
            try? output.writeEnd.close()
        }
        let worker = try TerminalInputWorker(
            inputDescriptor: input.readEnd,
            outputDescriptor: output.writeEnd
        )
        defer { worker.stop() }
        worker.requestInput { _ in }

        let responded = DispatchSemaphore(value: 0)
        let response = Array("a".utf8) + osc52ClipboardResponse("clipboard")
        DispatchQueue.global().async {
            let expected = Array(TerminalControl.pasteFromClipboardSequence.utf8)
            var request: [UInt8] = []
            while request.count < expected.count,
                  let byte = TerminalControl.readByte(from: output.readEnd, timeout: 1) {
                request.append(byte)
            }
            if request == expected {
                _ = try? input.writeEnd.writeAll(response)
            }
            responded.signal()
        }

        #expect(worker.paste() == "clipboard")
        #expect(responded.wait(timeout: .now() + 1) == .success)
        #expect(
            worker.readInput(timeout: 0)
                == .keyPress(KeyPress(key: "a", characters: "a"))
        )
    }

    @Test
    func `the viewport tracker skips redraw for an unchanged viewport`() {
        let viewport = TerminalViewportSize(columns: 80, rows: 24)
        let tracker = TerminalViewportTracker(renderedViewport: viewport)

        #expect(!tracker.needsRedraw(for: viewport))
    }

    @Test
    func `the viewport tracker requests redraw when either viewport dimension changes`() {
        let tracker = TerminalViewportTracker(
            renderedViewport: TerminalViewportSize(columns: 80, rows: 24)
        )

        #expect(tracker.needsRedraw(for: TerminalViewportSize(columns: 100, rows: 24)))
        #expect(tracker.needsRedraw(for: TerminalViewportSize(columns: 80, rows: 30)))
    }

    @Test
    func `updating the rendered viewport clears the pending redraw`() {
        var tracker = TerminalViewportTracker(
            renderedViewport: TerminalViewportSize(columns: 80, rows: 24)
        )
        let resizedViewport = TerminalViewportSize(columns: 100, rows: 30)

        #expect(tracker.needsRedraw(for: resizedViewport))

        tracker.update(renderedViewport: resizedViewport)

        #expect(!tracker.needsRedraw(for: resizedViewport))
    }

    @Test
    func `Control-C requests quit while Escape and printable bytes produce key presses`() {
        #expect(TerminalControl.input(for: 3) == .quit)
        #expect(TerminalControl.input(for: 27) == .keyPress(KeyPress(key: .escape, characters: "\u{001B}")))
        #expect(TerminalControl.input(for: 113) == .keyPress(KeyPress(key: "q", characters: "q")))
    }
}
