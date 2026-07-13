import Foundation
import Terminal

/// Stores a value constructor that is invoked only on the recognition actor.
///
/// The closure never crosses an actor boundary. The unchecked conformance
/// prevents Swift's metatype-capture diagnostic from treating generic value
/// constructors retained by an actor-isolated node factory as transferred
/// work.
nonisolated private struct BinaryRecognitionValueFactory<First, Second, Value>:
    @unchecked Sendable
{

    let makeValue: (First, Second) -> Value
}

nonisolated private func simultaneousInputValueFactory<First: InputEvent, Second: InputEvent>()
    -> BinaryRecognitionValueFactory<
        First.Value?,
        Second.Value?,
        SimultaneousInputEvent<First, Second>.Value
    >
{
    BinaryRecognitionValueFactory {
        SimultaneousInputEvent<First, Second>.Value(first: $0, second: $1)
    }
}

nonisolated private func sequenceInputValueFactory<First: InputEvent, Second: InputEvent>()
    -> BinaryRecognitionValueFactory<
        First.Value,
        Second.Value,
        SequenceInputEvent<First, Second>.Value
    >
{
    BinaryRecognitionValueFactory {
        SequenceInputEvent<First, Second>.Value(first: $0, second: $1)
    }
}

nonisolated private func simultaneousGestureValueFactory<First: Gesture, Second: Gesture>()
    -> BinaryRecognitionValueFactory<
        First.Value?,
        Second.Value?,
        SimultaneousGesture<First, Second>.Value
    >
{
    BinaryRecognitionValueFactory {
        SimultaneousGesture<First, Second>.Value(first: $0, second: $1)
    }
}

/// A lowered input-event graph used by SwiftTUI's attachment runtime.
///
/// This implementation type is intentionally opaque. Library clients define
/// custom ``InputEvent`` values through `body`; SwiftTUI creates definitions
/// while rendering an attachment.
@_documentation(visibility: internal)
public struct _InputEventDefinition<Value> {

    let configuration: InputRecognitionConfiguration

    let families: InputFamilies

    let stage: InputEventStage

    let makeNode: () -> InputRecognitionNode<Value>

    init(
        configuration: InputRecognitionConfiguration,
        families: InputFamilies,
        stage: InputEventStage = .immediate,
        makeNode: @escaping () -> InputRecognitionNode<Value>
    ) {
        self.configuration = configuration
        self.families = families
        self.stage = stage
        self.makeNode = makeNode
    }

    func deferred(to stage: InputEventStage) -> Self {
        Self(
            configuration: .wrapper("deferred:\(stage.rawValue)", configuration),
            families: families,
            stage: stage,
            makeNode: makeNode
        )
    }
}

/// A lowered gesture graph used by SwiftTUI's attachment runtime.
///
/// This implementation type is intentionally opaque. Library clients define
/// custom ``Gesture`` values through `body`; SwiftTUI creates definitions while
/// rendering an attachment.
@_documentation(visibility: internal)
public struct _GestureDefinition<Value> {

    let configuration: GestureRecognitionConfiguration

    let makeNode: () -> GestureRecognitionNode<Value>

    init(
        configuration: GestureRecognitionConfiguration,
        makeNode: @escaping () -> GestureRecognitionNode<Value>
    ) {
        self.configuration = configuration
        self.makeNode = makeNode
    }
}

struct InputRecognitionConfiguration: Hashable {

    var name: String

    var values: [AnyHashable]

    var children: [InputRecognitionConfiguration]

    init(
        _ name: String,
        values: [AnyHashable] = [],
        children: [InputRecognitionConfiguration] = []
    ) {
        self.name = name
        self.values = values
        self.children = children
    }

    static func wrapper(
        _ name: String,
        _ child: InputRecognitionConfiguration
    ) -> Self {
        Self(name, children: [child])
    }
}

struct GestureRecognitionConfiguration: Hashable {

    var name: String

    var values: [AnyHashable]

    var children: [GestureRecognitionConfiguration]

    init(
        _ name: String,
        values: [AnyHashable] = [],
        children: [GestureRecognitionConfiguration] = []
    ) {
        self.name = name
        self.values = values
        self.children = children
    }

    static func wrapper(
        _ name: String,
        _ child: GestureRecognitionConfiguration
    ) -> Self {
        Self(name, children: [child])
    }
}

struct InputFamilies: OptionSet {

    let rawValue: Int

    static let key = Self(rawValue: 1 << 0)

    static let pointerPress = Self(rawValue: 1 << 1)

    static let pointerMotion = Self(rawValue: 1 << 2)

    static let pointerScroll = Self(rawValue: 1 << 3)

    static let pointer: Self = [.pointerPress, .pointerMotion, .pointerScroll]
}

enum InputEventStage: Int, CaseIterable {

    case immediate

    case eager

    case lazy
}

enum RecognitionSample {

    case keyPress(KeyPress)

    case pointerPress(PointerPress)

    case pointerMotion(PointerMotion)

    case pointerScroll(PointerScroll)

    var families: InputFamilies {
        switch self {
        case .keyPress:
            .key
        case .pointerPress:
            .pointerPress
        case .pointerMotion:
            .pointerMotion
        case .pointerScroll:
            .pointerScroll
        }
    }

    var rootLocation: Point? {
        switch self {
        case .keyPress:
            nil
        case .pointerPress(let value):
            value.location
        case .pointerMotion(let value):
            value.location
        case .pointerScroll(let value):
            value.location
        }
    }
}

/// Converts raw global pointer locations for one InputEvent dispatch and
/// records when an active recognition loses a named coordinate space.
final class InputRecognitionContext {

    let convert: (Point, CoordinateSpace) -> Point?

    let isContinuingRecognition: Bool

    private(set) var didLoseCoordinateSpace = false

    init(
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        isContinuingRecognition: Bool
    ) {
        self.convert = convert
        self.isContinuingRecognition = isContinuingRecognition
    }

    func location(_ point: Point, in coordinateSpace: CoordinateSpace) -> Point? {
        if let converted = convert(point, coordinateSpace) {
            return converted
        }
        guard isContinuingRecognition else {
            preconditionFailure("The requested named coordinate space is not rendered.")
        }
        didLoseCoordinateSpace = true
        return nil
    }
}

enum RecognitionCompletion<Value> {

    case none

    case value(Value)
}

struct InputRecognitionOutput<Value> {

    var matched: Bool

    var completion: RecognitionCompletion<Value>

    var result: InputEventResult

    var beginsCapture: Bool

    var endsCapture: Bool

    static var noMatch: Self {
        Self(
            matched: false,
            completion: .none,
            result: .ignored,
            beginsCapture: false,
            endsCapture: false
        )
    }

    static func recognized(
        _ value: Value,
        result: InputEventResult = .ignored,
        beginsCapture: Bool = false,
        endsCapture: Bool = false
    ) -> Self {
        Self(
            matched: true,
            completion: .value(value),
            result: result,
            beginsCapture: beginsCapture,
            endsCapture: endsCapture
        )
    }

    static func progress(
        result: InputEventResult = .ignored,
        beginsCapture: Bool = false,
        endsCapture: Bool = false
    ) -> Self {
        Self(
            matched: true,
            completion: .none,
            result: result,
            beginsCapture: beginsCapture,
            endsCapture: endsCapture
        )
    }
}

enum RecognitionCancellationReason {

    case disabled

    case masked

    case removed

    case identityChanged

    case focusLost

    case superseded

    case sceneInactive

    case consumed

    case coordinateSpaceRemoved

    case sessionEnded
}

@MainActor
class InputRecognitionNode<Value> {

    init() {}

    var isActive: Bool { false }

    var acceptsNewPointerDownWhileActive: Bool { false }

