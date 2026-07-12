import Foundation

struct ChangeView<Content: View, Value: Equatable>: View, ChangeModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let value: Value

    let initial: Bool

    let actionPath: [Int]?

    let action: ChangeAction<Value>

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        register(in: runtime, renderedPath: path)
        return ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        register(in: runtime, renderedPath: path)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    private func register(in runtime: StateRuntime?, renderedPath: [Int]) {
        runtime?.registerChangeHandler(
            ChangeHandler(
                value: value,
                initial: initial,
                actionPath: actionPath ?? renderedPath,
                environment: EnvironmentRenderContext.current,
                action: action
            ),
            at: renderedPath
        )
    }
}

struct ChangeHandler {

    var value: Any

    var initial: Bool

    var actionPath: [Int]

    var environment: EnvironmentValues

    var previousValue: Any?

    private var hasChangedFrom: (Any) -> Bool

    private var performAction: (Any?) -> Void

    init<Value: Equatable>(
        value: Value,
        initial: Bool,
        actionPath: [Int],
        environment: EnvironmentValues,
        action: ChangeAction<Value>
    ) {
        self.value = value
        self.initial = initial
        self.actionPath = actionPath
        self.environment = environment
        self.previousValue = nil
        self.hasChangedFrom = { previousValue in
            guard let previousValue = previousValue as? Value else {
                return true
            }

            return previousValue != value
        }
        self.performAction = { previousValue in
            action.perform(previousValue: previousValue as? Value, currentValue: value)
        }
    }

    func hasChanged(since previous: ChangeHandler) -> Bool {
        hasChangedFrom(previous.value)
    }

    func perform() {
        performAction(previousValue)
    }
}

struct ChangeAction<Value: Equatable> {

    private var performAction: (Value?, Value) -> Void

    init(_ action: @escaping () -> Void) {
        self.performAction = { _, _ in
            action()
        }
    }

    init(_ action: @escaping (Value, Value) -> Void) {
        self.performAction = { previousValue, currentValue in
            action(previousValue ?? currentValue, currentValue)
        }
    }

    func perform(previousValue: Value?, currentValue: Value) {
        performAction(previousValue, currentValue)
    }
}

protocol ChangeModifierRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement?
}

extension View {

    /// Runs an action when a value changes and, optionally, on registration.
    ///
    /// SwiftTUI compares the current value to the value registered for the same
    /// rendered identity path during the previous render pass. When `initial` is
    /// true, the action runs once when this modifier is first registered. The
    /// callback runs after the render pass in the environment and state context
    /// captured by this modifier. Removing the view discards the remembered
    /// value without firing the action.
    ///
    /// - Parameters:
    ///   - value: The equatable value to observe.
    ///   - initial: Whether to run the action on the first render pass.
    ///   - action: The escaping action to run after a detected change or the
    ///     requested initial registration.
    /// - Returns: A view with a change handler attached.
    public func onChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        ChangeView(
            content: self,
            value: value,
            initial: initial,
            actionPath: StateContext.currentPath,
            action: ChangeAction(action)
        )
    }

    /// Runs an action when a value changes and, optionally, on registration.
    ///
    /// SwiftTUI compares the current value to the value registered for the same
    /// rendered identity path during the previous render pass. The action receives
    /// the old value and the new value. When `initial` is true, the action runs once
    /// with the initial value passed as both the old and new value. The callback
    /// runs after the render pass in the environment and state context captured
    /// by this modifier. Removing the view discards the remembered value without
    /// firing the action.
    ///
    /// - Parameters:
    ///   - value: The equatable value to observe.
    ///   - initial: Whether to run the action on the first render pass.
    ///   - action: The escaping action to run with the previous and current
    ///     values after a detected change, or with the initial value in both
    ///     positions for a requested initial registration.
    /// - Returns: A view with a change handler attached.
    public func onChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping (Value, Value) -> Void
    ) -> some View {
        ChangeView(
            content: self,
            value: value,
            initial: initial,
            actionPath: StateContext.currentPath,
            action: ChangeAction(action)
        )
    }
}

final class ChangeRuntime {

    private var activeHandlers: [ChangeIdentity: ChangeHandler] = [:]

    private var currentHandlers: [ChangeIdentity: ChangeHandler] = [:]

    private var nextOrdinalsByPath: [[Int]: Int] = [:]

    func beginRender() {
        currentHandlers = [:]
        nextOrdinalsByPath = [:]
    }

    func register(_ handler: ChangeHandler, at path: [Int]) {
        let ordinal = nextOrdinalsByPath[path, default: 0]
        nextOrdinalsByPath[path] = ordinal + 1
        currentHandlers[ChangeIdentity(path: path, ordinal: ordinal)] = handler
    }

    func finishRender(perform: (ChangeHandler) -> Void) {
        let identities = currentHandlers.keys.sorted()

        for identity in identities {
            guard let handler = currentHandlers[identity] else {
                continue
            }

            if let previous = activeHandlers[identity] {
                guard handler.hasChanged(since: previous) else {
                    continue
                }

                var handler = handler
                handler.previousValue = previous.value
                perform(handler)
            }
            else if handler.initial {
                perform(handler)
            }
        }

        activeHandlers = currentHandlers
    }
}

private struct ChangeIdentity: Hashable, Comparable {

    var path: [Int]

    var ordinal: Int

    static func < (lhs: ChangeIdentity, rhs: ChangeIdentity) -> Bool {
        if lhs.path != rhs.path {
            return lhs.path.lexicographicallyPrecedes(rhs.path)
        }

        return lhs.ordinal < rhs.ordinal
    }
}
