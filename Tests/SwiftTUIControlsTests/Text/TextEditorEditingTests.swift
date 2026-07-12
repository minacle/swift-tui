import Testing

@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("TextEditor Submission")
struct TextEditorEditingTests {

    @Test
    func `Return inserts a newline without invoking the TextEditor submit handler`() {
        let runtime = StateRuntime()
        let view = TextEditorSubmitView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.lines == ["    ", "    ", "none"])
        #expect(block?.caret == RenderedCaret(row: 1, column: 0))
    }
}
