import Testing

@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("TextField Submission")
struct TextFieldEditingTests {

    @Test
    func `Return submits a TextField's current value without moving its caret`() {
        let runtime = StateRuntime()
        let view = TextFieldSubmitView()

        #expect(runtime.block(from: view)?.lines == ["Name", "none"])
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["a ", "a "])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))
    }
}
