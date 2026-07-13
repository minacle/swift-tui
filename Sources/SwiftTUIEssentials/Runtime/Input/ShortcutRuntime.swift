import Foundation

struct TapShortcutHandler {

    let actionPath: [Int]?

    let key: KeyEquivalent

    let modifiers: EventModifiers

    let count: Int

    let action: () -> Void
}

struct LongPressShortcutHandler {

    let actionPath: [Int]?

    let key: KeyEquivalent

    let modifiers: EventModifiers

    let minimumDuration: TimeInterval

    let action: () -> Void

    let onPressingChanged: ((Bool) -> Void)?
}

struct TapShortcutView<Content: View>: View, InputModifierRenderable,
    LayoutTraitRenderable
{
    typealias Body = Never

    let content: Content

    let handler: TapShortcutHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerTapShortcutHandler(handler, at: interactionPath)
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
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerTapShortcutHandler(handler, at: interactionPath)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }
}

struct LongPressShortcutView<Content: View>: View, InputModifierRenderable,
    LayoutTraitRenderable
{
    typealias Body = Never

    let content: Content

    let handler: LongPressShortcutHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerLongPressShortcutHandler(handler, at: interactionPath)
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
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerLongPressShortcutHandler(handler, at: interactionPath)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }
}

/// Coordinates view-defined tap and long-press shortcuts independently for
/// each exact logical key combination.
final class ViewDefinedShortcutRuntime {

    private var handlersByPath: [[Int]: [ViewDefinedShortcutHandler]] = [:]

    private var pressSequences: [ShortcutInputIdentity: ShortcutPressSequence] = [:]

    private var tapSequences: [ShortcutInputIdentity: ShortcutTapSequence] = [:]

    private let tapTimeout: TimeInterval = 0.5

    var nextDeadline: Date? {
        let tapDeadlines = tapSequences.values.map(\.deadline)
        let longPressDeadlines: [Date] = pressSequences.values.compactMap {
            sequence -> Date? in

            guard sequence.winnerOrder == nil else {
                return nil
            }
            return eligibleLongPressCandidates(in: sequence).map(\.deadline).min()
        }
        return (tapDeadlines + longPressDeadlines).min()
    }

    func beginRender() {
        handlersByPath = [:]
    }

    /// Reconciles active sequences with newly rendered handler configuration.
    /// Actions are replaced with the latest closures only when the structural
    /// shortcut configuration is unchanged.
    func finishRender(perform: ([Int], () -> Void) -> Void) {
        for identity in Array(tapSequences.keys) {
            guard let sequence = tapSequences[identity],
                  let target = target(
                      for: identity,
                      toward: sequence.targetPath
                  ),
                  target.configuration == sequence.configuration else {
                tapSequences[identity] = nil
                continue
            }
        }

        for identity in Array(pressSequences.keys) {
            guard var sequence = pressSequences[identity],
                  let target = target(
                      for: identity,
                      toward: sequence.targetPath
                  ),
                  target.configuration == sequence.configuration else {
                if let sequence = pressSequences.removeValue(forKey: identity) {
                    finishPressing(sequence, perform: perform)
                }
                continue
            }

            sequence.handlers = target.handlers
            sequence.candidates = sequence.candidates.compactMap { candidate in
                guard target.handlers.indices.contains(candidate.order),
                      case .longPress(let handler) = target.handlers[candidate.order].handler
                else {
                    return nil
                }
                return ShortcutLongPressCandidate(
                    order: candidate.order,
                    path: target.handlers[candidate.order].path,
                    handler: handler,
                    deadline: candidate.deadline
                )
            }
            pressSequences[identity] = sequence
        }
    }

    func register(_ handler: TapShortcutHandler, at path: [Int]) {
        handlersByPath[path, default: []].append(.tap(handler))
    }

    func register(_ handler: LongPressShortcutHandler, at path: [Int]) {
        handlersByPath[path, default: []].append(.longPress(handler))
    }

    func dispatch(
        _ keyPress: KeyPress,
        toward focusedPath: [Int]?,
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        let identity = ShortcutInputIdentity(keyPress)
        _ = dispatchExpiredActions(at: date, perform: perform)

        if keyPress.phase == .down {
            return beginPress(
                identity,
                toward: focusedPath,
                at: date,
                perform: perform
            )
        }
        if keyPress.phase == .repeat {
            return false
        }
        guard keyPress.phase == .up else {
            return false
        }
        return endPress(identity, at: date, perform: perform)
    }

    func dispatchExpiredActions(
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        var recognized = dispatchExpiredTapActions(at: date, perform: perform)

        for identity in Array(pressSequences.keys) {
            guard var sequence = pressSequences[identity],
                  sequence.winnerOrder == nil,
                  let candidate = eligibleLongPressCandidates(in: sequence)
                    .filter({ date >= $0.deadline })
                    .min(by: longPressCandidatePrecedes) else {
                continue
            }

            perform(candidate.handler.actionPath ?? candidate.path) {
                candidate.handler.action()
            }
            sequence.winnerOrder = candidate.order
            pressSequences[identity] = sequence
            tapSequences[identity] = nil
            recognized = true
        }

        return recognized
    }

