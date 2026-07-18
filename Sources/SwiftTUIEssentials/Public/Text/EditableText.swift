/// A primitive view that edits text in the terminal.
///
/// `EditableText` provides the editing, selection, caret, and pointer behavior
/// used to build higher-level text controls. It edits the complete bound
/// string, inserts a newline for Return by default, and navigates wrapped
/// visual lines. Place it in a ``ScrollView`` when its natural content size
/// needs a viewport or automatic text-input reveal.
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

    /// Selects the keyboard editing operations accepted by editable text.
    ///
    /// Layout and scrolling don't depend on this policy. A finite column
    /// proposal still wraps content, and `EditableText` always returns its
    /// natural full height. Higher-level controls can disable operations that
    /// they reserve for submission or focus navigation without changing those
    /// layout rules.
    public nonisolated struct InputPolicy: Sendable {

        /// Whether Return inserts a newline into the bound string.
        public let allowsNewlineInsertion: Bool

        /// Whether Up and Down navigate between visual lines.
        public let allowsVerticalNavigation: Bool

        /// Creates a keyboard editing policy.
        ///
        /// - Parameters:
        ///   - allowsNewlineInsertion: Whether Return inserts `"\n"`. The
        ///     default is `true`. Disabling this operation doesn't remove or
        ///     normalize newlines already present in the binding.
        ///   - allowsVerticalNavigation: Whether Up and Down move the active
        ///     selection endpoint between visual lines. The default is `true`.
        public init(
            allowsNewlineInsertion: Bool = true,
            allowsVerticalNavigation: Bool = true
        ) {
            self.allowsNewlineInsertion = allowsNewlineInsertion
            self.allowsVerticalNavigation = allowsVerticalNavigation
        }
    }

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    let inputPolicy: InputPolicy

    let mask: Character?

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
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
    ///   - inputPolicy: The keyboard operations accepted by the editor. The
    ///     default inserts newlines and supports vertical visual-line
    ///     navigation. Disabled operations remain available to later input
    ///     handlers and key fallback.
    ///   - mask: A character to display for each editable character, or `nil`
    ///     to display the bound string. The mask itself isn't sanitized.
    ///     Multiline rendering preserves newline separators rather than
    ///     replacing them.
    public init(
        text: Binding<String>,
        inputPolicy: InputPolicy = InputPolicy(),
        mask: Character? = nil
    ) {
        self.text = text
        self.selection = nil
        self.inputPolicy = inputPolicy
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
    ///   - inputPolicy: The keyboard operations accepted by the editor. The
    ///     default inserts newlines and supports vertical visual-line
    ///     navigation. Disabled operations remain available to later input
    ///     handlers and key fallback.
    ///   - mask: A character to display for each editable character, or `nil`
    ///     to display the bound string. The mask itself isn't sanitized.
    ///     Multiline rendering preserves newline separators rather than
    ///     replacing them.
    public init(
        text: Binding<String>,
        selection: Binding<TextSelection?>,
        inputPolicy: InputPolicy = InputPolicy(),
        mask: Character? = nil
    ) {
        self.text = text
        self.selection = selection
        self.inputPolicy = inputPolicy
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
        renderedEditableTextBlock(
            in: proposal,
            placeholder: nil,
            path: path,
            runtime: runtime
        )
    }
}

extension EditableText {

    /// Displays placeholder text while editable text is empty.
    ///
    /// The placeholder participates in the editable text's own rendering, so it
    /// follows the current editing state even when the source binding rejects a
    /// write, such as a constant binding.
    ///
    /// SwiftTUI extracts textual content from the supplied view and renders it
    /// dimmed using the editable text's current style; the placeholder view's
    /// own interactive regions aren't embedded in the editor. Extracted
    /// placeholder text follows the same finite-width wrapping as editable
    /// content. It isn't sanitized for terminal controls, so sanitize untrusted
    /// placeholder content before supplying it.
    ///
    /// - Parameter content: A view builder that creates trusted or
    ///   caller-sanitized placeholder content.
    /// - Returns: Editable text that displays the placeholder when empty.
    public nonisolated func placeholder<Placeholder: View>(
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
        let focusPath = EnvironmentRenderContext.current.focusPath ?? path
        var placeholderEnvironment = EnvironmentRenderContext.current
        placeholderEnvironment.isFocused = runtime?.isFocused(at: focusPath) == true
        let placeholderText = EnvironmentRenderContext.withValues(
            placeholderEnvironment
        ) {
            ViewResolver.text(from: placeholder, path: path + [1])
        }
        return content.renderedEditableTextBlock(
            in: proposal,
            placeholder: placeholderText,
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
