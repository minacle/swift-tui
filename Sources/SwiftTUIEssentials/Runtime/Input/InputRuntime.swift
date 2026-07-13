import Foundation
import Terminal

/// A zero-based global pointer movement decoded from terminal input.
///
/// `button` identifies a button held during movement. It is `nil` for passive
/// movement used only for hover tracking.
struct PointerMotion: Equatable, Sendable {

    let button: PointerButton?

    let location: Point

    let modifiers: EventModifiers
}

/// A zero-based global scroll-wheel movement decoded from terminal input.
struct PointerScroll: Equatable, Sendable {

    enum Direction: Equatable, Sendable {

        case up

        case down

        case left

        case right
    }

    let direction: Direction

    let location: Point

    let modifiers: EventModifiers
}

/// A decoded pointer input whose location uses zero-based global terminal-cell
/// coordinates.
nonisolated protocol LocatedPointerInput {

    var location: Point { get }

    var modifiers: EventModifiers { get }
}

extension PointerPress: LocatedPointerInput {}

extension PointerMotion: LocatedPointerInput {}

extension PointerScroll: LocatedPointerInput {}

nonisolated struct KeyPressView<Content: View>: View, InputModifierRenderable, LayoutTraitRenderable {

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
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerKeyPressHandler(handler, at: interactionPath)
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
        runtime?.registerKeyPressHandler(handler, at: interactionPath)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }
}

nonisolated struct GlobalKeyPressView<Content: View>: View, InputModifierRenderable,
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
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerTapGestureHandler(handler, at: interactionPath)
        guard var block = ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        block.hitRegions.append(
            RenderedHitRegion(path: interactionPath, frame: block.bounds)
        )
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

nonisolated struct PointerPressView<Content: View>: View, InputModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let handler: PointerPressHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerPointerPressHandler(handler, at: path)
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

nonisolated struct PointerDragView<Content: View>: View, InputModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let handler: PointerDragHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerPointerDragHandler(handler, at: path)
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

struct LongPressGestureView<Content: View>: View, InputModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let handler: LongPressGestureHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerLongPressGestureHandler(handler, at: path)
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

struct HoverGestureView<Content: View>: View, InputModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let handler: HoverGestureHandler

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerHoverGestureHandler(handler, at: path)
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

struct CoordinateSpaceView<Content: View>: View, InputModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let coordinateSpace: CoordinateSpace

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard var block = ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        if runtime?.isSuppressingInteractiveRenderRegistrations != true,
           EnvironmentRenderContext.current.isEnabled,
           let name = coordinateSpace.name {
            block.coordinateSpaceRegions.append(
                RenderedCoordinateSpaceRegion(
                    name: name,
                    path: path,
                    frame: block.bounds
                )
            )
        }
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

nonisolated struct KeyPressHandler {

    let actionPath: [Int]?

    let matches: (KeyPress) -> Bool

    let action: (KeyPress) -> KeyPress.Result
}

struct TapGestureHandler {

    let actionPath: [Int]?

    let count: Int

    let action: TapGestureAction
}

nonisolated struct PointerPressHandler {

    let actionPath: [Int]?

    let coordinateSpace: CoordinateSpace

    let matches: (PointerPress) -> Bool

    let action: (PointerPress) -> PointerPress.Result
}

nonisolated struct PointerDragHandler {

    let actionPath: [Int]?

    let button: PointerButton

    let coordinateSpace: CoordinateSpace

    let action: (PointerDrag) -> Void
}

struct LongPressGestureHandler {

    let actionPath: [Int]?

    let minimumDuration: TimeInterval

    let maximumDistance: Size

    let action: () -> Void

    let onPressingChanged: ((Bool) -> Void)?
}

struct HoverGestureHandler {

    let actionPath: [Int]?

    let action: HoverGestureAction
}

enum TapGestureAction {

    case plain(() -> Void)

    case location(CoordinateSpace, (Point) -> Void)

    func perform(at location: Point) {
        switch self {
        case .plain(let action):
            action()
        case .location(_, let action):
            action(location)
        }
    }
}

enum HoverGestureAction {

    case state((Bool) -> Void)

    case phase(CoordinateSpace, (HoverPhase) -> Void)

    func performEnterOrMove(at location: Point) {
        switch self {
        case .state(let action):
            action(true)
        case .phase(_, let action):
            action(.active(location))
        }
    }

    func performExit() {
        switch self {
        case .state(let action):
            action(false)
        case .phase(_, let action):
            action(.ended)
        }
    }
}

struct LinkHandler {

    let actionPath: [Int]?

    let action: () -> Bool
}

struct PointerDownPositionHandler {

    let actionPath: [Int]?

    let requiresFocus: Bool

    var shouldDeferBegin: (Point) -> Bool = { _ in false }

    let began: (Point) -> Void

    let changed: (Point) -> Void
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

    /// Geometry and identity retained for any captured pointer sequence,
    /// including editable-text selection and public pointer drags.
    private struct PointerCapture {

        var path: [Int]

        var frame: RenderedRect

        var startLocation: Point

        static func localLocation(rootPoint: Point, frame: RenderedRect) -> Point {
            Point(
                column: rootPoint.column - frame.x,
                row: rootPoint.row - frame.y
            )
        }
    }

    private struct GlobalKeyPressHandler {

        var path: [Int]

        var order: Int

        var handler: KeyPressHandler
    }

    private struct ActivePointerDownPositionTarget {

        var capture: PointerCapture

        var hasBegun: Bool

        var path: [Int] { capture.path }

        var frame: RenderedRect { capture.frame }

        var startLocation: Point { capture.startLocation }

