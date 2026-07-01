import Foundation

struct LifecycleView<Content: View>: View, LifecycleModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let phase: LifecyclePhase

    let actionPath: [Int]?

    let action: () -> Void

    @MainActor
    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    @MainActor
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

    @MainActor
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

nonisolated struct TaskView<Content: View, ID: Equatable>: View, LifecycleModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let id: ID?

    let priority: TaskPriority

    let executorPreference: (any TaskExecutor)?

    let actionPath: [Int]?

    let action: @isolated(any) () async -> Void

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

    @MainActor
    private func register(in runtime: StateRuntime?, renderedPath: [Int]) {
        runtime?.registerTaskHandler(
            ViewTaskHandler(
                id: id.map { ViewTaskID($0) },
                priority: priority,
                executorPreference: executorPreference,
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

    /// Adds an asynchronous task to perform while this view is visible.
    nonisolated func task(
        name: String? = nil,
        priority: TaskPriority = .userInitiated,
        file: String = #fileID,
        line: Int = #line,
        @_inheritActorContext _ action: sending @escaping @isolated(any) () async -> Void
    ) -> some View {
        _ = name ?? "View.task @ \(file):\(line)"
        return TaskView(
            content: self,
            id: Optional<NoTaskID>.none,
            priority: priority,
            executorPreference: nil,
            actionPath: StateContext.currentPath,
            action: action
        )
    }

    /// Adds an asynchronous task to perform while this view is visible.
    nonisolated func task(
        name: String? = nil,
        executorPreference taskExecutor: any TaskExecutor,
        priority: TaskPriority = .userInitiated,
        file: String = #fileID,
        line: Int = #line,
        @_inheritActorContext action: sending @escaping @isolated(any) () async -> Void
    ) -> some View {
        _ = name ?? "View.task @ \(file):\(line)"
        return TaskView(
            content: self,
            id: Optional<NoTaskID>.none,
            priority: priority,
            executorPreference: taskExecutor,
            actionPath: StateContext.currentPath,
            action: action
        )
    }

    /// Adds an asynchronous task that restarts when the given value changes.
    nonisolated func task<ID: Equatable>(
        id value: ID,
        name: String? = nil,
        priority: TaskPriority = .userInitiated,
        file: String = #fileID,
        line: Int = #line,
        @_inheritActorContext _ action: sending @escaping @isolated(any) () async -> Void
    ) -> some View {
        _ = name ?? "View.task @ \(file):\(line)"
        return TaskView(
            content: self,
            id: value,
            priority: priority,
            executorPreference: nil,
            actionPath: StateContext.currentPath,
            action: action
        )
    }

    /// Adds an asynchronous task that restarts when the given value changes.
    nonisolated func task<ID: Equatable>(
        id value: ID,
        name: String? = nil,
        executorPreference taskExecutor: any TaskExecutor,
        priority: TaskPriority = .userInitiated,
        file: String = #fileID,
        line: Int = #line,
        @_inheritActorContext _ action: sending @escaping @isolated(any) () async -> Void
    ) -> some View {
        _ = name ?? "View.task @ \(file):\(line)"
        return TaskView(
            content: self,
            id: value,
            priority: priority,
            executorPreference: taskExecutor,
            actionPath: StateContext.currentPath,
            action: action
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

struct ViewTaskHandler: @unchecked Sendable {

    var id: ViewTaskID?

    var priority: TaskPriority

    var executorPreference: (any TaskExecutor)?

    var actionPath: [Int]

    var environment: EnvironmentValues

    var action: @isolated(any) () async -> Void
}

struct ViewTaskID {

    private let value: Any

    private let isEqual: (Any) -> Bool

    init<ID: Equatable>(_ value: ID) {
        self.value = value
        self.isEqual = { other in
            guard let other = other as? ID else {
                return false
            }

            return value == other
        }
    }
}

extension ViewTaskID: Equatable {

    static func == (lhs: ViewTaskID, rhs: ViewTaskID) -> Bool {
        lhs.isEqual(rhs.value)
    }
}

final class ViewTaskRuntime {

    private var activeTasks: [LifecycleIdentity: ActiveViewTask] = [:]

    private var currentHandlers: [LifecycleIdentity: ViewTaskHandler] = [:]

    private var nextOrdinalsByPath: [[Int]: Int] = [:]

    func beginRender() {
        currentHandlers = [:]
        nextOrdinalsByPath = [:]
    }

    func register(_ handler: ViewTaskHandler, at path: [Int]) {
        let ordinal = nextOrdinalsByPath[path, default: 0]
        nextOrdinalsByPath[path] = ordinal + 1
        currentHandlers[LifecycleIdentity(path: path, ordinal: ordinal)] = handler
    }

    func finishRender(start: (LifecycleIdentity, ViewTaskHandler) -> Task<Void, Never>) {
        let disappeared = activeTasks.keys
            .filter {
                currentHandlers[$0] == nil
            }
            .sorted()
        for identity in disappeared {
            activeTasks.removeValue(forKey: identity)?.task?.cancel()
        }

        for identity in currentHandlers.keys.sorted() {
            guard let handler = currentHandlers[identity] else {
                continue
            }

            if let activeTask = activeTasks[identity] {
                guard activeTask.id != handler.id else {
                    continue
                }

                activeTask.task?.cancel()
            }

            activeTasks[identity] = ActiveViewTask(
                id: handler.id,
                task: start(identity, handler)
            )
        }
    }

    func complete(_ identity: LifecycleIdentity, id: ViewTaskID?) {
        guard let activeTask = activeTasks[identity],
              activeTask.id == id else {
            return
        }

        activeTasks[identity] = ActiveViewTask(id: id, task: nil)
    }
}

private struct ActiveViewTask {

    var id: ViewTaskID?

    var task: Task<Void, Never>?
}

private nonisolated enum NoTaskID: Equatable {}

struct LifecycleIdentity: Hashable, Comparable {

    var path: [Int]

    var ordinal: Int

    static func < (lhs: LifecycleIdentity, rhs: LifecycleIdentity) -> Bool {
        if lhs.path != rhs.path {
            return lhs.path.lexicographicallyPrecedes(rhs.path)
        }

        return lhs.ordinal < rhs.ordinal
    }
}
