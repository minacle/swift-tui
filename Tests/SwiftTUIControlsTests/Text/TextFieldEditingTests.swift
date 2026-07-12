import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("Text Field Editing")
struct TextFieldEditingTests {

    @Test
    func `typing and backspace update a focused text field while unrelated control input is ignored`() {
        let runtime = StateRuntime()
        let view = TextFieldEditingView()

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
    func `a focused empty field overlays its placeholder without reserving a trailing caret cell`() {
        let runtime = StateRuntime()
        let view = OverlayPlaceholderTextFieldView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["Placeholder"])
        #expect(block?.width == 11)
        #expect(block?.caret == RenderedCaret(column: 0))
    }

    @Test
    func `a disabled text field rejects focus and leaves its binding unchanged`() {
        let runtime = StateRuntime()
        let textProbe = BindingProbe<String>()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = DisabledFocusedTextFieldView(
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
    func `stack layout offsets a text field's caret by preceding content`() {
        let runtime = StateRuntime()
        let view = LabeledTextFieldEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["Label: Name"])
        #expect(block?.caret == RenderedCaret(column: 7))
    }

    @Test
    func `a text field caret advances by terminal columns for wide glyphs`() {
        let runtime = StateRuntime()
        let view = TextFieldEditingView()

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
    func `typing an emoji ZWJ sequence inserts one grapheme and advances the text field caret two columns`() {
        let runtime = StateRuntime()
        let view = TextFieldEditingView()

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
    func `horizontal scrolling follows the text field caret in both directions`() {
        let runtime = StateRuntime()
        let view = TextFieldEditingView().frame(width: 3)

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
    func `text field scrolling clips wide glyphs only at terminal-cell boundaries`() {
        let runtime = StateRuntime()
        let view = TextFieldEditingView().frame(width: 3)

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
    func `exact-fit wide text remains unscrolled with its caret inside the final column`() {
        let runtime = StateRuntime()
        let text = String(repeating: "ㅁ", count: 16)
        let view = TextFieldInitialTextView(text: text)
            .frame(width: 32)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == [text])
        #expect(block?.caret == RenderedCaret(column: 31))
    }

    @Test
    func `an exact-fit field keeps its boundary caret out of the trailing sibling`() {
        let runtime = StateRuntime()
        let view = ExactFitDelimitedFixedSizeTextFieldView()

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
        let view = TextFieldInitialTextView(text: "ㄱㄴㄷㄹㅁ")
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
        let view = TextFieldInitialTextView(text: text)
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
    func `inserting into a full framed field scrolls content before its trailing delimiter`() {
        let runtime = StateRuntime()
        let text = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef"
        let view = DelimitedTextFieldView(text: text)

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
    func `a flexible field with wide overflow reaches a stable render after measurement`() {
        let runtime = StateRuntime()
        let view = FlexibleLabeledTextFieldView(
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
    func `an overlaid field in nested stacks remains stable after overflow input`() {
        let runtime = StateRuntime()
        let view = NestedOverlaidURLTextFieldEditingView()
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
    func `a field nested in ZStack accepts input after its overflow render stabilizes`() {
        let runtime = StateRuntime()
        let view = NestedZStackDelimitedTextFieldEditingView()
        let proposal = RenderProposal(columns: 20, rows: 4)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        typeText(textFieldOverflowInput(), into: runtime)
        #expect(runtime.consumeInvalidation())
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "Z", characters: "Z")) == .handled)
    }

    @Test
    func `a field nested in HStack accepts input after its overflow render stabilizes`() {
        let runtime = StateRuntime()
        let view = NestedHStackTextFieldEditingView()
        let proposal = RenderProposal(columns: 20, rows: 4)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        typeText(textFieldOverflowInput(), into: runtime)
        #expect(runtime.consumeInvalidation())
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "Z", characters: "Z")) == .handled)
    }

    @Test
    func `a nested secure field accepts input after its overflow render stabilizes`() {
        let runtime = StateRuntime()
        let view = NestedSecureFieldEditingView()
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
        let view = TextFieldEditingView()

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
    func `clicking a text field transfers focus and routes subsequent typing to its binding`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<FocusField?>()
        let textProbe = LabeledStringBindingProbe()
        let view = TwoTextFieldsClickFocusView(
            focusProbe: focusProbe,
            textProbe: textProbe
        )

        #expect(runtime.block(from: view)?.lines == ["first ", "second"])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 1), phase: .down)
            ) == .handled
        )
        #expect(focusProbe.binding?.wrappedValue == .second)

        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view)
        #expect(runtime.dispatch(KeyPress(key: "z", characters: "z")) == .handled)

        #expect(textProbe.bindings["first"]?.wrappedValue == "")
        #expect(textProbe.bindings["second"]?.wrappedValue == "z")
    }

    @Test
    func `clicking blank space inside a framed text field requests focus`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = FramedTextFieldClickFocusView(focusProbe: focusProbe)

        #expect(runtime.block(from: view)?.lines == ["A    "])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 4, row: 0), phase: .down)
            ) == .handled
        )
        #expect(focusProbe.binding?.wrappedValue == true)
    }

    @Test
    func `Return submits a text field's current value without moving its caret`() {
        let runtime = StateRuntime()
        let view = TextFieldSubmitView()

        #expect(runtime.block(from: view)?.lines == ["Name", "none"])
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["a ", "a "])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `moving optional row focus to a text field reveals its caret and enables editing`() {
        let runtime = StateRuntime()
        let view = DynamicTextFieldFocusWithOptionalRowFocusView()

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
    func `a dynamically focused text field remains visible and editable inside a vertical scroll view`() {
        let runtime = StateRuntime()
        let view = ScrollWrappedDynamicTextFieldFocusView()

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