    func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Value> {
        .noMatch
    }

    func cancel(_ reason: RecognitionCancellationReason) {}

    func restoreState(from old: InputRecognitionNode<Value>) {}
}

final class NeverInputRecognitionNode: InputRecognitionNode<Never> {}

final class MatcherInputRecognitionNode<Value>: InputRecognitionNode<Value> {

    let match: (RecognitionSample, InputRecognitionContext) -> Value?

    init(match: @escaping (RecognitionSample, InputRecognitionContext) -> Value?) {
        self.match = match
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Value> {
        guard let value = match(sample, context) else {
            return .noMatch
        }
        return .recognized(value)
    }
}

final class RecognizedInputRecognitionNode<Value>: InputRecognitionNode<Value> {

    let base: InputRecognitionNode<Value>

    let action: (Value) -> InputEventResult

    init(
        base: InputRecognitionNode<Value>,
        action: @escaping (Value) -> InputEventResult
    ) {
        self.base = base
        self.action = action
    }

    override var isActive: Bool { base.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        base.acceptsNewPointerDownWhileActive
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Value> {
        var output = base.process(sample, context: context)
        guard case .value(let value) = output.completion else {
            return output
        }

        if action(value) == .handled {
            output.result = .handled
        }
        return output
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        base.cancel(reason)
    }

    override func restoreState(from old: InputRecognitionNode<Value>) {
        guard let old = old as? RecognizedInputRecognitionNode<Value> else {
            return
        }
        base.restoreState(from: old.base)
    }
}

final class ExclusiveInputRecognitionNode<First, Second, Value>:
    InputRecognitionNode<Value>
{

    let first: InputRecognitionNode<First>

    let second: InputRecognitionNode<Second>

    let firstValue: (First) -> Value

    let secondValue: (Second) -> Value

    init(
        first: InputRecognitionNode<First>,
        second: InputRecognitionNode<Second>,
        firstValue: @escaping (First) -> Value,
        secondValue: @escaping (Second) -> Value
    ) {
        self.first = first
        self.second = second
        self.firstValue = firstValue
        self.secondValue = secondValue
        super.init()
    }

    override var isActive: Bool { first.isActive || second.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        first.acceptsNewPointerDownWhileActive
            || second.acceptsNewPointerDownWhileActive
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Value> {
        let firstOutput = first.process(sample, context: context)
        if firstOutput.matched {
            switch firstOutput.completion {
            case .none:
                return .progress(
                    result: firstOutput.result,
                    beginsCapture: firstOutput.beginsCapture,
                    endsCapture: firstOutput.endsCapture
                )
            case .value(let value):
                return .recognized(
                    firstValue(value),
                    result: firstOutput.result,
                    beginsCapture: firstOutput.beginsCapture,
                    endsCapture: firstOutput.endsCapture
                )
            }
        }

        let secondOutput = second.process(sample, context: context)
        switch secondOutput.completion {
        case .none:
            return secondOutput.matched
                ? .progress(
                    result: secondOutput.result,
                    beginsCapture: secondOutput.beginsCapture,
                    endsCapture: secondOutput.endsCapture
                )
                : .noMatch
        case .value(let value):
            return .recognized(
                secondValue(value),
                result: secondOutput.result,
                beginsCapture: secondOutput.beginsCapture,
                endsCapture: secondOutput.endsCapture
            )
        }
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        first.cancel(reason)
        second.cancel(reason)
    }

    override func restoreState(from old: InputRecognitionNode<Value>) {
        guard let old = old as? ExclusiveInputRecognitionNode<First, Second, Value> else {
            return
        }
        first.restoreState(from: old.first)
        second.restoreState(from: old.second)
    }
}

final class SimultaneousInputRecognitionNode<First, Second, Value>:
    InputRecognitionNode<Value>
{

    let first: InputRecognitionNode<First>

    let second: InputRecognitionNode<Second>

    let makeValue: (First?, Second?) -> Value

    init(
        first: InputRecognitionNode<First>,
        second: InputRecognitionNode<Second>,
        makeValue: @escaping (First?, Second?) -> Value
    ) {
        self.first = first
        self.second = second
        self.makeValue = makeValue
        super.init()
    }

    override var isActive: Bool { first.isActive || second.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        (!first.isActive || first.acceptsNewPointerDownWhileActive)
            && (!second.isActive || second.acceptsNewPointerDownWhileActive)
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Value> {
        let firstOutput = first.process(sample, context: context)
        let secondOutput = second.process(sample, context: context)
        guard firstOutput.matched || secondOutput.matched else {
            return .noMatch
        }

        let result: InputEventResult = firstOutput.result == .handled
            || secondOutput.result == .handled ? .handled : .ignored
        let beginsCapture = firstOutput.beginsCapture || secondOutput.beginsCapture
        let endsCapture = firstOutput.endsCapture || secondOutput.endsCapture
        let firstValue: First?
        let secondValue: Second?
        if case .value(let value) = firstOutput.completion {
            firstValue = value
        } else {
            firstValue = nil
        }
        if case .value(let value) = secondOutput.completion {
            secondValue = value
        } else {
            secondValue = nil
        }

        guard firstValue != nil || secondValue != nil else {
            return .progress(
                result: result,
                beginsCapture: beginsCapture,
                endsCapture: endsCapture
            )
        }
        return .recognized(
            makeValue(firstValue, secondValue),
            result: result,
            beginsCapture: beginsCapture,
            endsCapture: endsCapture
        )
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        first.cancel(reason)
        second.cancel(reason)
    }

    override func restoreState(from old: InputRecognitionNode<Value>) {
        guard let old = old as? SimultaneousInputRecognitionNode<First, Second, Value> else {
            return
        }
        first.restoreState(from: old.first)
        second.restoreState(from: old.second)
    }
}

final class SequenceInputRecognitionNode<First, Second, Value>:
    InputRecognitionNode<Value>
{

    let first: InputRecognitionNode<First>

    let second: InputRecognitionNode<Second>

    var firstValue: First?

    let makeValue: (First, Second) -> Value

    init(
        first: InputRecognitionNode<First>,
        second: InputRecognitionNode<Second>,
        makeValue: @escaping (First, Second) -> Value
    ) {
        self.first = first
        self.second = second
        self.makeValue = makeValue
        super.init()
    }

    override var isActive: Bool {
        firstValue != nil || first.isActive || second.isActive
    }

    override var acceptsNewPointerDownWhileActive: Bool {
        firstValue != nil || first.acceptsNewPointerDownWhileActive
    }

    override func process(
        _ sample: RecognitionSample,
        context: InputRecognitionContext
    ) -> InputRecognitionOutput<Value> {
        if let firstValue {
            let output = second.process(sample, context: context)
            guard output.matched else {
                return .noMatch
            }
            guard case .value(let secondValue) = output.completion else {
                return .progress(
                    result: output.result,
                    beginsCapture: output.beginsCapture,
                    endsCapture: output.endsCapture
                )
            }
            self.firstValue = nil
            return .recognized(
                makeValue(firstValue, secondValue),
                result: output.result,
                beginsCapture: output.beginsCapture,
                endsCapture: output.endsCapture
            )
        }

        let output = first.process(sample, context: context)
        guard output.matched else {
            return .noMatch
        }
        guard case .value(let value) = output.completion else {
            return .progress(
                result: output.result,
                beginsCapture: output.beginsCapture,
                endsCapture: output.endsCapture
            )
        }
        firstValue = value
        return .progress(
            result: output.result,
            beginsCapture: output.beginsCapture,
            endsCapture: output.endsCapture
        )
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        firstValue = nil
        first.cancel(reason)
        second.cancel(reason)
    }

    override func restoreState(from old: InputRecognitionNode<Value>) {
        guard let old = old as? SequenceInputRecognitionNode<First, Second, Value> else {
            return
        }
        firstValue = old.firstValue
        first.restoreState(from: old.first)
        second.restoreState(from: old.second)
    }
}

enum BodyExpansionContext {

    @TaskLocal static var inputTypes: [ObjectIdentifier] = []

    @TaskLocal static var gestureTypes: [ObjectIdentifier] = []

    static func input<Event: InputEvent, Value>(
        _ event: Event,
        make: () -> _InputEventDefinition<Value>
    ) -> _InputEventDefinition<Value> {
        let type = ObjectIdentifier(Event.self)
        precondition(
            !inputTypes.contains(type),
            "Recursive InputEvent.body expansion for \(Event.self)."
        )
        return $inputTypes.withValue(inputTypes + [type], operation: make)
    }

    static func gesture<Event: Gesture, Value>(
        _ gesture: Event,
        make: () -> _GestureDefinition<Value>
    ) -> _GestureDefinition<Value> {
        let type = ObjectIdentifier(Event.self)
        precondition(
            !gestureTypes.contains(type),
            "Recursive Gesture.body expansion for \(Event.self)."
        )
        return $gestureTypes.withValue(gestureTypes + [type], operation: make)
    }
}

extension InputEvent where Value == Body.Value {

    /// Recursively lowers a custom event body into an opaque recognition definition.
    ///
    /// SwiftTUI calls this implementation hook while registering an attachment.
    public func _makeInputEvent() -> _InputEventDefinition<Value> {
        BodyExpansionContext.input(self) {
            let definition = body._makeInputEvent()
            return _InputEventDefinition(
                configuration: .wrapper(
                    "body:\(String(reflecting: Self.self))",
                    definition.configuration
                ),
                families: definition.families,
                stage: definition.stage,
                makeNode: definition.makeNode
            )
        }
    }
}

/// Supplies the terminal recognition definition for an uninhabited input event.
extension Never {

    /// Builds the empty recognition definition for the uninhabited input event.
    ///
    /// SwiftTUI uses this implementation hook as the terminal body of primitive
    /// event declarations and never evaluates it for an input sample.
    public func _makeInputEvent() -> _InputEventDefinition<Never> {
        _InputEventDefinition(
            configuration: InputRecognitionConfiguration("never"),
            families: [],
            makeNode: NeverInputRecognitionNode.init
        )
    }
}

extension KeyPressEvent {

    /// Builds a recognition definition for the configured key filter and phases.
    ///
    /// SwiftTUI calls this implementation hook while registering an attachment.
    public func _makeInputEvent() -> _InputEventDefinition<KeyPress> {
        let filterValue: AnyHashable
        switch filter {
        case .any:
            filterValue = "any"
        case .keys(let keys):
            filterValue = keys
        case .characters(let characters):
            filterValue = characters.bitmapRepresentation
        }
        return _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "keyPress",
                values: [filterValue, phases.rawValue]
            ),
            families: .key,
            makeNode: {
                MatcherInputRecognitionNode { sample, _ in
                    guard case .keyPress(let press) = sample,
                          matches(press) else {
                        return nil
                    }
                    return press
                }
            }
        )
    }
}

extension PointerPressEvent {

