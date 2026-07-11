/// A primitive view that edits text in the terminal.
///
/// `EditableText` provides the editing, selection, caret, pointer, and
/// scrolling behavior used to build higher-level text controls. Use
/// ``LineMode/singleLine`` for a one-row control that leaves Return available
/// to an enclosing view, or ``LineMode/multiline`` for an editor that inserts
/// newlines and supports vertical caret movement.
///
/// Most applications should use the controls provided by the
/// `SwiftTUIControls` module. Use this primitive when a control needs custom
/// composition while retaining SwiftTUI's standard text-editing behavior.
///
/// SwiftTUI doesn't sanitize terminal control characters or escape sequences
/// in unmasked bound text, a mask character, or extracted placeholder text.
/// Sanitize untrusted values before supplying them. A mask changes only the
/// displayed characters; the original value remains available to bindings,
/// callbacks, memory, logs, and persistent storage.
///
/// ```swift
/// struct SearchView: View {
///     @State private var query = ""
///
///     var body: some View {
///         EditableText(text: $query)
///             .placeholder {
///                 Text("Search")
///             }
///     }
/// }
/// ```
public nonisolated struct EditableText: View, EditableTextRenderable,
    LayoutTraitRenderable
{

    /// The line-editing behavior of editable text.
    public nonisolated enum LineMode: Sendable {

        /// Edits one rendered row and leaves Return available to an enclosing
        /// handler.
        ///
        /// The view scrolls horizontally when a finite column proposal can't
        /// show the caret. Return is ignored rather than inserted, allowing an
        /// ancestor or global key handler to treat it as submission. This mode
        /// doesn't sanitize newline characters already supplied by the binding.
        case singleLine

        /// Edits multiple lines with newline insertion and vertical navigation.
        ///
        /// Text wraps to a finite proposed width. When either proposed axis is
        /// finite, the editor scrolls as needed to keep its rendered text caret
        /// visible within that axis.
        case multiline
    }

    /// The body type for this directly rendered primitive view.
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

    /// Creates editable text with selection managed entirely by SwiftTUI.
    ///
    /// The view reads external binding changes during rendering and writes each
    /// accepted edit synchronously. A binding that ignores a write doesn't
    /// immediately roll back the editor's internal text; a later distinct
    /// external value resynchronizes it, clamps the caret to the new character
    /// bounds, and clears any internal selected range.
    ///
    /// With no mask, bound text is emitted without terminal-control
    /// sanitization. A supplied mask character is also emitted unchanged.
    /// Sanitize untrusted text and masks before use. Masking changes only
    /// rendered output: it doesn't alter the value stored in `text` and isn't a
    /// substitute for protecting sensitive values in memory, logs, callbacks,
    /// or persistent storage.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string. Unmasked content isn't
    ///     sanitized before terminal rendering.
    ///   - lineMode: Whether the view edits one line or multiple lines.
    ///   - mask: A character to display for each editable character, or `nil`
    ///     to display the bound string. The mask itself isn't sanitized.
    ///     Multiline rendering preserves newline separators rather than
    ///     replacing them.
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
    /// When the view gains focus, it publishes its current insertion point or
    /// range to `selection`. Subsequent pointer selection, keyboard navigation,
    /// and editing publish each change while the view is active. Losing focus
    /// leaves the last published value intact; it doesn't write `nil`.
    ///
    /// Assign a valid non-`nil` selection built from the current bound string to
    /// update the insertion point or selected range. This assignment doesn't
    /// change `text`; a later edit replaces the selected range. Assign `nil` to
    /// hide the external selection and keep the editor's clamped internal caret
    /// until the next selection change. Indices from another or obsolete string
    /// can't be applied.
    ///
    /// With no mask, bound text is emitted without terminal-control
    /// sanitization. A supplied mask character is also emitted unchanged.
    /// Sanitize untrusted text and masks before use. Masking changes only
    /// rendered output: it doesn't alter the value stored in `text` and isn't a
    /// substitute for protecting sensitive values in memory, logs, callbacks,
    /// or persistent storage.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string. Unmasked content isn't
    ///     sanitized before terminal rendering.
    ///   - selection: A binding through which the caller can supply and observe
    ///     a selection in the current `text` value. `nil` means no externally
    ///     supplied selection; it isn't a focus indicator.
    ///   - lineMode: Whether the view edits one line or multiple lines.
    ///   - mask: A character to display for each editable character, or `nil`
    ///     to display the bound string. The mask itself isn't sanitized.
    ///     Multiline rendering preserves newline separators rather than
    ///     replacing them.
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

    /// Displays placeholder text while single-line editable text is empty.
    ///
    /// The placeholder participates in the editable text's own rendering, so it
    /// follows the current editing state even when the source binding rejects a
    /// write, such as a constant binding.
    ///
    /// SwiftTUI extracts textual content from the supplied view and renders it
    /// dimmed using the editable text's current style; the placeholder view's
    /// own layout and interactive regions aren't embedded in the editor. This
    /// modifier has no visual effect in ``LineMode/multiline``.
    /// Extracted placeholder text isn't sanitized for terminal controls, so
    /// sanitize untrusted placeholder content before supplying it.
    ///
    /// - Parameter content: A view builder that creates trusted or
    ///   caller-sanitized placeholder content.
    /// - Returns: Editable text that displays the placeholder when empty.
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
