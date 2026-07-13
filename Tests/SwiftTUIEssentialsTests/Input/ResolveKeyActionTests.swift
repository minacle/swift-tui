import Testing
@testable import SwiftTUIEssentials

@Suite("Key Resolution", .serialized)
struct ResolveKeyActionTests {

    @Test
    func `the default environment action ignores every key`() {
        let action = EnvironmentValues().resolveKey

        #expect(action(.escape) == .ignored)
        #expect(action(.return) == .ignored)
    }

    @Test
    func `a resolver receives the exact matching key equivalent`() {
        var receivedKey: KeyEquivalent?
        var action = ResolveKeyAction()
        action[.escape] = { key in
            receivedKey = key
            return .handled
        }

        #expect(action(.escape) == .handled)
        #expect(receivedKey == .escape)
    }

    @Test
    func `an unrelated key bypasses the registered resolver`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = Text("A")
            .environment(\.resolveKey[.escape]) { key in
                probe.record("resolve", key: key)
                return .handled
            }

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(probe.events.isEmpty)
    }

    @Test
    func `the closest value handler stops its inherited fallback`() {
        let probe = ResolveKeyProbe()
        var outer = ResolveKeyAction()
        outer[.escape] = { key in
            probe.record("outer", key: key)
            return .handled
        }
        var inner = outer
        inner[.escape] = { key in
            probe.record("inner", key: key)
            return .handled
        }

        #expect(inner(.escape) == .handled)
        #expect(probe.events == ["inner"])
    }

    @Test
    func `an ignored value handler continues to its inherited fallback`() {
        let probe = ResolveKeyProbe()
        var outer = ResolveKeyAction()
        outer[.escape] = { key in
            probe.record("outer", key: key)
            return .handled
        }
        var inner = outer
        inner[.escape] = { key in
            probe.record("inner", key: key)
            return .ignored
        }

        #expect(inner(.escape) == .handled)
        #expect(probe.events == ["inner", "outer"])
    }

    @Test
    func `a handled focused key handler prevents key resolution`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = FocusedGlobalAndResolveView(
            probe: probe,
            focusedResult: .handled,
            globalResult: .handled
        )

        _ = runtime.block(from: view)
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["focused"])
    }

    @Test
    func `a handled global key handler prevents key resolution`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = FocusedGlobalAndResolveView(
            probe: probe,
            focusedResult: .ignored,
            globalResult: .handled
        )

        _ = runtime.block(from: view)
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["focused", "global"])
    }

    @Test
    func `key resolution follows ignored focused and global handlers`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = FocusedGlobalAndResolveView(
            probe: probe,
            focusedResult: .ignored,
            globalResult: .ignored
        )

        _ = runtime.block(from: view)
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["focused", "global", "resolve"])
    }

    @Test
    func `repeat and key-up events skip key resolution`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = Text("A")
            .environment(\.resolveKey[.escape]) { key in
                probe.record("resolve", key: key)
                return .handled
            }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                KeyPress(key: .escape, characters: "\u{001B}", phase: .repeat)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                KeyPress(key: .escape, characters: "\u{001B}", phase: .up)
            ) == .ignored
        )
        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["resolve"])
    }

    @Test
    func `focused key resolution walks only the focused ancestor branch outward`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = FocusedResolveBranchView(probe: probe)

        _ = runtime.block(from: view)
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["focused leaf", "focused ancestor", "root"])
    }

    @Test
    func `without focus the deepest matching branch excludes sibling resolvers`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("deep")
                    .environment(\.resolveKey[.escape]) { key in
                        probe.record("deep", key: key)
                        return .ignored
                    }
            }
            Text("sibling")
                .environment(\.resolveKey[.escape]) { key in
                    probe.record("sibling", key: key)
                    return .handled
                }
        }
        .environment(\.resolveKey[.escape]) { key in
            probe.record("root", key: key)
            return .handled
        }

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["deep", "root"])
    }

    @Test
    func `nested declarations at one path run from the innermost modifier outward`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = Text("A")
            .environment(\.resolveKey[.escape]) { key in
                probe.record("inner", key: key)
                return .ignored
            }
            .environment(\.resolveKey[.escape]) { key in
                probe.record("outer", key: key)
                return .handled
            }

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["inner", "outer"])
    }

    @Test
    func `equal-depth branches select the first rendered matching path`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = VStack(spacing: 0) {
            Text("first")
                .environment(\.resolveKey[.escape]) { key in
                    probe.record("first", key: key)
                    return .ignored
                }
            Text("second")
                .environment(\.resolveKey[.escape]) { key in
                    probe.record("second", key: key)
                    return .handled
                }
        }
        .environment(\.resolveKey[.escape]) { key in
            probe.record("root", key: key)
            return .handled
        }

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(probe.events == ["first", "root"])
    }

    @Test
    func `a resolver mutates declaration state and invokes its captured environment action`() {
        var didTerminate = false
        let runtime = StateRuntime()
        let view = StatefulResolveKeyView()
            .environment(\.terminate, TerminateAction {
                didTerminate = true
            })

        #expect(runtime.block(from: view)?.text == "0")
        #expect(runtime.dispatch(escapeKeyPress()) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1")
        #expect(didTerminate)
    }

    @Test
    func `a disabled subtree does not register its key resolver`() {
        let runtime = StateRuntime()
        let probe = ResolveKeyProbe()
        let view = VStack(spacing: 0) {
            Text("A")
                .environment(\.resolveKey[.escape]) { key in
                    probe.record("disabled", key: key)
                    return .handled
                }
        }
        .disabled(true)

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(escapeKeyPress()) == .ignored)
        #expect(probe.events.isEmpty)
    }
}

private final class ResolveKeyProbe {

    private(set) var events: [String] = []

    func record(_ event: String, key: KeyEquivalent) {
        #expect(key == .escape)
        events.append(event)
    }
}

private struct FocusedGlobalAndResolveView: View {

    @FocusState private var isFocused = true

    let probe: ResolveKeyProbe

    let focusedResult: InputEventResult

    let globalResult: InputEventResult

    var body: some View {
        Text("A")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.escape) {
                probe.record("focused", key: .escape)
                return focusedResult
            }
            ._onGlobalKeyPress(.escape) {
                probe.record("global", key: .escape)
                return globalResult
            }
            .environment(\.resolveKey[.escape]) { key in
                probe.record("resolve", key: key)
                return .handled
            }
    }
}

private struct FocusedResolveBranchView: View {

    @FocusState private var isFocused = true

    let probe: ResolveKeyProbe

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("focused")
                    .focusable()
                    .focused($isFocused)
                    .environment(\.resolveKey[.escape]) { key in
                        probe.record("focused leaf", key: key)
                        return .ignored
                    }
            }
            .environment(\.resolveKey[.escape]) { key in
                probe.record("focused ancestor", key: key)
                return .ignored
            }

            Text("sibling")
                .environment(\.resolveKey[.escape]) { key in
                    probe.record("sibling", key: key)
                    return .handled
                }
        }
        .environment(\.resolveKey[.escape]) { key in
            probe.record("root", key: key)
            return .handled
        }
    }
}

private struct StatefulResolveKeyView: View {

    @Environment(\.terminate) private var terminate

    @State private var count = 0

    var body: some View {
        Text("\(count)")
            .environment(\.resolveKey[.escape]) { _ in
                count += 1
                terminate()
                return .handled
            }
    }
}

private func escapeKeyPress() -> KeyPress {
    KeyPress(key: .escape, characters: "\u{001B}")
}
