import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Shortcut State")
struct ShortcutStateTests {

    @Test
    func `updating precedes onChanged and success ends before one state reset`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(from: ShortcutStateProbeView(probe: probe))
        dispatchStateKey("s", phase: .down, to: runtime)
        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
            ]
        )

        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "ended",
                "reset-true-false",
            ]
        )

        dispatchStateKey("s", phase: .up, to: runtime)
        #expect(probe.events.filter({ $0.hasPrefix("reset") }).count == 1)
    }

    @Test
    func `an early key-up fails and resets ShortcutState without ending`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(from: ShortcutStateProbeView(probe: probe))
        dispatchStateKey("s", phase: .down, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.1)
        dispatchStateKey("s", phase: .up, to: runtime)

        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "reset-true-false",
            ]
        )
    }

    @Test
    func `scene cancellation resets ShortcutState once without ending`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(from: ShortcutStateProbeView(probe: probe))
        dispatchStateKey("s", phase: .down, to: runtime)
        runtime.dispatchSceneInactive()
        runtime.dispatchSceneInactive()

        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "reset-true-false",
            ]
        )
    }

    @Test
    func `session termination resets ShortcutState once without ending`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(from: ShortcutStateProbeView(probe: probe))
        dispatchStateKey("s", phase: .down, to: runtime)
        runtime.endInputSession()
        runtime.endInputSession()

        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "reset-true-false",
            ]
        )
    }

    @Test
    func `losing focus resets an active ShortcutState once`() {
        let probe = ShortcutStateProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let runtime = StateRuntime(now: { probe.date })
        let view = ExternallyFocusedShortcutStateView(
            probe: probe,
            focusProbe: focusProbe
        )

        _ = runtime.block(from: view)
        dispatchStateKey("s", phase: .down, to: runtime)
        focusProbe.binding?.wrappedValue = false
        _ = runtime.block(from: view)

        #expect(
            probe.events == [
                "updating-true",
                "reset-true",
            ]
        )
    }

    @Test
    func `removing an active attachment resets ShortcutState without ending`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(from: ShortcutStateProbeView(probe: probe))
        dispatchStateKey("s", phase: .down, to: runtime)
        _ = runtime.block(from: Text("replacement"))

        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "reset-true-false",
            ]
        )
    }

    @Test
    func `changing shortcut configuration resets active state and rejects the old key-up`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(
            from: ConfigurableShortcutStateView(key: "s", probe: probe)
        )
        dispatchStateKey("s", phase: .down, to: runtime)
        _ = runtime.block(
            from: ConfigurableShortcutStateView(key: "x", probe: probe)
        )
        dispatchStateKey("s", phase: .up, to: runtime)

        #expect(
            probe.events == [
                "updating-true",
                "reset-true",
            ]
        )
    }

    @Test
    func `changing a mask removes the active attachment and resets ShortcutState`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(
            from: MaskedShortcutStateView(mask: .all, probe: probe)
        )
        dispatchStateKey("s", phase: .down, to: runtime)
        _ = runtime.block(
            from: MaskedShortcutStateView(mask: .subviews, probe: probe)
        )

        #expect(
            probe.events == [
                "updating-true",
                "reset-true",
            ]
        )
    }

    @Test
    func `a winning shortcut resets competing updated ShortcutState once`() {
        let probe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { probe.date })

        _ = runtime.block(from: CompetingShortcutStateView(probe: probe))
        dispatchStateKey("s", phase: .down, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)

        #expect(
            probe.events == [
                "updating-true",
                "winner-ended",
                "reset-true",
            ]
        )
    }

    @Test
    func `rerendering an unchanged shortcut preserves its deadline and latest actions`() {
        let firstProbe = ShortcutStateProbe()
        let secondProbe = ShortcutStateProbe()
        let runtime = StateRuntime(now: { firstProbe.date })

        _ = runtime.block(
            from: ReplacedShortcutActionView(probe: firstProbe)
        )
        dispatchStateKey("s", phase: .down, to: runtime)
        _ = runtime.block(
            from: ReplacedShortcutActionView(probe: secondProbe)
        )
        firstProbe.date = firstProbe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: firstProbe.date)

        #expect(firstProbe.events.isEmpty)
        #expect(secondProbe.events == ["ended"])
    }
}

private final class ShortcutStateProbe {
    var date = Date(timeIntervalSinceReferenceDate: 100)
    var events: [String] = []
}