    /// Builds a recognition definition for the configured pointer press matcher.
    ///
    /// Recognized locations are converted into the event's coordinate space
    /// before the definition emits a value.
    public func _makeInputEvent() -> _InputEventDefinition<PointerPress> {
        _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "pointerPress",
                values: [buttons, phases.rawValue, coordinateSpace]
            ),
            families: .pointerPress,
            makeNode: {
                MatcherInputRecognitionNode { sample, context in
                    guard case .pointerPress(let press) = sample,
                          matches(press) else {
                        return nil
                    }
                    guard let location = context.location(
                        press.location,
                        in: coordinateSpace
                    ) else {
                        return nil
                    }
                    return PointerPress(
                        button: press.button,
                        location: location,
                        modifiers: press.modifiers,
                        phase: press.phase
                    )
                }
            }
        )
    }
}

extension PointerMotionEvent {

    /// Builds a recognition definition for the configured pointer motion matcher.
    ///
    /// Recognized locations are converted into the event's coordinate space
    /// before the definition emits a value.
    public func _makeInputEvent() -> _InputEventDefinition<PointerMotion> {
        let filterValue: AnyHashable
        switch filter {
        case .any:
            filterValue = "any"
        case .buttonless:
            filterValue = "buttonless"
        case .pressed:
            filterValue = "pressed"
        case .buttons(let buttons):
            filterValue = buttons
        }
        return _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "pointerMotion",
                values: [filterValue, coordinateSpace]
            ),
            families: .pointerMotion,
            makeNode: {
                MatcherInputRecognitionNode { sample, context in
                    guard case .pointerMotion(let motion) = sample,
                          matches(motion) else {
                        return nil
                    }
                    guard let location = context.location(
                        motion.location,
                        in: coordinateSpace
                    ) else {
                        return nil
                    }
                    return PointerMotion(
                        button: motion.button,
                        location: location,
                        modifiers: motion.modifiers
                    )
                }
            }
        )
    }
}

extension PointerScrollEvent {

    /// Builds a recognition definition for the configured pointer scroll axes.
    ///
    /// Recognized locations are converted into the event's coordinate space
    /// before the definition emits a value.
    public func _makeInputEvent() -> _InputEventDefinition<PointerScroll> {
        _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "pointerScroll",
                values: [axes.rawValue, coordinateSpace]
            ),
            families: .pointerScroll,
            makeNode: {
                MatcherInputRecognitionNode { sample, context in
                    guard case .pointerScroll(let scroll) = sample,
                          matches(scroll) else {
                        return nil
                    }
                    guard let location = context.location(
                        scroll.location,
                        in: coordinateSpace
                    ) else {
                        return nil
                    }
                    return PointerScroll(
                        delta: scroll.delta,
                        location: location,
                        modifiers: scroll.modifiers
                    )
                }
            }
        )
    }
}

extension RecognizedInputEvent {

    /// Builds a recognition definition that invokes this event's action.
    ///
    /// The wrapper preserves the base event's input families and deferred stage.
    public func _makeInputEvent() -> _InputEventDefinition<Value> {
        let definition = base._makeInputEvent()
        return _InputEventDefinition(
            configuration: .wrapper("recognized", definition.configuration),
            families: definition.families,
            stage: definition.stage,
            makeNode: {
                RecognizedInputRecognitionNode(
                    base: definition.makeNode(),
                    action: action
                )
            }
        )
    }
}

extension DeferredInputEvent {

    /// Builds a recognition definition at this event's deferred execution stage.
    ///
    /// The outer deferred wrapper determines the stage of the complete base graph.
    public func _makeInputEvent() -> _InputEventDefinition<Value> {
        base._makeInputEvent().deferred(
            to: priority == .eager ? .eager : .lazy
        )
    }
}

extension ExclusiveInputEvent {

    /// Builds a recognition definition that gives the first event precedence.
    ///
    /// The second definition remains a fallback only when the first doesn't match.
    public func _makeInputEvent() -> _InputEventDefinition<Value> {
        let firstDefinition = first._makeInputEvent()
        let secondDefinition = second._makeInputEvent()
        return _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "exclusive",
                children: [
                    firstDefinition.configuration,
                    secondDefinition.configuration,
                ]
            ),
            families: firstDefinition.families.union(secondDefinition.families),
            stage: max(firstDefinition.stage, secondDefinition.stage),
            makeNode: {
                ExclusiveInputRecognitionNode(
                    first: firstDefinition.makeNode(),
                    second: secondDefinition.makeNode(),
                    firstValue: Value.first,
                    secondValue: Value.second
                )
            }
        )
    }
}

