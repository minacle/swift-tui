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
public nonisolated struct Button<Label: View>: View, ButtonRenderable,
    LayoutTraitRenderable
{

    public typealias Body = Never

    let label: Label

    let actionPath: [Int]?

    let action: () -> Void

    var layoutTraits: LayoutTraits {
        switch EnvironmentRenderContext.current.buttonSizing.storage {
        case .automatic, .fitted:
            return ViewResolver.layoutTraits(from: label)
        case .flexible:
            var traits = ViewResolver.layoutTraits(from: label)
            traits.flexibleAxes.insert(.horizontal)
            return traits
        }
    }

    /// Creates a button that displays a custom label.
    public init(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.actionPath = StateContext.currentPath
        self.action = action
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
        EnvironmentValueView(
            content: self,
            keyPath: \.buttonSizing,
            value: sizing
        )
    }
}

protocol ButtonRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

extension Button {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let environment = EnvironmentRenderContext.current
        guard var block = ViewResolver.block(
            from: label,
            in: proposal,
            path: path + [0],
            runtime: runtime
        ) else {
            return nil
        }

        if environment.buttonSizing == .flexible,
           let width = proposal?.columns {
            block = block.framed(width: width, height: block.height, alignment: .leading)
        }

        registerActivation(in: runtime, path: path, environment: environment)
        block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
        block.hitRegions.append(RenderedHitRegion(path: path, frame: block.bounds))
        return block
    }

    private func registerActivation(
        in runtime: StateRuntime?,
        path: [Int],
        environment: EnvironmentValues
    ) {
        guard let runtime else {
            return
        }

        runtime.registerFocusable(true, at: path)
        runtime.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: actionPath ?? path,
                matches: {
                    $0.key == .return && [.down, .repeat].contains($0.phase)
                },
                action: { _ in
                    EnvironmentRenderContext.withValues(environment) {
                        action()
                    }
                    return .handled
                }
            ),
            at: path
        )
        runtime.registerTapGestureHandler(
            TapGestureHandler(
                actionPath: actionPath ?? path,
                count: 1,
                action: {
                    EnvironmentRenderContext.withValues(environment) {
                        action()
                    }
                }
            ),
            at: path
        )
    }
}

private struct ButtonSizingKey: EnvironmentKey {

    nonisolated static var defaultValue: ButtonSizing {
        .automatic
    }
}
