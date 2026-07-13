import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Shortcut Composition")
struct ShortcutCompositionTests {

    @Test
    func `ExclusiveShortcut replays an early release into its tap fallback`() {
        let probe = ShortcutCompositionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let shortcut = LongPressShortcut("s", minimumDuration: 0.5)
            .exclusively(before: TapShortcut("s"))
            .onEnded { value in
                switch value {
                case .first:
                    probe.events.append("long")
                case .second:
                    probe.events.append("tap")
                }
            }

        _ = runtime.block(from: Text("A").shortcut(shortcut))
        dispatchCompositionKey("s", phase: .down, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.1)
        dispatchCompositionKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["tap"])
    }

    @Test
    func `ExclusiveShortcut retains its preferred long press after success`() {
        let probe = ShortcutCompositionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let shortcut = LongPressShortcut("s", minimumDuration: 0.5)
            .exclusively(before: TapShortcut("s"))
            .onEnded { value in
                switch value {
                case .first:
                    probe.events.append("long")
                case .second:
                    probe.events.append("tap")
                }
            }

        _ = runtime.block(from: Text("A").shortcut(shortcut))
        dispatchCompositionKey("s", phase: .down, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        dispatchCompositionKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["long"])
    }

    @Test
    func `external cancellation does not activate an ExclusiveShortcut fallback`() {
        let probe = ShortcutCompositionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let shortcut = LongPressShortcut("s", minimumDuration: 0.5)
            .exclusively(before: TapShortcut("s"))
            .onEnded { _ in probe.events.append("ended") }

        _ = runtime.block(from: Text("A").shortcut(shortcut))
        dispatchCompositionKey("s", phase: .down, to: runtime)
        runtime.dispatchSceneInactive()

        #expect(probe.events.isEmpty)
    }

    @Test
    func `SimultaneousShortcut retains a completed long press until tap release`() {
        let probe = ShortcutCompositionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let shortcut = TapShortcut("s")
            .simultaneously(
                with: LongPressShortcut("s", minimumDuration: 0.5)
            )
            .onEnded { value in
                probe.events.append(
                    "tap-\(value.first != nil)-long-\(value.second == true)"
                )
            }

        _ = runtime.block(from: Text("A").shortcut(shortcut))
        dispatchCompositionKey("s", phase: .down, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        #expect(probe.events.isEmpty)

        dispatchCompositionKey("s", phase: .up, to: runtime)
        #expect(probe.events == ["tap-true-long-true"])
    }

    @Test
    func `SimultaneousShortcut ends with a nil branch that never matches the key sequence`() {
        let probe = ShortcutCompositionProbe()
        let runtime = StateRuntime()
        let shortcut = TapShortcut("s")
            .simultaneously(with: TapShortcut("x"))
            .onEnded { value in
                probe.events.append(
                    "s-\(value.first != nil)-x-\(value.second != nil)"
                )
            }

        _ = runtime.block(from: Text("A").shortcut(shortcut))
        dispatchCompositionKey("s", phase: .down, to: runtime)
        dispatchCompositionKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["s-true-x-false"])
    }

    @Test
    func `SequenceShortcut retains its first value without adding a timeout`() {
        let probe = ShortcutCompositionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let shortcut = TapShortcut("s")
            .sequenced(before: TapShortcut("x"))
            .onEnded { value in
                guard case .second(_, let second) = value else {
                    Issue.record("The sequence did not end in its second stage.")
                    return
                }
                probe.events.append(second == nil ? "ended-nil" : "ended-second")
            }

        _ = runtime.block(from: Text("A").shortcut(shortcut))
        dispatchCompositionKey("s", phase: .down, to: runtime)
        dispatchCompositionKey("s", phase: .up, to: runtime)
        #expect(probe.events.isEmpty)
        #expect(runtime.nextRecognitionDeadline == nil)

        probe.date = probe.date.addingTimeInterval(100)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        #expect(probe.events.isEmpty)

        dispatchCompositionKey("x", phase: .down, to: runtime)
        dispatchCompositionKey("x", phase: .up, to: runtime)
        #expect(probe.events == ["ended-second"])
    }

    @Test
    func `SequenceShortcut clears its armed value when the second shortcut fails`() {
        let probe = ShortcutCompositionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let shortcut = LongPressShortcut("s", minimumDuration: 0)
            .sequenced(
                before: LongPressShortcut("x", minimumDuration: 0.5)
            )
            .onChanged { value in
                guard case .second(_, let second) = value else {
                    return
                }
                probe.events.append(second == nil ? "armed" : "pressing")
            }
            .onEnded { _ in probe.events.append("ended") }

        _ = runtime.block(from: Text("A").shortcut(shortcut))
        dispatchCompositionKey("s", phase: .down, to: runtime)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        dispatchCompositionKey("x", phase: .down, to: runtime)
        dispatchCompositionKey("x", phase: .up, to: runtime)
        dispatchCompositionKey("x", phase: .down, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)

        #expect(probe.events == ["armed", "pressing"])
    }
}

private final class ShortcutCompositionProbe {
    var date = Date(timeIntervalSinceReferenceDate: 100)
    var events: [String] = []
}

private func dispatchCompositionKey(
    _ key: KeyEquivalent,
    phase: KeyPress.Phases,
    to runtime: StateRuntime
) {
    _ = runtime.dispatch(
        KeyPress(
            key: key,
            characters: String(key.character),
            phase: phase
        )
    )
}
