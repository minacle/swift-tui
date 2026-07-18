import Testing

@testable import SwiftTUIEssentials

@Suite("EditableText Basics")
struct EditableTextTests {

    @Test
    func `EditableText inserts text and a Return newline by default`() {
        var text = ""
        let binding = Binding(
            get: { text },
            set: { text = $0 }
        )
        let runtime = StateRuntime()
        let view = FocusedEditableText(text: binding)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(text == "a\n")
    }

    @Test
    func `a finite frame clips EditableText without changing its content offset`() {
        let runtime = StateRuntime()
        let view = FocusedEditableText(text: .constant("abc"))
            .frame(width: 3)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["abc", "   "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 0))
    }

    @Test
    func `an input policy leaves Return and vertical navigation unhandled`() {
        var text = "a"
        let binding = Binding(
            get: { text },
            set: { text = $0 }
        )
        let runtime = StateRuntime()
        let view = FocusedEditableText(
            text: binding,
            inputPolicy: EditableText.InputPolicy(
                allowsNewlineInsertion: false,
                allowsVerticalNavigation: false
            )
        )

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(text == "ab")
    }

    @Test
    func `layout measurement and blocked vertical movement do not advance the input anchor generation`() {
        let state = EditableTextState(initialText: "abc") {}
        let layout = EditableTextLayout(text: state.text, maxWidth: 3)

        state.updateLayoutWidth(3)
        #expect(state.textInputGeneration == 0)
        #expect(state.moveVertically(by: 1, layout: layout) == false)
        #expect(state.textInputGeneration == 0)
        #expect(state.moveLeft())
        #expect(state.textInputGeneration == 1)
    }

    @Test
    func `masking replaces displayed characters without changing bound text`() {
        var text = "secret"
        let binding = Binding(
            get: { text },
            set: { text = $0 }
        )
        let runtime = StateRuntime()
        let view = EditableText(text: binding, mask: "*")

        #expect(runtime.block(from: view)?.text == "****** ")
        #expect(text == "secret")
    }
}

private struct FocusedEditableText: View {

    let text: Binding<String>

    let inputPolicy: EditableText.InputPolicy

    @FocusState private var isFocused = true

    init(
        text: Binding<String>,
        inputPolicy: EditableText.InputPolicy = EditableText.InputPolicy()
    ) {
        self.text = text
        self.inputPolicy = inputPolicy
    }

    var body: some View {
        EditableText(text: text, inputPolicy: inputPolicy)
            .focused($isFocused)
    }
}
