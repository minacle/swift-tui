import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Focused and Global Key Input", .serialized)
struct KeyInputTests {

    @Test
    func `attaching a focused key handler leaves rendered output unchanged`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()

        let block = runtime.block(
            from: FocusedKeyPressView(
                focusProbe: focusProbe,
                keyProbe: keyProbe,
                result: .handled
            )
        )

        #expect(block?.text == "A")
    }

    @Test
    func `focused key handlers ignore input while their view is unfocused`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = FocusedKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            result: .handled
        )

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .ignored)
        #expect(keyProbe.events.isEmpty)
    }

    @Test
    func `a focused view handles a matching key press`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = FocusedKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            result: .handled
        )

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["child"])
    }

    @Test
    func `a key handler can mutate state and trigger an updated render`() {
        let runtime = StateRuntime()
        let view = KeyPressStateMutationView()

        #expect(runtime.block(from: view)?.text == "0")

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1")
    }

    @Test
    func `a child key callback can directly mutate and rerender parent state`() {
        let runtime = StateRuntime()
        let view = ParentCallbackDirectStateMutationKeyPressView()

        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

        focusParentCallbackKeyPressChild(in: runtime)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
    }

    @Test
    func `a child key callback can mutate parent state through a binding and rerender it`() {
        let runtime = StateRuntime()
        let view = ParentCallbackBindingMutationKeyPressView()

        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

        focusParentCallbackKeyPressChild(in: runtime)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
    }

    @Test
    func `a child key callback renders newly activated conditional state with its final value`() {
        let runtime = StateRuntime()
        let view = DeferredParentStateMutationView()

        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "idle"])

        focusParentCallbackKeyPressChild(in: runtime)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
    }

    @Test
    func `a newly activated conditional branch renders updated parent state instead of the previous branch state`() {
        let runtime = StateRuntime()
        let view = DeferredParentStateMutationWithExistingStringCellView()

        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

        focusParentCallbackKeyPressChild(in: runtime)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
    }

    @Test
    func `an ignored ancestor key handler continues propagation toward the focused view`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = ParentKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            parentResult: .ignored,
            childResult: .handled
        )

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["parent", "child"])
    }

    @Test
    func `a handled ancestor key handler prevents propagation to the focused view`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = ParentKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            parentResult: .handled,
            childResult: .handled
        )

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["parent"])
    }

    @Test
    func `focused key dispatch proceeds from the outermost ancestor toward the focused view`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = NestedFocusedKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe
        )

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["outer", "middle", "child"])
    }

    @Test
    func `the last attached matching focused key handler runs before earlier handlers`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = OrderedKeyPressView(focusProbe: focusProbe, keyProbe: keyProbe)

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["second"])
    }

    @Test
    func `key-handler overloads filter events by key, key set, character class, and phase`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = KeyPressOverloadView(focusProbe: focusProbe, keyProbe: keyProbe)

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a", phase: .repeat)) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a", phase: .up)) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b", phase: .repeat)) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c", phase: .repeat)) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "d", characters: "d", phase: .repeat)) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "5", characters: "5")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "5", characters: "5", phase: .repeat)) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: "5", characters: "")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: "q", characters: "q", phase: .up)) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "z", characters: "z")) == .ignored)
        #expect(
            keyProbe.events == [
                "plain",
                "plain",
                "phase",
                "exact",
                "exact",
                "set",
                "set",
                "characters",
                "phase",
            ]
        )
    }

    @Test
    func `global key handlers receive matching input without focus`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let view = Text("A")
            ._onGlobalKeyPress(.escape) {
                keyProbe.record("global")
                return .handled
            }

        #expect(runtime.block(from: view)?.text == "A")
        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(keyProbe.events == ["global"])
    }

    @Test
    func `global key-handler overloads retain key set character and phase matching`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let view = GlobalKeyPressOverloadView(keyProbe: keyProbe)

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(
            runtime.dispatch(
                KeyPress(key: "q", characters: "q", phase: .up)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                KeyPress(key: "b", characters: "b", phase: .repeat)
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "5", characters: "5")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "z", characters: "z")) == .ignored)
        #expect(keyProbe.events == ["plain", "phase", "exact", "set", "characters"])
    }

    @Test
    func `the deepest matching global key handler receives input before its ancestors`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let view = NestedGlobalKeyPressView(
            keyProbe: keyProbe,
            innerResult: .handled
        )

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["inner"])
    }

    @Test
    func `an ignored inner global key handler continues to its outer ancestor`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let view = NestedGlobalKeyPressView(
            keyProbe: keyProbe,
            innerResult: .ignored
        )

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["inner", "outer"])
    }

    @Test
    func `a handled focused key handler runs before a matching global handler`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = FocusedAndGlobalKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            focusedResult: .handled
        )

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["focused"])
    }

    @Test
    func `an ignored focused key handler falls back to the matching global handler`() {
        let runtime = StateRuntime()
        let keyProbe = KeyPressProbe()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = FocusedAndGlobalKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            focusedResult: .ignored
        )

        _ = runtime.block(from: view)
        focusProbe.binding?.wrappedValue = true
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(keyProbe.events == ["focused", "global"])
    }

    @Test
    func `a global key handler can invoke an action captured from its environment`() {
        var didTerminate = false
        let runtime = StateRuntime()
        let view = GlobalEnvironmentTerminateView()
            .environment(\.terminate, TerminateAction {
                didTerminate = true
            })

        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(didTerminate)
    }
}
