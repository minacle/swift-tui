import Testing

@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Editable Text")
struct EditableTextTests {

    @Test
    func `single-line editing inserts text and leaves Return unhandled`() {
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
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(text == "a")
    }

    @Test
    func `multiline editing inserts a newline and accepts text on the new line`() {
        var text = "a"
        let binding = Binding(
            get: { text },
            set: { text = $0 }
        )
        let runtime = StateRuntime()
        let view = FocusedEditableText(text: binding, lineMode: .multiline)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(text == "a\nb")
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

    let lineMode: EditableText.LineMode

    @FocusState private var isFocused = true

    init(
        text: Binding<String>,
        lineMode: EditableText.LineMode = .singleLine
    ) {
        self.text = text
        self.lineMode = lineMode
    }

    var body: some View {
        EditableText(text: text, lineMode: lineMode)
            .focused($isFocused)
    }
}
