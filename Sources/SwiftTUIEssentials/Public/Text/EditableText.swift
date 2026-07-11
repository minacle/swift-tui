/// A primitive view that edits text in the terminal.
///
/// `EditableText` provides the editing, selection, caret, pointer, and
/// scrolling behavior used to build higher-level text controls.
public nonisolated struct EditableText: View, EditableTextRenderable,
    LayoutTraitRenderable
{

    /// The line-editing behavior of editable text.
    public nonisolated enum LineMode: Sendable {

        /// Edits one line and leaves Return available to an enclosing view.
        case singleLine

        /// Edits multiple lines, including newline insertion and vertical navigation.
        case multiline
    }

    /// The body type for this primitive view.
    public typealias Body = Never

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    let lineMode: LineMode

    let mask: Character?

    var layoutTraits: LayoutTraits {
        switch lineMode {
        case .singleLine:
            LayoutTraits(flexibleAxes: .horizontal)
        case .multiline:
            LayoutTraits(flexibleAxes: [.horizontal, .vertical])
        }
    }

    /// Creates editable text without exposing its current selection.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string.
    ///   - lineMode: Whether the view edits one line or multiple lines.
    ///   - mask: A character displayed in place of each non-newline character,
    ///     or `nil` to display the original text.
    public init(
        text: Binding<String>,
        lineMode: LineMode = .singleLine,
        mask: Character? = nil
    ) {
        self.text = text
        self.selection = nil
        self.lineMode = lineMode
        self.mask = mask
    }

    /// Creates editable text with a binding to its current selection.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string.
    ///   - selection: A binding to the current selection.
    ///   - lineMode: Whether the view edits one line or multiple lines.
    ///   - mask: A character displayed in place of each non-newline character,
    ///     or `nil` to display the original text.
    public init(
        text: Binding<String>,
        selection: Binding<TextSelection?>,
        lineMode: LineMode = .singleLine,
        mask: Character? = nil
    ) {
        self.text = text
        self.selection = selection
        self.lineMode = lineMode
        self.mask = mask
    }

    func displayedText(for text: String) -> String {
        guard let mask else {
            return text
        }

        return String(text.map { $0 == "\n" ? $0 : mask })
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        switch lineMode {
        case .singleLine:
            return EditableTextSingleLineRenderer.renderedBlock(
                text: text,
                selection: selection,
                prompt: nil,
                label: Text(""),
                displayMode: mask.map(EditableTextDisplayMode.masked) ?? .plain,
                proposal: proposal,
                path: path,
                runtime: runtime
            )
        case .multiline:
            return renderedMultilineBlock(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

public extension EditableText {

    /// Displays placeholder content while single-line editable text is empty.
    ///
    /// The placeholder participates in the editable text's own rendering, so it
    /// follows the current editing state even when the source binding rejects a
    /// write, such as a constant binding.
    nonisolated func placeholder<Placeholder: View>(
        @ViewBuilder content: () -> Placeholder
    ) -> some View {
        EditableTextPlaceholder(content: self, placeholder: content())
    }
}

private nonisolated struct EditableTextPlaceholder<Placeholder: View>:
    View, EditableTextRenderable, LayoutTraitRenderable
{

    typealias Body = Never

    let content: EditableText

    let placeholder: Placeholder

    var layoutTraits: LayoutTraits {
        content.layoutTraits
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard case .singleLine = content.lineMode else {
            return content.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        return EditableTextSingleLineRenderer.renderedBlock(
            text: content.text,
            selection: content.selection,
            prompt: nil,
            label: placeholder,
            displayMode: content.mask.map(EditableTextDisplayMode.masked) ?? .plain,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

protocol EditableTextRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}
