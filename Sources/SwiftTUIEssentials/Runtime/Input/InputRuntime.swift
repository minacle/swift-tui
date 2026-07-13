import Foundation
import Terminal

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

    let action: (KeyPress) -> InputEventResult
}

nonisolated struct ViewDefinedKeyPressEvent: KeyEvent {

    typealias Value = KeyPress

    typealias Body = Never

    let handler: KeyPressHandler

    func _makeInputEvent() -> _InputEventDefinition<KeyPress> {
        _InputEventDefinition(
            configuration: InputRecognitionConfiguration("viewDefinedKeyPress"),
            families: .key,
            makeNode: {
                RecognizedInputRecognitionNode(
                    base: MatcherInputRecognitionNode { sample, _ in
                        guard case .keyPress(let press) = sample,
                              handler.matches(press) else {
                            return nil
                        }
                        return press
                    },
                    action: handler.action
                )
            }
        )
    }
}

/// A key-down fallback closure together with the state path that declared it.
nonisolated struct ResolveKeyHandler {

    let actionPath: [Int]?

    let action: ResolveKeyAction.Handler
}

struct TapGestureHandler {

    let actionPath: [Int]?

    let count: Int

    let action: TapGestureAction
}

struct ViewDefinedTapGesture: Gesture {

    typealias Value = Void

    typealias Body = Never

    let handler: TapGestureHandler

    func _makeGesture() -> _GestureDefinition<Void> {
        let coordinateSpace: CoordinateSpace?
        switch handler.action {
        case .plain:
            coordinateSpace = nil
        case .location(let space, _):
            coordinateSpace = space
        }
        return _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "viewDefinedTap",
                values: [handler.count, coordinateSpace ?? CoordinateSpace.global]
            ),
            makeNode: {
                ViewDefinedTapGestureRecognitionNode(
                    count: handler.count,
                    coordinateSpace: coordinateSpace,
                    action: handler.action
                )
            }
        )
    }
}

final class ViewDefinedTapGestureRecognitionNode: GestureRecognitionNode<Void> {

    enum Storage {

        case plain(TapGestureRecognitionNode<Void>)

        case location(TapGestureRecognitionNode<Point>)
    }

    let storage: Storage

    let action: TapGestureAction

    init(
        count: Int,
        coordinateSpace: CoordinateSpace?,
        action: TapGestureAction
    ) {
        if let coordinateSpace {
            storage = .location(
                TapGestureRecognitionNode(
                    count: count,
                    coordinateSpace: coordinateSpace,
                    makeValue: { $0 }
                )
            )
        } else {
            storage = .plain(
                TapGestureRecognitionNode(
                    count: count,
                    coordinateSpace: nil,
                    makeValue: { _ in () }
                )
            )
        }
        self.action = action
        super.init()
    }

    override var isActive: Bool {
        switch storage {
        case .plain(let node):
            node.isActive
        case .location(let node):
            node.isActive
        }
    }

