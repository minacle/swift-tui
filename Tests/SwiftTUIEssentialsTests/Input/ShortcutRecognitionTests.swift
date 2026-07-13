import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Shortcut Recognition")
struct ShortcutRecognitionTests {

    @Test
    func `a custom Shortcut body recognizes through its primitive graph`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .shortcut(
                CustomSaveShortcut()
                    .onEnded { probe.events.append("ended") }
            )

        _ = runtime.block(from: view)
        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .up, to: runtime)

        #expect(probe.events == ["ended"])
    }

    @Test
    func `TapShortcut counts exact down-up pairs and ignores repeat phases`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .shortcut(
                TapShortcut("s", modifiers: .control, count: 2)
                    .onEnded { probe.events.append("ended") }
            )

        _ = runtime.block(from: view)
        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .repeat, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .repeat, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .up, to: runtime)
        #expect(probe.events.isEmpty)

        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .up, to: runtime)
        #expect(probe.events == ["ended"])
    }

    @Test
    func `an unrelated key preserves a pending TapShortcut count until its deadline`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .shortcut(
                TapShortcut("s", modifiers: .control, count: 2)
                    .onEnded { probe.events.append("ended") }
            )

        _ = runtime.block(from: view)
        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .up, to: runtime)
        dispatchKey("x", phase: .down, to: runtime)
        dispatchKey("x", phase: .up, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .up, to: runtime)

        #expect(probe.events == ["ended"])
    }

    @Test
    func `TapShortcut resets a partial count when its half-second deadline expires`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let view = Text("A")
            .shortcut(
                TapShortcut("s", count: 2)
                    .onEnded { probe.events.append("ended") }
            )

        _ = runtime.block(from: view)
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)
        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)

        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)
        #expect(probe.events.isEmpty)

        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)
        #expect(probe.events == ["ended"])
    }

    @Test
    func `a mismatched key-up leaves TapShortcut active until a new key-down supersedes it`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .shortcut(
                TapShortcut("s", modifiers: .control)
                    .onEnded { probe.events.append("ended") }
            )

        _ = runtime.block(from: view)
        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)
        #expect(probe.events.isEmpty)

        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .up, to: runtime)
        #expect(probe.events == ["ended"])
    }

    @Test
    func `LongPressShortcut changes on down and ends once at its deadline`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let shortcut = LongPressShortcut(
            "s",
            modifiers: .control,
            minimumDuration: 0.5
        )
            .onChanged { value in
                probe.events.append("changed-\(value)")
            }
            .onEnded { value in
                probe.events.append("ended-\(value)")
            }
        let view = Text("A").shortcut(shortcut)

        _ = runtime.block(from: view)
        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", modifiers: .control, phase: .repeat, to: runtime)
        #expect(probe.events == ["changed-true"])

        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        #expect(probe.events == ["changed-true", "ended-true"])

        dispatchKey("s", modifiers: .control, phase: .up, to: runtime)
        #expect(probe.events == ["changed-true", "ended-true"])
    }

    @Test
    func `LongPressShortcut ignores every phase whose modifiers do not exactly match`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime(now: { probe.date })
        let view = Text("A")
            .shortcut(
                LongPressShortcut(
                    "s",
                    modifiers: .control,
                    minimumDuration: 0.5
                )
                .onChanged { _ in probe.events.append("changed") }
                .onEnded { _ in probe.events.append("ended") }
            )

        _ = runtime.block(from: view)
        dispatchKey("s", phase: .down, to: runtime)
        #expect(probe.events.isEmpty)

        dispatchKey("s", modifiers: .control, phase: .down, to: runtime)
        dispatchKey("s", phase: .repeat, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)
        #expect(probe.events == ["changed"])

        probe.date = probe.date.addingTimeInterval(0.5)
        runtime.dispatchExpiredRecognitionActions(at: probe.date)
        #expect(probe.events == ["changed", "ended"])
    }

    @Test
    func `without focus only a root shortcut recognizes`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = VStack {
            Text("A")
                .shortcut(
                    TapShortcut("s")
                        .onEnded { probe.events.append("child") }
                )
        }
        .shortcut(
            TapShortcut("s")
                .onEnded { probe.events.append("root") }
        )

        _ = runtime.block(from: view)
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["root"])
    }

    @Test
    func `a successful Shortcut and focused key handler observe the same phases`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = FocusedShortcutView(probe: probe)

        _ = runtime.block(from: view)
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["raw-down", "raw-up", "shortcut"])
    }

    @Test
    func `Shortcut success preserves global key fallback and key resolution`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(from: ShortcutGlobalResolveView(probe: probe))
        dispatchKey(.escape, phase: .down, to: runtime)
        dispatchKey(.escape, phase: .up, to: runtime)

        #expect(probe.events == ["global", "resolve", "shortcut"])
    }

    @Test
    func `ShortcutMask selects the current shortcut or receiver shortcuts structurally`() {
        let currentProbe = ShortcutRecognitionProbe()
        let currentRuntime = StateRuntime()
        let currentView = Text("A")
            .shortcut(recordingShortcut("receiver", in: currentProbe))
            .shortcut(
                recordingShortcut("current", in: currentProbe),
                including: .shortcut
            )

        _ = currentRuntime.block(from: currentView)
        dispatchKey("s", phase: .down, to: currentRuntime)
        dispatchKey("s", phase: .up, to: currentRuntime)
        #expect(currentProbe.events == ["current"])

        let receiverProbe = ShortcutRecognitionProbe()
        let receiverRuntime = StateRuntime()
        let receiverView = Text("A")
            .shortcut(recordingShortcut("receiver", in: receiverProbe))
            .shortcut(
                recordingShortcut("current", in: receiverProbe),
                including: .subviews
            )

        _ = receiverRuntime.block(from: receiverView)
        dispatchKey("s", phase: .down, to: receiverRuntime)
        dispatchKey("s", phase: .up, to: receiverRuntime)
        #expect(receiverProbe.events == ["receiver"])
    }

    @Test
    func `disabling a shortcut attachment preserves its receiver shortcut`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .shortcut(recordingShortcut("receiver", in: probe))
            .shortcut(
                recordingShortcut("disabled", in: probe),
                isEnabled: false
            )

        _ = runtime.block(from: view)
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["receiver"])
    }

    @Test
    func `a focused child shortcut defeats an ancestor in the same tier`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(from: FocusedShortcutPriorityView(probe: probe))
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["child"])
    }

    @Test
    func `an ancestor high-priority shortcut defeats a focused child shortcut`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(
            from: FocusedShortcutPriorityView(
                probe: probe,
                parentIsHighPriority: true
            )
        )
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["parent"])
    }

    @Test
    func `a simultaneous shortcut observes the same success as a normal shortcut`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .shortcut(recordingShortcut("normal", in: probe))
            .simultaneousShortcut(recordingShortcut("simultaneous", in: probe))

        _ = runtime.block(from: view)
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["simultaneous", "normal"])
    }

    @Test
    func `a handled immediate key event prevents shortcut recognition`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()
        let view = FocusedHandledInputShortcutView(probe: probe)

        _ = runtime.block(from: view)
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(probe.events == ["input", "input"])
    }

    @Test
    func `a handled lazy key event observes Shortcut success and stops later key handling`() {
        let probe = ShortcutRecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(from: FocusedLazyInputShortcutView(probe: probe))
        dispatchKey("s", phase: .down, to: runtime)
        dispatchKey("s", phase: .up, to: runtime)

        #expect(
            probe.events == [
                "onKeyPress-down",
                "global-down",
                "onKeyPress-up",
                "shortcut",
                "lazy",
            ]
        )
    }
}