private struct ShortcutStateProbeView: View {

    let probe: ShortcutStateProbe

    @FocusState private var isFocused = true

    @ShortcutState private var active = false

    init(probe: ShortcutStateProbe) {
        self.probe = probe
        _active = ShortcutState(wrappedValue: false) { value, transaction in
            probe.events.append("reset-\(value)-\(transaction.isContinuous)")
        }
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .shortcut(
                LongPressShortcut("s", minimumDuration: 0.5)
                    .updating($active) { value, active, transaction in
                        active = value
                        probe.events.append(
                            "updating-\(active)-\(transaction.isContinuous)"
                        )
                    }
                    .onChanged { value in
                        probe.events.append("changed-\(value)")
                    }
                    .onEnded { _ in
                        probe.events.append("ended")
                    }
            )
    }
}

private struct ConfigurableShortcutStateView: View {

    let key: KeyEquivalent

    let probe: ShortcutStateProbe

    @FocusState private var isFocused = true

    @ShortcutState private var active = false

    init(key: KeyEquivalent, probe: ShortcutStateProbe) {
        self.key = key
        self.probe = probe
        _active = ShortcutState(wrappedValue: false) { value, _ in
            probe.events.append("reset-\(value)")
        }
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .shortcut(
                LongPressShortcut(key)
                    .updating($active) { value, active, _ in
                        active = value
                        probe.events.append("updating-\(active)")
                    }
            )
    }
}

private struct ReplacedShortcutActionView: View {

    let probe: ShortcutStateProbe

    @FocusState private var isFocused = true

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .shortcut(
                LongPressShortcut("s", minimumDuration: 0.5)
                    .onEnded { _ in probe.events.append("ended") }
            )
    }
}

private struct ExternallyFocusedShortcutStateView: View {

    let probe: ShortcutStateProbe

    let focusProbe: FocusBindingProbe<Bool>

    @FocusState private var isFocused = true

    @ShortcutState private var active = false

    init(probe: ShortcutStateProbe, focusProbe: FocusBindingProbe<Bool>) {
        self.probe = probe
        self.focusProbe = focusProbe
        _active = ShortcutState(wrappedValue: false) { value, _ in
            probe.events.append("reset-\(value)")
        }
    }

    var body: some View {
        CapturedFocusedShortcutStateView(
            binding: $isFocused,
            state: $active,
            probe: probe,
            focusProbe: focusProbe
        )
    }
}

private struct CapturedFocusedShortcutStateView: View {

    let binding: FocusState<Bool>.Binding

    let state: ShortcutState<Bool>

    let probe: ShortcutStateProbe

    init(
        binding: FocusState<Bool>.Binding,
        state: ShortcutState<Bool>,
        probe: ShortcutStateProbe,
        focusProbe: FocusBindingProbe<Bool>
    ) {
        self.binding = binding
        self.state = state
        self.probe = probe
        focusProbe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(binding)
            .shortcut(
                LongPressShortcut("s")
                    .updating(state) { value, active, _ in
                        active = value
                        probe.events.append("updating-\(active)")
                    }
            )
    }
}

private struct MaskedShortcutStateView: View {

    let mask: ShortcutMask

    let probe: ShortcutStateProbe

    @FocusState private var isFocused = true

    @ShortcutState private var active = false

    init(mask: ShortcutMask, probe: ShortcutStateProbe) {
        self.mask = mask
        self.probe = probe
        _active = ShortcutState(wrappedValue: false) { value, _ in
            probe.events.append("reset-\(value)")
        }
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .shortcut(
                LongPressShortcut("s")
                    .updating($active) { value, active, _ in
                        active = value
                        probe.events.append("updating-\(active)")
                    },
                including: mask
            )
    }
}

private struct CompetingShortcutStateView: View {

    let probe: ShortcutStateProbe

    @FocusState private var isFocused = true

    @ShortcutState private var active = false

    init(probe: ShortcutStateProbe) {
        self.probe = probe
        _active = ShortcutState(wrappedValue: false) { value, _ in
            probe.events.append("reset-\(value)")
        }
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .shortcut(
                LongPressShortcut("s")
                    .onEnded { _ in probe.events.append("winner-ended") }
            )
            .shortcut(
                LongPressShortcut("s")
                    .updating($active) { value, active, _ in
                        active = value
                        probe.events.append("updating-\(active)")
                    }
            )
    }
}

private func dispatchStateKey(
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