    override var nextDeadline: Date? {
        switch storage {
        case .plain(let node):
            node.nextDeadline
        case .location(let node):
            node.nextDeadline
        }
    }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Void> {
        switch storage {
        case .plain(let node):
            return observe(node.process(sample, context: context), context: context)
        case .location(let node):
            return observe(node.process(sample, context: context), context: context)
        }
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Void> {
        switch storage {
        case .plain(let node):
            return observe(node.advance(to: date, context: context), context: context)
        case .location(let node):
            return observe(node.advance(to: date, context: context), context: context)
        }
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        switch storage {
        case .plain(let node):
            node.cancel(reason)
        case .location(let node):
            node.cancel(reason)
        }
    }

    private func observe<Child>(
        _ output: GestureRecognitionOutput<Child>,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Void> {
        let phase: GestureRecognitionPhase<Void>
        switch output.phase {
        case .none:
            phase = .none
        case .changed:
            phase = .changed(())
        case .ended(let value):
            let location = value as? Point ?? .zero
            context.appendEnded { [action] in
                action.perform(at: location)
            }
            phase = .ended(())
        case .failed:
            phase = .failed
        }
        return GestureRecognitionOutput(
            participated: output.participated,
            phase: phase,
            claimsCompetition: output.claimsCompetition,
            beginsCapture: output.beginsCapture,
            endsCapture: output.endsCapture
        )
    }
}

nonisolated struct PointerPressHandler {

    let actionPath: [Int]?

    let coordinateSpace: CoordinateSpace

    let matches: (PointerPress) -> Bool

    let action: (PointerPress) -> InputEventResult
}

nonisolated struct ViewDefinedPointerPressEvent: PointerEvent {

    typealias Value = PointerPress

    typealias Body = Never

    let handler: PointerPressHandler

    func _makeInputEvent() -> _InputEventDefinition<PointerPress> {
        _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "viewDefinedPointerPress",
                values: [handler.coordinateSpace]
            ),
            families: .pointerPress,
            makeNode: {
                RecognizedInputRecognitionNode(
                    base: MatcherInputRecognitionNode { sample, context in
                        guard case .pointerPress(let press) = sample,
                              handler.matches(press) else {
                            return nil
                        }
                        guard let location = context.location(
                            press.location,
                            in: handler.coordinateSpace
                        ) else {
                            return nil
                        }
                        return PointerPress(
                            button: press.button,
                            location: location,
                            modifiers: press.modifiers,
                            phase: press.phase
                        )
                    },
                    action: handler.action
                )
            }
        )
    }
}

struct LongPressGestureHandler {

    let actionPath: [Int]?

    let minimumDuration: TimeInterval

    let maximumDistance: Size

    let action: () -> Void

    let onPressingChanged: ((Bool) -> Void)?
}

struct ViewDefinedLongPressGesture: Gesture {

    typealias Value = Bool

    typealias Body = Never

    let handler: LongPressGestureHandler

    func _makeGesture() -> _GestureDefinition<Bool> {
        _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "viewDefinedLongPress",
                values: [
                    handler.minimumDuration.bitPattern,
                    handler.maximumDistance.columns,
                    handler.maximumDistance.rows,
                ]
            ),
            makeNode: {
                ViewDefinedLongPressGestureRecognitionNode(handler: handler)
            }
        )
    }
}

final class ViewDefinedLongPressGestureRecognitionNode: GestureRecognitionNode<Bool> {

    let handler: LongPressGestureHandler

    let base: LongPressGestureRecognitionNode

    var isPressing = false

    init(handler: LongPressGestureHandler) {
        self.handler = handler
        self.base = LongPressGestureRecognitionNode(
            minimumDuration: handler.minimumDuration,
            maximumDistance: handler.maximumDistance
        )
        super.init()
    }

    override var isActive: Bool { base.isActive }

    override var nextDeadline: Date? { base.nextDeadline }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Bool> {
        let wasActive = base.isActive
        let output = base.process(sample, context: context)
        if !wasActive, base.isActive {
            isPressing = true
            if let action = handler.onPressingChanged {
                context.appendChanged { action(true) }
            }
        } else if wasActive, !base.isActive {
            finishPressing(context: context)
        }
        return observe(output, context: context)
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Bool> {
        observe(base.advance(to: date, context: context), context: context)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        base.cancel(reason)
        guard isPressing else {
            return
        }
        isPressing = false
        handler.onPressingChanged?(false)
    }

    private func observe(
        _ output: GestureRecognitionOutput<Bool>,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Bool> {
        if case .ended = output.phase {
            context.appendEnded { [handler] in handler.action() }
        }
        return output
    }

    private func finishPressing(context: GestureRecognitionContext) {
        guard isPressing else {
            return
        }
        isPressing = false
        if let action = handler.onPressingChanged {
            context.appendChanged { action(false) }
        }
    }
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

struct PointerPositionInputEvent: PointerEvent {

    typealias Value = Void

    typealias Body = Never

    let handler: PointerDownPositionHandler

    let isEligible: () -> Bool

    let sequence: PointerPositionSequenceState

    let stage: InputEventStage

    func _makeInputEvent() -> _InputEventDefinition<Void> {
        _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "pointerPosition:\(stage.rawValue)",
                values: [handler.requiresFocus]
            ),
            families: [.pointerPress, .pointerMotion],
            stage: stage,
            makeNode: {
                if stage == .eager {
                    return PointerPositionTrackingInputRecognitionNode(
                        handler: handler,
                        isEligible: isEligible,
                        sequence: sequence
                    )
                }
                return PointerPositionCompletionInputRecognitionNode(
                    handler: handler,
                    sequence: sequence,
                    shouldComplete: isEligible
                )
            }
        )
    }
}

final class PointerPositionSequenceState {

