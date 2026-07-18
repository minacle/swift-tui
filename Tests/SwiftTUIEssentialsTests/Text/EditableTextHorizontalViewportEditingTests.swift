import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

@Suite("EditableText Horizontal Viewport Editing")
struct EditableTextHorizontalViewportEditingTests {

    @Test
    func `typing and backspace update a focused horizontally scrolled EditableText while unrelated control input is ignored`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextEditingView()

        #expect(runtime.block(from: view)?.text == "Name")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Name")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 0))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "a ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))

        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c", modifiers: .control)) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "a ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `a focused empty horizontally scrolled EditableText overlays its placeholder without reserving a trailing caret cell`() {
        let runtime = StateRuntime()
        let view = OverlayPlaceholderSingleLineEditableTextView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["Placeholder"])
        #expect(block?.width == 11)
        #expect(block?.caret == RenderedCaret(column: 0))
    }

    @Test
    func `a disabled horizontally scrolled EditableText rejects focus and leaves its binding unchanged`() {
        let runtime = StateRuntime()
        let textProbe = BindingProbe<String>()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = DisabledFocusedSingleLineEditableTextView(
            textProbe: textProbe,
            focusProbe: focusProbe
        )

        #expect(runtime.block(from: view)?.text == "Name")
        #expect(focusProbe.binding?.wrappedValue == false)
        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
        #expect(textProbe.binding?.wrappedValue == "")
    }

    @Test
    func `stack layout offsets a horizontally scrolled EditableText's caret by preceding content`() {
        let runtime = StateRuntime()
        let view = LabeledSingleLineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["Label: Name"])
        #expect(block?.caret == RenderedCaret(column: 7))
    }

    @Test
    func `a horizontally scrolled EditableText caret advances by terminal columns for wide glyphs`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "한A ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 3))
    }

    @Test
    func `typing an emoji ZWJ sequence inserts one grapheme and advances the horizontally scrolled EditableText caret two columns`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                KeyPress(key: "👨‍👩‍👧‍👦", characters: "👨‍👩‍👧‍👦")
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view)
        #expect(block?.text == "👨‍👩‍👧‍👦A ")
        #expect(block?.caret == RenderedCaret(column: 3))
    }

    @Test
    func `horizontal scrolling follows the horizontally scrolled EditableText caret in both directions`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextEditingView().frame(width: 3)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        for character in "abcd" {
            #expect(
                runtime.dispatch(
                    KeyPress(key: KeyEquivalent(character), characters: String(character))
                ) == .handled
            )
        }

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["cd "])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))

        #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["bcd"])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 0))
    }

    @Test
    func `an EditableText horizontal viewport clips wide glyphs only at terminal-cell boundaries`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextEditingView().frame(width: 3)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "B", characters: "B")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["AB "])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))
    }

    @Test
    func `an exact-fit horizontally scrolled EditableText keeps its boundary caret out of the trailing sibling`() {
        let runtime = StateRuntime()
        let view = ExactFitDelimitedFixedSizeSingleLineEditableTextView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view)

        #expect(block?.lines == ["[abc ]"])
        #expect(block?.caret == RenderedCaret(column: 4))
    }

    @Test
    func `moving the caret past an exact-width run of wide glyphs scrolls without clipping a glyph`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextInitialTextView(text: "ㄱㄴㄷㄹㅁ")
            .frame(width: 6)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["ㄱㄴㄷ"])

        for _ in 0..<3 {
            #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
        }

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["ㄴㄷㄹ"])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 4))
    }

    @Test
    func `deleting wide text never scrolls the viewport into the middle of a glyph`() {
        let runtime = StateRuntime()
        let text = "ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆ"
        let view = SingleLineEditableTextInitialTextView(text: text)
            .frame(width: 32)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        #expect(runtime.block(from: view)?.lines == ["ㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆ  "])

        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.lines == ["ㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃ  "])
        #expect(block?.caret == RenderedCaret(column: 30))
    }

    @Test
    func `inserting into a full framed horizontally scrolled EditableText scrolls content before its trailing delimiter`() {
        let runtime = StateRuntime()
        let text = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef"
        let view = DelimitedSingleLineEditableTextView(text: text)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "g", characters: "g")) == .handled)
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view)

        #expect(block?.lines == ["[CDEFGHIJKLMNOPQRSTUVWXYZabcdefg ]"])
        #expect(block?.caret == RenderedCaret(column: 32))
    }

    @Test
    func `a flexible horizontally scrolled EditableText with wide overflow reaches a stable render after measurement`() {
        let runtime = StateRuntime()
        let view = FlexibleLabeledSingleLineEditableTextView(
            text: String(repeating: "한글", count: 30)
        )

        for _ in 0..<3 {
            _ = runtime.block(from: view, in: RenderProposal(columns: 40, rows: 4))
            _ = runtime.consumeInvalidation()
        }

        _ = runtime.block(from: view, in: RenderProposal(columns: 40, rows: 4))
        #expect(!runtime.consumeInvalidation())
    }

    @Test
    func `an overlaid horizontally scrolled EditableText in nested stacks remains stable after overflow input`() {
        let runtime = StateRuntime()
        let view = NestedOverlaidURLSingleLineEditableTextEditingView()
        let proposal = RenderProposal(columns: 80, rows: 24)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        typeText(textFieldOverflowInput(), into: runtime)
        #expect(runtime.consumeInvalidation())
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "Z", characters: "Z")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        let block = runtime.block(from: view, in: proposal)
        #expect(block?.width == 80)
        #expect(block?.lines.first?.count == 80)
    }

    @Test
    func `a horizontally scrolled EditableText nested in ZStack accepts input after its overflow render stabilizes`() {
        let runtime = StateRuntime()
        let view = NestedZStackDelimitedSingleLineEditableTextEditingView()
        let proposal = RenderProposal(columns: 20, rows: 4)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        typeText(textFieldOverflowInput(), into: runtime)
        #expect(runtime.consumeInvalidation())
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "Z", characters: "Z")) == .handled)
    }

    @Test
    func `a horizontally scrolled EditableText nested in HStack accepts input after its overflow render stabilizes`() {
        let runtime = StateRuntime()
        let view = NestedHStackSingleLineEditableTextEditingView()
        let proposal = RenderProposal(columns: 20, rows: 4)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        typeText(textFieldOverflowInput(), into: runtime)
        #expect(runtime.consumeInvalidation())
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "Z", characters: "Z")) == .handled)
    }

    @Test
    func `a nested masked horizontally scrolled EditableText accepts input after its overflow render stabilizes`() {
        let runtime = StateRuntime()
        let view = NestedMaskedSingleLineEditableTextEditingView()
        let proposal = RenderProposal(columns: 20, rows: 4)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        typeText(textFieldOverflowInput(), into: runtime)
        #expect(runtime.consumeInvalidation())
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "Z", characters: "Z")) == .handled)
    }

    @Test
    func `vertical arrow keys are ignored without inserting their control characters`() {
        let runtime = StateRuntime()
        let view = SingleLineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .ignored)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "a ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `clicking a horizontally scrolled EditableText transfers focus and routes subsequent typing to its binding`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<FocusField?>()
        let textProbe = LabeledStringBindingProbe()
        let view = TwoSingleLineEditableTextsClickFocusView(
            focusProbe: focusProbe,
            textProbe: textProbe
        )

        #expect(runtime.block(from: view)?.lines == ["first ", "second"])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 1), phase: .down)
            ) == .ignored
        )
        #expect(focusProbe.binding?.wrappedValue == .second)

        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view)
        #expect(runtime.dispatch(KeyPress(key: "z", characters: "z")) == .handled)

        #expect(textProbe.bindings["first"]?.wrappedValue == "")
        #expect(textProbe.bindings["second"]?.wrappedValue == "z")
    }

    @Test
    func `clicking blank space inside a framed horizontally scrolled EditableText requests focus`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = FramedSingleLineEditableTextClickFocusView(focusProbe: focusProbe)

        #expect(runtime.block(from: view)?.lines == ["A    "])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 4, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(focusProbe.binding?.wrappedValue == true)
    }

    @Test
    func `moving optional row focus to a horizontally scrolled EditableText reveals its caret and enables editing`() {
        let runtime = StateRuntime()
        let view = DynamicSingleLineEditableTextFocusWithOptionalRowFocusView()

        _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
        #expect(runtime.consumeInvalidation())

        let editorBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
        #expect(editorBlock?.caret == RenderedCaret(row: 1, column: 2))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())

        let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
        #expect(editedBlock?.lines.dropFirst().first?.hasPrefix("> a") == true)
        #expect(editedBlock?.caret == RenderedCaret(row: 1, column: 3))
    }

    @Test
    func `a dynamically focused horizontally scrolled EditableText remains visible and editable inside a vertical scroll view`() {
        let runtime = StateRuntime()
        let view = ScrollWrappedDynamicSingleLineEditableTextFocusView()

        _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
        #expect(runtime.consumeInvalidation())

        let editorBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
        #expect(editorBlock?.caret == RenderedCaret(row: 1, column: 2))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())

        let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
        #expect(editedBlock?.lines.dropFirst().first?.hasPrefix("> a") == true)
        #expect(editedBlock?.caret == RenderedCaret(row: 1, column: 3))
    }
}
