public import SwiftTUIEssentials

/// A control that displays editable multi-line text in the terminal.
public nonisolated struct TextEditor: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    /// Creates a text editor.
    ///
    /// - Parameter text: A binding to the editable string.
    public init(text: Binding<String>) {
        self.text = text
        self.selection = nil
    }

    /// Creates a text editor with bindings to its text and current selection.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string.
    ///   - selection: A binding to the current selection.
    public init(
        text: Binding<String>,
        selection: Binding<TextSelection?>
    ) {
        self.text = text
        self.selection = selection
    }

    /// The editable multi-line content.
    @ViewBuilder
    @MainActor
    public var body: some View {
        if let selection {
            EditableText(
                text: text,
                selection: selection,
                lineMode: .multiline
            )
        }
        else {
            EditableText(text: text, lineMode: .multiline)
        }
    }
}