    var startLocation: Point?

    var hasBegun = false

    func reset() {
        startLocation = nil
        hasBegun = false
    }
}

final class PointerPositionTrackingInputRecognitionNode: InputRecognitionNode<Void> {

    let handler: PointerDownPositionHandler

    let isEligible: () -> Bool

    let sequence: PointerPositionSequenceState

    init(
        handler: PointerDownPositionHandler,
        isEligible: @escaping () -> Bool,
        sequence: PointerPositionSequenceState
    ) {
        self.handler = handler
        self.isEligible = isEligible
        self.sequence = sequence
        super.init()
    }

    override var isActive: Bool {
        sequence.startLocation != nil
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Void> {
        switch sample {
        case .pointerPress(let press)
        where press.button == .left && press.phase == .down:
            guard isEligible() else {
                return .noMatch
            }
            guard let location = context.location(press.location, in: .local) else {
                return .noMatch
            }
            sequence.startLocation = location
            sequence.hasBegun = !handler.shouldDeferBegin(location)
            if sequence.hasBegun {
                handler.began(location)
            }
            return .progress(beginsCapture: true)

        case .pointerMotion(let motion) where motion.button == .left:
            guard let startLocation = sequence.startLocation else {
                return .noMatch
            }
            if !sequence.hasBegun {
                sequence.hasBegun = true
                handler.began(startLocation)
            }
            guard let location = context.location(motion.location, in: .local) else {
                return .noMatch
            }
            handler.changed(location)
            return .progress()

        case .pointerPress(let press)
        where press.button == .left && press.phase == .up:
            guard sequence.startLocation != nil else {
                return .noMatch
            }
            return .progress(endsCapture: true)

        default:
            return .noMatch
        }
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        sequence.reset()
    }

    override func restoreState(from old: InputRecognitionNode<Void>) {
        guard let old = old as? PointerPositionTrackingInputRecognitionNode else {
            return
        }
        sequence.startLocation = old.sequence.startLocation
        sequence.hasBegun = old.sequence.hasBegun
    }
}

final class PointerPositionCompletionInputRecognitionNode: InputRecognitionNode<Void> {

    let handler: PointerDownPositionHandler

    let sequence: PointerPositionSequenceState

    let shouldComplete: () -> Bool

    init(
        handler: PointerDownPositionHandler,
        sequence: PointerPositionSequenceState,
        shouldComplete: @escaping () -> Bool
    ) {
        self.handler = handler
        self.sequence = sequence
        self.shouldComplete = shouldComplete
        super.init()
    }

    override var isActive: Bool {
        sequence.startLocation != nil
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Void> {
        guard case .pointerPress(let press) = sample,
              press.button == .left,
              press.phase == .up,
              sequence.startLocation != nil else {
            return .noMatch
        }
        guard shouldComplete() else {
            sequence.reset()
            return .recognized(())
        }
        if !sequence.hasBegun {
            guard let location = context.location(press.location, in: .local) else {
                return .noMatch
            }
            handler.began(location)
        }
        sequence.reset()
        return .recognized(())
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        sequence.reset()
    }

    override func restoreState(from old: InputRecognitionNode<Void>) {
        guard let old = old as? PointerPositionCompletionInputRecognitionNode else {
            return
        }
        sequence.startLocation = old.sequence.startLocation
        sequence.hasBegun = old.sequence.hasBegun
    }
}

/// Tracks link activation without treating button-bearing selection motion as
/// a click. Buttonless hover motion remains outside this consumable state.
struct LinkActivationInputEvent: PointerEvent {

