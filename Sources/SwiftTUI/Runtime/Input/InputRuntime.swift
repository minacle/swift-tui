import Foundation

enum MouseButton: Equatable, Hashable, Sendable {

    case left

    case middle

    case right

    case wheelUp

    case wheelDown

    case wheelLeft

    case wheelRight

    case other(Int)
}

struct MouseEvent: Equatable, Sendable {

    enum Phase: Equatable, Sendable {

        case down

        case up
    }

    let button: MouseButton

    let column: Int

    let row: Int

    let modifiers: EventModifiers

    let phase: Phase

    init(
        button: MouseButton,
        column: Int,
        row: Int,
        modifiers: EventModifiers = [],
        phase: Phase
    ) {
        self.button = button
        self.column = max(column, 1)
        self.row = max(row, 1)
        self.modifiers = modifiers
        self.phase = phase
    }
}

struct KeyPressView<Content: View>: View, InputModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let handler: KeyPressHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerKeyPressHandler(handler, at: path)
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
        runtime?.registerKeyPressHandler(handler, at: path)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }
}

struct GlobalKeyPressView<Content: View>: View, InputModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let handler: KeyPressHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerGlobalKeyPressHandler(handler, at: path)
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
        runtime?.registerGlobalKeyPressHandler(handler, at: path)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }
}

struct TapGestureView<Content: View>: View, InputModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let handler: TapGestureHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerTapGestureHandler(handler, at: path)
        guard var block = ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        block.hitRegions.append(RenderedHitRegion(path: path, frame: block.bounds))
        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
    }
}

struct KeyPressHandler {

    let actionPath: [Int]?

    let matches: (KeyPress) -> Bool

    let action: (KeyPress) -> KeyPress.Result
}

struct TapGestureHandler {

    let actionPath: [Int]?

    let count: Int

    let action: () -> Void
}

struct LinkHandler {

    let actionPath: [Int]?

    let action: () -> Bool
}

protocol InputModifierRenderable {

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

final class InputRuntime {

    private struct GlobalKeyPressHandler {

        var path: [Int]

        var order: Int

        var handler: KeyPressHandler
    }

    private var handlersByPath: [[Int]: [KeyPressHandler]] = [:]

    private var globalHandlers: [GlobalKeyPressHandler] = []

    private var tapHandlersByPath: [[Int]: [TapGestureHandler]] = [:]

    private var linkHandlersByPath: [[Int]: LinkHandler] = [:]

    private var hitRegions: [RenderedHitRegion] = []

    private var scrollRegions: [RenderedScrollRegion] = []

    private var focusRegions: [RenderedFocusRegion] = []

    private var rootFrame = TextFrame(text: "", row: 1, column: 1)

    private var pressedTapTarget: [Int]?

    private var pressedLinkTarget: [Int]?

    private var tapSequence: TapSequence?

    private let tapTimeout: TimeInterval = 0.5

    var nextTapDeadline: Date? {
        tapSequence?.deadline
    }

    func beginRender() {
        handlersByPath = [:]
        globalHandlers = []
        tapHandlersByPath = [:]
        linkHandlersByPath = [:]
    }

    func register(_ handler: KeyPressHandler, at path: [Int]) {
        handlersByPath[path, default: []].append(handler)
    }

    func registerGlobal(_ handler: KeyPressHandler, at path: [Int]) {
        globalHandlers.append(
            GlobalKeyPressHandler(
                path: path,
                order: globalHandlers.count,
                handler: handler
            )
        )
    }

    func register(_ handler: TapGestureHandler, at path: [Int]) {
        tapHandlersByPath[path, default: []].append(handler)
    }

    func register(_ handler: LinkHandler, at path: [Int]) {
        linkHandlersByPath[path] = handler
    }

    func updateHitRegions(_ hitRegions: [RenderedHitRegion]) {
        self.hitRegions = hitRegions
    }

    func updateScrollRegions(_ scrollRegions: [RenderedScrollRegion]) {
        self.scrollRegions = scrollRegions
    }

    func updateFocusRegions(_ focusRegions: [RenderedFocusRegion]) {
        self.focusRegions = focusRegions
    }

    func updateRootFrame(_ frame: TextFrame) {
        self.rootFrame = frame
    }

