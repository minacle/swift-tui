import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Shortcut Convenience")
struct ShortcutConvenienceTests {

    @Test
    func `onTapShortcut performs after an exact down-up pair`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .onTapShortcut("s", modifiers: .control) {
                probe.events.append("tap")
            }

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .up, to: runtime)
        #expect(probe.events.isEmpty)

        dispatchShortcutKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchShortcutKey("s", modifiers: .control, phase: .up, to: runtime)
        #expect(probe.events == ["tap"])
    }

    @Test
    func `an outer tap count runs after an inner higher count times out`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime(now: { probe.date })
        let view = Text("A")
            .onTapShortcut("s", count: 2) {
                probe.events.append("inner-two")
            }
            .onTapShortcut("s") {
                probe.events.append("outer-one")
            }

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .up, to: runtime)
        #expect(probe.events.isEmpty)

        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        #expect(probe.events == ["outer-one"])
    }

    @Test
    func `an inner tap count recognizes before its outer fallback`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime(now: { probe.date })
        let view = Text("A")
            .onTapShortcut("s", count: 2) {
                probe.events.append("inner-two")
            }
            .onTapShortcut("s") {
                probe.events.append("outer-one")
            }

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .up, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.1)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["inner-two"])
    }

    @Test
    func `onLongPressShortcut reports pressing changes and performs at its deadline`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime(now: { probe.date })
        let view = Text("A")
            .onLongPressShortcut(
                "s",
                minimumDuration: 0.5,
                perform: { probe.events.append("long") },
                onPressingChanged: {
                    probe.events.append("pressing-\($0)")
                }
            )

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .repeat, to: runtime)
        #expect(probe.events == ["pressing-true"])

        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        #expect(probe.events == ["pressing-true", "long"])

        dispatchShortcutKey("s", phase: .up, to: runtime)
        #expect(probe.events == ["pressing-true", "long", "pressing-false"])
    }

    @Test
    func `releasing before a long press deadline lets a tap shortcut recognize`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime(now: { probe.date })
        let view = Text("A")
            .onTapShortcut("s") {
                probe.events.append("tap")
            }
            .onLongPressShortcut(
                "s",
                minimumDuration: 0.5,
                perform: { probe.events.append("long") },
                onPressingChanged: {
                    probe.events.append("pressing-\($0)")
                }
            )

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.1)
        dispatchShortcutKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["pressing-true", "pressing-false", "tap"])
    }

    @Test
    func `different modifier combinations use independent shortcut groups`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .onTapShortcut("s") {
                probe.events.append("plain")
            }
            .onTapShortcut("s", modifiers: .control) {
                probe.events.append("control")
            }

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .up, to: runtime)
        dispatchShortcutKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchShortcutKey("s", modifiers: .control, phase: .up, to: runtime)

        #expect(probe.events == ["plain", "control"])
    }

    @Test
    func `a high-priority Shortcut defeats a view-defined tap shortcut`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .onTapShortcut("s") {
                probe.events.append("view-defined")
            }
            .highPriorityShortcut(
                TapShortcut("s")
                    .onEnded { probe.events.append("high") }
            )

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["high"])
    }

    @Test
    func `a view-defined tap shortcut defeats a normal Shortcut`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .shortcut(
                TapShortcut("s")
                    .onEnded { probe.events.append("normal") }
            )
            .onTapShortcut("s") {
                probe.events.append("view-defined")
            }

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        dispatchShortcutKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["view-defined"])
    }

    @Test
    func `scene cancellation ends a pressing callback without performing`() {
        let probe = ShortcutConvenienceProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .onLongPressShortcut(
                "s",
                perform: { probe.events.append("long") },
                onPressingChanged: {
                    probe.events.append("pressing-\($0)")
                }
            )

        _ = runtime.block(from: view)
        dispatchShortcutKey("s", phase: .down, to: runtime)
        runtime.dispatchSceneInactive()
        runtime.dispatchSceneInactive()

        #expect(probe.events == ["pressing-true", "pressing-false"])
    }
}

private final class ShortcutConvenienceProbe {
    var date = Date(timeIntervalSinceReferenceDate: 100)
    var events: [String] = []
}

private func dispatchShortcutKey(
    _ key: KeyEquivalent,
    modifiers: EventModifiers = [],
    phase: KeyPress.Phases,
    to runtime: StateRuntime
) {
    _ = runtime.dispatch(
        KeyPress(
            key: key,
            characters: String(key.character),
            modifiers: modifiers,
            phase: phase
        )
    )
}