    func cancelAll(perform: ([Int], () -> Void) -> Void) {
        for sequence in pressSequences.values {
            finishPressing(sequence, perform: perform)
        }
        pressSequences = [:]
        tapSequences = [:]
    }

    private func beginPress(
        _ identity: ShortcutInputIdentity,
        toward focusedPath: [Int]?,
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        if let old = pressSequences.removeValue(forKey: identity) {
            finishPressing(old, perform: perform)
        }
        guard let target = target(for: identity, toward: focusedPath) else {
            return false
        }

        if tapSequences[identity]?.configuration != target.configuration
            || tapSequences[identity]?.isExpired(at: date) == true {
            tapSequences[identity] = nil
        }

        let candidates = target.handlers.enumerated().compactMap {
            order, registered -> ShortcutLongPressCandidate? in

            guard case .longPress(let handler) = registered.handler else {
                return nil
            }
            return ShortcutLongPressCandidate(
                order: order,
                path: registered.path,
                handler: handler,
                deadline: date.addingTimeInterval(handler.minimumDuration)
            )
        }
        let sequence = ShortcutPressSequence(
            targetPath: focusedPath ?? [],
            configuration: target.configuration,
            handlers: target.handlers,
            candidates: candidates
        )
        pressSequences[identity] = sequence

        for candidate in candidates {
            perform(candidate.handler.actionPath ?? candidate.path) {
                candidate.handler.onPressingChanged?(true)
            }
        }

        return dispatchExpiredActions(at: date, perform: perform)
    }

    private func endPress(
        _ identity: ShortcutInputIdentity,
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        guard let sequence = pressSequences.removeValue(forKey: identity) else {
            return false
        }

        if sequence.winnerOrder != nil {
            finishPressing(sequence, perform: perform)
            tapSequences[identity] = nil
            return true
        }

        let tapOutcome = recognizeTap(
            identity,
            in: sequence,
            at: date
        )
        finishPress(
            sequence,
            tapOutcome: tapOutcome,
            perform: perform
        )
        return tapOutcome.recognized
    }

    private func recognizeTap(
        _ identity: ShortcutInputIdentity,
        in sequence: ShortcutPressSequence,
        at date: Date
    ) -> ShortcutTapOutcome {
        guard let recognized = sequence.handlers.enumerated().reversed()
            .compactMap({ order, registered -> (Int, RegisteredShortcutHandler)? in
                guard case .tap = registered.handler else {
                    return nil
                }
                return (order, registered)
            })
            .first else {
            tapSequences[identity] = nil
            return .ignored
        }
        let (order, registered) = recognized
        guard case .tap(let handler) = registered.handler else {
            return .ignored
        }

        if tapSequences[identity] == nil
            || tapSequences[identity]?.configuration != sequence.configuration
            || tapSequences[identity]?.isExpired(at: date) == true {
            tapSequences[identity] = ShortcutTapSequence(
                targetPath: sequence.targetPath,
                configuration: sequence.configuration
            )
        }
        tapSequences[identity]?.count += 1
        tapSequences[identity]?.deadline = date.addingTimeInterval(tapTimeout)

        guard let tapSequence = tapSequences[identity] else {
            return .ignored
        }
        if tapSequence.count == handler.count {
            tapSequences[identity] = nil
            return .recognized(order: order)
        }
        if tapSequence.count > handler.count {
            tapSequences[identity] = nil
        }
        return .pending
    }

    private func dispatchExpiredTapActions(
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        var recognized = false
        for identity in Array(tapSequences.keys) {
            guard let sequence = tapSequences[identity],
                  date >= sequence.deadline else {
                continue
            }
            tapSequences[identity] = nil
            guard let target = target(
                for: identity,
                toward: sequence.targetPath
            ),
                  target.configuration == sequence.configuration,
                  let registered = target.handlers.reversed().first(where: {
                      guard case .tap(let handler) = $0.handler else {
                          return false
                      }
                      return handler.count == sequence.count
                  }),
                  case .tap(let handler) = registered.handler else {
                continue
            }
            perform(handler.actionPath ?? registered.path) {
                handler.action()
            }
            recognized = true
        }
        return recognized
    }

    private func finishPress(
        _ sequence: ShortcutPressSequence,
        tapOutcome: ShortcutTapOutcome,
        perform: ([Int], () -> Void) -> Void
    ) {
        for (order, registered) in sequence.handlers.enumerated() {
            switch registered.handler {
            case .tap(let handler):
                guard case .recognized(let recognizedOrder) = tapOutcome,
                      order == recognizedOrder else {
                    continue
                }
                perform(handler.actionPath ?? registered.path) {
                    handler.action()
                }
            case .longPress(let handler):
                perform(handler.actionPath ?? registered.path) {
                    handler.onPressingChanged?(false)
                }
            }
        }
    }