extension SimultaneousInputEvent {

    /// Builds a recognition definition that offers each sample to both events.
    ///
    /// The definition preserves both child callbacks before aggregating handling.
    public func _makeInputEvent() -> _InputEventDefinition<Value> {
        let firstDefinition = first._makeInputEvent()
        let secondDefinition = second._makeInputEvent()
        let valueFactory: BinaryRecognitionValueFactory<
            First.Value?, Second.Value?, Value
        > = simultaneousInputValueFactory()
        return _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "simultaneous",
                children: [
                    firstDefinition.configuration,
                    secondDefinition.configuration,
                ]
            ),
            families: firstDefinition.families.union(secondDefinition.families),
            stage: max(firstDefinition.stage, secondDefinition.stage),
            makeNode: {
                SimultaneousInputRecognitionNode(
                    first: firstDefinition.makeNode(),
                    second: secondDefinition.makeNode(),
                    makeValue: valueFactory.makeValue
                )
            }
        )
    }
}

extension SequenceInputEvent {

    /// Builds a stateful recognition definition that runs both events in order.
    ///
    /// The definition retains the first value until the second event completes
    /// or the attachment is cancelled.
    public func _makeInputEvent() -> _InputEventDefinition<Value> {
        let firstDefinition = first._makeInputEvent()
        let secondDefinition = second._makeInputEvent()
        let valueFactory: BinaryRecognitionValueFactory<
            First.Value, Second.Value, Value
        > = sequenceInputValueFactory()
        return _InputEventDefinition(
            configuration: InputRecognitionConfiguration(
                "sequence",
                children: [
                    firstDefinition.configuration,
                    secondDefinition.configuration,
                ]
            ),
            families: firstDefinition.families.union(secondDefinition.families),
            stage: max(firstDefinition.stage, secondDefinition.stage),
            makeNode: {
                SequenceInputRecognitionNode(
                    first: firstDefinition.makeNode(),
                    second: secondDefinition.makeNode(),
                    makeValue: valueFactory.makeValue
                )
            }
        )
    }
}

extension InputEventStage: Comparable {

    static func < (lhs: InputEventStage, rhs: InputEventStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

@MainActor
class GestureRecognitionNode<Value> {

    init() {}

    var isActive: Bool { false }

    var acceptsNewPointerDownWhileActive: Bool { false }

    var nextDeadline: Date? { nil }

    func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        .noMatch
    }

    func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        .noMatch
    }

    func cancel(_ reason: RecognitionCancellationReason) {}

    func restoreState(from old: GestureRecognitionNode<Value>) {}
}

enum GestureRecognitionPhase<Value> {

    case none

    case changed(Value)

    case ended(Value)

    case failed
}

struct GestureRecognitionOutput<Value> {

    var participated: Bool

    var phase: GestureRecognitionPhase<Value>

    /// Whether this transition establishes the node as the winner of its
    /// attachment lane. A changed value alone isn't sufficient because a
    /// long-press publishes its active state before recognition succeeds.
    var claimsCompetition: Bool

    var beginsCapture: Bool

    var endsCapture: Bool

    static var noMatch: Self {
        Self(
            participated: false,
            phase: .none,
            claimsCompetition: false,
            beginsCapture: false,
            endsCapture: false
        )
    }

    static func progress(
        claimsCompetition: Bool = false,
        captures: Bool = false
    ) -> Self {
        Self(
            participated: true,
            phase: .none,
            claimsCompetition: claimsCompetition,
            beginsCapture: captures,
            endsCapture: false
        )
    }

    static func changed(
        _ value: Value,
        claimsCompetition: Bool = false,
        captures: Bool = false
    ) -> Self {
        Self(
            participated: true,
            phase: .changed(value),
            claimsCompetition: claimsCompetition,
            beginsCapture: captures,
            endsCapture: false
        )
    }

    static func ended(_ value: Value, releasesCapture: Bool = false) -> Self {
        Self(
            participated: true,
            phase: .ended(value),
            claimsCompetition: true,
            beginsCapture: false,
            endsCapture: releasesCapture
        )
    }

    static func failed(releasesCapture: Bool = false) -> Self {
        Self(
            participated: true,
            phase: .failed,
            claimsCompetition: false,
            beginsCapture: false,
            endsCapture: releasesCapture
        )
    }
}

@MainActor
final class GestureRecognitionContext {

    let date: Date

    let isTargeted: Bool

    let convert: (Point, CoordinateSpace) -> Point?

    let invalidate: () -> Void

    private var changedActions: [() -> Void] = []

    private var endedActions: [() -> Void] = []

    private var resetActions: [() -> Void] = []

    init(
        date: Date,
        isTargeted: Bool,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) {
        self.date = date
        self.isTargeted = isTargeted
        self.convert = convert
        self.invalidate = invalidate
    }

    func location(
        _ point: Point,
        in coordinateSpace: CoordinateSpace,
        active: Bool
    ) -> Point? {
        if let location = convert(point, coordinateSpace) {
            return location
        }
        if active {
            return nil
        }
        preconditionFailure("The requested named coordinate space is not rendered.")
    }

    func appendChanged(_ action: @escaping () -> Void) {
        changedActions.append(action)
    }

    func appendEnded(_ action: @escaping () -> Void) {
        endedActions.append(action)
    }

    func appendReset(_ action: @escaping () -> Void) {
        resetActions.append(action)
    }

    func flush() {
        changedActions.forEach { $0() }
        endedActions.forEach { $0() }
        resetActions.forEach { $0() }
        changedActions = []
        endedActions = []
        resetActions = []
    }
}

final class NeverGestureRecognitionNode: GestureRecognitionNode<Never> {}

final class TapGestureRecognitionNode<Value>: GestureRecognitionNode<Value> {

    let count: Int

    let coordinateSpace: CoordinateSpace?

    let makeValue: (Point) -> Value

    var isPressed = false

    var recognizedCount = 0

    var lastLocation: Point?

    var deadline: Date?

    init(
        count: Int,
        coordinateSpace: CoordinateSpace?,
        makeValue: @escaping (Point) -> Value
    ) {
        self.count = count
        self.coordinateSpace = coordinateSpace
        self.makeValue = makeValue
        super.init()
    }

    override var isActive: Bool {
        isPressed || recognizedCount > 0
    }

    override var nextDeadline: Date? { deadline }

    override var acceptsNewPointerDownWhileActive: Bool {
        recognizedCount > 0 && !isPressed
    }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        guard case .pointerPress(let press) = sample,
              press.button == .left else {
            return .noMatch
        }

        if press.phase == .down {
            if let coordinateSpace {
                _ = context.location(
                    press.location,
                    in: coordinateSpace,
                    active: false
                )
            }
            isPressed = true
            lastLocation = press.location
            return .progress()
        }

        guard press.phase == .up, isPressed else {
            return .noMatch
        }
        isPressed = false
        lastLocation = press.location
        guard context.isTargeted else {
            recognizedCount = 0
            deadline = nil
            return .failed()
        }
        recognizedCount += 1
        if recognizedCount < count {
            deadline = context.date.addingTimeInterval(0.5)
            return .progress()
        }

        recognizedCount = 0
        deadline = nil
        guard let location = convertedLocation(press.location, context: context) else {
            return .failed()
        }
        return .ended(makeValue(location))
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        guard let deadline, date >= deadline else {
            return .noMatch
        }
        self.deadline = nil
        recognizedCount = 0
        return .failed()
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        isPressed = false
        recognizedCount = 0
        lastLocation = nil
        deadline = nil
    }

    override func restoreState(from old: GestureRecognitionNode<Value>) {
        guard let old = old as? TapGestureRecognitionNode<Value> else {
            return
        }
        isPressed = old.isPressed
        recognizedCount = old.recognizedCount
        lastLocation = old.lastLocation
        deadline = old.deadline
    }

    private func convertedLocation(
        _ point: Point,
        context: GestureRecognitionContext
    ) -> Point? {
        guard let coordinateSpace else {
            return point
        }
        return context.location(point, in: coordinateSpace, active: true)
    }
}