        init(path: [Int], frame: RenderedRect, startLocation: Point, hasBegun: Bool) {
            capture = PointerCapture(path: path, frame: frame, startLocation: startLocation)
            self.hasBegun = hasBegun
        }
    }

    private struct ActivePointerDragTarget {

        var capture: PointerCapture

        var handler: PointerDragHandler

        var lastLocation: Point

        var modifiers: EventModifiers

        var path: [Int] { capture.path }

        var frame: RenderedRect { capture.frame }

        var startLocation: Point { capture.startLocation }

        init(
            path: [Int],
            frame: RenderedRect,
            handler: PointerDragHandler,
            startLocation: Point,
            lastLocation: Point,
            modifiers: EventModifiers
        ) {
            capture = PointerCapture(path: path, frame: frame, startLocation: startLocation)
            self.handler = handler
            self.lastLocation = lastLocation
            self.modifiers = modifiers
        }
    }

    private var handlersByPath: [[Int]: [KeyPressHandler]] = [:]

    private var globalHandlers: [GlobalKeyPressHandler] = []

    private var defaultGestureHandlersByPath: [[Int]: [DefaultGestureHandler]] = [:]

    private var pointerPressHandlersByPath: [[Int]: [PointerPressHandler]] = [:]

    private var pointerDragHandlersByPath: [[Int]: PointerDragHandler] = [:]

    private var hoverHandlersByPath: [[Int]: [HoverGestureHandler]] = [:]

    private var linkHandlersByPath: [[Int]: LinkHandler] = [:]

    private var pointerDownPositionHandlersByPath: [[Int]: PointerDownPositionHandler] = [:]

    private var hitRegions: [RenderedHitRegion] = []

    private var scrollRegions: [RenderedScrollRegion] = []

    private var focusRegions: [RenderedFocusRegion] = []

    private var coordinateSpaceRegions: [RenderedCoordinateSpaceRegion] = []

    private var rootFrame = RenderedTerminalFrame(text: "", row: 1, column: 1)

    private var pressedDefaultGestureTarget: DefaultGesturePressTarget?

    private var pressedLinkTarget: [Int]?

    private var activePointerDownPositionTarget: ActivePointerDownPositionTarget?

    private var activePointerDragTarget: ActivePointerDragTarget?

    private var tapSequence: TapSequence?

    private var longPressSequence: LongPressSequence?

    private var activeHoverPaths: Set<[Int]> = []

    private let tapTimeout: TimeInterval = 0.5

    var nextTapDeadline: Date? {
        tapSequence?.deadline
    }

    var nextLongPressDeadline: Date? {
        guard let sequence = longPressSequence,
              !sequence.didPerform else {
            return nil
        }

        return sequence.candidates
            .filter {
                !isBlockedByInnerTap(
                    $0,
                    in: pressedDefaultGestureTarget
                )
            }
            .map(\.deadline)
            .min()
    }

    func beginRender() {
        handlersByPath = [:]
        globalHandlers = []
        defaultGestureHandlersByPath = [:]
        pointerPressHandlersByPath = [:]
        pointerDragHandlersByPath = [:]
        hoverHandlersByPath = [:]
        linkHandlersByPath = [:]
        pointerDownPositionHandlersByPath = [:]
    }

    func finishRender(perform: ([Int], () -> Void) -> Void) {
        guard let target = activePointerDragTarget,
              pointerDragHandlersByPath[target.path] == nil else {
            return
        }
        cancelActivePointerDrag(perform: perform)
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
        defaultGestureHandlersByPath[path, default: []].append(.tap(handler))
    }

    func register(_ handler: PointerPressHandler, at path: [Int]) {
        pointerPressHandlersByPath[path, default: []].append(handler)
    }

    func register(_ handler: PointerDragHandler, at path: [Int]) {
        pointerDragHandlersByPath[path] = handler
    }

    func register(_ handler: LongPressGestureHandler, at path: [Int]) {
        defaultGestureHandlersByPath[path, default: []].append(.longPress(handler))
    }

    func register(_ handler: HoverGestureHandler, at path: [Int]) {
        hoverHandlersByPath[path, default: []].append(handler)
    }

    func register(_ handler: LinkHandler, at path: [Int]) {
        linkHandlersByPath[path] = handler
    }