    func dispatch(
        _ keyPress: KeyPress,
        from focusedPath: [Int],
        perform: ([Int], () -> KeyPress.Result) -> KeyPress.Result
    ) -> KeyPress.Result {
        var path = focusedPath

        while true {
            if dispatch(keyPress, at: path, perform: perform) == .handled {
                return .handled
            }

            guard !path.isEmpty else {
                return .ignored
            }

            path.removeLast()
        }
    }

    func dispatchGlobal(
        _ keyPress: KeyPress,
        perform: ([Int], () -> KeyPress.Result) -> KeyPress.Result
    ) -> KeyPress.Result {
        for entry in globalHandlers.sorted(by: globalHandlerPrecedes)
            where entry.handler.matches(keyPress) {
            let handler = entry.handler
            let actionPath = handler.actionPath ?? []
            if perform(actionPath, { handler.action(keyPress) }) == .handled {
                return .handled
            }
        }

        return .ignored
    }

    private func globalHandlerPrecedes(
        _ lhs: GlobalKeyPressHandler,
        _ rhs: GlobalKeyPressHandler
    ) -> Bool {
        if lhs.path.count != rhs.path.count {
            return lhs.path.count > rhs.path.count
        }

        return lhs.order < rhs.order
    }

    private func dispatch(
        _ keyPress: KeyPress,
        at path: [Int],
        perform: ([Int], () -> KeyPress.Result) -> KeyPress.Result
    ) -> KeyPress.Result {
        for handler in handlersByPath[path] ?? [] where handler.matches(keyPress) {
            let actionPath = handler.actionPath ?? path
            if perform(actionPath, { handler.action(keyPress) }) == .handled {
                return .handled
            }
        }

        return .ignored
    }

    func dispatch(
        _ mouseEvent: MouseEvent,
        at date: Date,
        perform: ([Int], () -> Void) -> Void,
        performLink: ([Int], () -> Bool) -> Bool,
        focus: ([Int]) -> Bool,
        scroll: ([Int], MouseEvent) -> KeyPress.Result
    ) -> KeyPress.Result {
        _ = dispatchExpiredTapActions(at: date, perform: perform)

        if mouseEvent.button.isScrollWheel {
            pressedTapTarget = nil
            pressedLinkTarget = nil
            return dispatchScroll(mouseEvent, scroll: scroll)
        }

        guard mouseEvent.button == .left else {
            pressedTapTarget = nil
            pressedLinkTarget = nil
            return .ignored
        }

        switch mouseEvent.phase {
        case .down:
            let focused = focusTargets(at: mouseEvent).contains {
                focus($0)
            }
            pressedLinkTarget = linkTarget(at: mouseEvent)
            pressedTapTarget = tapTarget(at: mouseEvent)
            return focused || pressedLinkTarget != nil || pressedTapTarget != nil
                ? .handled : .ignored
        case .up:
            if let pressedLinkTarget {
                defer {
                    self.pressedLinkTarget = nil
                    self.pressedTapTarget = nil
                }

                guard linkTarget(at: mouseEvent) == pressedLinkTarget else {
                    return .ignored
                }

                return dispatchLink(at: pressedLinkTarget, perform: performLink)
            }

            guard let pressedTapTarget else {
                return .ignored
            }

            defer {
                self.pressedTapTarget = nil
            }

            guard tapTarget(at: mouseEvent) == pressedTapTarget else {
                resetTapSequence()
                return .ignored
            }

            return dispatchTap(at: pressedTapTarget, date: date, perform: perform)
        }
    }

    func dispatchExpiredTapActions(
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        guard let sequence = tapSequence,
              date >= sequence.deadline else {
            return .ignored
        }

        defer {
            resetTapSequence()
        }

        guard let count = sequence.pendingCount else {
            return .ignored
        }

        performTapActions(at: sequence.path, count: count, perform: perform)
        return .handled
    }

    private func tapTarget(at mouseEvent: MouseEvent) -> [Int]? {
        let column = mouseEvent.column - rootFrame.column
        let row = mouseEvent.row - rootFrame.row
        return hitRegions
            .filter {
                tapHandlersByPath[$0.path] != nil
                    && $0.frame.contains(column: column, row: row)
            }
            .max {
                if $0.path.count != $1.path.count {
                    return $0.path.count < $1.path.count
                }

                return $0.frame.area > $1.frame.area
            }?
            .path
    }