final class LongPressGestureRecognitionNode: GestureRecognitionNode<Bool> {

    let minimumDuration: Double

    let maximumDistance: Size

    var startLocation: Point?

    var deadline: Date?

    var didRecognize = false

    init(minimumDuration: Double, maximumDistance: Size) {
        self.minimumDuration = minimumDuration
        self.maximumDistance = maximumDistance
        super.init()
    }

    override var isActive: Bool { startLocation != nil }

    override var nextDeadline: Date? { didRecognize ? nil : deadline }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Bool> {
        switch sample {
        case .pointerPress(let press) where press.button == .left && press.phase == .down:
            startLocation = press.location
            deadline = context.date.addingTimeInterval(minimumDuration)
            didRecognize = false
            return .changed(true)
        case .pointerMotion(let motion) where motion.button == .left:
            guard let startLocation else {
                return .noMatch
            }
            let distance = Size(
                columns: abs(motion.location.column - startLocation.column),
                rows: abs(motion.location.row - startLocation.row)
            )
            guard distance.columns <= maximumDistance.columns,
                  distance.rows <= maximumDistance.rows else {
                reset()
                return .failed()
            }
            return .progress()
        case .pointerPress(let press) where press.button == .left && press.phase == .up:
            guard startLocation != nil else {
                return .noMatch
            }
            if didRecognize {
                reset()
                return .progress()
            }
            reset()
            return .failed()
        default:
            return .noMatch
        }
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Bool> {
        guard startLocation != nil,
              !didRecognize,
              let deadline,
              date >= deadline else {
            return .noMatch
        }
        didRecognize = true
        self.deadline = nil
        return .ended(true)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        reset()
    }

    override func restoreState(from old: GestureRecognitionNode<Bool>) {
        guard let old = old as? LongPressGestureRecognitionNode else {
            return
        }
        startLocation = old.startLocation
        deadline = old.deadline
        didRecognize = old.didRecognize
    }

    private func reset() {
        startLocation = nil
        deadline = nil
        didRecognize = false
    }
}

final class DragGestureRecognitionNode: GestureRecognitionNode<DragGesture.Value> {

    struct Sample {

        var date: Date

        var rootLocation: Point

        var convertedLocation: Point
    }

    let gesture: DragGesture

    var start: Sample?

    var previousDistinct: Sample?

    var latest: Sample?

    var didRecognize = false

    var lastVelocity = DragGesture.Value.Velocity.zero

    init(gesture: DragGesture) {
        self.gesture = gesture
        super.init()
    }

    override var isActive: Bool { start != nil }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<DragGesture.Value> {
        switch sample {
        case .pointerPress(let press)
        where press.button == gesture.button && press.phase == .down:
            guard let location = context.location(
                press.location,
                in: gesture.coordinateSpace,
                active: false
            ) else {
                return .failed()
            }
            let current = Sample(
                date: context.date,
                rootLocation: press.location,
                convertedLocation: location
            )
            start = current
            latest = current
            previousDistinct = nil
            lastVelocity = .zero
            didRecognize = gesture.minimumDistance == 0
            return didRecognize
                ? .changed(
                    value(for: current, modifiers: press.modifiers),
                    claimsCompetition: true,
                    captures: true
                )
                : .progress()

        case .pointerMotion(let motion) where motion.button == gesture.button:
            guard let start else {
                return .noMatch
            }
            guard let location = context.location(
                motion.location,
                in: gesture.coordinateSpace,
                active: true
            ) else {
                reset()
                return .failed(releasesCapture: didRecognize)
            }
            let current = Sample(
                date: context.date,
                rootLocation: motion.location,
                convertedLocation: location
            )
            record(current)
            if !didRecognize {
                let distance = max(
                    abs(current.rootLocation.column - start.rootLocation.column),
                    abs(current.rootLocation.row - start.rootLocation.row)
                )
                guard distance >= gesture.minimumDistance else {
                    return .progress()
                }
                didRecognize = true
                return .changed(
                    value(for: current, modifiers: motion.modifiers),
                    claimsCompetition: true,
                    captures: true
                )
            }
            return .changed(value(for: current, modifiers: motion.modifiers))

        case .pointerPress(let press)
        where press.button == gesture.button && press.phase == .up:
            guard start != nil else {
                return .noMatch
            }
            guard didRecognize else {
                reset()
                return .failed()
            }
            let current: Sample
            if let location = context.location(
                press.location,
                in: gesture.coordinateSpace,
                active: true
            ) {
                current = Sample(
                    date: context.date,
                    rootLocation: press.location,
                    convertedLocation: location
                )
                if latest?.rootLocation != current.rootLocation {
                    record(current)
                }
            } else {
                reset()
                return .failed(releasesCapture: true)
            }
            let value = value(for: current, modifiers: press.modifiers)
            reset()
            return .ended(value, releasesCapture: true)

        default:
            return .noMatch
        }
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        reset()
    }

    override func restoreState(from old: GestureRecognitionNode<DragGesture.Value>) {
        guard let old = old as? DragGestureRecognitionNode else {
            return
        }
        start = old.start
        previousDistinct = old.previousDistinct
        latest = old.latest
        didRecognize = old.didRecognize
        lastVelocity = old.lastVelocity
    }

    private func record(_ sample: Sample) {
        guard latest?.rootLocation != sample.rootLocation else {
            latest = sample
            return
        }
        previousDistinct = latest
        latest = sample
        if let previousDistinct,
           sample.date > previousDistinct.date {
            let seconds = sample.date.timeIntervalSince(previousDistinct.date)
            lastVelocity = DragGesture.Value.Velocity(
                columnsPerSecond: Double(
                    sample.convertedLocation.column - previousDistinct.convertedLocation.column
                ) / seconds,
                rowsPerSecond: Double(
                    sample.convertedLocation.row - previousDistinct.convertedLocation.row
                ) / seconds
            )
        }
    }

    private func value(
        for current: Sample,
        modifiers: EventModifiers
    ) -> DragGesture.Value {
        let start = self.start ?? current
        let delta: Size
        if let previousDistinct,
           previousDistinct.rootLocation != current.rootLocation {
            delta = Size(
                columns: current.convertedLocation.column
                    - previousDistinct.convertedLocation.column,
                rows: current.convertedLocation.row
                    - previousDistinct.convertedLocation.row
            )
        } else {
            delta = .zero
        }
        let predicted = Point(
            column: current.convertedLocation.column + delta.columns,
            row: current.convertedLocation.row + delta.rows
        )
        return DragGesture.Value(
            time: current.date,
            location: current.convertedLocation,
            startLocation: start.convertedLocation,
            translation: Size(
                columns: current.convertedLocation.column - start.convertedLocation.column,
                rows: current.convertedLocation.row - start.convertedLocation.row
            ),
            velocity: lastVelocity,
            predictedEndLocation: predicted,
            predictedEndTranslation: Size(
                columns: predicted.column - start.convertedLocation.column,
                rows: predicted.row - start.convertedLocation.row
            ),
            modifiers: modifiers
        )
    }

