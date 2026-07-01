import Foundation

struct ChangeView<Content: View, Value: Equatable>: View, ChangeModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let value: Value

    let initial: Bool

    let actionPath: [Int]?

    let action: () -> Void

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

    var action: () -> Void

    private var hasChangedFrom: (Any) -> Bool

    init<Value: Equatable>(
        value: Value,
        initial: Bool,
        actionPath: [Int],
        environment: EnvironmentValues,
        action: @escaping () -> Void
    ) {
        self.value = value
        self.initial = initial
        self.actionPath = actionPath
        self.environment = environment
        self.action = action
        self.hasChangedFrom = { previousValue in
            guard let previousValue = previousValue as? Value else {
                return true
            }

            return previousValue != value
        }
    }

    func hasChanged(since previous: ChangeHandler) -> Bool {
        hasChangedFrom(previous.value)
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

public extension View {

    /// Adds a modifier for this view that fires an action when a specific value changes.
    func onChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        ChangeView(
            content: self,
            value: value,
            initial: initial,
            actionPath: StateContext.currentPath,
            action: action
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
