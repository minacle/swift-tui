import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

@Suite("EditableText Multiline Editing")
struct EditableTextMultilineEditingTests {

    @Test
    func `typing and Return update multiline EditableText content and place the caret after the inserted text`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.lines == ["a", "b"])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `Backspace joins multiline EditableText lines when deletion crosses a newline`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextInitialTextView(text: "ab\ncd")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        #expect(block?.lines == ["ab"])
        #expect(block?.caret == RenderedCaret(row: 0, column: 2))
    }

    @Test
    func `vertical, Home, and horizontal navigation follow wrapped visual lines`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextInitialTextView(text: "abcde")

        _ = runtime.block(from: view, in: RenderProposal(columns: 3))
        _ = runtime.consumeInvalidation()
        var block = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(block?.lines == ["abc", "de "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 2))

        #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .handled)
        #expect(runtime.consumeInvalidation())
        block = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(block?.caret == RenderedCaret(row: 0, column: 2))

        #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
        #expect(runtime.consumeInvalidation())
        block = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(block?.caret == RenderedCaret(row: 0, column: 0))

        #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
        #expect(runtime.consumeInvalidation())
        block = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(block?.caret == RenderedCaret(row: 1, column: 2))
    }

    @Test
    func `an exact-width multiline EditableText line exposes a trailing visual row for caret and further input`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextEditingView()
        let proposal = RenderProposal(columns: 3, rows: 2)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        for character in "abc" {
            #expect(
                runtime.dispatch(
                    KeyPress(key: KeyEquivalent(character), characters: String(character))
                ) == .handled
            )
        }
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        var block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["abc", "   "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 0))

        #expect(runtime.dispatch(KeyPress(key: "d", characters: "d")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        block = runtime.block(from: view, in: proposal)
        #expect(block?.lines == ["abc", "d  "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `wrapped trailing spaces remain visible with the caret on the overflow row`() {
        let runtime = StateRuntime()
        let line = "Lorem ipsum dolor sit amet."
        let view = MultilineEditableTextInitialTextView(text: line + "  ")
        let proposal = RenderProposal(columns: 28, rows: 2)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let block = runtime.block(from: view, in: proposal)

        #expect(block?.lines == [
            line + " ",
            String(repeating: " ", count: 28),
        ])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `spaces before a wrapped character retain their source order and caret position`() {
        let runtime = StateRuntime()
        let line = "Lorem ipsum dolor sit amet."
        let view = MultilineEditableTextInitialTextView(text: line + "  a")
        let proposal = RenderProposal(columns: 28, rows: 2)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let block = runtime.block(from: view, in: proposal)

        #expect(block?.lines == [
            line + " ",
            " a" + String(repeating: " ", count: 26),
        ])
        #expect(block?.caret == RenderedCaret(row: 1, column: 2))
    }

    @Test
    func `the multiline EditableText caret advances by terminal columns for wide glyphs`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view)

        #expect(block?.lines == ["한A"])
        #expect(block?.caret == RenderedCaret(row: 0, column: 3))
    }

    @Test
    func `typing an emoji ZWJ sequence inserts one grapheme and advances the multiline EditableText caret two columns`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                KeyPress(key: "👩‍❤️‍💋‍👨", characters: "👩‍❤️‍💋‍👨")
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view)

        #expect(block?.lines == ["👩‍❤️‍💋‍👨A"])
        #expect(block?.caret == RenderedCaret(row: 0, column: 3))
    }

    @Test
    func `initial multiline content scrolls vertically to reveal the caret at the end`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextInitialTextView(text: "a\nb\nc\nd")

        _ = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))

        #expect(block?.lines == ["c  ", "d  "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `an empty multiline EditableText fills its proposed rows with one focus region and an initial caret`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextEditingView()

        _ = runtime.block(from: view, in: RenderProposal(columns: 5, rows: 2))
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view, in: RenderProposal(columns: 5, rows: 2))

        #expect(block?.lines == ["     ", "     "])
        #expect(block?.caret == RenderedCaret(row: 0, column: 0))
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(x: 0, y: 0, width: 5, height: 2),
        ])
    }

    @Test
    func `a disabled multiline EditableText rejects focus and leaves its binding unchanged`() {
        let runtime = StateRuntime()
        let textProbe = BindingProbe<String>()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = DisabledFocusedMultilineEditableTextView(
            textProbe: textProbe,
            focusProbe: focusProbe
        )

        #expect(runtime.block(from: view)?.lines == [" "])
        #expect(focusProbe.binding?.wrappedValue == false)
        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
        #expect(textProbe.binding?.wrappedValue == "")
    }

    @Test
    func `an external text replacement rerenders the multiline EditableText and clamps its caret`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<String>()
        let view = CapturedMultilineEditableTextView(text: "abc", probe: probe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        probe.binding?.wrappedValue = "x"
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view)

        #expect(block?.lines == ["x"])
        #expect(block?.caret == RenderedCaret(row: 0, column: 1))
    }
}
