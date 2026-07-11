public import SwiftTUIEssentials

/// The sizing behavior of buttons and other button-like controls.
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

    /// The default button sizing behavior.
    public static var automatic: ButtonSizing {
        ButtonSizing(.automatic)
    }

    /// Sizes a button along its primary axis to fit its inner content.
    public static var fitted: ButtonSizing {
        ButtonSizing(.fitted)
    }

    /// Sizes a button flexibly along its primary axis.
    public static var flexible: ButtonSizing {
        ButtonSizing(.flexible)
    }
}

/// A control that initiates an action.
public nonisolated struct Button<Label: View>: View {

    let label: Label

    let action: () -> Void

    /// Creates a button that displays a custom label.
    public init(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.action = action
    }

    /// The interactive button label.
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
            .onKeyPress(.return) {
                action()
                return .handled
            }
            .onTapGesture(perform: action)
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

public extension Button where Label == Text {

    /// Creates a button that generates its label from a localized string key.
    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.init(action: action) {
            Text(titleKey)
        }
    }
}

public extension EnvironmentValues {

    /// The preferred sizing behavior of buttons in the view hierarchy.
    nonisolated var buttonSizing: ButtonSizing {
        get {
            self[ButtonSizingKey.self]
        }
        set {
            self[ButtonSizingKey.self] = newValue
        }
    }
}

public extension View {

    /// Sets the preferred sizing behavior of buttons in this view hierarchy.
    nonisolated func buttonSizing(_ sizing: ButtonSizing) -> some View {
        environment(\.buttonSizing, sizing)
    }
}

private struct ButtonSizingKey: EnvironmentKey {

    nonisolated static var defaultValue: ButtonSizing {
        .automatic
    }
}
