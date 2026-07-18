import Testing

@testable import SwiftTUIEssentials

@Suite("Text Input Anchor Scrolling")
struct TextInputAnchorScrollingTests {

    @Test
    func `padding frame and clipping transform a text-input anchor with its content`() {
        let anchor = RenderedTextInputAnchor(
            focusPath: [2],
            generation: 3,
            row: 0,
            column: 2
        )
        let block = RenderedBlock(lines: ["ab"], textInputAnchor: anchor)
        let padded = block.padded(
            by: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 0)
        )
        let framed = padded.framed(width: 6, height: 5, alignment: .bottomTrailing)
        let clipped = framed.offsetBy(
            x: -6,
            y: 0,
            clippedTo: RenderedRect(width: 2, height: 5)
        )

        #expect(padded.textInputAnchor?.row == 1)
        #expect(padded.textInputAnchor?.column == 4)
        #expect(framed.textInputAnchor?.row == 3)
        #expect(framed.textInputAnchor?.column == 5)
        #expect(clipped.textInputAnchor == nil)
    }

    @Test
    func `eager and lazy stacks translate an EditableText anchor to its placed row and column`() {
        let eager = VStack(alignment: .leading, spacing: 0) {
            Text("A")
            HStack(spacing: 0) {
                Text(">")
                EditableText(text: .constant("bc"))
            }
        }
        let lazy = LazyVStack(alignment: .leading, spacing: 0) {
            Text("A")
            HStack(spacing: 0) {
                Text(">")
                EditableText(text: .constant("bc"))
            }
        }

        let eagerAnchor = ViewResolver.block(from: eager)?.textInputAnchor
        let lazyAnchor = ViewResolver.block(from: lazy)?.textInputAnchor

        #expect(eagerAnchor?.row == 1)
        #expect(eagerAnchor?.column == 3)
        #expect(lazyAnchor?.row == 1)
        #expect(lazyAnchor?.column == 3)
    }

    @Test
    func `a pinned section header keeps its EditableText anchor at the pinned row`() {
        let view = ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 0,
                pinnedViews: [.sectionHeaders]
            ) {
                Section {
                    Text("A")
                    Text("B")
                    Text("C")
                } header: {
                    EditableText(text: .constant("H"))
                }
            }
        }
        .scrollPosition(.constant(ScrollPosition(y: 2)))
        .frame(width: 2, height: 2)

        let block = ViewResolver.block(from: view)

        #expect(block?.lines == ["H ", "C "])
        #expect(block?.textInputAnchor?.row == 0)
        #expect(block?.textInputAnchor?.column == 1)
        #expect(block?.textInputAnchor?.hasFocusViewport == true)
    }

    @Test
    func `a focused range hides the caret but anchors reveal at its active endpoint`() {
        let text = "abcdef"
        let lowerBound = text.index(text.startIndex, offsetBy: 1)
        let upperBound = text.index(text.startIndex, offsetBy: 5)
        let selection = TextSelection(
            range: lowerBound..<upperBound
        )
        let runtime = StateRuntime()
        let view = FocusedSelectedEditableText(
            text: text,
            selection: .constant(selection)
        )

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.caret == nil)
        #expect(block?.textInputAnchor?.column == 5)
        #expect(block?.textInputAnchor?.isFocused == true)
    }

    @Test
    func `the focused editor supplies the anchor selected from a stack of editors`() {
        let runtime = StateRuntime()
        let view = ScrollView {
            FocusedEditorStack()
        }
        .frame(width: 3, height: 1)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["bb "])
        #expect(block?.caret == RenderedCaret(row: 0, column: 2))
        #expect(block?.textInputAnchor?.focusPath == [0, 0, 0, 1])
        #expect(block?.textInputAnchor?.isFocused == true)
    }

    @Test
    func `text-input reveal overrides an explicit point and publishes the concrete viewport`() {
        var position = ScrollPosition(x: 0)
        let positionBinding = Binding(
            get: { position },
            set: { position = $0 }
        )
        let runtime = StateRuntime()
        let view = FocusedHorizontalEditableText(position: positionBinding)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["ef "])
        #expect(block?.caret == RenderedCaret(row: 0, column: 2))
        #expect(position.point == ScrollPoint(x: 4))
    }

    @Test
    func `wheel movement remains until the focused editor changes its anchor`() {
        let runtime = StateRuntime()
        let view = FocusedWheelScrollableEditableText()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        #expect(runtime.block(from: view)?.lines == ["ef "])

        #expect(
            runtime.dispatch(
                PointerScroll(
                    delta: Size(columns: -1, rows: 0),
                    location: Point(column: 0, row: 0)
                )
            ) == .handled
        )
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["def"])

        #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["abc"])
    }

    @Test
    func `nested scroll views reveal the same anchor on each enabled axis`() {
        let runtime = StateRuntime()
        let view = FocusedNestedEditableText()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["ef "])
        #expect(block?.caret == RenderedCaret(row: 0, column: 2))
        #expect(block?.textInputAnchor?.row == 0)
        #expect(block?.textInputAnchor?.column == 2)
        #expect(block?.textInputAnchor?.hasFocusViewport == true)
    }
}

private struct FocusedSelectedEditableText: View {

    let text: String

    let selection: Binding<TextSelection?>

    @FocusState private var isFocused = true

    var body: some View {
        EditableText(text: .constant(text), selection: selection)
            .focused($isFocused)
    }
}

private enum EditorFocus: Hashable {

    case first

    case second
}

private struct FocusedEditorStack: View {

    @FocusState private var focus: EditorFocus? = .second

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditableText(text: .constant("aa"))
                .focused($focus, equals: .first)
            EditableText(text: .constant("bb"))
                .focused($focus, equals: .second)
        }
    }
}

private struct FocusedHorizontalEditableText: View {

    let position: Binding<ScrollPosition>

    @FocusState private var isFocused = true

    var body: some View {
        ScrollView(.horizontal) {
            EditableText(text: .constant("abcdef"))
                .focused($isFocused)
        }
        .scrollPosition(position)
        .frame(width: 3, height: 1)
    }
}

private struct FocusedWheelScrollableEditableText: View {

    @FocusState private var isFocused = true

    var body: some View {
        ScrollView(.horizontal) {
            EditableText(text: .constant("abcdef"))
                .focused($isFocused)
        }
        .frame(width: 3, height: 1)
    }
}

private struct FocusedNestedEditableText: View {

    @FocusState private var isFocused = true

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Text("top")
                ScrollView(.horizontal) {
                    EditableText(text: .constant("abcdef"))
                        .focused($isFocused)
                }
                .frame(width: 3, height: 1)
            }
        }
        .frame(width: 3, height: 1)
    }
}
