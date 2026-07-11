public import SwiftTUIEssentials

/// A control that displays editable single-line text in the terminal.
///
/// A text field is horizontally flexible, occupies one terminal row, and sends
/// edits to a bound string. With a finite column proposal, it scrolls at
/// terminal-cell boundaries to keep the caret visible. A nonempty field
/// reserves one trailing terminal column so an end-of-text caret doesn't
/// overlap adjacent content.
///
/// The field is focusable unless disabled. Pointer presses request focus;
/// clicking positions the caret and dragging creates a replacement selection.
/// The caret is rendered only while focused and is hidden while a range is
/// selected. Return is consumed without inserting a newline and invokes the
/// nearest ``View/onSubmit(_:)`` action when one is installed.
///
/// Single-line describes layout and Return-key behavior; the field doesn't
/// remove newline characters already supplied through the binding.
///
/// Selection navigation and highlighting follow the environment's selection
/// navigation behavior, tint, and selected-text foreground style.
///
/// While the editable value is empty, the field displays `prompt`, or text
/// resolved from its label when `prompt` is `nil`. This placeholder inherits
/// the field's text style and is dimmed. The label isn't rendered as a
/// persistent caption; place a separate ``Text`` next to the field when the
/// caption must remain visible.
///
/// ```swift
/// import SwiftTUIControls
///
/// struct NameField: View {
///     @State private var name = ""
///     @State private var submittedName = ""
///
///     var body: some View {
///         VStack {
///             TextField("Name", text: $name, prompt: Text("Required"))
///                 .onSubmit {
///                     submittedName = name
///                 }
///             Text(submittedName)
///         }
///     }
/// }
/// ```
public nonisolated struct TextField<Label: View>: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    let prompt: Text?

    let label: Label

    /// Creates a text field with a custom label view.
    ///
    /// - Parameters:
    ///   - text: A binding that supplies the current value and receives edits.
    ///     External replacements update the field and clamp its insertion point
    ///     to the new value, clearing any internally selected range.
    ///   - prompt: Text to display while `text` is empty. When this value is
    ///     `nil`, the field uses text resolved from `label` as its placeholder.
    ///   - label: A view builder whose textual content becomes the fallback
    ///     placeholder. The field doesn't render this view as a persistent
    ///     caption.
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

    /// The view that renders the field and installs its editing interactions.
    ///
    /// SwiftTUI uses this view to register focus, keyboard, pointer, caret,
    /// horizontal scrolling, and placeholder behavior.
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

    /// Creates a text field that uses a title as its fallback placeholder.
    ///
    /// This initializer keeps selection state inside the field. Use
    /// ``init(_:text:selection:prompt:)`` when the selection is part of your
    /// model.
    ///
    /// - Parameters:
    ///   - title: The fallback placeholder displayed while `text` is empty.
    ///   - text: A binding that supplies the current value and receives edits.
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a text field with an optional explicit placeholder.
    ///
    /// - Parameters:
    ///   - title: The fallback placeholder used when `prompt` is `nil`.
    ///   - text: A binding that supplies the current value and receives edits.
    ///   - prompt: Text to display while `text` is empty. Pass `nil` to use
    ///     `title` as the placeholder.
    init(_ title: String, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt) {
            Text(title)
        }
    }

    /// Creates a text field with bindings to its text and current selection.
    ///
    /// The field writes a ``TextSelection`` after focus is acquired and after
    /// keyboard or pointer changes. Assigning a valid selection updates the
    /// field to that insertion point or selected range. A subsequent insertion
    /// or deletion replaces or removes a nonempty range. Assigning `nil` clears
    /// a range while preserving the field's current insertion point. Losing
    /// focus hides the caret but doesn't clear or otherwise rewrite the
    /// selection binding.
    ///
    /// Construct selection indices from the current value of `text`. If the
    /// indices can't be converted into that string, the field leaves its
    /// insertion point in bounds and doesn't select a range.
    ///
    /// - Parameters:
    ///   - title: The fallback placeholder used when `prompt` is `nil`.
    ///   - text: A binding that supplies the current value and receives edits.
    ///   - selection: A binding to the current insertion point or selected
    ///     range. Its indices refer to the current `text` value.
    ///   - prompt: Text to display while `text` is empty. Pass `nil` to use
    ///     `title` as the placeholder.
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
///
/// A secure field has the same one-row focus, submission, placeholder,
/// keyboard, pointer-selection, and horizontal-scrolling behavior as
/// ``TextField``. It renders each `Character` in its editable value as one
/// bullet and uses bullet widths for caret placement and scrolling. The
/// placeholder remains readable while the value is empty. Single-line
/// describes layout and Return-key behavior; the field doesn't remove newline
/// characters already supplied through the binding. Selection navigation and
/// highlighting follow the same environment values as `TextField`.
///
/// > Important: Masking changes only the field's rendered characters. It still
/// > reveals the value's `Character` count, and the bound `String` contains the
/// > original value. The control doesn't erase that value or protect it from
/// > application memory, logs, persistence, callbacks, or other code with
/// > access to the binding.
///
/// ```swift
/// import SwiftTUIControls
///
/// struct PasswordField: View {
///     @State private var password = ""
///
///     var body: some View {
///         SecureField("Password", text: $password)
///     }
/// }
/// ```
public nonisolated struct SecureField<Label: View>: View {

    let text: Binding<String>

    let prompt: Text?

    let label: Label

    /// Creates a secure field with a custom label view.
    ///
    /// - Parameters:
    ///   - text: A binding that supplies the original, unmasked value and
    ///     receives edits. External replacements clamp the insertion point and
    ///     clear any internally selected range.
    ///   - prompt: Text to display while `text` is empty. When this value is
    ///     `nil`, the field uses text resolved from `label` as its placeholder.
    ///   - label: A view builder whose textual content becomes the fallback
    ///     placeholder. The field doesn't render this view as a persistent
    ///     caption.
    public init(
        text: Binding<String>,
        prompt: Text? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.text = text
        self.prompt = prompt
        self.label = label()
    }

    /// The view that renders the masked field and installs its interactions.
    ///
    /// SwiftTUI uses this view to register focus, keyboard, pointer selection,
    /// caret, submission, horizontal scrolling, and placeholder behavior.
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

    /// Creates a secure field that uses a title as its fallback placeholder.
    ///
    /// - Parameters:
    ///   - title: The fallback placeholder displayed while `text` is empty.
    ///   - text: A binding that supplies the original, unmasked value and
    ///     receives edits.
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a secure field with an optional explicit placeholder.
    ///
    /// - Parameters:
    ///   - title: The fallback placeholder used when `prompt` is `nil`.
    ///   - text: A binding that supplies the original, unmasked value and
    ///     receives edits.
    ///   - prompt: Text to display while `text` is empty. Pass `nil` to use
    ///     `title` as the placeholder.
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
    ///
    /// A focused ``TextField`` or ``SecureField`` invokes the action
    /// synchronously for Return key-down and repeat events. The field consumes
    /// Return without inserting a newline. If modifiers are nested, the
    /// innermost action replaces outer actions rather than combining with them.
    /// ``TextEditor`` consumes Return to insert a newline and never invokes this
    /// action.
    ///
    /// - Parameter action: The action to run for each submission in the
    ///   modified subtree. Holding Return can invoke it repeatedly.
    /// - Returns: A view that supplies `action` to descendant single-line text
    ///   fields through the environment.
    func onSubmit(_ action: @escaping () -> Void) -> some View {
        environment(\.submitAction, SubmitAction(action: action))
    }
}

private struct SubmitActionKey: EnvironmentKey {

    nonisolated static var defaultValue: SubmitAction? {
        nil
    }
}