    private func finishPressing(
        _ sequence: ShortcutPressSequence,
        perform: ([Int], () -> Void) -> Void
    ) {
        for registered in sequence.handlers {
            guard case .longPress(let handler) = registered.handler else {
                continue
            }
            perform(handler.actionPath ?? registered.path) {
                handler.onPressingChanged?(false)
            }
        }
    }

    private func target(
        for identity: ShortcutInputIdentity,
        toward focusedPath: [Int]?
    ) -> ShortcutHandlerTarget? {
        let anchor = focusedPath ?? []
        let handlers = handlersByPath.keys
            .filter { anchor.starts(with: $0) }
            .sorted {
                if $0.count != $1.count {
                    return $0.count < $1.count
                }
                return $0.lexicographicallyPrecedes($1)
            }
            .flatMap { path -> [RegisteredShortcutHandler] in
                (handlersByPath[path] ?? []).compactMap {
                    handler -> RegisteredShortcutHandler? in

                    guard handler.identity == identity else {
                        return nil
                    }
                    return RegisteredShortcutHandler(path: path, handler: handler)
                }
            }
        guard !handlers.isEmpty else {
            return nil
        }
        return ShortcutHandlerTarget(handlers: handlers)
    }

    private func eligibleLongPressCandidates(
        in sequence: ShortcutPressSequence
    ) -> [ShortcutLongPressCandidate] {
        sequence.candidates.filter { candidate in
            !sequence.handlers.enumerated().contains { order, registered in
                guard order > candidate.order,
                      case .tap = registered.handler else {
                    return false
                }
                return true
            }
        }
    }

    private func longPressCandidatePrecedes(
        _ lhs: ShortcutLongPressCandidate,
        _ rhs: ShortcutLongPressCandidate
    ) -> Bool {
        if lhs.deadline != rhs.deadline {
            return lhs.deadline < rhs.deadline
        }
        return lhs.order > rhs.order
    }
}

private struct ShortcutInputIdentity: Hashable {

    let key: KeyEquivalent

    let modifiers: Int

    init(_ keyPress: KeyPress) {
        key = keyPress.key
        modifiers = keyPress.modifiers.rawValue
    }

    init(key: KeyEquivalent, modifiers: EventModifiers) {
        self.key = key
        self.modifiers = modifiers.rawValue
    }
}

private enum ViewDefinedShortcutHandler {

    case tap(TapShortcutHandler)

    case longPress(LongPressShortcutHandler)

    var identity: ShortcutInputIdentity {
        switch self {
        case .tap(let handler):
            ShortcutInputIdentity(key: handler.key, modifiers: handler.modifiers)
        case .longPress(let handler):
            ShortcutInputIdentity(key: handler.key, modifiers: handler.modifiers)
        }
    }

    var configuration: ViewDefinedShortcutHandlerConfiguration {
        switch self {
        case .tap(let handler):
            .tap(
                key: handler.key,
                modifiers: handler.modifiers.rawValue,
                count: handler.count
            )
        case .longPress(let handler):
            .longPress(
                key: handler.key,
                modifiers: handler.modifiers.rawValue,
                minimumDuration: handler.minimumDuration.bitPattern
            )
        }
    }
}

private enum ViewDefinedShortcutHandlerConfiguration: Equatable {

    case tap(key: KeyEquivalent, modifiers: Int, count: Int)

    case longPress(key: KeyEquivalent, modifiers: Int, minimumDuration: UInt64)
}

private struct RegisteredShortcutHandler {

    let path: [Int]

    let handler: ViewDefinedShortcutHandler

    var configuration: RegisteredShortcutHandlerConfiguration {
        RegisteredShortcutHandlerConfiguration(
            path: path,
            handler: handler.configuration
        )
    }
}

private struct RegisteredShortcutHandlerConfiguration: Equatable {

    let path: [Int]

    let handler: ViewDefinedShortcutHandlerConfiguration
}

private struct ShortcutHandlerTarget {

    let handlers: [RegisteredShortcutHandler]

    var configuration: [RegisteredShortcutHandlerConfiguration] {
        handlers.map(\.configuration)
    }
}

private struct ShortcutTapSequence {

    let targetPath: [Int]

    let configuration: [RegisteredShortcutHandlerConfiguration]

    var count = 0

    var deadline = Date.distantPast

    func isExpired(at date: Date) -> Bool {
        date >= deadline
    }
}

private struct ShortcutPressSequence {

    let targetPath: [Int]

    let configuration: [RegisteredShortcutHandlerConfiguration]

    var handlers: [RegisteredShortcutHandler]

    var candidates: [ShortcutLongPressCandidate]

    var winnerOrder: Int?
}

private struct ShortcutLongPressCandidate {

    let order: Int

    let path: [Int]

    let handler: LongPressShortcutHandler

    let deadline: Date
}

private enum ShortcutTapOutcome {

    case ignored

    case pending

    case recognized(order: Int)

    var recognized: Bool {
        if case .recognized = self {
            return true
        }
        return false
    }
}
