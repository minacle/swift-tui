import Foundation

struct LifecycleView<Content: View>: View, LifecycleModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let phase: LifecyclePhase

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
        runtime?.registerLifecycleHandler(
            LifecycleHandler(
                phase: phase,
                actionPath: actionPath ?? renderedPath,
                environment: EnvironmentRenderContext.current,
                action: action
            ),
            at: renderedPath
        )
    }
}

enum LifecyclePhase {

    case appear

    case disappear
}

struct LifecycleHandler {

    var phase: LifecyclePhase

    var actionPath: [Int]

    var environment: EnvironmentValues

    var action: () -> Void
}

protocol LifecycleModifierRenderable {

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

    /// Adds an action to perform before this view appears.
    func onAppear(perform action: (() -> Void)? = nil) -> some View {
        LifecycleView(
            content: self,
            phase: .appear,
            actionPath: StateContext.currentPath,
            action: action ?? {}
        )
    }

    /// Adds an action to perform after this view disappears.
    func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        LifecycleView(
            content: self,
            phase: .disappear,
            actionPath: StateContext.currentPath,
            action: action ?? {}
        )
    }
}

final class LifecycleRuntime {

    private var activeHandlers: [LifecycleIdentity: LifecycleHandler] = [:]

    private var currentHandlers: [LifecycleIdentity: LifecycleHandler] = [:]

    private var nextOrdinalsByPath: [[Int]: Int] = [:]

    func beginRender() {
        currentHandlers = [:]
        nextOrdinalsByPath = [:]
    }

    func register(_ handler: LifecycleHandler, at path: [Int]) {
        let ordinal = nextOrdinalsByPath[path, default: 0]
        nextOrdinalsByPath[path] = ordinal + 1
        currentHandlers[LifecycleIdentity(path: path, ordinal: ordinal)] = handler
    }

    func finishRender(perform: (LifecycleHandler) -> Void) {
        let appeared = currentHandlers.keys
            .filter {
                activeHandlers[$0] == nil
            }
            .sorted()
        let disappeared = activeHandlers.keys
            .filter {
                currentHandlers[$0] == nil
            }
            .sorted()

        for identity in appeared {
            guard let handler = currentHandlers[identity],
                  handler.phase == .appear else {
                continue
            }

            perform(handler)
        }

        for identity in disappeared {
            guard let handler = activeHandlers[identity],
                  handler.phase == .disappear else {
                continue
            }

            perform(handler)
        }

        activeHandlers = currentHandlers
    }
}

private struct LifecycleIdentity: Hashable, Comparable {

    var path: [Int]

    var ordinal: Int

    static func < (lhs: LifecycleIdentity, rhs: LifecycleIdentity) -> Bool {
        if lhs.path != rhs.path {
            return lhs.path.lexicographicallyPrecedes(rhs.path)
        }

        return lhs.ordinal < rhs.ordinal
    }
}