    private func reset() {
        start = nil
        previousDistinct = nil
        latest = nil
        didRecognize = false
        lastVelocity = .zero
    }
}

final class ChangedGestureRecognitionNode<Value: Equatable>:
    GestureRecognitionNode<Value>
{
    let base: GestureRecognitionNode<Value>

    let action: (Value) -> Void

    var previousValue: Value?

    init(base: GestureRecognitionNode<Value>, action: @escaping (Value) -> Void) {
        self.base = base
        self.action = action
        super.init()
    }

    override var isActive: Bool { base.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        base.acceptsNewPointerDownWhileActive
    }

    override var nextDeadline: Date? { base.nextDeadline }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        observe(base.process(sample, context: context), context: context)
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        observe(base.advance(to: date, context: context), context: context)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        previousValue = nil
        base.cancel(reason)
    }

    override func restoreState(from old: GestureRecognitionNode<Value>) {
        guard let old = old as? ChangedGestureRecognitionNode<Value> else {
            return
        }
        previousValue = old.previousValue
        base.restoreState(from: old.base)
    }

    private func observe(
        _ output: GestureRecognitionOutput<Value>,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        if case .changed(let value) = output.phase,
           previousValue != value {
            previousValue = value
            context.appendChanged { [action] in action(value) }
        }
        switch output.phase {
        case .ended, .failed:
            previousValue = nil
        case .none, .changed:
            break
        }
        return output
    }
}

final class EndedGestureRecognitionNode<Value>: GestureRecognitionNode<Value> {

    let base: GestureRecognitionNode<Value>

    let action: (Value) -> Void

    init(base: GestureRecognitionNode<Value>, action: @escaping (Value) -> Void) {
        self.base = base
        self.action = action
        super.init()
    }

    override var isActive: Bool { base.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        base.acceptsNewPointerDownWhileActive
    }

    override var nextDeadline: Date? { base.nextDeadline }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        observe(base.process(sample, context: context), context: context)
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        observe(base.advance(to: date, context: context), context: context)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        base.cancel(reason)
    }

    override func restoreState(from old: GestureRecognitionNode<Value>) {
        guard let old = old as? EndedGestureRecognitionNode<Value> else {
            return
        }
        base.restoreState(from: old.base)
    }

    private func observe(
        _ output: GestureRecognitionOutput<Value>,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        if case .ended(let value) = output.phase {
            context.appendEnded { [action] in action(value) }
        }
        return output
    }
}

final class GestureStateRecognitionNode<Value, State>: GestureRecognitionNode<Value> {

    let base: GestureRecognitionNode<Value>

    let storage: GestureStateStorage<State>

    let update: (Value, inout State, inout Transaction) -> Void

    var didUpdate = false

    init(
        base: GestureRecognitionNode<Value>,
        storage: GestureStateStorage<State>,
        update: @escaping (Value, inout State, inout Transaction) -> Void
    ) {
        self.base = base
        self.storage = storage
        self.update = update
        super.init()
    }

    override var isActive: Bool { base.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        base.acceptsNewPointerDownWhileActive
    }

    override var nextDeadline: Date? { base.nextDeadline }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        observe(base.process(sample, context: context), context: context)
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        observe(base.advance(to: date, context: context), context: context)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        base.cancel(reason)
        resetIfNeeded()
    }

    override func restoreState(from old: GestureRecognitionNode<Value>) {
        guard let old = old as? GestureStateRecognitionNode<Value, State> else {
            return
        }
        didUpdate = old.didUpdate
        base.restoreState(from: old.base)
    }

    private func observe(
        _ output: GestureRecognitionOutput<Value>,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        switch output.phase {
        case .changed(let value):
            var transaction = Transaction()
            transaction.isContinuous = true
            update(value, &storage.value, &transaction)
            didUpdate = true
            context.invalidate()
        case .ended, .failed:
            if didUpdate {
                context.appendReset { [weak self] in
                    self?.resetIfNeeded()
                }
            }
        case .none:
            break
        }
        return output
    }

    private func resetIfNeeded() {
        guard didUpdate else {
            return
        }
        didUpdate = false
        storage.reset()
    }
}

extension Gesture where Value == Body.Value {

    /// Recursively lowers a custom gesture body into an opaque recognition definition.
    ///
    /// SwiftTUI calls this implementation hook while registering an attachment.
    public func _makeGesture() -> _GestureDefinition<Value> {
        BodyExpansionContext.gesture(self) {
            let definition = body._makeGesture()
            return _GestureDefinition(
                configuration: .wrapper(
                    "body:\(String(reflecting: Self.self))",
                    definition.configuration
                ),
                makeNode: definition.makeNode
            )
        }
    }
}

/// Supplies the terminal recognition definition for an uninhabited gesture.
extension Never {

    /// Builds the empty recognition definition for the uninhabited gesture.
    ///
    /// SwiftTUI uses this implementation hook as the terminal body of primitive
    /// gesture declarations and never evaluates it for an input sample.
    public func _makeGesture() -> _GestureDefinition<Never> {
        _GestureDefinition(
            configuration: GestureRecognitionConfiguration("never"),
            makeNode: NeverGestureRecognitionNode.init
        )
    }
}

extension TapGesture {

    /// Builds a recognition definition for the configured tap count.
    ///
    /// SwiftTUI calls this implementation hook while registering an attachment.
    public func _makeGesture() -> _GestureDefinition<Void> {
        _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "tap",
                values: [count]
            ),
            makeNode: {
                TapGestureRecognitionNode(
                    count: count,
                    coordinateSpace: nil,
                    makeValue: { _ in () }
                )
            }
        )
    }
}

extension SpatialTapGesture {

    /// Builds a recognition definition for taps with converted locations.
    ///
    /// Recognized locations are reported in the gesture's coordinate space.
    public func _makeGesture() -> _GestureDefinition<Value> {
        _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "spatialTap",
                values: [count, coordinateSpace]
            ),
            makeNode: {
                TapGestureRecognitionNode(
                    count: count,
                    coordinateSpace: coordinateSpace,
                    makeValue: Value.init(location:)
                )
            }
        )
    }
}

extension LongPressGesture {

    /// Builds a recognition definition for this duration and movement allowance.
    ///
    /// SwiftTUI calls this implementation hook while registering an attachment.
    public func _makeGesture() -> _GestureDefinition<Bool> {
        _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "longPress",
                values: [
                    minimumDuration.bitPattern,
                    maximumDistance.columns,
                    maximumDistance.rows,
                ]
            ),
            makeNode: {
                LongPressGestureRecognitionNode(
                    minimumDuration: minimumDuration,
                    maximumDistance: maximumDistance
                )
            }
        )
    }
}

extension DragGesture {

    /// Builds a recognition definition for this button, distance, and coordinate space.
    ///
    /// SwiftTUI calls this implementation hook while registering an attachment.
    public func _makeGesture() -> _GestureDefinition<Value> {
        _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "drag",
                values: [button, minimumDistance, coordinateSpace]
            ),
            makeNode: {
                DragGestureRecognitionNode(gesture: self)
            }
        )
    }
}

extension ChangedGesture {

    func _makeGesture() -> _GestureDefinition<Value> {
        let definition = base._makeGesture()
        return _GestureDefinition(
            configuration: .wrapper("changed", definition.configuration),
            makeNode: {
                ChangedGestureRecognitionNode(
                    base: definition.makeNode(),
                    action: action
                )
            }
        )
    }
}

extension EndedGesture {

    func _makeGesture() -> _GestureDefinition<Value> {
        let definition = base._makeGesture()
        return _GestureDefinition(
            configuration: .wrapper("ended", definition.configuration),
            makeNode: {
                EndedGestureRecognitionNode(
                    base: definition.makeNode(),
                    action: action
                )
            }
        )
    }
}

extension GestureStateGesture {

