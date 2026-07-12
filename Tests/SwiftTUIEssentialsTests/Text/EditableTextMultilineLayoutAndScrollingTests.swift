import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

@Suite("EditableText Multiline Layout and Scrolling")
struct EditableTextMultilineLayoutAndScrollingTests {

    @Test
    func `Return at the viewport bottom scrolls the multiline EditableText and keeps subsequent input visible`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextEditingView()

        _ = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        let bottomBlock = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
        #expect(bottomBlock?.caret == RenderedCaret(row: 1, column: 0))

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        let scrolledBlock = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
        #expect(scrolledBlock?.lines == ["   ", "   "])
        #expect(scrolledBlock?.caret == RenderedCaret(row: 1, column: 0))

        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
        #expect(editedBlock?.lines == ["   ", "b  "])
        #expect(editedBlock?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `a fixed-height multiline EditableText scrolls after Return and remains editable`() {
        let runtime = StateRuntime()
        let view = FramedMultilineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        let scrolledBlock = runtime.block(from: view)
        #expect(scrolledBlock?.lines == ["   ", "   "])
        #expect(scrolledBlock?.caret == RenderedCaret(row: 1, column: 0))

        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view)
        #expect(editedBlock?.lines == ["   ", "b  "])
        #expect(editedBlock?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `a max-height framed multiline EditableText expands, scrolls, and remains editable after Return`() {
        let runtime = StateRuntime()
        let view = MaxHeightFramedMultilineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let initialBlock = runtime.block(from: view)
        #expect(initialBlock?.lines == ["   "])
        #expect(initialBlock?.caret == RenderedCaret(row: 0, column: 0))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        let scrolledBlock = runtime.block(from: view)
        #expect(scrolledBlock?.lines == ["   ", "   "])
        #expect(scrolledBlock?.caret == RenderedCaret(row: 1, column: 0))

        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view)
        #expect(editedBlock?.lines == ["   ", "b  "])
        #expect(editedBlock?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `a max-height multiline EditableText without a row proposal remains editable`() {
        let runtime = StateRuntime()
        let view = MaxHeightOnlyMultilineEditableTextEditingView()

        _ = runtime.block(from: view, in: RenderProposal(columns: 3))
        _ = runtime.consumeInvalidation()
        let initialBlock = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(initialBlock?.lines == ["   "])
        #expect(initialBlock?.caret == RenderedCaret(row: 0, column: 0))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(editedBlock?.lines == ["a  "])
        #expect(editedBlock?.caret == RenderedCaret(row: 0, column: 1))
    }

    @Test
    func `clicking a max-height multiline EditableText without a row proposal enables typing`() {
        let runtime = StateRuntime()
        let view = MaxHeightOnlyMultilineEditableTextClickFocusView()

        _ = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view, in: RenderProposal(columns: 3))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 3))
        #expect(editedBlock?.lines == ["a  "])
        #expect(editedBlock?.caret == RenderedCaret(row: 0, column: 1))
    }

    @Test
    func `a max-height multiline EditableText below a scroll view accepts click focus in a short viewport`() {
        let runtime = StateRuntime()
        let view = MaxHeightConstantMultilineEditableTextBelowScrollViewView()
        let proposal = RenderProposal(columns: 8, rows: 6)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 4), phase: .down)
            ) == .handled
        )

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let editedBlock = runtime.block(from: view, in: proposal)
        #expect(editedBlock?.lines.suffix(2) == ["│a     │", "└──────┘"])
        #expect(editedBlock?.caret == RenderedCaret(row: 4, column: 2))
    }

    @Test
    func `a max-height multiline EditableText below a scroll view accepts click focus in a tall viewport`() {
        let runtime = StateRuntime()
        let view = MaxHeightConstantMultilineEditableTextBelowScrollViewView()
        let proposal = RenderProposal(columns: 80, rows: 24)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 22), phase: .down)
            ) == .handled
        )

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let editedBlock = runtime.block(from: view, in: proposal)
        #expect(editedBlock?.lines.suffix(2) == [
            "│a                                                                             │",
            "└──────────────────────────────────────────────────────────────────────────────┘"
        ])
        #expect(editedBlock?.caret == RenderedCaret(row: 22, column: 2))
    }

    @Test
    func `Return grows a max-height multiline EditableText below a scroll view without hiding prior lines`() {
        let runtime = StateRuntime()
        let view = MaxHeightConstantMultilineEditableTextBelowScrollViewView()
            .onTerminate {}
        let proposal = RenderProposal(columns: 80)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 2), phase: .down)
            ) == .handled
        )
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        var block = runtime.block(from: view, in: proposal)
        #expect(block?.lines.suffix(3) == [
            "┌──────────────────────────────────────────────────────────────────────────────┐",
            "│a                                                                             │",
            "└──────────────────────────────────────────────────────────────────────────────┘"
        ])

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        block = runtime.block(from: view, in: proposal)
        #expect(block?.lines.suffix(4) == [
            "┌──────────────────────────────────────────────────────────────────────────────┐",
            "│a                                                                             │",
            "│                                                                              │",
            "└──────────────────────────────────────────────────────────────────────────────┘"
        ])

        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        block = runtime.block(from: view, in: proposal)
        #expect(block?.lines.suffix(4) == [
            "┌──────────────────────────────────────────────────────────────────────────────┐",
            "│a                                                                             │",
            "│b                                                                             │",
            "└──────────────────────────────────────────────────────────────────────────────┘"
        ])

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        block = runtime.block(from: view, in: proposal)
        #expect(block?.lines.suffix(5) == [
            "┌──────────────────────────────────────────────────────────────────────────────┐",
            "│a                                                                             │",
            "│b                                                                             │",
            "│                                                                              │",
            "└──────────────────────────────────────────────────────────────────────────────┘"
        ])
    }

    @Test
    func `a prefilled framed multiline EditableText adds a line at the bottom and accepts more input`() {
        let runtime = StateRuntime()
        let view = FramedMultilineEditableTextInitialTextView(text: "abcdef")

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let initialBlock = runtime.block(from: view)
        #expect(initialBlock?.lines == ["def", "   "])
        #expect(initialBlock?.caret == RenderedCaret(row: 1, column: 0))

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        let scrolledBlock = runtime.block(from: view)
        #expect(scrolledBlock?.lines == ["def", "   "])
        #expect(scrolledBlock?.caret == RenderedCaret(row: 1, column: 0))

        #expect(runtime.dispatch(KeyPress(key: "g", characters: "g")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view)
        #expect(editedBlock?.lines == ["def", "g  "])
        #expect(editedBlock?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `wrapped overflow scrolls a framed multiline EditableText and keeps the caret visible at the insertion point`() {
        let runtime = StateRuntime()
        let view = FramedMultilineEditableTextEditingView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        for character in "abcdefg" {
            #expect(
                runtime.dispatch(
                    KeyPress(key: KeyEquivalent(character), characters: String(character))
                ) == .handled
            )
        }
        #expect(runtime.consumeInvalidation())
        let block = runtime.block(from: view)
        #expect(block?.lines == ["def", "g  "])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `a boxed multiline EditableText below a scroll view remains editable at its bottom row`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextBelowScrollViewView()

        _ = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        let bottomBlock = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))
        #expect(bottomBlock?.caret == RenderedCaret(row: 4, column: 1))

        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(runtime.consumeInvalidation())
        let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))
        #expect(editedBlock?.lines.suffix(2) == ["│b     │", "└──────┘"])
        #expect(editedBlock?.caret == RenderedCaret(row: 4, column: 2))
    }

    @Test
    func `a boxed multiline EditableText scrolls after filling visible rows and continues accepting input`() {
        let runtime = StateRuntime()
        let view = MultilineEditableTextBelowScrollViewView()
        let proposal = RenderProposal(columns: 80, rows: 24)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        for _ in 0..<9 {
            #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        }
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let bottomBlock = runtime.block(from: view, in: proposal)
        #expect(bottomBlock?.caret == RenderedCaret(row: 22, column: 1))

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let scrolledBlock = runtime.block(from: view, in: proposal)
        #expect(scrolledBlock?.caret == RenderedCaret(row: 22, column: 1))

        #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let editedBlock = runtime.block(from: view, in: proposal)
        #expect(editedBlock?.caret == RenderedCaret(row: 22, column: 2))
    }

    @Test
    func `clicking blank space inside a framed multiline EditableText requests focus`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<Bool>()
        let view = FramedMultilineEditableTextClickFocusView(focusProbe: focusProbe)

        #expect(runtime.block(from: view)?.lines == ["     ", "     ", "     "])
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 1), phase: .down)
            ) == .handled
        )
        #expect(focusProbe.binding?.wrappedValue == true)
    }

}
