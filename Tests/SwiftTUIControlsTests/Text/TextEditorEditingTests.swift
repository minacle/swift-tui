import Testing

@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("TextEditor Editing")
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

    @Test
    func `a finite TextEditor width wraps content and returns its full natural height to the vertical viewport`() {
        let view = TextEditor(text: .constant("abcdef"))
            .frame(width: 3, height: 2)

        #expect(ViewResolver.block(from: view)?.lines == ["abc", "def"])
    }

    @Test
    func `vertical wheel movement in a focused TextEditor persists until editing changes its anchor`() {
        let runtime = StateRuntime()
        let view = FocusedScrollableTextEditor()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        #expect(runtime.block(from: view)?.lines == ["c "])

        #expect(
            runtime.dispatch(
                PointerScroll(
                    delta: Size(columns: 0, rows: -1),
                    location: Point(column: 0, row: 0)
                )
            ) == .handled
        )
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["b "])

        #expect(runtime.dispatch(KeyPress(key: "x", characters: "x")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view)
        #expect(editedBlock?.lines == ["  "])
        #expect(editedBlock?.caret == RenderedCaret(row: 0, column: 0))
    }

    @Test
    func `pointer-down in an empty TextEditor viewport focuses the editor for typing`() {
        let runtime = StateRuntime()
        let view = EmptyViewportTextEditor()

        let initialBlock = runtime.block(from: view)
        #expect(initialBlock?.focusRegions.map(\.frame) == [
            RenderedRect(width: 4, height: 3),
        ])
        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 3, row: 2),
                    phase: .down
                )
            ) == .ignored
        )
        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view)
        #expect(runtime.dispatch(KeyPress(key: "x", characters: "x")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["x   ", "    ", "    "])
    }
}

private struct FocusedScrollableTextEditor: View {

    @FocusState private var isFocused = true

    var body: some View {
        TextEditor(text: .constant("a\nb\nc"))
            .focused($isFocused)
            .frame(width: 2, height: 1)
    }
}

private struct EmptyViewportTextEditor: View {

    @State private var text = ""

    var body: some View {
        TextEditor(text: $text)
            .frame(width: 4, height: 3)
    }
}
