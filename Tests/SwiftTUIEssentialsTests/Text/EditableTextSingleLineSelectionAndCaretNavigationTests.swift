import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

@Suite("EditableText Single-Line Selection and Caret Navigation")
struct EditableTextSingleLineSelectionAndCaretNavigationTests {

    @Test
    func `an external Unicode selection is replaced and republished as a caret in updated text`() {
        let text = "A👨‍👩‍👧‍👦한"
        let emojiStart = text.index(after: text.startIndex)
        let emojiEnd = text.index(after: emojiStart)
        let textProbe = BindingProbe<String>()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = SelectionSingleLineEditableTextView(
            text: text,
            selection: TextSelection(range: emojiStart..<emojiEnd),
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
        let runtime = StateRuntime()

        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(runtime.block(from: view)?.caret == nil)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(renderUntilStable(runtime, view: view) <= 4)

        let updatedText = textProbe.binding?.wrappedValue
        #expect(updatedText == "AX한")
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: updatedText ?? ""
            ) == 2..<2
        )
    }

    @Test
    func `pointer drags and arrow keys publish each single-line EditableText selection change`() {
        let textProbe = BindingProbe<String>()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = SelectionSingleLineEditableTextView(
            text: "abcd",
            selection: nil,
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
        let runtime = StateRuntime()

        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 4..<4
        )

        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 1,
            fromRow: 1,
            toColumn: 4,
            toRow: 1
        )
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 0..<3
        )

        #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 3..<3
        )
        #expect(runtime.dispatch(KeyPress(
            key: .leftArrow,
            characters: "\u{F702}",
            modifiers: .shift
        )) == .handled)
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 2..<3
        )
    }

    @Test
    func `invalid external selections clamp to text bounds and nil restores the internal caret`() {
        let source = "abcdef"
        let textProbe = BindingProbe<String>()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = SelectionSingleLineEditableTextView(
            text: "ab",
            selection: TextSelection(insertionPoint: source.endIndex),
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
        let runtime = StateRuntime()

        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 2..<2
        )

        let currentText = textProbe.binding?.wrappedValue ?? ""
        selectionProbe.binding?.wrappedValue = TextSelection(
            range: currentText.startIndex..<currentText.endIndex
        )
        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(runtime.block(from: view)?.caret == nil)

        selectionProbe.binding?.wrappedValue = nil
        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))
        #expect(selectionProbe.binding?.wrappedValue == nil)

        #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 1..<1
        )
    }

    @Test
    func `backward and forward deletion remove selected ranges and publish the resulting caret`() {
        let initialText = "abcd"
        let lowerBound = initialText.index(after: initialText.startIndex)
        let upperBound = initialText.index(before: initialText.endIndex)
        let textProbe = BindingProbe<String>()
        let selectionProbe = BindingProbe<TextSelection?>()
        let view = SelectionSingleLineEditableTextView(
            text: initialText,
            selection: TextSelection(
                range: lowerBound..<upperBound
            ),
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
        let runtime = StateRuntime()

        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{7F}")) == .handled)
        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(textProbe.binding?.wrappedValue == "ad")
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 1..<1
        )

        let currentText = textProbe.binding?.wrappedValue ?? ""
        selectionProbe.binding?.wrappedValue = TextSelection(
            range: currentText.index(after: currentText.startIndex)..<currentText.endIndex
        )
        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(
            runtime.dispatch(
                KeyPress(key: .deleteForward, characters: "\u{F728}")
            ) == .handled
        )
        #expect(renderUntilStable(runtime, view: view) <= 4)
        #expect(textProbe.binding?.wrappedValue == "a")
        #expect(
            selectionCharacterOffsets(
                selectionProbe.binding?.wrappedValue,
                in: textProbe.binding?.wrappedValue ?? ""
            ) == 1..<1
        )
    }

    @Test
    func `horizontal arrows reposition the single-line EditableText caret for subsequent insertion`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "ab ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))

        #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "ab ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))

        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "acb ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))

        #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "acb ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 3))
    }

    @Test
    func `Shift-arrow selection is replaced by the next inserted character`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(
            key: .leftArrow,
            characters: "\u{F702}",
            modifiers: .shift
        )) == .handled)
        #expect(runtime.dispatch(KeyPress(
            key: .leftArrow,
            characters: "\u{F702}",
            modifiers: .shift
        )) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)

        let block = runtime.block(from: view)
        #expect(block?.text == "abX ")
        #expect(block?.caret == RenderedCaret(column: 3))
    }

    @Test
    func `an unmodified arrow collapses selection before subsequent insertion`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        for _ in 0..<2 {
            _ = runtime.dispatch(KeyPress(
                key: .leftArrow,
                characters: "\u{F702}",
                modifiers: .shift
            ))
        }
        _ = runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}"))
        _ = runtime.dispatch(KeyPress(key: "X", characters: "X"))

        #expect(runtime.block(from: view)?.text == "abXcd ")
    }

    @Test
    func `Backspace removes the complete selected range and restores the caret`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        for _ in 0..<2 {
            _ = runtime.dispatch(KeyPress(
                key: .leftArrow,
                characters: "\u{F702}",
                modifiers: .shift
            ))
        }
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)

        #expect(runtime.block(from: view)?.text == "ab ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))
    }

    @Test
    func `clicking a text column positions the caret for subsequent insertion`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .down)
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.text == "abXcd ")
        #expect(block?.caret == RenderedCaret(column: 3))
    }

    @Test
    func `tap observes selection before pointer-up collapses it while long press preserves it`() {
        var text = "abcd"
        var selection: TextSelection?
        var tapSelection: TextSelection?
        var longPressSelection: TextSelection?
        let runtime = StateRuntime()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = SingleLineEditableText(
            "Label",
            text: Binding(
                get: { text },
                set: { text = $0 }
            ),
            selection: Binding(
                get: { selection },
                set: { selection = $0 }
            )
        )
        .onTapGesture {
            tapSelection = selection
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            longPressSelection = selection
        }

        _ = runtime.block(from: view)
        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 2,
            fromRow: 1,
            toColumn: 4,
            toRow: 1
        )
        #expect(selectionCharacterOffsets(selection, in: text) == 1..<3)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .down),
                at: date
            ) == .handled
        )
        #expect(selectionCharacterOffsets(selection, in: text) == 1..<3)
        #expect(runtime.block(from: view)?.caret == nil)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .up),
                at: date.addingTimeInterval(0.1)
            ) == .handled
        )
        #expect(selectionCharacterOffsets(tapSelection, in: text) == 1..<3)
        #expect(selectionCharacterOffsets(selection, in: text) == 2..<2)
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))

        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 2,
            fromRow: 1,
            toColumn: 4,
            toRow: 1
        )
        #expect(selectionCharacterOffsets(selection, in: text) == 1..<3)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .down),
                at: date.addingTimeInterval(1)
            ) == .handled
        )
        #expect(
            runtime.dispatchExpiredLongPressActions(
                at: date.addingTimeInterval(1.5)
            ) == .handled
        )
        #expect(selectionCharacterOffsets(longPressSelection, in: text) == 1..<3)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .up),
                at: date.addingTimeInterval(1.6)
            ) == .handled
        )
        #expect(selectionCharacterOffsets(selection, in: text) == 1..<3)
        #expect(runtime.block(from: view)?.caret == nil)
    }

    @Test
    func `clicking the reserved trailing cell inserts at the end of the single-line EditableText`() {
        let runtime = StateRuntime()
        let view = ExactFitDelimitedFixedSizeSingleLineEditableTextView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
        #expect(runtime.consumeInvalidation())

        var block = runtime.block(from: view)
        #expect(block?.lines == ["[abc ]"])
        #expect(block?.caret == RenderedCaret(column: 3))

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 4, row: 0), phase: .down)
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        block = runtime.block(from: view)
        #expect(block?.lines == ["[abcX ]"])
        #expect(block?.caret == RenderedCaret(column: 5))
    }

    @Test
    func `dragging across a single-line EditableText selects the traversed range for replacement`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 3, row: 0), modifiers: [])
            ) == .handled
        )
        #expect(runtime.block(from: view)?.caret == nil)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.text == "Xd ")
        #expect(block?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `navigationDirection extends a dragged single-line EditableText selection from its command-side endpoint`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcdef")
            .environment(\.textSelectionNavigationBehavior, .navigationDirection)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)
        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 3,
            fromRow: 1,
            toColumn: 6,
            toRow: 1
        )
        #expect(runtime.dispatch(KeyPress(
            key: .leftArrow,
            characters: "\u{F702}",
            modifiers: .shift
        )) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)

        #expect(runtime.block(from: view)?.text == "aXf ")
    }

    @Test
    func `the nearest selection-navigation modifier wins over an outer environment value`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcdef")
            .textSelectionNavigationBehavior(.dragEndpoint)
            .environment(\.textSelectionNavigationBehavior, .navigationDirection)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)
        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 3,
            fromRow: 1,
            toColumn: 6,
            toRow: 1
        )
        #expect(runtime.dispatch(KeyPress(
            key: .leftArrow,
            characters: "\u{F702}",
            modifiers: .shift
        )) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)

        #expect(runtime.block(from: view)?.text == "abXef ")
    }

    @Test
    func `navigationDirection applies command-side extension to masked single-line EditableText selection`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<String>()
        let view = MaskedSingleLineEditableTextEditingView(textProbe: probe)
            .textSelectionNavigationBehavior(.navigationDirection)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)
        for character in "abcdef" {
            let characters = String(character)
            #expect(
                runtime.dispatch(KeyPress(key: KeyEquivalent(character), characters: characters))
                    == .handled
            )
        }
        _ = runtime.block(from: view)
        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 3,
            fromRow: 1,
            toColumn: 6,
            toRow: 1
        )
        #expect(runtime.dispatch(KeyPress(
            key: .leftArrow,
            characters: "\u{F702}",
            modifiers: .shift
        )) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)

        #expect(probe.binding?.wrappedValue == "aXf")
    }

    @Test
    func `navigationDirection makes Shift-Home and Shift-End extend from the command-side endpoint`() {
        let start = EditableTextSingleLineState(initialText: "abcdef") {}
        start.beginSelection(toColumn: 2, layoutText: start.text)
        start.extendSelection(toColumn: 5, layoutText: start.text)
        start.moveToStart(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(start.offset == 0)
        #expect(start.selectedRange == 0..<5)

        let end = EditableTextSingleLineState(initialText: "abcdef") {}
        end.beginSelection(toColumn: 5, layoutText: end.text)
        end.extendSelection(toColumn: 2, layoutText: end.text)
        end.moveToEnd(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(end.offset == 6)
        #expect(end.selectedRange == 2..<6)
    }

    @Test
    func `navigationDirection starts selection extension from the current caret after a click or text synchronization`() {
        let click = EditableTextSingleLineState(initialText: "abcdef") {}
        click.beginSelection(toColumn: 2, layoutText: click.text)
        click.moveRight(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(click.offset == 3)
        #expect(click.selectedRange == 2..<3)

        let externalChange = EditableTextSingleLineState(initialText: "abcdef") {}
        externalChange.beginSelection(toColumn: 2, layoutText: externalChange.text)
        externalChange.extendSelection(toColumn: 5, layoutText: externalChange.text)
        externalChange.synchronize(with: "xy")
        externalChange.moveLeft(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(externalChange.offset == 1)
        #expect(externalChange.selectedRange == 1..<2)
    }

    @Test
    func `navigationDirection holds a boundary selection until movement reverses inward`() {
        let state = EditableTextSingleLineState(initialText: "abcdef") {}
        state.beginSelection(toColumn: 0, layoutText: state.text)
        state.extendSelection(toColumn: 5, layoutText: state.text)

        state.moveLeft(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(state.offset == 0)
        #expect(state.selectedRange == 0..<5)

        state.moveRight(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(state.offset == 1)
        #expect(state.selectedRange == 1..<5)
    }

    @Test
    func `selection extension starts from the resulting caret after insertion or deletion`() {
        var insertedText = "abcdef"
        let insertion = EditableTextSingleLineState(initialText: insertedText) {}
        insertion.beginSelection(toColumn: 2, layoutText: insertion.text)
        insertion.extendSelection(toColumn: 5, layoutText: insertion.text)
        insertion.insert(
            "X",
            update: Binding(
                get: {
                    insertedText
                },
                set: {
                    insertedText = $0
                }
            )
        )
        insertion.moveLeft(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(insertedText == "abXf")
        #expect(insertion.selectedRange == 2..<3)

        var deletedText = "abcdef"
        let deletion = EditableTextSingleLineState(initialText: deletedText) {}
        deletion.beginSelection(toColumn: 2, layoutText: deletion.text)
        deletion.extendSelection(toColumn: 5, layoutText: deletion.text)
        deletion.deleteBackward(
            update: Binding(
                get: {
                    deletedText
                },
                set: {
                    deletedText = $0
                }
            )
        )
        deletion.moveRight(
            selecting: true,
            navigationBehavior: .navigationDirection
        )
        #expect(deletedText == "abf")
        #expect(deletion.selectedRange == 2..<3)
    }

    @Test
    func `dragging beyond a narrow single-line EditableText scrolls the selected endpoint into view`() {
        let runtime = StateRuntime()
        let view = PrefixedNarrowSingleLineEditableTextInitialTextView(text: "abcdef")

        #expect(renderUntilStable(runtime, view: view) <= 3)
        var block = runtime.block(from: view)
        #expect(block?.lines == ["|ef "])
        #expect(block?.caret == RenderedCaret(column: 3))

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 3, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 0, row: 0), modifiers: [])
            ) == .handled
        )
        #expect(renderUntilStable(runtime, view: view) <= 3)

        block = runtime.block(from: view)
        #expect(block?.lines == ["|def"])
        #expect(block?.caret == nil)
    }

    @Test
    func `unpressed pointer motion leaves the single-line EditableText caret unchanged`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 0, row: 0), modifiers: [])
            ) == .ignored
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.text == "abcdX ")
        #expect(block?.caret == RenderedCaret(column: 5))
    }

    @Test
    func `pointer-up ends a single-line EditableText drag so later motion cannot move its caret`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "abcd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 3, row: 0), modifiers: [])
            ) == .ignored
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.text == "Xabcd ")
        #expect(block?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `a scrolled single-line EditableText containing a wide glyph maps clicked terminal columns to source insertion points`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "한ABC")
            .frame(width: 3)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        var block = runtime.block(from: view)
        #expect(block?.lines == ["BC "])
        #expect(block?.caret == RenderedCaret(column: 2))

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .down)
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        block = runtime.block(from: view)
        #expect(block?.lines == ["BXC"])
        #expect(block?.caret == RenderedCaret(column: 2))
    }
}