    private func linkTarget(at mouseEvent: MouseEvent) -> [Int]? {
        let column = mouseEvent.column - rootFrame.column
        let row = mouseEvent.row - rootFrame.row
        return hitRegions
            .filter {
                linkHandlersByPath[$0.path] != nil
                    && $0.frame.contains(column: column, row: row)
            }
            .max {
                if $0.path.count != $1.path.count {
                    return $0.path.count < $1.path.count
                }

                return $0.frame.area > $1.frame.area
            }?
            .path
    }

    private func focusTargets(at mouseEvent: MouseEvent) -> [[Int]] {
        let column = mouseEvent.column - rootFrame.column
        let row = mouseEvent.row - rootFrame.row
        return focusRegions
            .filter {
                $0.frame.contains(column: column, row: row)
            }
            .sorted {
                if $0.path.count != $1.path.count {
                    return $0.path.count > $1.path.count
                }

                return $0.frame.area < $1.frame.area
            }
            .map(\.path)
    }

    private func dispatchScroll(
        _ mouseEvent: MouseEvent,
        scroll: ([Int], MouseEvent) -> KeyPress.Result
    ) -> KeyPress.Result {
        guard mouseEvent.phase == .down else {
            return .ignored
        }

        for path in scrollTargets(at: mouseEvent) {
            if scroll(path, mouseEvent) == .handled {
                return .handled
            }
        }

        return .ignored
    }

    private func scrollTargets(at mouseEvent: MouseEvent) -> [[Int]] {
        let column = mouseEvent.column - rootFrame.column
        let row = mouseEvent.row - rootFrame.row
        return scrollRegions
            .filter {
                $0.frame.contains(column: column, row: row)
            }
            .sorted {
                if $0.path.count != $1.path.count {
                    return $0.path.count > $1.path.count
                }

                return $0.frame.area < $1.frame.area
            }
            .map(\.path)
    }

    private func dispatchTap(
        at path: [Int],
        date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        let handlers = tapHandlersByPath[path] ?? []
        guard let maximumCount = handlers.map(\.count).max() else {
            resetTapSequence()
            return .ignored
        }

        if tapSequence?.path != path || tapSequence?.isExpired(at: date) == true {
            tapSequence = TapSequence(path: path)
        }

        tapSequence?.count += 1
        tapSequence?.deadline = date.addingTimeInterval(tapTimeout)

        guard let sequence = tapSequence else {
            return .ignored
        }

        if handlers.contains(where: { $0.count == sequence.count }) {
            if sequence.count >= maximumCount {
                performTapActions(at: path, count: sequence.count, perform: perform)
                resetTapSequence()
            }
            else {
                tapSequence?.pendingCount = sequence.count
            }
            return .handled
        }

        if let pendingCount = handlers.map(\.count)
            .filter({ $0 <= sequence.count })
            .max() {
            tapSequence?.pendingCount = pendingCount
        }

        if sequence.count >= maximumCount {
            resetTapSequence()
        }

        return .handled
    }

    private func dispatchLink(
        at path: [Int],
        perform: ([Int], () -> Bool) -> Bool
    ) -> KeyPress.Result {
        guard let handler = linkHandlersByPath[path] else {
            return .ignored
        }

        let actionPath = handler.actionPath ?? path
        return perform(actionPath, handler.action) ? .handled : .ignored
    }

    private func performTapActions(
        at path: [Int],
        count: Int,
        perform: ([Int], () -> Void) -> Void
    ) {
        for handler in tapHandlersByPath[path] ?? [] where handler.count == count {
            perform(handler.actionPath ?? path, handler.action)
        }
    }

    private func resetTapSequence() {
        tapSequence = nil
    }
}

private extension MouseButton {

    var isScrollWheel: Bool {
        switch self {
        case .wheelUp, .wheelDown, .wheelLeft, .wheelRight:
            return true
        default:
            return false
        }
    }
}

private struct TapSequence {

    let path: [Int]

    var count = 0

    var deadline = Date.distantPast

    var pendingCount: Int?

    func isExpired(at date: Date) -> Bool {
        date >= deadline
    }
}
