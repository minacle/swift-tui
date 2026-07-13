import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Input Event Semantics")
struct InputEventSemanticsTests {

    @Test
    func `terminal geometry types preserve negative components and default to zero`() {
        let size = Size(columns: -1, rows: -2)
        let point = Point(column: -3, row: -4)
        let frame = Rect(origin: point, size: size)

        #expect(size.columns == -1)
        #expect(size.rows == -2)
        #expect(point.column == -3)
        #expect(point.row == -4)
        #expect(frame.origin == point)
        #expect(frame.size == size)
        #expect(Size() == .zero)
        #expect(Point() == .zero)
        #expect(Rect() == .zero)
    }

    @Test
    func `input event value types preserve stored data, expose option-set membership, and distinguish handled from ignored results`() {
        let key: KeyEquivalent = "a"
        let modifiers: EventModifiers = [.shift, .control]
        let phases: KeyPress.Phases = [.down, .repeat]
        let pointer = PointerPress(
            button: .left,
            location: Point(column: 1, row: 2),
            modifiers: .shift,
            phase: .down
        )

        #expect(key.character == "a")
        #expect(KeyEquivalent.upArrow.character == "\u{F700}")
        #expect(EventModifiers.all.contains(.command))
        #expect(modifiers.contains(.shift))
        #expect(modifiers.contains(.control))
        #expect(!modifiers.contains(.option))
        #expect(KeyPress.Phases.all.contains(.up))
        #expect(phases.contains(.down))
        #expect(phases.contains(.repeat))
        #expect(InputEventResult.handled != .ignored)
        #expect(PointerPress.Phases.all.contains(.down))
        #expect(PointerPress.Phases.all.contains(.up))
        #expect(InputEventResult.handled != .ignored)
        #expect(
            PointerPress(
                button: .left,
                location: Point(column: 1, row: 2),
                modifiers: .shift,
                phase: .down
            ).location == Point(column: 1, row: 2)
        )
        #expect(pointer.button == .left)
        #expect(pointer.location == Point(column: 1, row: 2))
        #expect(pointer.modifiers == .shift)
        #expect(pointer.phase == .down)
    }

    @Test
    func `the terminal parser converts ASCII and multibyte UTF-8 characters into key presses`() {
        #expect(TerminalControl.input(for: [65]) == .keyPress(KeyPress(key: "A", characters: "A")))
        #expect(
            TerminalControl.input(for: Array("é".utf8))
                == .keyPress(KeyPress(key: "é", characters: "é"))
        )
        #expect(
            TerminalControl.input(for: Array("한".utf8))
                == .keyPress(KeyPress(key: "한", characters: "한"))
        )
    }

    @Test
    func `terminal readInput assembles a complete UTF-8 character with continuation timeouts`() {
        var bytes = Array("한".utf8)
        var requestedTimeouts: [TimeInterval?] = []

        let input = TerminalControl.readInput(timeout: 1) { timeout in
            requestedTimeouts.append(timeout)
            guard !bytes.isEmpty else {
                return nil
            }

            return bytes.removeFirst()
        }

        #expect(input == .keyPress(KeyPress(key: "한", characters: "한")))
        #expect(requestedTimeouts == [1, 0.1, 0.1])
    }

    @Test
    func `terminal readInput returns no event when a UTF-8 sequence remains incomplete after a timeout`() {
        var bytes = [Array("한".utf8)[0]]
        var requestedTimeouts: [TimeInterval?] = []

        let input = TerminalControl.readInput { timeout in
            requestedTimeouts.append(timeout)
            guard !bytes.isEmpty else {
                return nil
            }

            return bytes.removeFirst()
        }

        #expect(input == .none)
        #expect(requestedTimeouts == [nil, 0.1])
    }

    @Test
    func `terminal readInput recovers from incomplete UTF-8 and parses a following escape sequence`() {
        var escapeBytes = [Array("한".utf8)[0], 27]

        #expect(
            TerminalControl.readInput {
                _ in

                guard !escapeBytes.isEmpty else {
                    return nil
                }

                return escapeBytes.removeFirst()
            } == .keyPress(KeyPress(key: .escape, characters: "\u{001B}"))
        )

        var arrowBytes = [Array("한".utf8)[0], 27, 91, 65]

        #expect(
            TerminalControl.readInput {
                _ in

                guard !arrowBytes.isEmpty else {
                    return nil
                }

                return arrowBytes.removeFirst()
            } == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}"))
        )
    }

    @Test
    func `terminal readInput returns a lone Escape after a nonblocking lookahead`() {
        var bytes: [UInt8] = [27]
        var requestedTimeouts: [TimeInterval?] = []

        let input = TerminalControl.readInput {
            timeout in

            requestedTimeouts.append(timeout)
            guard !bytes.isEmpty else {
                return nil
            }

            return bytes.removeFirst()
        }

        #expect(input == .keyPress(KeyPress(key: .escape, characters: "\u{001B}")))
        #expect(requestedTimeouts == [nil, 0])
    }

    @Test
    func `terminal readInput uses a continuation timeout to complete a buffered escape sequence`() {
        var bytes: [UInt8] = [27, 91, 65]
        var requestedTimeouts: [TimeInterval?] = []

        let input = TerminalControl.readInput {
            timeout in

            requestedTimeouts.append(timeout)
            guard !bytes.isEmpty else {
                return nil
            }

            return bytes.removeFirst()
        }

        #expect(input == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}")))
        #expect(requestedTimeouts == [nil, 0, 0.1])
    }

    @Test
    func `terminal readInput returns no event when a CSI sequence times out after its second byte`() {
        var bytes: [UInt8] = [27, 91]
        var requestedTimeouts: [TimeInterval?] = []

        let input = TerminalControl.readInput {
            timeout in

            requestedTimeouts.append(timeout)
            guard !bytes.isEmpty else {
                return nil
            }

            return bytes.removeFirst()
        }

        #expect(input == .none)
        #expect(requestedTimeouts == [nil, 0, 0.1])
    }

    @Test
    func `terminal readInput rejects Escape followed by an unknown printable byte`() {
        var bytes: [UInt8] = [27, 97]
        var requestedTimeouts: [TimeInterval?] = []

        let input = TerminalControl.readInput {
            timeout in

            requestedTimeouts.append(timeout)
            guard !bytes.isEmpty else {
                return nil
            }

            return bytes.removeFirst()
        }

        #expect(input == .none)
        #expect(requestedTimeouts == [nil, 0])
    }

    @Test
    func `the terminal parser maps control-letter bytes to lowercase keys with the Control modifier`() {
        #expect(
            TerminalControl.input(for: 1)
                == .keyPress(KeyPress(key: "a", characters: "a", modifiers: .control))
        )
        #expect(
            TerminalControl.input(for: 26)
                == .keyPress(KeyPress(key: "z", characters: "z", modifiers: .control))
        )
    }

    @Test
    func `the terminal parser maps Return, Tab, Space, and Delete bytes to special keys`() {
        #expect(TerminalControl.input(for: 13) == .keyPress(KeyPress(key: .return, characters: "\r")))
        #expect(TerminalControl.input(for: 10) == .keyPress(KeyPress(key: .return, characters: "\r")))
        #expect(TerminalControl.input(for: 9) == .keyPress(KeyPress(key: .tab, characters: "\t")))
        #expect(TerminalControl.input(for: 32) == .keyPress(KeyPress(key: .space, characters: " ")))
        #expect(TerminalControl.input(for: 8) == .keyPress(KeyPress(key: .delete, characters: "\u{0008}")))
        #expect(TerminalControl.input(for: 127) == .keyPress(KeyPress(key: .delete, characters: "\u{0008}")))
    }

    @Test
    func `the terminal parser maps navigation CSI sequences and Shift modifiers while rejecting unknown sequences`() {
        #expect(TerminalControl.input(for: [27, 91, 65]) == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}")))
        #expect(TerminalControl.input(for: [27, 91, 66]) == .keyPress(KeyPress(key: .downArrow, characters: "\u{F701}")))
        #expect(TerminalControl.input(for: [27, 91, 67]) == .keyPress(KeyPress(key: .rightArrow, characters: "\u{F703}")))
        #expect(TerminalControl.input(for: [27, 91, 68]) == .keyPress(KeyPress(key: .leftArrow, characters: "\u{F702}")))
        #expect(TerminalControl.input(for: [27, 91, 72]) == .keyPress(KeyPress(key: .home, characters: "\u{F729}")))
        #expect(TerminalControl.input(for: [27, 91, 70]) == .keyPress(KeyPress(key: .end, characters: "\u{F72B}")))
        #expect(TerminalControl.input(for: [27, 91, 53, 126]) == .keyPress(KeyPress(key: .pageUp, characters: "\u{F72C}")))
        #expect(TerminalControl.input(for: [27, 91, 54, 126]) == .keyPress(KeyPress(key: .pageDown, characters: "\u{F72D}")))
        #expect(TerminalControl.input(for: [27, 91, 51, 126]) == .keyPress(KeyPress(key: .deleteForward, characters: "\u{F728}")))
        #expect(TerminalControl.input(for: [27, 91, 49, 59, 50, 65]) == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}", modifiers: .shift)))
        #expect(TerminalControl.input(for: [27, 91, 49, 59, 50, 66]) == .keyPress(KeyPress(key: .downArrow, characters: "\u{F701}", modifiers: .shift)))
        #expect(TerminalControl.input(for: [27, 91, 49, 59, 50, 67]) == .keyPress(KeyPress(key: .rightArrow, characters: "\u{F703}", modifiers: .shift)))
        #expect(TerminalControl.input(for: [27, 91, 49, 59, 50, 68]) == .keyPress(KeyPress(key: .leftArrow, characters: "\u{F702}", modifiers: .shift)))
        #expect(TerminalControl.input(for: [27, 91, 49, 59, 50, 72]) == .keyPress(KeyPress(key: .home, characters: "\u{F729}", modifiers: .shift)))
        #expect(TerminalControl.input(for: [27, 91, 49, 59, 50, 70]) == .keyPress(KeyPress(key: .end, characters: "\u{F72B}", modifiers: .shift)))
        #expect(TerminalControl.input(for: [27, 91, 90]) == .none)
    }

    @Test
    func `terminal escape-sequence detection distinguishes partial SGR input from complete sequences`() {
        #expect(TerminalControl.escapeSequenceIsComplete([27]))
        #expect(!TerminalControl.escapeSequenceIsComplete(Array("\u{001B}[<64;88;17".utf8)))
        #expect(TerminalControl.escapeSequenceIsComplete(Array("\u{001B}[<64;88;17M".utf8)))
        #expect(TerminalControl.escapeSequenceIsComplete([27, 91, 65]))
        #expect(TerminalControl.escapeSequenceIsComplete([27, 91, 51, 126]))
    }

    @Test
    func `the terminal parser reports focus-in and focus-out control sequences`() {
        #expect(TerminalControl.input(for: Array("\u{001B}[I".utf8)) == .focusIn)
        #expect(TerminalControl.input(for: Array("\u{001B}[O".utf8)) == .focusOut)
    }

    @Test
    func `the terminal parser decodes SGR pointer buttons, phases, modifiers, motion, and coordinates while rejecting malformed input`() {
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<0;12;3M".utf8))
                == .pointerPress(
                    PointerPress(
                        button: .left,
                        location: Point(column: 11, row: 2),
                        phase: .down
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<0;12;3m".utf8))
                == .pointerPress(
                    PointerPress(
                        button: .left,
                        location: Point(column: 11, row: 2),
                        phase: .up
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<20;1;2M".utf8))
                == .pointerPress(
                    PointerPress(
                        button: .left,
                        location: Point(column: 0, row: 1),
                        modifiers: [.shift, .control],
                        phase: .down
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<32;12;3M".utf8))
                == .pointerMotion(
                    PointerMotion(
                        button: .left,
                        location: Point(column: 11, row: 2),
                        modifiers: []
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<52;1;2M".utf8))
                == .pointerMotion(
                    PointerMotion(
                        button: .left,
                        location: Point(column: 0, row: 1),
                        modifiers: [.shift, .control],
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<35;8;9M".utf8))
                == .pointerMotion(
                    PointerMotion(
                        button: nil,
                        location: Point(column: 7, row: 8),
                        modifiers: []
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<2;4;5M".utf8))
                == .pointerPress(
                    PointerPress(
                        button: .right,
                        location: Point(column: 3, row: 4),
                        phase: .down
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<64;6;7M".utf8))
                == .pointerScroll(
                    PointerScroll(
                        delta: Size(columns: 0, rows: -1),
                        location: Point(column: 5, row: 6),
                        modifiers: []
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<65;6;7M".utf8))
                == .pointerScroll(
                    PointerScroll(
                        delta: Size(columns: 0, rows: 1),
                        location: Point(column: 5, row: 6),
                        modifiers: []
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<66;6;7M".utf8))
                == .pointerScroll(
                    PointerScroll(
                        delta: Size(columns: 1, rows: 0),
                        location: Point(column: 5, row: 6),
                        modifiers: []
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<67;6;7M".utf8))
                == .pointerScroll(
                    PointerScroll(
                        delta: Size(columns: -1, rows: 0),
                        location: Point(column: 5, row: 6),
                        modifiers: []
                    )
                )
        )
        #expect(
            TerminalControl.input(for: Array("\u{001B}[<68;6;7M".utf8))
                == .pointerScroll(
                    PointerScroll(
                        delta: Size(columns: 0, rows: -1),
                        location: Point(column: 5, row: 6),
                        modifiers: .shift
                    )
                )
        )
        #expect(TerminalControl.input(for: Array("\u{001B}[<64;6;7m".utf8)) == .none)
        #expect(TerminalControl.input(for: Array("\u{001B}[<0;12M".utf8)) == .none)
    }

    @Test
    func `hidden views omit rendering, hit regions, scrolling, focus, and all input handlers`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = VStack(spacing: 0) {
            Button("Run") {
                tapProbe.record("button")
            }
            Text("Key")
                .focusable()
                .onKeyPress("k") {
                    tapProbe.record("key")
                    return .handled
                }
                .onTapGesture {
                    tapProbe.record("tap")
                }
                .onLongPressGesture {
                    tapProbe.record("long")
                }
                .onPointerPress {
                    tapProbe.record("pointer")
                    return .handled
                }
                .onHover { _ in
                    tapProbe.record("hover")
                }
                .onContinuousHover { _ in
                    tapProbe.record("continuous-hover")
                }
            ScrollView(.vertical) {
                Text("A")
                Text("B")
            }
        }
        .hidden()

        let block = runtime.block(from: view, in: RenderProposal(columns: 5, rows: 2))

        #expect(block?.runs == [])
        #expect(block?.hitRegions == [])
        #expect(block?.scrollRegions == [])
        #expect(block?.focusRegions == [])
        #expect(runtime.dispatch(KeyPress(key: "k", characters: "k")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
        dispatchHover(to: runtime, column: 1, row: 1, expecting: .ignored)
        #expect(runtime.dispatchExpiredLongPressActions() == .ignored)
        #expect(tapProbe.events.isEmpty)
    }

    @Test
    func `disabled views reject focus and suppress focused-key, global-key, pointer-press, tap, and hover handlers`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<Bool>()
        let keyProbe = KeyPressProbe()
        let tapProbe = TapGestureProbe()
        let view = DisabledInputModifiersView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            tapProbe: tapProbe
        )

        #expect(runtime.block(from: view)?.text == "A")
        #expect(focusProbe.binding?.wrappedValue == false)
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: "g", characters: "g")) == .ignored)
        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
        dispatchHover(to: runtime, column: 1, row: 1, expecting: .ignored)
        #expect(runtime.dispatchExpiredLongPressActions() == .ignored)
        #expect(keyProbe.events.isEmpty)
        #expect(tapProbe.events.isEmpty)
    }
}
