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

extension View {

    /// Adds an action to perform when this view first appears at an identity.
    ///
    /// The action runs after SwiftTUI completes the first render containing the
    /// identity. Re-rendering the same identity doesn't run it again; removing
    /// and later recreating the identity does.
    ///
    /// - Parameter action: The action to perform. Passing `nil` installs a no-op.
    /// - Returns: A view with an appear handler attached.
    public func onAppear(perform action: (() -> Void)? = nil) -> some View {
        LifecycleView(
            content: self,
            phase: .appear,
            actionPath: StateContext.currentPath,
            action: action ?? {}
        )
    }

    /// Adds an action to perform after this view disappears.
    ///
    /// The action runs when a previously rendered identity path is no longer
    /// present in a subsequent rendered hierarchy. SwiftTUI restores the
    /// runtime environment and state path captured by the removed registration
    /// before discarding that identity's state subtree.
    ///
    /// - Parameter action: The action to perform. Passing `nil` installs a no-op.
    /// - Returns: A view with a disappear handler attached.
    public func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        LifecycleView(
            content: self,
            phase: .disappear,
            actionPath: StateContext.currentPath,
            action: action ?? {}
        )
    }

    /// Adds an asynchronous task while this view's identity remains in the
    /// rendered hierarchy.
    ///
    /// SwiftTUI starts one unstructured task after the view's identity appears.
    /// Stable re-renders don't restart a completed or running task. When the
    /// identity disappears, SwiftTUI requests cancellation and removes its task
    /// record without waiting for cleanup. Cancellation is cooperative: work
    /// that doesn't observe cancellation can continue and retain captured
    /// values after the view disappears.
    ///
    /// - Parameters:
    ///   - name: Currently ignored. The runtime doesn't retain a task name or
    ///     include it in diagnostics.
    ///   - priority: The priority passed when creating the unstructured task.
    ///   - file: Currently ignored; no source-file metadata is retained.
    ///   - line: Currently ignored; no source-line metadata is retained.
    ///   - action: The escaping asynchronous operation. Its inherited actor
    ///     isolation remains authoritative for execution.
    /// - Returns: A view with a rendered-hierarchy-scoped task attached.
    public nonisolated func task(
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

    /// Adds an asynchronous task while this view's identity remains in the
    /// rendered hierarchy.
    ///
    /// SwiftTUI creates one unstructured task with the supplied executor
    /// preference after the identity appears. An actor-isolated action still
    /// runs on its actor. When the identity disappears, SwiftTUI requests
    /// cancellation and removes its record without awaiting cleanup;
    /// uncooperative work can continue and retain captured values.
    ///
    /// - Parameters:
    ///   - name: Currently ignored. The runtime doesn't retain a task name or
    ///     include it in diagnostics.
    ///   - taskExecutor: The preference passed when creating the task. It
    ///     doesn't override the action's actor isolation.
    ///   - priority: The priority passed when creating the unstructured task.
    ///   - file: Currently ignored; no source-file metadata is retained.
    ///   - line: Currently ignored; no source-line metadata is retained.
    ///   - action: The escaping asynchronous operation to run.
    /// - Returns: A view with a rendered-hierarchy-scoped task attached.
    public nonisolated func task(
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
    ///
    /// SwiftTUI compares `value` with the identifier registered for the same
    /// rendered identity. When it changes, SwiftTUI requests cancellation of
    /// the previous task and immediately starts a new unstructured task without
    /// waiting for the old task to finish. Cancellation is cooperative, so the
    /// old operation can continue and overlap the replacement if it ignores the
    /// request. Disappearance has the same cancellation boundary.
    ///
    /// - Parameters:
    ///   - value: The equatable identifier. Equal values preserve the existing
    ///     task record.
    ///   - name: Currently ignored. The runtime doesn't retain a task name or
    ///     include it in diagnostics.
    ///   - priority: The priority passed when creating each task.
    ///   - file: Currently ignored; no source-file metadata is retained.
    ///   - line: Currently ignored; no source-line metadata is retained.
    ///   - action: The escaping asynchronous operation. Its inherited actor
    ///     isolation remains authoritative for execution.
    /// - Returns: A view with an identity-scoped task attached.
    public nonisolated func task<ID: Equatable>(
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
    ///
    /// When `value` changes, SwiftTUI requests cancellation of the previous task
    /// and immediately creates a replacement with the supplied executor
    /// preference. It doesn't await the old task, so an operation that ignores
    /// cancellation can overlap the replacement and retain its captures. An
    /// actor-isolated action still runs on its actor rather than being forced
    /// onto the preferred executor. Disappearance requests cancellation under
    /// the same cooperative boundary.
    ///
    /// - Parameters:
    ///   - value: The equatable identifier. Equal values preserve the existing
    ///     task record.
    ///   - name: Currently ignored. The runtime doesn't retain a task name or
    ///     include it in diagnostics.
    ///   - taskExecutor: The preference passed when creating each task. It
    ///     doesn't override action actor isolation.
    ///   - priority: The priority passed when creating each task.
    ///   - file: Currently ignored; no source-file metadata is retained.
    ///   - line: Currently ignored; no source-line metadata is retained.
    ///   - action: The escaping asynchronous operation to run.
    /// - Returns: A view with an identity-scoped task attached.
    public nonisolated func task<ID: Equatable>(
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
