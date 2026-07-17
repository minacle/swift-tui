import Testing

@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("TextField Submission")
struct TextFieldEditingTests {

    @Test
    func `Return submits a TextField's current value once and handles the key without moving its caret`() {
        let runtime = StateRuntime()
        let view = TextFieldSubmitView()

        #expect(runtime.block(from: view)?.lines == [" Name ", "none:0"])
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["a  ", "a:1"])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `an ignored immediate Return handler runs before TextField submission handles the key`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = OrderedTextFieldSubmitView(tapProbe: tapProbe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(tapProbe.events == ["immediate", "submit"])
    }

    @Test
    func `Return remains unhandled in a focused TextField without an onSubmit action`() {
        let runtime = StateRuntime()
        let view = FocusedTextFieldWithoutSubmitView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
    }
}

private struct OrderedTextFieldSubmitView: View {

    @FocusState var isFocused: Bool = true

    let tapProbe: TapGestureProbe

    var body: some View {
        TextField("Name", text: .constant(""))
            .focused($isFocused)
            .onKeyPress(.return) {
                tapProbe.record("immediate")
                return .ignored
            }
            .onSubmit {
                tapProbe.record("submit")
            }
            .environment(\.resolveKey[.return]) { _ in
                tapProbe.record("resolve")
                return .handled
            }
    }
}

private struct FocusedTextFieldWithoutSubmitView: View {

    @FocusState var isFocused: Bool = true

    var body: some View {
        TextField("Name", text: .constant(""))
            .focused($isFocused)
    }
}