    /// Builds a recognition definition that updates this gesture's transient state.
    ///
    /// The wrapper preserves the base gesture's recognition behavior and resets
    /// state through the shared gesture lifecycle.
    public func _makeGesture() -> _GestureDefinition<Value> {
        let definition = base._makeGesture()
        return _GestureDefinition(
            configuration: .wrapper("updating", definition.configuration),
            makeNode: {
                GestureStateRecognitionNode(
                    base: definition.makeNode(),
                    storage: state.storage,
                    update: update
                )
            }
        )
    }
}

final class ExclusiveGestureRecognitionNode<First, Second, Value>:
    GestureRecognitionNode<Value>
{
    struct ReplaySample {

        var sample: RecognitionSample

        var date: Date

        var isTargeted: Bool
    }

    let first: GestureRecognitionNode<First>

    let second: GestureRecognitionNode<Second>

    let firstValue: (First) -> Value

    let secondValue: (Second) -> Value

    var usesSecond = false

    var replaySamples: [ReplaySample] = []

    init(
        first: GestureRecognitionNode<First>,
        second: GestureRecognitionNode<Second>,
        firstValue: @escaping (First) -> Value,
        secondValue: @escaping (Second) -> Value
    ) {
        self.first = first
        self.second = second
        self.firstValue = firstValue
        self.secondValue = secondValue
        super.init()
    }

    override var isActive: Bool {
        usesSecond ? second.isActive : first.isActive || !replaySamples.isEmpty
    }

    override var nextDeadline: Date? {
        usesSecond ? second.nextDeadline : first.nextDeadline
    }

    override var acceptsNewPointerDownWhileActive: Bool {
        usesSecond
            ? second.acceptsNewPointerDownWhileActive
            : first.acceptsNewPointerDownWhileActive
    }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        if usesSecond {
            return finishSecondIfNeeded(
                second.process(sample, context: context)
            )
        }
        replaySamples.append(
            ReplaySample(
                sample: sample,
                date: context.date,
                isTargeted: context.isTargeted
            )
        )
        let output = first.process(sample, context: context)
        guard case .failed = output.phase else {
            if case .ended = output.phase {
                replaySamples = []
            }
            return mapFirst(output)
        }
        // Finish callbacks and transient-state reset from the failed preferred
        // branch before exposing values from the fallback branch.
        context.flush()
        usesSecond = true
        return replaySecond(to: context.date, context: context)
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        if usesSecond {
            return finishSecondIfNeeded(
                second.advance(to: date, context: context)
            )
        }
        let output = first.advance(to: date, context: context)
        guard case .failed = output.phase else {
            return mapFirst(output)
        }
        context.flush()
        usesSecond = true
        return replaySecond(to: date, context: context)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        first.cancel(reason)
        second.cancel(reason)
        usesSecond = false
        replaySamples = []
    }

    override func restoreState(from old: GestureRecognitionNode<Value>) {
        guard let old = old as? ExclusiveGestureRecognitionNode<First, Second, Value> else {
            return
        }
        usesSecond = old.usesSecond
        replaySamples = old.replaySamples
        first.restoreState(from: old.first)
        second.restoreState(from: old.second)
    }

    private func replaySecond(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        var latest: GestureRecognitionOutput<Second> = .noMatch
        for replay in replaySamples {
            let replayContext = GestureRecognitionContext(
                date: replay.date,
                isTargeted: replay.isTargeted,
                convert: context.convert,
                invalidate: context.invalidate
            )
            let output = second.process(replay.sample, context: replayContext)
            replayContext.flush()
            if output.participated {
                latest = output
            }
            if case .ended = output.phase {
                break
            }
            if case .failed = output.phase {
                break
            }
        }
        replaySamples = []

        if second.nextDeadline.map({ $0 <= date }) == true,
           !isTerminal(latest) {
            let advanceContext = GestureRecognitionContext(
                date: date,
                isTargeted: context.isTargeted,
                convert: context.convert,
                invalidate: context.invalidate
            )
            let output = second.advance(to: date, context: advanceContext)
            advanceContext.flush()
            if output.participated {
                latest = output
            }
        }

        guard latest.participated || second.isActive else {
            usesSecond = false
            return .failed()
        }
        return finishSecondIfNeeded(latest)
    }

    private func finishSecondIfNeeded(
        _ output: GestureRecognitionOutput<Second>
    ) -> GestureRecognitionOutput<Value> {
        let mapped = mapSecond(output)
        if isTerminal(output) {
            usesSecond = false
        }
        return mapped
    }

    private func isTerminal<Child>(
        _ output: GestureRecognitionOutput<Child>
    ) -> Bool {
        switch output.phase {
        case .ended, .failed:
            true
        case .none, .changed:
            false
        }
    }

    private func mapFirst(
        _ output: GestureRecognitionOutput<First>
    ) -> GestureRecognitionOutput<Value> {
        map(output, transform: firstValue)
    }

    private func mapSecond(
        _ output: GestureRecognitionOutput<Second>
    ) -> GestureRecognitionOutput<Value> {
        map(output, transform: secondValue)
    }

    private func map<Child>(
        _ output: GestureRecognitionOutput<Child>,
        transform: (Child) -> Value
    ) -> GestureRecognitionOutput<Value> {
        let phase: GestureRecognitionPhase<Value>
        switch output.phase {
        case .none:
            phase = .none
        case .changed(let value):
            phase = .changed(transform(value))
        case .ended(let value):
            phase = .ended(transform(value))
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

final class SimultaneousGestureRecognitionNode<First, Second, Value>:
    GestureRecognitionNode<Value>
{
    let first: GestureRecognitionNode<First>

    let second: GestureRecognitionNode<Second>

    let makeValue: (First?, Second?) -> Value

    var latestFirst: First?

    var latestSecond: Second?

    var firstTerminal = false

    var secondTerminal = false

    var firstSucceeded = false

    var secondSucceeded = false

    init(
        first: GestureRecognitionNode<First>,
        second: GestureRecognitionNode<Second>,
        makeValue: @escaping (First?, Second?) -> Value
    ) {
        self.first = first
        self.second = second
        self.makeValue = makeValue
        super.init()
    }

    override var isActive: Bool {
        first.isActive || second.isActive || firstTerminal != secondTerminal
    }

    override var nextDeadline: Date? {
        [first.nextDeadline, second.nextDeadline].compactMap { $0 }.min()
    }

    override var acceptsNewPointerDownWhileActive: Bool {
        (firstTerminal || !first.isActive || first.acceptsNewPointerDownWhileActive)
            && (secondTerminal || !second.isActive || second.acceptsNewPointerDownWhileActive)
    }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        let firstOutput = firstTerminal
            ? GestureRecognitionOutput<First>.noMatch
            : first.process(sample, context: context)
        let secondOutput = secondTerminal
            ? GestureRecognitionOutput<Second>.noMatch
            : second.process(sample, context: context)
        return combine(
            firstOutput,
            secondOutput,
            endsPointerSequence: sample.endsPointerSequence
        )
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        let firstOutput = firstTerminal
            ? GestureRecognitionOutput<First>.noMatch
            : first.advance(to: date, context: context)
        let secondOutput = secondTerminal
            ? GestureRecognitionOutput<Second>.noMatch
            : second.advance(to: date, context: context)
        return combine(
            firstOutput,
            secondOutput,
            endsPointerSequence: false
        )
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        first.cancel(reason)
        second.cancel(reason)
        reset()
    }

    override func restoreState(from old: GestureRecognitionNode<Value>) {
        guard let old = old as? SimultaneousGestureRecognitionNode<First, Second, Value> else {
            return
        }
        latestFirst = old.latestFirst
        latestSecond = old.latestSecond
        firstTerminal = old.firstTerminal
        secondTerminal = old.secondTerminal
        firstSucceeded = old.firstSucceeded
        secondSucceeded = old.secondSucceeded
        first.restoreState(from: old.first)
        second.restoreState(from: old.second)
    }

    private func combine(
        _ firstOutput: GestureRecognitionOutput<First>,
        _ secondOutput: GestureRecognitionOutput<Second>,
        endsPointerSequence: Bool
    ) -> GestureRecognitionOutput<Value> {
        update(
            firstOutput,
            latest: &latestFirst,
            terminal: &firstTerminal,
            succeeded: &firstSucceeded
        )
        update(
            secondOutput,
            latest: &latestSecond,
            terminal: &secondTerminal,
            succeeded: &secondSucceeded
        )
        if endsPointerSequence,
           !firstTerminal,
           !first.isActive,
           !firstOutput.participated {
            firstTerminal = true
        }
        if endsPointerSequence,
           !secondTerminal,
           !second.isActive,
           !secondOutput.participated {
            secondTerminal = true
        }
        let participated = firstOutput.participated || secondOutput.participated
        guard participated else {
            return .noMatch
        }

        let capture = firstOutput.beginsCapture || secondOutput.beginsCapture
        let claimsCompetition = firstOutput.claimsCompetition
            || secondOutput.claimsCompetition
        let release = firstOutput.endsCapture || secondOutput.endsCapture
        if firstTerminal && secondTerminal {
            guard firstSucceeded || secondSucceeded else {
                reset()
                return .failed(releasesCapture: release)
            }
            let value = makeValue(latestFirst, latestSecond)
            reset()
            return .ended(value, releasesCapture: release)
        }
        return .changed(
            makeValue(latestFirst, latestSecond),
            claimsCompetition: claimsCompetition,
            captures: capture
        )
    }

    private func update<Child>(
        _ output: GestureRecognitionOutput<Child>,
        latest: inout Child?,
        terminal: inout Bool,
        succeeded: inout Bool
    ) {
        switch output.phase {
        case .none:
            break
        case .changed(let value):
            latest = value
        case .ended(let value):
            latest = value
            terminal = true
            succeeded = true
        case .failed:
            terminal = true
        }
    }

    private func reset() {
        latestFirst = nil
        latestSecond = nil
        firstTerminal = false
        secondTerminal = false
        firstSucceeded = false
        secondSucceeded = false
    }
}

extension RecognitionSample {

    /// Whether this sample closes the terminal's current single-pointer press
    /// sequence for recognizers that never became active.
    var endsPointerSequence: Bool {
        guard case .pointerPress(let press) = self else {
            return false
        }
        return press.phase == .up
    }
}

final class SequenceGestureRecognitionNode<First, Second, Value>:
    GestureRecognitionNode<Value>
{
    let first: GestureRecognitionNode<First>

    let second: GestureRecognitionNode<Second>

    let firstPhase: (First) -> Value

    let secondPhase: (First, Second?) -> Value

    var retainedFirst: First?

    init(
        first: GestureRecognitionNode<First>,
        second: GestureRecognitionNode<Second>,
        firstPhase: @escaping (First) -> Value,
        secondPhase: @escaping (First, Second?) -> Value
    ) {
        self.first = first
        self.second = second
        self.firstPhase = firstPhase
        self.secondPhase = secondPhase
        super.init()
    }

    override var isActive: Bool {
        retainedFirst != nil || first.isActive || second.isActive
    }

    override var acceptsNewPointerDownWhileActive: Bool {
        retainedFirst != nil || first.acceptsNewPointerDownWhileActive
    }

    override var nextDeadline: Date? {
        retainedFirst == nil ? first.nextDeadline : second.nextDeadline
    }

    override func process(
        _ sample: RecognitionSample,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        if let retainedFirst {
            return mapSecond(
                second.process(sample, context: context),
                first: retainedFirst
            )
        }
        return mapFirst(first.process(sample, context: context))
    }

    override func advance(
        to date: Date,
        context: GestureRecognitionContext
    ) -> GestureRecognitionOutput<Value> {
        if let retainedFirst {
            return mapSecond(
                second.advance(to: date, context: context),
                first: retainedFirst
            )
        }
        return mapFirst(first.advance(to: date, context: context))
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        first.cancel(reason)
        second.cancel(reason)
        retainedFirst = nil
    }

    override func restoreState(from old: GestureRecognitionNode<Value>) {
        guard let old = old as? SequenceGestureRecognitionNode<First, Second, Value> else {
            return
        }
        retainedFirst = old.retainedFirst
        first.restoreState(from: old.first)
        second.restoreState(from: old.second)
    }

    private func mapFirst(
        _ output: GestureRecognitionOutput<First>
    ) -> GestureRecognitionOutput<Value> {
        let phase: GestureRecognitionPhase<Value>
        switch output.phase {
        case .none:
            phase = .none
        case .changed(let value):
            phase = .changed(firstPhase(value))
        case .ended(let value):
            retainedFirst = value
            phase = .changed(secondPhase(value, nil))
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

    private func mapSecond(
        _ output: GestureRecognitionOutput<Second>,
        first: First
    ) -> GestureRecognitionOutput<Value> {
        let phase: GestureRecognitionPhase<Value>
        switch output.phase {
        case .none:
            phase = .none
        case .changed(let value):
            phase = .changed(secondPhase(first, value))
        case .ended(let value):
            retainedFirst = nil
            phase = .ended(secondPhase(first, value))
        case .failed:
            retainedFirst = nil
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

extension ExclusiveGesture {

    /// Builds a recognition definition that gives the first gesture precedence.
    ///
    /// The second gesture is eligible only after actual recognition failure.
    public func _makeGesture() -> _GestureDefinition<Value> {
        let firstDefinition = first._makeGesture()
        let secondDefinition = second._makeGesture()
        return _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "exclusive",
                children: [
                    firstDefinition.configuration,
                    secondDefinition.configuration,
                ]
            ),
            makeNode: {
                ExclusiveGestureRecognitionNode(
                    first: firstDefinition.makeNode(),
                    second: secondDefinition.makeNode(),
                    firstValue: Value.first,
                    secondValue: Value.second
                )
            }
        )
    }
}

extension SimultaneousGesture {

    /// Builds a recognition definition that runs both gestures independently.
    ///
    /// Either child can update, succeed, or fail without cancelling its sibling.
    public func _makeGesture() -> _GestureDefinition<Value> {
        let firstDefinition = first._makeGesture()
        let secondDefinition = second._makeGesture()
        let valueFactory: BinaryRecognitionValueFactory<
            First.Value?, Second.Value?, Value
        > = simultaneousGestureValueFactory()
        return _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "simultaneous",
                children: [
                    firstDefinition.configuration,
                    secondDefinition.configuration,
                ]
            ),
            makeNode: {
                SimultaneousGestureRecognitionNode(
                    first: firstDefinition.makeNode(),
                    second: secondDefinition.makeNode(),
                    makeValue: valueFactory.makeValue
                )
            }
        )
    }
}

extension SequenceGesture {

    /// Builds a recognition definition that activates the second gesture after the first.
    ///
    /// The definition retains the first gesture's value while the second runs.
    public func _makeGesture() -> _GestureDefinition<Value> {
        let firstDefinition = first._makeGesture()
        let secondDefinition = second._makeGesture()
        return _GestureDefinition(
            configuration: GestureRecognitionConfiguration(
                "sequence",
                children: [
                    firstDefinition.configuration,
                    secondDefinition.configuration,
                ]
            ),
            makeNode: {
                SequenceGestureRecognitionNode(
                    first: firstDefinition.makeNode(),
                    second: secondDefinition.makeNode(),
                    firstPhase: Value.first,
                    secondPhase: Value.second
                )
            }
        )
    }
}