private final class ShortcutRecognitionProbe {
    var date = Date(timeIntervalSinceReferenceDate: 100)
    var events: [String] = []
}

private struct CustomSaveShortcut: Shortcut {

    typealias Value = Void

    var body: some Shortcut<Void> {
        TapShortcut("s", modifiers: .control)
    }
}

private struct FocusedShortcutView: View {

    @FocusState private var isFocused = true

    let probe: ShortcutRecognitionProbe

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .onKeyPress("s", phases: .all) { press in
                if press.phase == .down {
                    probe.events.append("raw-down")
                } else if press.phase == .up {
                    probe.events.append("raw-up")
                }
                return .ignored
            }
            .shortcut(
                TapShortcut("s")
                    .onEnded { probe.events.append("shortcut") }
            )
    }
}

private struct FocusedShortcutPriorityView: View {

    @FocusState private var isFocused = true

    let probe: ShortcutRecognitionProbe

    var parentIsHighPriority = false

    var body: some View {
        if parentIsHighPriority {
            focusedChild.highPriorityShortcut(
                recordingShortcut("parent", in: probe)
            )
        } else {
            focusedChild.shortcut(recordingShortcut("parent", in: probe))
        }
    }

    private var focusedChild: some View {
        VStack {
            Text("A")
                .focusable()
                .focused($isFocused)
                .shortcut(recordingShortcut("child", in: probe))
        }
    }
}

private struct FocusedHandledInputShortcutView: View {

    @FocusState private var isFocused = true

    let probe: ShortcutRecognitionProbe

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .inputEvent(
                KeyPressEvent("s", phases: .all)
                    .onRecognized { _ in
                        probe.events.append("input")
                        return .handled
                    }
            )
            .shortcut(recordingShortcut("shortcut", in: probe))
    }
}

private struct ShortcutGlobalResolveView: View {

    @FocusState private var isFocused = true

    let probe: ShortcutRecognitionProbe

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .shortcut(
                TapShortcut(.escape)
                    .onEnded { probe.events.append("shortcut") }
            )
            ._onGlobalKeyPress(.escape) {
                probe.events.append("global")
                return .ignored
            }
            .environment(\.resolveKey[.escape]) { _ in
                probe.events.append("resolve")
                return .ignored
            }
    }
}

private struct FocusedLazyInputShortcutView: View {

    @FocusState private var isFocused = true

    let probe: ShortcutRecognitionProbe

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .onKeyPress("s", phases: .all) { press in
                probe.events.append(
                    press.phase == .down ? "onKeyPress-down" : "onKeyPress-up"
                )
                return .ignored
            }
            ._onGlobalKeyPress("s", phases: .all) { press in
                probe.events.append(
                    press.phase == .down ? "global-down" : "global-up"
                )
                return .ignored
            }
            .inputEvent(
                KeyPressEvent("s", phases: .up)
                    .onRecognized { _ in
                        probe.events.append("lazy")
                        return .handled
                    }
                    .deferred(priority: .lazy)
            )
            .shortcut(
                TapShortcut("s")
                    .onEnded { probe.events.append("shortcut") }
            )
    }
}

private func recordingShortcut(
    _ name: String,
    in probe: ShortcutRecognitionProbe
) -> some Shortcut<Void> {
    TapShortcut("s").onEnded { probe.events.append(name) }
}

private func dispatchKey(
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
