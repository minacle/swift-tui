import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

@Suite("EditableText Multiline Selection and Hit Testing")
struct EditableTextMultilineSelectionAndHitTestingTests {

    @Test
    func `replacing an external multiline EditableText selection with Return publishes a caret after the newline`() {
        let text = "ab\ncd"
        let lowerBound = text.index(after: text.startIndex)
        let upperBound = text.index(text.startIndex, offsetBy: 4)
        let textProbe = BindingProbe<String>()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = SelectionMultilineEditableTextView(
            text: text,
            selection: TextSelection(range: lowerBound..<upperBound),
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
        let runtime = StateRuntime()

        #expect(renderUntilStable(runtime, view: view, in: RenderProposal(columns: 4)) <= 4)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: RenderProposal(columns: 4)) <= 4)

        let updatedText = textProbe.binding?.wrappedValue
        #expect(updatedText == "a\nd")
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: updatedText ?? ""
            ) == 2..<2
        )
    }

    @Test
    func `clicking a scrolled multiline EditableText publishes a source-relative insertion point`() {
        let textProbe = BindingProbe<String>()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = SelectionMultilineEditableTextView(
            text: "a\nb\nc\nd",
            selection: nil,
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
        let runtime = StateRuntime()
        let proposal = RenderProposal(columns: 3, rows: 2)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 4)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 5..<5
        )
    }

    @Test
    func `measurement rendering leaves the multiline EditableText selection binding untouched`() {
        let textProbe = BindingProbe<String>()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = SelectionMultilineEditableTextView(
            text: "abc",
            selection: nil,
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
        let runtime = StateRuntime()

        #expect(renderUntilStable(runtime, view: view) <= 4)
        selectionProbe.binding?.wrappedValue = nil
        _ = LayoutMeasurementContext.withMeasurement {
            runtime.block(from: view, in: RenderProposal(columns: 2, rows: 1))
        }

        #expect(selectionProbe.binding?.wrappedValue == nil)
    }

    @Test
    func `Shift-Home selects from the caret to visual line start before replacement`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextInitialTextView(text: "ab\ncd")
        let proposal = RenderProposal(columns: 4)

        _ = runtime.block(from: view, in: proposal)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: proposal)

        #expect(runtime.dispatch(KeyPress(
            key: .home,
            characters: "\u{F729}",
            modifiers: .shift
        )) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)

        let block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["ab  ", "X   "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `Return replaces a multiline EditableText selection while external text changes clear stale selection`() {
        var boundText = "ab\ncd"
        let binding = Binding(
            get: { boundText },
            set: { boundText = $0 }
        )
        let state = EditableTextMultilineState(initialText: boundText) {}
        var layout = EditableTextMultilineLayout(text: state.text, maxWidth: 4)

        state.moveToLineStart(layout: layout, selecting: true)
        state.insert("\n", update: binding)
        #expect(boundText == "ab\n\n")
        #expect(state.offset == 4)
        #expect(state.selectedRange == nil)

        state.moveLeft(selecting: true)
        state.synchronize(with: "x")
        #expect(state.selectedRange == nil)
        #expect(state.offset == 1)

        boundText = "x"
        layout = EditableTextMultilineLayout(text: state.text, maxWidth: 4)
        state.moveToLineEnd(layout: layout)
        state.insert("y", update: binding)
        #expect(boundText == "xy")
    }

    @Test
    func `multiline alignment shifts both the multiline EditableText rendering and pointer-to-offset mapping`() {
        let layout = EditableTextMultilineLayout(
            text: "A\nBBB",
            maxWidth: 5,
            alignment: .trailing
        )
        let block = ViewResolver.block(
            from: MultilineEditableText(text: .constant("A\nBBB"))
                .multilineTextAlignment(.trailing),
            in: RenderProposal(columns: 5)
        )

        #expect(layout.renderedWidth == 5)
        #expect(layout.horizontalOffset(onLine: 0) == 4)
        #expect(layout.horizontalOffset(onLine: 1) == 2)
        #expect(layout.offset(onLine: 0, nearestRenderedColumn: 4) == 0)
        #expect(layout.offset(onLine: 0, nearestRenderedColumn: 5) == 1)
        #expect(block?.lines == ["    A", "  BBB"])
    }

    @Test
    func `clicking a multiline EditableText line positions the caret for insertion at that source offset`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextInitialTextView(text: "ab\ncd")
        let proposal = RenderProposal(columns: 4)

        _ = runtime.block(from: view, in: proposal)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: proposal)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 1), phase: .down)
            ) == .ignored
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["ab  ", "cXd "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 2))
    }

    @Test
    func `clicking inside a multiline EditableText selection defers its collapse until pointer-up`() {
        var text = "ab\ncd"
        var selection: TextSelection?
        let runtime = StateRuntime()
        let proposal = RenderProposal(columns: 4)
        let view = MultilineEditableText(
            text: Binding(
                get: { text },
                set: { text = $0 }
            ),
            selection: Binding(
                get: { selection },
                set: { selection = $0 }
            )
        )

        _ = runtime.block(from: view, in: proposal)
        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 1,
            fromRow: 1,
            toColumn: 2,
            toRow: 2
        )
        #expect(selectionCharacterOffsets(selection, in: text) == 0..<4)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(selectionCharacterOffsets(selection, in: text) == 0..<4)
        #expect(runtime.block(from: view, in: proposal)?.caret == nil)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .up)
            ) == .ignored
        )
        #expect(selectionCharacterOffsets(selection, in: text) == 1..<1)
        #expect(
            runtime.block(from: view, in: proposal)?.caret
                == RenderedCaret(row: 0, column: 1)
        )
    }

    @Test
    func `dragging across multiline EditableText lines selects the traversed source range for replacement`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextInitialTextView(text: "ab\ncd")
        let proposal = RenderProposal(columns: 4)

        _ = runtime.block(from: view, in: proposal)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: proposal)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 2, row: 1), modifiers: [])
            ) == .ignored
        )
        #expect(runtime.block(from: view, in: proposal)?.caret == nil)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["X   "])
        #expect(block?.caret == RenderedCaret(row: 0, column: 1))
    }

    @Test
    func `navigationDirection reanchors dragged multiline EditableText selection before vertical, Home, and End extension`() {
        let text = "ab\ncd\nef\ngh"
        let layout = EditableTextMultilineLayout(text: text, maxWidth: 4)

        let up = EditableTextMultilineState(initialText: text) {}
        up.beginSelection(to: Point(column: 1, row: 1), layout: layout)
        up.extendSelection(to: Point(column: 1, row: 2), layout: layout)
        up.moveVertically(
            by: -1,
            layout: layout,
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(up.offset == 1)
        #expect(up.selectedRange == 1..<7)

        let down = EditableTextMultilineState(initialText: text) {}
        down.beginSelection(to: Point(column: 1, row: 2), layout: layout)
        down.extendSelection(to: Point(column: 1, row: 1), layout: layout)
        down.moveVertically(
            by: 1,
            layout: layout,
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(down.offset == 10)
        #expect(down.selectedRange == 4..<10)

        let home = EditableTextMultilineState(initialText: text) {}
        home.beginSelection(to: Point(column: 1, row: 1), layout: layout)
        home.extendSelection(to: Point(column: 1, row: 2), layout: layout)
        home.moveToLineStart(
            layout: layout,
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(home.offset == 3)
        #expect(home.selectedRange == 3..<7)

        let end = EditableTextMultilineState(initialText: text) {}
        end.beginSelection(to: Point(column: 1, row: 2), layout: layout)
        end.extendSelection(to: Point(column: 1, row: 1), layout: layout)
        end.moveToLineEnd(
            layout: layout,
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(end.offset == 8)
        #expect(end.selectedRange == 4..<8)
    }

    @Test
    func `dragEndpoint continues from the pointer endpoint and collapses the selection when it reaches the anchor`() {
        let text = "ab\ncd\nef"
        let layout = EditableTextMultilineLayout(text: text, maxWidth: 4)
        let state = EditableTextMultilineState(initialText: text) {}
        state.beginSelection(to: Point(column: 1, row: 1), layout: layout)
        state.extendSelection(to: Point(column: 1, row: 2), layout: layout)

        state.moveVertically(
            by: -1,
            layout: layout,
            selecting: true,
            navigationBehavior: .dragEndpoint
        )

        #expect(state.offset == 4)
        #expect(state.selectedRange == nil)
    }

    @Test
    func `dragging beyond a multiline EditableText frame scrolls the selected endpoint into view`() {
        let runtime = StateRuntime()
        let view = PrefixedBoundedMultilineEditableTextInitialTextView(text: "a\nb\nc\nd")
        let proposal = RenderProposal(columns: 4)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        var block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["top ", "c   ", "d   "])
        #expect(block?.caret == RenderedCaret(row: 2, column: 1))

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 2), phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 0, row: 0), modifiers: [])
            ) == .ignored
        )
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["top ", "b   ", "c   "])
        #expect(block?.caret == nil)
    }

    @Test
    func `a scrolled multiline EditableText maps viewport clicks through its scroll offset before insertion`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextInitialTextView(text: "a\nb\nc\nd")
        let proposal = RenderProposal(columns: 3, rows: 2)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        var block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["c  ", "d  "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["cX ", "d  "])
        #expect(block?.caret == RenderedCaret(row: 0, column: 2))
    }

    @Test
    func `an indented multiline EditableText uses its receiver geometry without reacting to the outer header`() {
        let runtime = StateRuntime()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = FocusableCompositeMultilineEditableText(
            selectionProbe: selectionProbe
        )
        let proposal = RenderProposal(columns: 12, rows: 3)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 4)
        dispatchClick(to: runtime, column: 8, row: 3)
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: "ab\ncd"
            ) == 4..<4
        )

        dispatchClick(to: runtime, column: 2, row: 1)
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: "ab\ncd"
            ) == 4..<4
        )
    }

}

private struct FocusableCompositeMultilineEditableText: View {

    @State private var text = "ab\ncd"

    @State private var selection: TextSelection?

    @FocusState private var isEditorFocused = true

    let selectionProbe: BindingProbe<TextSelection?>

    var body: some View {
        CapturedFocusableCompositeMultilineEditableText(
            text: $text,
            selection: $selection,
            isEditorFocused: $isEditorFocused,
            selectionProbe: selectionProbe
        )
    }
}

private struct CapturedFocusableCompositeMultilineEditableText: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>

    let isEditorFocused: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        selection: Binding<TextSelection?>,
        isEditorFocused: FocusState<Bool>.Binding,
        selectionProbe: BindingProbe<TextSelection?>
    ) {
        self.text = text
        self.selection = selection
        self.isEditorFocused = isEditorFocused
        selectionProbe.capture(selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Header")
                .simultaneousInputEvent(
                    PointerPressEvent(.left)
                        .onRecognized { _ in .ignored }
                )
            HStack(alignment: .top, spacing: 0) {
                Text("> ")
                EditableText(
                    text: text,
                    selection: selection,
                    lineMode: .multiline
                )
                .focused(isEditorFocused)
            }
            .padding(.leading, 4)
        }
        .focusable()
    }
}
