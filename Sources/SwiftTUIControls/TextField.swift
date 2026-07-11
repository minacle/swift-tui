public import SwiftTUIEssentials

/// A control that displays editable single-line text in the terminal.
public nonisolated struct TextField<Label: View>: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    let prompt: Text?

    let label: Label

    /// Creates a text field with a custom label view.
    public init(
        text: Binding<String>,
        prompt: Text? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.text = text
        self.selection = nil
        self.prompt = prompt
        self.label = label()
    }

    /// The editable field and its placeholder content.
    @ViewBuilder
    @MainActor
    public var body: some View {
        TextFieldBody(
            text: text,
            selection: selection,
            prompt: prompt,
            label: label,
            mask: nil
        )
    }
}

public extension TextField where Label == Text {

    /// Creates a text field with a text label generated from a title string.
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a text field with a text label generated from a title string.
    init(_ title: String, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt) {
            Text(title)
        }
    }

    /// Creates a text field with bindings to its text and current selection.
    init(
        _ title: String,
        text: Binding<String>,
        selection: Binding<TextSelection?>,
        prompt: Text? = nil
    ) {
        self.text = text
        self.selection = selection
        self.prompt = prompt
        self.label = Text(title)
    }
}

/// A control that displays editable single-line secure text in the terminal.
public nonisolated struct SecureField<Label: View>: View {

    let text: Binding<String>

    let prompt: Text?

    let label: Label

    /// Creates a secure field with a custom label view.
    public init(
        text: Binding<String>,
        prompt: Text? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.text = text
        self.prompt = prompt
        self.label = label()
    }

    /// The editable secure field and its placeholder content.
    @MainActor
    public var body: some View {
        TextFieldBody(
            text: text,
            selection: nil,
            prompt: prompt,
            label: label,
            mask: "•"
        )
    }
}

public extension SecureField where Label == Text {

    /// Creates a secure field with a text label generated from a title string.
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a secure field with a text label generated from a title string.
    init(_ title: String, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt) {
            Text(title)
        }
    }
}

private struct TextFieldBody<Label: View>: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    let prompt: Text?

    let label: Label

    let mask: Character?

    @Environment(\.submitAction)
    private var submitAction

    @ViewBuilder
    var body: some View {
        if let selection {
            EditableText(text: text, selection: selection, mask: mask)
                .placeholder {
                    placeholder
                }
                .onKeyPress(.return, action: submit)
        }
        else {
            EditableText(text: text, mask: mask)
                .placeholder {
                    placeholder
                }
                .onKeyPress(.return, action: submit)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if let prompt {
            prompt
        }
        else {
            label
        }
    }

    private func submit() -> KeyPress.Result {
        submitAction?()
        return .handled
    }
}

struct SubmitAction {

    let action: () -> Void

    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {

    var submitAction: SubmitAction? {
        get {
            self[SubmitActionKey.self]
        }
        set {
            self[SubmitActionKey.self] = newValue
        }
    }
}

public extension View {

    /// Performs an action when the user submits a text field within this view.
    func onSubmit(_ action: @escaping () -> Void) -> some View {
        environment(\.submitAction, SubmitAction(action: action))
    }
}

private struct SubmitActionKey: EnvironmentKey {

    nonisolated static var defaultValue: SubmitAction? {
        nil
    }
}