    func register(_ handler: PointerDownPositionHandler, at path: [Int]) {
        pointerDownPositionHandlersByPath[path] = handler
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

    func updateCoordinateSpaceRegions(_ coordinateSpaceRegions: [RenderedCoordinateSpaceRegion]) {
        self.coordinateSpaceRegions = coordinateSpaceRegions
    }

    func updateRootFrame(_ frame: RenderedTerminalFrame) {
        self.rootFrame = frame
    }

    /// Offers a key press to each identity path from the root toward the focused view.
    ///
    /// Dispatch stops as soon as a handler consumes the event.
    func dispatch(
        _ keyPress: KeyPress,
        toward focusedPath: [Int],
        perform: ([Int], () -> KeyPress.Result) -> KeyPress.Result
    ) -> KeyPress.Result {
        var path: [Int] = []
        if dispatch(keyPress, at: path, perform: perform) == .handled {
            return .handled
        }

        for component in focusedPath {
            path.append(component)
            if dispatch(keyPress, at: path, perform: perform) == .handled {
                return .handled
            }
        }

        return .ignored
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
        _ pointerPress: PointerPress,
        at date: Date,
        perform: ([Int], () -> Void) -> Void,
        performLink: ([Int], () -> Bool) -> Bool,
        focus: ([Int]) -> Bool
    ) -> KeyPress.Result {
        _ = dispatchExpiredTapActions(at: date, perform: perform)
        _ = dispatchExpiredLongPressActions(at: date, perform: perform)

        if let activePointerDragTarget {
            if pointerPress.phase == .up,
               pointerPress.button == activePointerDragTarget.handler.button {
                dispatchActivePointerDrag(
                    pointerPress,
                    phase: .ended,
                    perform: perform
                )
                self.activePointerDragTarget = nil
                return .handled
            }

            cancelActivePointerDrag(perform: perform)
        }

        if pointerPress.phase == .down,
           beginPointerDrag(pointerPress, perform: perform) {
            _ = cancelLongPress(perform: perform)
            activePointerDownPositionTarget = nil
            pressedDefaultGestureTarget = nil
            pressedLinkTarget = nil
            resetTapSequence()
            return .handled
        }

        guard pointerPress.button == .left else {
            let cancelled = cancelLongPress(perform: perform)
            activePointerDownPositionTarget = nil
            pressedDefaultGestureTarget = nil
            pressedLinkTarget = nil
            let pointerPressResult = dispatchPointerPress(pointerPress, perform: perform)
            return pointerPressResult == .handled || cancelled ? .handled : .ignored
        }

        if pointerPress.phase == .down {
            _ = cancelLongPress(perform: perform)
            activePointerDownPositionTarget = nil
            let focusedPath = focusTargets(at: pointerPress).first {
                focus($0)
            }
            let positioned = beginPointerDownPositionDrag(
                at: pointerPress,
                eligiblePaths: focusedPath.map { [$0] } ?? [],
                perform: perform
            )
            pressedLinkTarget = linkTarget(at: pointerPress)
            let defaultGestureTarget = defaultGestureTarget(at: pointerPress)
            pressedDefaultGestureTarget = defaultGestureTarget
            let longPressStarted = beginLongPress(
                at: defaultGestureTarget,
                location: rootPoint(for: pointerPress),
                date: date,
                perform: perform
            )
            let longPressRecognized = dispatchExpiredLongPressActions(
                at: date,
                perform: perform
            ) == .handled
            let pointerPressResult = dispatchPointerPress(pointerPress, perform: perform)
            return focusedPath != nil
                || positioned
                || pressedLinkTarget != nil
                || pressedDefaultGestureTarget != nil
                || longPressStarted
                || longPressRecognized
                || pointerPressResult == .handled
                ? .handled : .ignored
        }

        if pointerPress.phase == .up {
            let pointerPressResult = dispatchPointerPress(pointerPress, perform: perform)
            if pointerPressResult == .handled {
                activePointerDownPositionTarget = nil
                _ = cancelLongPress(perform: perform)
                pressedLinkTarget = nil
                pressedDefaultGestureTarget = nil
                resetTapSequence()
                return .handled
            }

            let defaultGestureWasActive = pressedDefaultGestureTarget != nil
            let pointerDownPositionWasActive = activePointerDownPositionTarget != nil
            if longPressSequence?.didPerform == true {
                _ = endLongPress(perform: perform)
                activePointerDownPositionTarget = nil
                pressedLinkTarget = nil
                pressedDefaultGestureTarget = nil
                return .handled
            }

            if let pressedLinkTarget {
                _ = cancelLongPress(perform: perform)
                defer {
                    self.pressedLinkTarget = nil
                    self.pressedDefaultGestureTarget = nil
                }

                guard linkTarget(at: pointerPress) == pressedLinkTarget else {
                    activePointerDownPositionTarget = nil
                    return .ignored
                }

                let linkResult = dispatchLink(at: pressedLinkTarget, perform: performLink)
                let positioned = finishActivePointerDownPosition(
                    at: pointerPress,
                    perform: perform
                )
                return linkResult == .handled || positioned ? .handled : .ignored
            }

            guard let pressedDefaultGestureTarget else {
                _ = cancelLongPress(perform: perform)
                let positioned = finishActivePointerDownPosition(
                    at: pointerPress,
                    perform: perform
                )
                return defaultGestureWasActive || pointerDownPositionWasActive || positioned
                    ? .handled : .ignored
            }

            defer {
                self.pressedDefaultGestureTarget = nil
            }

            let releasePoint = rootPoint(for: pointerPress)
            guard pressedDefaultGestureTarget.frame.contains(
                column: releasePoint.column,
                row: releasePoint.row
            ) else {
                activePointerDownPositionTarget = nil
                _ = cancelLongPress(perform: perform)
                resetTapSequence()
                return .ignored
            }

            let tapOutcome = recognizeTap(
                at: pressedDefaultGestureTarget,
                location: releasePoint,
                date: date
            )
            finishDefaultGesturePress(
                pressedDefaultGestureTarget,
                tapOutcome: tapOutcome,
                rootPoint: releasePoint,
                perform: perform
            )
            let positioned = finishActivePointerDownPosition(
                at: pointerPress,
                perform: perform
            )
            return tapOutcome.result == .handled
                || defaultGestureWasActive
                || positioned
                ? .handled : .ignored
        }

        return .ignored
    }

    func dispatch(
        _ pointerMotion: PointerMotion,
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        _ = dispatchExpiredTapActions(at: date, perform: perform)
        _ = dispatchExpiredLongPressActions(at: date, perform: perform)

        if let activePointerDragTarget {
            if pointerMotion.button == activePointerDragTarget.handler.button {
                dispatchActivePointerDrag(
                    pointerMotion,
                    phase: .changed,
                    perform: perform
                )
                return .handled
            }

            cancelActivePointerDrag(perform: perform)
        }

        let hoverResult = dispatchHoverMotion(pointerMotion, perform: perform)
        guard pointerMotion.button == .left else {
            let cancelled = cancelLongPress(perform: perform)
            activePointerDownPositionTarget = nil
            pressedDefaultGestureTarget = nil
            pressedLinkTarget = nil
            return hoverResult == .handled || cancelled ? .handled : .ignored
        }

        let positioned = dispatchActivePointerDownPositionDrag(
            at: pointerMotion,
            perform: perform
        )
        if positioned {
            pressedLinkTarget = nil
            pressedDefaultGestureTarget = nil
        }
        let longPressResult = dispatchLongPressMotion(pointerMotion, perform: perform)
        return hoverResult == .handled
            || positioned
            || longPressResult == .handled
            ? .handled : .ignored
    }

    func dispatch(
        _ pointerScroll: PointerScroll,
        at date: Date,
        perform: ([Int], () -> Void) -> Void,
        scroll: ([Int], PointerScroll) -> KeyPress.Result
    ) -> KeyPress.Result {
        _ = dispatchExpiredTapActions(at: date, perform: perform)
        _ = dispatchExpiredLongPressActions(at: date, perform: perform)
        cancelActivePointerDrag(perform: perform)

        let cancelled = cancelLongPress(perform: perform)
        activePointerDownPositionTarget = nil
        pressedDefaultGestureTarget = nil
        pressedLinkTarget = nil
        let result = dispatchScroll(pointerScroll, scroll: scroll)
        return result == .handled || cancelled ? .handled : .ignored
    }

    private func beginPointerDrag(
        _ pointerPress: PointerPress,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        let rootPoint = rootPoint(for: pointerPress)
        guard let region = hitRegions
            .filter({ region in
                region.frame.contains(column: rootPoint.column, row: rootPoint.row)
                    && pointerDragHandlersByPath[region.path]?.button == pointerPress.button
            })
            .sorted(by: hitRegionPrecedes)
            .first,
              let handler = pointerDragHandlersByPath[region.path] else {
            return false
        }

        let location = pointerDragLocation(
            rootPoint: rootPoint,
            path: region.path,
            frame: region.frame,
            coordinateSpace: handler.coordinateSpace
        )
        activePointerDragTarget = ActivePointerDragTarget(
            path: region.path,
            frame: region.frame,
            handler: handler,
            startLocation: location,
            lastLocation: location,
            modifiers: pointerPress.modifiers
        )
        perform(handler.actionPath ?? region.path) {
            handler.action(PointerDrag(
                phase: .began,
                startLocation: location,
                location: location,
                modifiers: pointerPress.modifiers
            ))
        }
        return true
    }

    private func dispatchActivePointerDrag<Input: LocatedPointerInput>(
        _ pointerInput: Input,
        phase: PointerDrag.Phase,
        perform: ([Int], () -> Void) -> Void
    ) {
        guard var target = activePointerDragTarget else {
            return
        }
        let location = pointerDragLocation(
            rootPoint: rootPoint(for: pointerInput),
            path: target.path,
            frame: target.frame,
            coordinateSpace: target.handler.coordinateSpace
        )
        target.lastLocation = location
        target.modifiers = pointerInput.modifiers
        activePointerDragTarget = target
        perform(target.handler.actionPath ?? target.path) {
            target.handler.action(PointerDrag(
                phase: phase,
                startLocation: target.startLocation,
                location: location,
                modifiers: pointerInput.modifiers
            ))
        }
    }

    private func cancelActivePointerDrag(
        perform: ([Int], () -> Void) -> Void
    ) {
        guard let target = activePointerDragTarget else {
            return
        }
        activePointerDragTarget = nil
        perform(target.handler.actionPath ?? target.path) {
            target.handler.action(PointerDrag(
                phase: .cancelled,
                startLocation: target.startLocation,
                location: target.lastLocation,
                modifiers: target.modifiers
            ))
        }
    }

    private func pointerDragLocation(
        rootPoint: Point,
        path: [Int],
        frame: RenderedRect,
        coordinateSpace: CoordinateSpace
    ) -> Point {
        switch coordinateSpace.storage {
        case .local:
            return PointerCapture.localLocation(rootPoint: rootPoint, frame: frame)
        case .global:
            return rootPoint
        case .named(let name):
            guard let region = coordinateSpaceRegion(named: name, containing: path) else {
                preconditionFailure("No coordinate space named \(name) is registered.")
            }
            return Point(
                column: rootPoint.column - region.frame.x,
                row: rootPoint.row - region.frame.y
            )
        }
    }

    func dispatchExpiredLongPressActions(
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        guard var sequence = longPressSequence,
              !sequence.didPerform,
              let candidate = sequence.candidates
                .filter({
                    date >= $0.deadline
                        && !isBlockedByInnerTap(
                            $0,
                            in: pressedDefaultGestureTarget
                        )
                })
                .min(by: longPressCandidatePrecedes) else {
            return .ignored
        }

        perform(candidate.handler.actionPath ?? candidate.path) {
            candidate.handler.action()
        }
        sequence.winnerOrder = candidate.order
        longPressSequence = sequence
        return .handled
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

        guard let target = defaultGestureTarget(atRootPoint: sequence.location),
              target.path == sequence.path,
              let recognized = tapHandler(
                  in: target,
                  recognizing: sequence.count
              ) else {
            return .ignored
        }

        performTapAction(
            recognized.handler,
            at: recognized.path,
            rootPoint: sequence.location,
            perform: perform
        )
        return .handled
    }

    private func beginLongPress(
        at target: DefaultGesturePressTarget?,
        location: Point,
        date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        guard let target else {
            return false
        }

        let candidates: [LongPressCandidate] = target.handlers.enumerated()
            .compactMap { order, registered in

                guard case .longPress(let handler) = registered.handler else {
                    return nil
                }
                return LongPressCandidate(
                    order: order,
                    path: registered.path,
                    handler: handler,
                    deadline: date.addingTimeInterval(handler.minimumDuration)
                )
            }
        guard !candidates.isEmpty else {
            return false
        }
        longPressSequence = LongPressSequence(
            path: target.path,
            startLocation: location,
            candidates: candidates
        )

        for candidate in candidates {
            perform(candidate.handler.actionPath ?? candidate.path) {
                candidate.handler.onPressingChanged?(true)
            }
        }
        return true
    }

    private func dispatchLongPressMotion(
        _ pointerMotion: PointerMotion,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        guard var sequence = longPressSequence else {
            return .ignored
        }

        if sequence.didPerform {
            return .handled
        }

        let location = rootPoint(for: pointerMotion)
        var remaining: [LongPressCandidate] = []
        var handled = false
        for candidate in sequence.candidates {
            if isWithinExtent(
                from: sequence.startLocation,
                to: location,
                maximumDistance: candidate.handler.maximumDistance
            ) {
                remaining.append(candidate)
            }
            else {
                perform(candidate.handler.actionPath ?? candidate.path) {
                    candidate.handler.onPressingChanged?(false)
                }
                handled = true
            }
        }

        sequence.candidates = remaining
        longPressSequence = remaining.isEmpty ? nil : sequence
        return handled || !remaining.isEmpty ? .handled : .ignored
    }

    private func longPressCandidatePrecedes(
        _ lhs: LongPressCandidate,
        _ rhs: LongPressCandidate
    ) -> Bool {
        if lhs.deadline != rhs.deadline {
            return lhs.deadline < rhs.deadline
        }
        return lhs.order > rhs.order
    }

    private func isBlockedByInnerTap(
        _ candidate: LongPressCandidate,
        in target: DefaultGesturePressTarget?
    ) -> Bool {
        guard let target,
              target.path == longPressSequence?.path,
              candidate.order + 1 < target.handlers.count else {
            return false
        }
        return target.handlers[(candidate.order + 1)...].contains {
            if case .tap = $0.handler {
                return true
            }
            return false
        }
    }

    private func dispatchHoverMotion(
        _ pointerMotion: PointerMotion,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        let rootPoint = rootPoint(for: pointerMotion)
        let targets = hoverTargets(at: pointerMotion)
        let targetPaths = Set(targets.map(\.path))
        let exitedPaths = activeHoverPaths.subtracting(targetPaths)
        var handled = false

        for path in exitedPaths.sorted(by: pathPrecedes) {
            performHoverExit(at: path, perform: perform)
            handled = true
        }

        for target in targets {
            let didEnter = activeHoverPaths.insert(target.path).inserted
            if didEnter {
                performHoverEnter(at: target.path, rootPoint: rootPoint, perform: perform)
                handled = true
            }
            else {
                performContinuousHoverMove(
                    at: target.path,
                    rootPoint: rootPoint,
                    perform: perform
                )
                handled = true
            }
        }

        activeHoverPaths.subtract(exitedPaths)
        return handled ? .handled : .ignored
    }

    private func dispatchPointerPress(
        _ pointerPress: PointerPress,
        perform: ([Int], () -> Void) -> Void
    ) -> KeyPress.Result {
        let rootPoint = rootPoint(for: pointerPress)
        for target in pointerPressTargets(at: pointerPress) {
            for handler in pointerPressHandlersByPath[target.path] ?? [] {
                let location = location(
                    in: handler.coordinateSpace,
                    path: target.path,
                    rootPoint: rootPoint
                )
                let deliveredPress = PointerPress(
                    button: pointerPress.button,
                    location: location,
                    modifiers: pointerPress.modifiers,
                    phase: pointerPress.phase
                )
                guard handler.matches(deliveredPress) else {
                    continue
                }

                let actionPath = handler.actionPath ?? target.path
                var result = PointerPress.Result.ignored
                perform(actionPath) {
                    result = handler.action(deliveredPress)
                }
                if result == .handled {
                    return .handled
                }
            }
        }

        return .ignored
    }

    private func cancelLongPress(perform: ([Int], () -> Void) -> Void) -> Bool {
        guard let sequence = longPressSequence else {
            return false
        }

        finishLongPress(sequence, perform: perform)
        longPressSequence = nil
        return true
    }

    private func endLongPress(perform: ([Int], () -> Void) -> Void) -> Bool {
        guard let sequence = longPressSequence else {
            return false
        }

        finishLongPress(sequence, perform: perform)
        longPressSequence = nil
        return sequence.didPerform
    }

    private func finishLongPress(
        _ sequence: LongPressSequence,
        perform: ([Int], () -> Void) -> Void
    ) {
        for candidate in sequence.candidates {
            perform(candidate.handler.actionPath ?? candidate.path) {
                candidate.handler.onPressingChanged?(false)
            }
        }
    }

    private func defaultGestureTarget(
        at pointerPress: PointerPress
    ) -> DefaultGesturePressTarget? {
        defaultGestureTarget(atRootPoint: rootPoint(for: pointerPress))
    }

    private func defaultGestureTarget(
        atRootPoint point: Point
    ) -> DefaultGesturePressTarget? {
        let matchingRegions = hitRegions.filter {
            defaultGestureHandlersByPath[$0.path] != nil
                && $0.frame.contains(column: point.column, row: point.row)
        }
        guard let region = matchingRegions.max(by: {
            if $0.path.count != $1.path.count {
                return $0.path.count < $1.path.count
            }

            return $0.frame.area > $1.frame.area
        }),
              let deepestHandlers = defaultGestureHandlersByPath[region.path] else {
            return nil
        }

        let hasTap = deepestHandlers.contains {
            if case .tap = $0 {
                return true
            }
            return false
        }
        let hasLongPress = deepestHandlers.contains {
            if case .longPress = $0 {
                return true
            }
            return false
        }
        let matchingPaths = Set(matchingRegions.map(\.path))
        // The deepest hit region owns every gesture kind it registers. A kind
        // missing there can still compete from an ancestor, which lets a
        // control's internal tap arbitrate with a modifier outside its body
        // without restoring same-kind bubbling between structural regions.
        let ancestorHandlers = matchingPaths
            .filter {
                $0 != region.path && region.path.starts(with: $0)
            }
            .sorted { $0.count < $1.count }
            .flatMap { path in
                (defaultGestureHandlersByPath[path] ?? []).map {
                    RegisteredDefaultGestureHandler(path: path, handler: $0)
                }
            }
            .filter {
                switch $0.handler {
                case .tap:
                    return !hasTap
                case .longPress:
                    return !hasLongPress
                }
            }
        let handlers = ancestorHandlers + deepestHandlers.map {
            RegisteredDefaultGestureHandler(path: region.path, handler: $0)
        }
        return DefaultGesturePressTarget(
            path: region.path,
            frame: region.frame,
            handlers: handlers
        )
    }

    private func linkTarget(at pointerPress: PointerPress) -> [Int]? {
        let point = rootPoint(for: pointerPress)
        return hitRegions
            .filter {
                linkHandlersByPath[$0.path] != nil
                    && $0.frame.contains(column: point.column, row: point.row)
            }
            .max {
                if $0.path.count != $1.path.count {
                    return $0.path.count < $1.path.count
                }

                return $0.frame.area > $1.frame.area
            }?
            .path
    }

    private func pointerPressTargets(at pointerPress: PointerPress) -> [RenderedHitRegion] {
        let point = rootPoint(for: pointerPress)
        var paths: Set<[Int]> = []
        return hitRegions
            .filter {
                pointerPressHandlersByPath[$0.path] != nil
                    && $0.frame.contains(column: point.column, row: point.row)
            }
            .sorted(by: pointerPressHitRegionPrecedes)
            .filter {
                paths.insert($0.path).inserted
            }
    }

    private func hoverTargets(at pointerMotion: PointerMotion) -> [RenderedHitRegion] {
        let point = rootPoint(for: pointerMotion)
        var paths: Set<[Int]> = []
        return hitRegions
            .filter {
                hoverHandlersByPath[$0.path] != nil
                    && $0.frame.contains(column: point.column, row: point.row)
            }
            .sorted(by: hitRegionPrecedes)
            .filter {
                paths.insert($0.path).inserted
            }
    }

    private func pointerPressHitRegionPrecedes(
        _ lhs: RenderedHitRegion,
        _ rhs: RenderedHitRegion
    ) -> Bool {
        if lhs.path.count != rhs.path.count {
            return lhs.path.count > rhs.path.count
        }

        return lhs.frame.area < rhs.frame.area
    }

    private func hitRegionPrecedes(
        _ lhs: RenderedHitRegion,
        _ rhs: RenderedHitRegion
    ) -> Bool {
        if lhs.path.count != rhs.path.count {
            return lhs.path.count < rhs.path.count
        }

        return lhs.frame.area > rhs.frame.area
    }

    private func pathPrecedes(_ lhs: [Int], _ rhs: [Int]) -> Bool {
        if lhs.count != rhs.count {
            return lhs.count > rhs.count
        }

        return lhs.lexicographicallyPrecedes(rhs)
    }

    private func focusTargets(at pointerPress: PointerPress) -> [[Int]] {
        let point = rootPoint(for: pointerPress)
        return focusRegions
            .filter {
                $0.frame.contains(column: point.column, row: point.row)
            }
            .sorted {
                if $0.path.count != $1.path.count {
                    return $0.path.count > $1.path.count
                }

                return $0.frame.area < $1.frame.area
            }
            .map(\.path)
    }

    private func beginPointerDownPositionDrag(
        at pointerPress: PointerPress,
        eligiblePaths: [[Int]],
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        guard let target = pointerDownPositionTarget(
            at: pointerPress,
            eligiblePaths: eligiblePaths
        ),
              let handler = pointerDownPositionHandlersByPath[target.path] else {
            return false
        }

        let shouldDeferBegin = handler.shouldDeferBegin(target.location)
        activePointerDownPositionTarget = ActivePointerDownPositionTarget(
            path: target.path,
            frame: target.frame,
            startLocation: target.location,
            hasBegun: !shouldDeferBegin
        )
        if !shouldDeferBegin {
            perform(handler.actionPath ?? target.path) {
                handler.began(target.location)
            }
        }
        return true
    }

    private func dispatchActivePointerDownPositionDrag(
        at pointerMotion: PointerMotion,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        guard var target = activePointerDownPositionTarget,
              let handler = pointerDownPositionHandlersByPath[target.path] else {
            activePointerDownPositionTarget = nil
            return false
        }

        if !target.hasBegun {
            target.hasBegun = true
            activePointerDownPositionTarget = target
            perform(handler.actionPath ?? target.path) {
                handler.began(target.startLocation)
            }
        }
        let location = location(of: pointerMotion, in: target.frame)
        perform(handler.actionPath ?? target.path) {
            handler.changed(location)
        }
        return true
    }

    private func finishActivePointerDownPosition(
        at pointerPress: PointerPress,
        perform: ([Int], () -> Void) -> Void
    ) -> Bool {
        guard let target = activePointerDownPositionTarget else {
            return false
        }
        activePointerDownPositionTarget = nil
        guard !target.hasBegun,
              let handler = pointerDownPositionHandlersByPath[target.path] else {
            return false
        }

        let location = location(of: pointerPress, in: target.frame)
        perform(handler.actionPath ?? target.path) {
            handler.began(location)
        }
        return true
    }

    private func location<Input: LocatedPointerInput>(
        of pointerInput: Input,
        in frame: RenderedRect
    ) -> Point {
        PointerCapture.localLocation(
            rootPoint: rootPoint(for: pointerInput),
            frame: frame
        )
    }

    private func pointerDownPositionTarget(
        at pointerPress: PointerPress,
        eligiblePaths: [[Int]]
    ) -> (path: [Int], frame: RenderedRect, location: Point)? {
        let point = rootPoint(for: pointerPress)
        let column = point.column
        let row = point.row
        if let region = focusRegions
            .filter({
                eligiblePaths.contains($0.path)
                    && pointerDownPositionHandlersByPath[$0.path]?.requiresFocus == true
                    && $0.frame.contains(column: column, row: row)
            })
            .sorted(by: focusRegionPrecedes)
            .first {
            let positionFrame = region.positionFrame ?? region.frame
            return (
                region.path,
                positionFrame,
                Point(
                    column: column - positionFrame.x,
                    row: row - positionFrame.y
                )
            )
        }

        guard let region = hitRegions
            .filter({
                pointerDownPositionHandlersByPath[$0.path]?.requiresFocus == false
                    && $0.frame.contains(column: column, row: row)
            })
            .sorted(by: hitRegionPrecedes)
            .first else {
            return nil
        }

        return (
            region.path,
            region.frame,
            Point(column: column - region.frame.x, row: row - region.frame.y)
        )
    }

    private func focusRegionPrecedes(
        _ lhs: RenderedFocusRegion,
        _ rhs: RenderedFocusRegion
    ) -> Bool {
        if lhs.path.count != rhs.path.count {
            return lhs.path.count > rhs.path.count
        }

        return lhs.frame.area < rhs.frame.area
    }

    private func dispatchScroll(
        _ pointerScroll: PointerScroll,
        scroll: ([Int], PointerScroll) -> KeyPress.Result
    ) -> KeyPress.Result {
        for path in scrollTargets(at: pointerScroll) {
            if scroll(path, pointerScroll) == .handled {
                return .handled
            }
        }

        return .ignored
    }

    private func scrollTargets(at pointerScroll: PointerScroll) -> [[Int]] {
        let point = rootPoint(for: pointerScroll)
        return scrollRegions
            .filter {
                $0.frame.contains(column: point.column, row: point.row)
            }
            .sorted {
                if $0.path.count != $1.path.count {
                    return $0.path.count > $1.path.count
                }

                return $0.frame.area < $1.frame.area
            }
            .map(\.path)
    }

    private func recognizeTap(
        at target: DefaultGesturePressTarget,
        location: Point,
        date: Date
    ) -> TapDispatchOutcome {
        guard let recognized = target.handlers.enumerated().reversed().compactMap({
            order, registered -> (Int, [Int], TapGestureHandler)? in

            guard case .tap(let handler) = registered.handler else {
                return nil
            }
            return (order, registered.path, handler)
        }).first else {
            resetTapSequence()
            return .ignored
        }
        let (order, path, handler) = recognized

        if tapSequence?.path != target.path || tapSequence?.isExpired(at: date) == true {
            tapSequence = TapSequence(path: target.path)
        }

        tapSequence?.count += 1
        tapSequence?.location = location
        tapSequence?.deadline = date.addingTimeInterval(tapTimeout)

        guard let sequence = tapSequence else {
            return .ignored
        }

        if sequence.count == handler.count {
            resetTapSequence()
            return .recognized(order: order, path: path, handler: handler)
        }
        if sequence.count > handler.count {
            resetTapSequence()
        }

        return .pending
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

    private func tapHandler(
        in target: DefaultGesturePressTarget,
        recognizing count: Int
    ) -> (path: [Int], handler: TapGestureHandler)? {
        target.handlers.reversed().compactMap {
            guard case .tap(let handler) = $0.handler,
                  handler.count == count else {
                return nil
            }
            return ($0.path, handler)
        }.first
    }

    private func performTapAction(
        _ handler: TapGestureHandler,
        at path: [Int],
        rootPoint: Point,
        perform: ([Int], () -> Void) -> Void
    ) {
        let location = location(for: handler.action, path: path, rootPoint: rootPoint)
        perform(handler.actionPath ?? path) {
            handler.action.perform(at: location)
        }
    }

    private func finishDefaultGesturePress(
        _ target: DefaultGesturePressTarget,
        tapOutcome: TapDispatchOutcome,
        rootPoint: Point,
        perform: ([Int], () -> Void) -> Void
    ) {
        let candidatesByOrder = Dictionary(
            uniqueKeysWithValues: (longPressSequence?.candidates ?? []).map {
                ($0.order, $0)
            }
        )

        for (order, registered) in target.handlers.enumerated() {
            switch registered.handler {
            case .tap:
                guard case .recognized(
                    let recognizedOrder,
                    let path,
                    let handler
                ) = tapOutcome,
                      order == recognizedOrder else {
                    continue
                }
                performTapAction(
                    handler,
                    at: path,
                    rootPoint: rootPoint,
                    perform: perform
                )
            case .longPress:
                guard let candidate = candidatesByOrder[order] else {
                    continue
                }
                perform(candidate.handler.actionPath ?? candidate.path) {
                    candidate.handler.onPressingChanged?(false)
                }
            }
        }
        longPressSequence = nil
    }

    private func performHoverEnter(
        at path: [Int],
        rootPoint: Point,
        perform: ([Int], () -> Void) -> Void
    ) {
        for handler in hoverHandlersByPath[path] ?? [] {
            let location = location(for: handler.action, path: path, rootPoint: rootPoint)
            perform(handler.actionPath ?? path) {
                handler.action.performEnterOrMove(at: location)
            }
        }
    }

    private func performContinuousHoverMove(
        at path: [Int],
        rootPoint: Point,
        perform: ([Int], () -> Void) -> Void
    ) {
        for handler in hoverHandlersByPath[path] ?? []
            where handler.action.isContinuous {
            let location = location(for: handler.action, path: path, rootPoint: rootPoint)
            perform(handler.actionPath ?? path) {
                handler.action.performEnterOrMove(at: location)
            }
        }
    }

    private func performHoverExit(
        at path: [Int],
        perform: ([Int], () -> Void) -> Void
    ) {
        for handler in (hoverHandlersByPath[path] ?? []).reversed() {
            perform(handler.actionPath ?? path) {
                handler.action.performExit()
            }
        }
    }

    private func rootPoint<Input: LocatedPointerInput>(for pointerInput: Input) -> Point {
        Point(
            column: pointerInput.location.column - (rootFrame.column - 1),
            row: pointerInput.location.row - (rootFrame.row - 1)
        )
    }

    private func location(
        for action: TapGestureAction,
        path: [Int],
        rootPoint: Point
    ) -> Point {
        switch action {
        case .plain:
            return rootPoint
        case .location(let coordinateSpace, _):
            return location(in: coordinateSpace, path: path, rootPoint: rootPoint)
        }
    }

    private func location(
        for action: HoverGestureAction,
        path: [Int],
        rootPoint: Point
    ) -> Point {
        switch action {
        case .state:
            return rootPoint
        case .phase(let coordinateSpace, _):
            return location(in: coordinateSpace, path: path, rootPoint: rootPoint)
        }
    }

    private func location(
        in coordinateSpace: CoordinateSpace,
        path: [Int],
        rootPoint: Point
    ) -> Point {
        switch coordinateSpace.storage {
        case .local:
            let frame = hitRegion(at: path, containing: rootPoint)?.frame
                ?? RenderedRect()
            return Point(column: rootPoint.column - frame.x, row: rootPoint.row - frame.y)
        case .global:
            return rootPoint
        case .named(let name):
            guard let region = coordinateSpaceRegion(
                named: name,
                containing: path
            ) else {
                preconditionFailure("No coordinate space named \(name) is registered.")
            }
            return Point(
                column: rootPoint.column - region.frame.x,
                row: rootPoint.row - region.frame.y
            )
        }
    }

    private func hitRegion(at path: [Int], containing point: Point) -> RenderedHitRegion? {
        hitRegions
            .filter {
                $0.path == path
                    && $0.frame.contains(column: point.column, row: point.row)
            }
            .max {
                $0.frame.area > $1.frame.area
            }
    }

    private func coordinateSpaceRegion(
        named name: AnyHashable,
        containing path: [Int]
    ) -> RenderedCoordinateSpaceRegion? {
        coordinateSpaceRegions
            .filter {
                $0.name == name && isPrefix($0.path, of: path)
            }
            .max {
                if $0.path.count != $1.path.count {
                    return $0.path.count < $1.path.count
                }
                return $0.frame.area > $1.frame.area
            }
    }

    private func isPrefix(_ prefix: [Int], of path: [Int]) -> Bool {
        guard prefix.count <= path.count else {
            return false
        }

        return zip(prefix, path).allSatisfy(==)
    }

    private func resetTapSequence() {
        tapSequence = nil
    }

    private func isWithinExtent(
        from start: Point,
        to end: Point,
        maximumDistance: Size
    ) -> Bool {
        let columns = end.column - start.column
        let rows = end.row - start.row
        return abs(columns) <= maximumDistance.columns
            && abs(rows) <= maximumDistance.rows
    }
}

extension HoverGestureAction {

    fileprivate var isContinuous: Bool {
        switch self {
        case .state:
            return false
        case .phase:
            return true
        }
    }
}

private enum DefaultGestureHandler {

    case tap(TapGestureHandler)

    case longPress(LongPressGestureHandler)
}

private struct RegisteredDefaultGestureHandler {

    let path: [Int]

    let handler: DefaultGestureHandler
}

private struct DefaultGesturePressTarget {

    let path: [Int]

    let frame: RenderedRect

    let handlers: [RegisteredDefaultGestureHandler]
}

private enum TapDispatchOutcome {

    case ignored

    case pending

    case recognized(order: Int, path: [Int], handler: TapGestureHandler)

    var result: KeyPress.Result {
        switch self {
        case .ignored:
            return .ignored
        case .pending, .recognized:
            return .handled
        }
    }
}

private struct TapSequence {

    let path: [Int]

    var count = 0

    var location = Point.zero

    var deadline = Date.distantPast

    func isExpired(at date: Date) -> Bool {
        date >= deadline
    }
}

private struct LongPressSequence {

    let path: [Int]

    let startLocation: Point

    var candidates: [LongPressCandidate]

    var winnerOrder: Int?

    var didPerform: Bool {
        winnerOrder != nil
    }
}

private struct LongPressCandidate {

    let order: Int

    let path: [Int]

    let handler: LongPressGestureHandler

    let deadline: Date
}
