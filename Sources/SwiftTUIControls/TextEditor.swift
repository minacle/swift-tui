public import SwiftTUIEssentials

/// A control that displays editable multi-line text in the terminal.
///
/// A text editor is flexible in both axes and sends edits to a bound string. It
/// wraps content to a finite proposed column count and scrolls a constrained
/// viewport as needed to keep the caret visible. Return inserts a newline and
/// never invokes ``View/onSubmit(_:)``.
/// Its vertical viewport accepts pointer-wheel input; wheel movement remains
/// in place until editing or actual selection navigation requests another
/// minimal caret reveal. Pointer-down anywhere in an empty viewport requests
/// focus, not only on a row containing text.
///
/// The editor is focusable unless disabled. Pointer presses request focus;
/// clicking positions the caret and dragging creates a replacement selection.
/// Keyboard navigation follows wrapped visual lines. The caret is rendered
/// only while focused and is hidden while a range is selected.
///
/// ```swift
/// import SwiftTUIControls
///
/// struct NotesEditor: View {
///     @State private var notes = ""
///
///     var body: some View {
///         TextEditor(text: $notes)
///             .frame(width: 40, height: 8)
///     }
/// }
/// ```
///
/// The editor follows the environment's multiline text alignment, selection
/// navigation behavior, tint, and selected-text foreground style.
public nonisolated struct TextEditor: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    /// Creates a text editor without exposing its current selection.
    ///
    /// The editor keeps its insertion point and selected range internally.
    /// External text replacements update the editor and clamp its insertion
    /// point to the new value, clearing any internally selected range.
    ///
    /// - Parameter text: A binding that supplies the current value and receives
    ///   edits, including newlines inserted with Return.
    public init(text: Binding<String>) {
        self.text = text
        self.selection = nil
    }

    /// Creates a text editor with bindings to its text and current selection.
    ///
    /// The editor writes a ``TextSelection`` after focus is acquired and after
    /// keyboard or pointer changes. Assigning a valid selection updates the
    /// editor to that insertion point or selected range. A subsequent insertion
    /// or deletion replaces or removes a nonempty range. Assigning `nil` clears
    /// a range while preserving the editor's current insertion point. Losing
    /// focus hides the caret but doesn't clear or otherwise rewrite the
    /// selection binding.
    ///
    /// Construct selection indices from the current value of `text`. If the
    /// indices can't be converted into that string, the editor leaves its
    /// insertion point in bounds and doesn't select a range.
    ///
    /// - Parameters:
    ///   - text: A binding that supplies the current value and receives edits,
    ///     including inserted newlines.
    ///   - selection: A binding to the current insertion point or selected
    ///     range. Its indices refer to the current `text` value.
    public init(
        text: Binding<String>,
        selection: Binding<TextSelection?>
    ) {
        self.text = text
        self.selection = selection
    }

    /// The view that renders the editor and installs its editing interactions.
    ///
    /// SwiftTUI uses this view to register focus, keyboard, pointer, caret,
    /// wrapping, alignment, selection, and viewport-scrolling behavior.
    @ViewBuilder
    @MainActor
    public var body: some View {
        ScrollView(.vertical) {
            if let selection {
                EditableText(
                    text: text,
                    selection: selection
                )
            }
            else {
                EditableText(text: text)
            }
        }
    }
}