    typealias Value = Void

    typealias Body = Never

    let handler: LinkHandler

    func _makeInputEvent() -> _InputEventDefinition<Void> {
        _InputEventDefinition(
            configuration: InputRecognitionConfiguration("linkActivation"),
            families: [.pointerPress, .pointerMotion],
            stage: .eager,
            makeNode: {
                LinkActivationInputRecognitionNode(handler: handler)
            }
        )
    }
}

final class LinkActivationInputRecognitionNode: InputRecognitionNode<Void> {

    let handler: LinkHandler

    var startLocation: Point?

    init(handler: LinkHandler) {
        self.handler = handler
        super.init()
    }

    override var isActive: Bool {
        startLocation != nil
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Void> {
        switch sample {
        case .pointerPress(let press)
        where press.button == .left && press.phase == .down:
            startLocation = press.location
            return .progress()

        case .pointerMotion(let motion) where motion.button == .left:
            guard let startLocation else {
                return .noMatch
            }
            if motion.location != startLocation {
                self.startLocation = nil
            }
            return .progress()

        case .pointerPress(let press)
        where press.button == .left && press.phase == .up:
            guard startLocation != nil else {
                return .noMatch
            }
            startLocation = nil
            _ = handler.action()
            return .recognized(())

        default:
            return .noMatch
        }
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        startLocation = nil
    }

    override func restoreState(from old: InputRecognitionNode<Void>) {
        guard let old = old as? LinkActivationInputRecognitionNode else {
            return
        }
        startLocation = old.startLocation
    }
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

    /// One rendered key resolver. `path` controls branch selection, while
    /// `order` provides stable render-order and same-path modifier precedence.
    private struct ResolveKeyHandlerEntry {

        var path: [Int]

        var order: Int

        var handler: ResolveKeyHandler
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

    private var handlersByPath: [[Int]: [KeyPressHandler]] = [:]

    private var globalHandlers: [GlobalKeyPressHandler] = []

    private var resolveKeyHandlers: [KeyEquivalent: [ResolveKeyHandlerEntry]] = [:]

    private var defaultGestureHandlersByPath: [[Int]: [DefaultGestureHandler]] = [:]

    private var pointerPressHandlersByPath: [[Int]: [PointerPressHandler]] = [:]

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

    var hasRecognizedLongPress: Bool {
        longPressSequence?.didPerform == true
    }

    private(set) var hasRecognizedTap = false

    func beginRender() {
        handlersByPath = [:]
        globalHandlers = []
        resolveKeyHandlers = [:]
        defaultGestureHandlersByPath = [:]
        pointerPressHandlersByPath = [:]
        hoverHandlersByPath = [:]
        linkHandlersByPath = [:]
        pointerDownPositionHandlersByPath = [:]
    }

    func finishRender(perform: ([Int], () -> Void) -> Void) {
        let location: Point
        let configuration: [RegisteredDefaultGestureConfiguration]
        if let pressedDefaultGestureTarget {
            location = pressedDefaultGestureTarget.location
            configuration = pressedDefaultGestureTarget.configuration
        } else if let tapSequence {
            location = tapSequence.location
            configuration = tapSequence.configuration
        } else {
            return
        }
        guard let updatedTarget = defaultGestureTarget(
            atRootPoint: location
        ),
              updatedTarget.configuration == configuration else {
            cancelDefaultGestureRecognition(perform: perform)
            return
        }

        if pressedDefaultGestureTarget != nil {
            self.pressedDefaultGestureTarget = updatedTarget
        }
        tapSequence?.configuration = updatedTarget.configuration
        if var sequence = longPressSequence {
            sequence.candidates = sequence.candidates.compactMap { candidate in
                guard updatedTarget.handlers.indices.contains(candidate.order),
                      case .longPress(let handler) = updatedTarget
                        .handlers[candidate.order].handler else {
                    return nil
                }
                return LongPressCandidate(
                    order: candidate.order,
                    path: candidate.path,
                    handler: handler,
                    deadline: candidate.deadline
                )
            }
            longPressSequence = sequence
        }
    }

    func cancelInteractions(
        perform: ([Int], () -> Void) -> Void
    ) {
        _ = cancelLongPress(perform: perform)
        activePointerDownPositionTarget = nil
        pressedDefaultGestureTarget = nil
        pressedLinkTarget = nil
        resetTapSequence()

        for path in activeHoverPaths.sorted(by: pathPrecedes) {
            performHoverExit(at: path, perform: perform)
        }
        activeHoverPaths = []
    }

    func cancelDefaultGestureRecognition(
        perform: ([Int], () -> Void) -> Void
    ) {
        _ = cancelLongPress(perform: perform)
        pressedDefaultGestureTarget = nil
        resetTapSequence()
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

    func registerResolveKey(
        _ handler: ResolveKeyHandler,
        for key: KeyEquivalent,
        at path: [Int]
    ) {
        let order = resolveKeyHandlers[key, default: []].count
        resolveKeyHandlers[key, default: []].append(
            ResolveKeyHandlerEntry(path: path, order: order, handler: handler)
        )
    }

    func register(_ handler: TapGestureHandler, at path: [Int]) {
        defaultGestureHandlersByPath[path, default: []].append(.tap(handler))
    }

    func register(_ handler: PointerPressHandler, at path: [Int]) {
        pointerPressHandlersByPath[path, default: []].append(handler)
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
        perform: ([Int], () -> InputEventResult) -> InputEventResult
    ) -> InputEventResult {
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
        perform: ([Int], () -> InputEventResult) -> InputEventResult
    ) -> InputEventResult {
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

    /// Resolves one key along the focused branch, or along one selected
    /// deepest rendered branch when no view has focus.
    func resolve(
        _ key: KeyEquivalent,
        toward focusedPath: [Int]?,
        perform: ([Int], () -> ResolveKeyAction.Result) -> ResolveKeyAction.Result
    ) -> ResolveKeyAction.Result {
        guard let entries = resolveKeyHandlers[key], !entries.isEmpty else {
            return .ignored
        }

        let anchorPath: [Int]
        if let focusedPath {
            anchorPath = focusedPath
        } else {
            guard let entry = entries.max(by: resolveKeyAnchorPrecedes) else {
                return .ignored
            }
            anchorPath = entry.path
        }

        let candidates = entries
            .filter {
                anchorPath.starts(with: $0.path)
            }
            .sorted(by: resolveKeyHandlerPrecedes)

        for entry in candidates {
            let actionPath = entry.handler.actionPath ?? entry.path
            if perform(actionPath, { entry.handler.action(key) }) == .handled {
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

    /// Orders candidates so `max(by:)` selects the deepest path and then the
    /// first registration among paths at the same depth.
    private func resolveKeyAnchorPrecedes(
        _ lhs: ResolveKeyHandlerEntry,
        _ rhs: ResolveKeyHandlerEntry
    ) -> Bool {
        if lhs.path.count != rhs.path.count {
            return lhs.path.count < rhs.path.count
        }

        return lhs.order > rhs.order
    }

    private func resolveKeyHandlerPrecedes(
        _ lhs: ResolveKeyHandlerEntry,
        _ rhs: ResolveKeyHandlerEntry
    ) -> Bool {
        if lhs.path.count != rhs.path.count {
            return lhs.path.count > rhs.path.count
        }

        return lhs.order > rhs.order
    }

    private func dispatch(
        _ keyPress: KeyPress,
        at path: [Int],
        perform: ([Int], () -> InputEventResult) -> InputEventResult
    ) -> InputEventResult {
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
    ) -> InputEventResult {
        hasRecognizedTap = false
        _ = dispatchExpiredTapActions(at: date, perform: perform)
        _ = dispatchExpiredLongPressActions(at: date, perform: perform)

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
            if case .recognized = tapOutcome {
                hasRecognizedTap = true
            }
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
        includesHover: Bool = true,
        perform: ([Int], () -> Void) -> Void
    ) -> InputEventResult {
        _ = dispatchExpiredTapActions(at: date, perform: perform)
        _ = dispatchExpiredLongPressActions(at: date, perform: perform)

        let hoverResult = includesHover
            ? dispatchHoverMotion(pointerMotion, perform: perform)
            : .ignored
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

    func reconcileHover(
        _ pointerMotion: PointerMotion,
        perform: ([Int], () -> Void) -> Void
    ) {
        _ = dispatchHoverMotion(pointerMotion, perform: perform)
    }

    func dispatch(
        _ pointerScroll: PointerScroll,
        at date: Date,
        perform: ([Int], () -> Void) -> Void,
        scroll: ([Int], PointerScroll) -> InputEventResult
    ) -> InputEventResult {
        _ = dispatchExpiredTapActions(at: date, perform: perform)
        _ = dispatchExpiredLongPressActions(at: date, perform: perform)
        let cancelled = cancelLongPress(perform: perform)
        activePointerDownPositionTarget = nil
        pressedDefaultGestureTarget = nil
        pressedLinkTarget = nil
        let result = dispatchScroll(pointerScroll, scroll: scroll)
        return result == .handled || cancelled ? .handled : .ignored
    }

    func dispatchExpiredLongPressActions(
        at date: Date,
        perform: ([Int], () -> Void) -> Void
    ) -> InputEventResult {
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
    ) -> InputEventResult {
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
    ) -> InputEventResult {
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
    ) -> InputEventResult {
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
    ) -> InputEventResult {
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
                var result = InputEventResult.ignored
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
            location: point,
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
        scroll: ([Int], PointerScroll) -> InputEventResult
    ) -> InputEventResult {
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
            tapSequence = TapSequence(
                path: target.path,
                configuration: target.configuration
            )
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
    ) -> InputEventResult {
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
            registered -> (path: [Int], handler: TapGestureHandler)? in

            guard case .tap(let handler) = registered.handler,
                  handler.count == count else {
                return nil
            }
            return (registered.path, handler)
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

    var configuration: DefaultGestureHandlerConfiguration {
        switch self {
        case .tap(let handler):
            let coordinateSpace: CoordinateSpace?
            switch handler.action {
            case .plain:
                coordinateSpace = nil
            case .location(let space, _):
                coordinateSpace = space
            }
            return .tap(count: handler.count, coordinateSpace: coordinateSpace)
        case .longPress(let handler):
            return .longPress(
                minimumDuration: handler.minimumDuration.bitPattern,
                maximumDistance: handler.maximumDistance
            )
        }
    }
}

private enum DefaultGestureHandlerConfiguration: Equatable {

    case tap(count: Int, coordinateSpace: CoordinateSpace?)

    case longPress(minimumDuration: UInt64, maximumDistance: Size)
}

private struct RegisteredDefaultGestureHandler {

    let path: [Int]

    let handler: DefaultGestureHandler

    var configuration: RegisteredDefaultGestureConfiguration {
        RegisteredDefaultGestureConfiguration(
            path: path,
            handler: handler.configuration
        )
    }
}

private struct RegisteredDefaultGestureConfiguration: Equatable {

    var path: [Int]

    var handler: DefaultGestureHandlerConfiguration
}

private struct DefaultGesturePressTarget {

    let path: [Int]

    let frame: RenderedRect

    let location: Point

    let handlers: [RegisteredDefaultGestureHandler]

    var configuration: [RegisteredDefaultGestureConfiguration] {
        handlers.map(\.configuration)
    }
}

private enum TapDispatchOutcome {

    case ignored

    case pending

    case recognized(order: Int, path: [Int], handler: TapGestureHandler)

    var result: InputEventResult {
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

    var configuration: [RegisteredDefaultGestureConfiguration]

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
