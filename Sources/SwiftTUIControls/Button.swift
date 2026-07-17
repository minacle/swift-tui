public import SwiftTUIEssentials

/// A value that controls how a button uses horizontally proposed space.
///
/// A ``Button`` reads this value from the environment when it lays out its
/// label. The setting affects horizontal expansion; the label continues to
/// determine the button's height. Use ``View/buttonSizing(_:)`` to set the
/// behavior for a branch of the view hierarchy.
public nonisolated struct ButtonSizing: Equatable, Hashable, Sendable {

    enum Storage: Equatable, Hashable, Sendable {
        case automatic
        case fitted
        case flexible
    }

    let storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    /// Preserves the label's normal layout behavior.
    ///
    /// This is the default. The button doesn't introduce additional
    /// horizontal flexibility, although a custom label can still have flexible
    /// layout behavior of its own.
    public static var automatic: ButtonSizing {
        ButtonSizing(.automatic)
    }

    /// Requests a width fitted to the button's label.
    ///
    /// SwiftTUI currently resolves this value like ``automatic``: the button
    /// preserves the label's own layout behavior and doesn't introduce
    /// additional horizontal flexibility.
    public static var fitted: ButtonSizing {
        ButtonSizing(.fitted)
    }

    /// Allows a button to expand horizontally into proposed space.
    ///
    /// The label remains leading-aligned while trailing empty columns fill a
    /// finite width proposed by the parent. Those columns are part of the
    /// button's focus and pointer hit region.
    public static var flexible: ButtonSizing {
        ButtonSizing(.flexible)
    }
}

/// A control that initiates an action.
///
/// A button is focusable and runs its action for Return key-down and repeat
/// events while focused. Holding Return can therefore invoke the action more
/// than once. A primary-pointer tap also runs the action when the press begins
/// and ends in the button's rendered hit region. A disabled button rejects
/// focus and both activation paths.
///
/// After invoking the action, the button handles the triggering Return sample
/// or the pointer-up sample that completes an activation. Later consumable
/// input events and gestures don't receive that sample, and Return doesn't
/// reach global-key fallback or key resolution. The button doesn't handle the
/// initial pointer-down, so an outer gesture that recognizes before the
/// completing pointer-up isn't undone.
///
/// Each activation invokes the action synchronously in the environment
/// captured when the button was rendered. By default, the button disables
/// selection of noneditable text in its label. A nearer descendant modifier
/// can override that value, and nested editable controls retain their own
/// selection behavior. With ``ButtonSizing/flexible``, the hit region includes
/// any trailing columns added to fill the proposed width.
///
/// ```swift
/// import SwiftTUIControls
///
/// struct SaveButton: View {
///     @State private var status = "Unsaved"
///
///     var body: some View {
///         VStack {
///             Text(status)
///             Button(action: { status = "Saved" }) {
///                 HStack {
///                     Text("Save")
///                     Text("Return")
///                 }
///             }
///         }
///     }
/// }
/// ```
public nonisolated struct Button<Label: View>: View {

    let label: Label

    let action: () -> Void

    /// Creates a button that displays a custom label.
    ///
    /// The button stores `action` and can invoke it repeatedly for distinct
    /// pointer activations or Return repeat events.
    ///
    /// - Parameters:
    ///   - action: The synchronous action to run each time the button is
    ///     activated.
    ///   - label: A view builder that creates the visible button label.
    public init(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.action = action
    }

    /// The view that lays out the label and installs the button's interactions.
    ///
    /// SwiftTUI uses this view to apply button sizing, disable selection in the
    /// label, and register focus, Return, and pointer activation behavior.
    @MainActor
    public var body: some View {
        ButtonBody(label: label, action: action)
    }
}

private struct ButtonBody<Label: View>: View {

    let label: Label

    let action: () -> Void

    @Environment(\.buttonSizing)
    private var buttonSizing

    var body: some View {
        sizedLabel
            .textSelection(.disabled)
            .focusable()
            .simultaneousInputEvent(
                KeyPressEvent(.return)
                    .onRecognized { _ in
                        action()
                        return .handled
                    }
                    .deferred(priority: .eager)
            )
            .simultaneousInputEvent(
                PointerPressEvent(.left)
                    .sequenced(
                        before: PointerPressEvent(.left, phases: .up)
                    )
                    .onRecognized { _ in
                        action()
                        return .handled
                    }
                    .deferred(priority: .eager)
            )
    }

    @ViewBuilder
    private var sizedLabel: some View {
        switch buttonSizing.storage {
        case .automatic, .fitted:
            label
        case .flexible:
            HStack(spacing: 0) {
                label
                Spacer(minLength: 0)
            }
        }
    }
}

extension Button where Label == Text {

    /// Creates a button with a plain string label.
    ///
    /// SwiftTUI renders `title` unchanged. Sanitize untrusted strings before
    /// rendering them because terminal control characters remain unchanged.
    ///
    /// - Parameters:
    ///   - title: The string to render as the button label.
    ///   - action: The synchronous action to run each time the button is
    ///     activated.
    public init(_ title: String, action: @escaping () -> Void) {
        self.init(title: title, action: action)
    }

    /// Builds the text-label form shared by plain and deprecated initializers.
    internal init(title: String, action: @escaping () -> Void) {
        self.init(action: action) {
            Text(title)
        }
    }

    /// Creates a button that generates its label from a localized string key.
    ///
    /// - Parameters:
    ///   - titleKey: The key whose stored string SwiftTUI renders as the button
    ///     label.
    ///   - action: The synchronous action to run each time the button is
    ///     activated.
    @available(
        *,
        deprecated,
        message: "Localize with String.init(localized:...) and pass the resulting String."
    )
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.init(title: titleKey.key, action: action)
    }
}

extension EnvironmentValues {

    /// The preferred sizing behavior of buttons in the view hierarchy.
    ///
    /// Descendant ``Button`` values read this environment value while laying
    /// out their labels. The default is ``ButtonSizing/automatic``, and the
    /// nearest value in the environment hierarchy takes precedence.
    public nonisolated var buttonSizing: ButtonSizing {
        get {
            self[ButtonSizingKey.self]
        }
        set {
            self[ButtonSizingKey.self] = newValue
        }
    }
}

extension View {

    /// Sets the preferred sizing behavior of buttons in this view hierarchy.
    ///
    /// The modifier affects buttons in the modified subtree without changing
    /// ancestors or siblings. A nearer modifier overrides an outer value.
    ///
    /// - Parameter sizing: The horizontal sizing behavior to apply to the
    ///   modified button or descendant buttons.
    /// - Returns: A view that supplies `sizing` through its environment.
    public nonisolated func buttonSizing(_ sizing: ButtonSizing) -> some View {
        environment(\.buttonSizing, sizing)
    }
}

private struct ButtonSizingKey: EnvironmentKey {

    nonisolated static var defaultValue: ButtonSizing {
        .automatic
    }
}
