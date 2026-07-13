public import Foundation
public import Terminal

/// A declarative recognizer that produces values from a sequence of input.
///
/// A gesture stores recognition configuration. Attach a gesture to a view to
/// participate in input routing, or compose it with other gestures before
/// attachment. Primitive gestures use `Never` as their body.
@MainActor
@preconcurrency
public protocol Gesture<Value> {

    /// The value produced as the gesture recognizes or completes.
    associatedtype Value

    /// The gesture that defines this gesture's recognition behavior.
    associatedtype Body: Gesture

    /// The gesture's declarative composition.
    ///
    /// SwiftTUI can reevaluate a custom body during rendering, so callers must
    /// not rely on evaluation for side effects. Primitive gestures receive an
    /// uninhabited default implementation that must not be evaluated.
    var body: Body { get }

    /// Lowers this gesture into SwiftTUI's recognition graph.
    ///
    /// SwiftTUI supplies this implementation for custom gestures whose `Value`
    /// equals `Body.Value`. This underscored public witness enforces that
    /// relationship during conformance checking without runtime casts. Pass
    /// gestures to a view attachment instead of calling this hook directly.
    func _makeGesture() -> _GestureDefinition<Value>
}

extension Gesture where Body == Never {

    /// Marks a primitive gesture as having no composed body.
    ///
    /// - Precondition: This property must not be evaluated.
    public var body: Never {
        fatalError("Primitive gestures do not have a body.")
    }

}

/// Makes `Never` the terminal body of primitive gestures.
extension Never: Gesture {}

/// Recognizes one or more primary-button taps.
public nonisolated struct TapGesture: Gesture, Equatable, Sendable {

    /// The completion value produced by a tap gesture.
    public typealias Value = Void

    /// The uninhabited body of this primitive gesture.
    public typealias Body = Never

    /// The number of consecutive taps required for recognition.
    public var count: Int

    /// Creates a tap gesture.
    ///
    /// - Parameter count: The required number of consecutive taps. The default
    ///   is one.
    /// - Precondition: `count >= 1`.
    public init(count: Int = 1) {
        precondition(count >= 1, "TapGesture count must be greater than zero.")
        self.count = count
    }
}

/// Recognizes taps and reports their two-dimensional terminal-cell location.
///
/// SwiftTUI reports only the terminal grid's column and row. It doesn't model
/// three-dimensional spatial input.
public nonisolated struct SpatialTapGesture: Gesture, Equatable, Sendable {

    /// The location produced when a spatial tap recognizes.
    public struct Value: Equatable, Sendable {

        /// The zero-based terminal-cell tap location.
        public let location: Point

        /// Creates a spatial-tap value.
        ///
        /// - Parameter location: The tap location in the configured coordinate space.
        public init(location: Point) {
            self.location = location
        }
    }

    /// The uninhabited body of this primitive gesture.
    public typealias Body = Never

    /// The number of consecutive taps required for recognition.
    public var count: Int

    /// The coordinate space used for the recognized location.
    public var coordinateSpace: CoordinateSpace

    /// Creates a spatial tap gesture.
    ///
    /// - Parameters:
    ///   - count: The required number of consecutive taps. The default is one.
    ///   - coordinateSpace: The coordinate space used for the recognized location.
    /// - Precondition: `count >= 1`.
    public init(
        count: Int = 1,
        coordinateSpace: CoordinateSpace = .local
    ) {
        precondition(count >= 1, "SpatialTapGesture count must be greater than zero.")
        self.count = count
        self.coordinateSpace = coordinateSpace
    }
}

/// Recognizes a primary-button press held for a minimum duration.
///
/// Movement tolerance is measured independently in terminal columns and rows,
/// not as Euclidean distance.
public nonisolated struct LongPressGesture: Gesture, Equatable, Sendable {

    /// The active and successful value produced by a long press.
    public typealias Value = Bool

    /// The uninhabited body of this primitive gesture.
    public typealias Body = Never

    /// The normalized minimum duration in seconds.
    public var minimumDuration: Double

    /// The normalized per-axis terminal-cell movement tolerance.
    public var maximumDistance: Size

    /// Creates a long-press gesture.
    ///
    /// Negative duration and distance components are independently normalized
    /// to zero.
    ///
    /// - Parameters:
    ///   - minimumDuration: The minimum press duration in seconds.
    ///   - maximumDistance: The permitted column and row movement.
    public init(
        minimumDuration: Double = 0.5,
        maximumDistance: Size = .zero
    ) {
        self.minimumDuration = max(minimumDuration, 0)
        self.maximumDistance = Size(
            columns: max(maximumDistance.columns, 0),
            rows: max(maximumDistance.rows, 0)
        )
    }
}

/// Recognizes a captured terminal pointer drag.
public nonisolated struct DragGesture: Gesture, Equatable, Sendable {

    /// A drag sample reported as terminal-cell geometry and timing.
    public struct Value: Equatable, Sendable {

        /// A terminal-grid velocity measured in cells per second.
        public struct Velocity: Equatable, Sendable {

            /// Horizontal velocity in columns per second.
            public let columnsPerSecond: Double

            /// Vertical velocity in rows per second.
            public let rowsPerSecond: Double

            /// Creates a terminal-grid velocity.
            ///
            /// - Parameters:
            ///   - columnsPerSecond: Horizontal cells traveled per second.
            ///   - rowsPerSecond: Vertical cells traveled per second.
            public init(columnsPerSecond: Double, rowsPerSecond: Double) {
                self.columnsPerSecond = columnsPerSecond
                self.rowsPerSecond = rowsPerSecond
            }

            /// A velocity with no horizontal or vertical movement.
            public static let zero = Velocity(columnsPerSecond: 0, rowsPerSecond: 0)
        }

        /// The time of this sample.
        public let time: Date

        /// The current location in the gesture's coordinate space.
        public let location: Point

        /// The pointer-down location that began the drag.
        public let startLocation: Point

        /// The signed column and row displacement from the start location.
        public let translation: Size

        /// The velocity derived from the latest two distinct samples.
        public let velocity: Velocity

        /// The location predicted by extending the latest cell delta once.
        public let predictedEndLocation: Point

        /// The signed displacement from the start to the predicted end.
        public let predictedEndTranslation: Size

        /// The modifier keys reported with this sample.
        public let modifiers: EventModifiers

        /// Creates a complete drag sample.
        ///
        /// - Parameters:
        ///   - time: The sample time.
        ///   - location: The current location.
        ///   - startLocation: The drag's pointer-down location.
        ///   - translation: The signed displacement from `startLocation`.
        ///   - velocity: The latest terminal-grid velocity.
        ///   - predictedEndLocation: The one-sample linear prediction.
        ///   - predictedEndTranslation: The predicted displacement from the start.
        ///   - modifiers: The reported modifier flags.
        public init(
            time: Date,
            location: Point,
            startLocation: Point,
            translation: Size,
            velocity: Velocity,
            predictedEndLocation: Point,
            predictedEndTranslation: Size,
            modifiers: EventModifiers
        ) {
            self.time = time
            self.location = location
            self.startLocation = startLocation
            self.translation = translation
            self.velocity = velocity
            self.predictedEndLocation = predictedEndLocation
            self.predictedEndTranslation = predictedEndTranslation
            self.modifiers = modifiers
        }
    }

    /// The uninhabited body of this primitive gesture.
    public typealias Body = Never

    /// The pointer button that can begin this drag.
    public var button: PointerButton

    /// The normalized Chebyshev distance required before recognition.
    public var minimumDistance: Int

    /// The coordinate space used for all reported locations.
    public var coordinateSpace: CoordinateSpace

    /// Creates a drag gesture.
    ///
    /// A zero distance begins on pointer-down. Negative distances are
    /// normalized to zero.
    ///
    /// - Parameters:
    ///   - button: The pointer button that begins the drag.
    ///   - minimumDistance: The required terminal-cell Chebyshev distance.
    ///   - coordinateSpace: The coordinate space used for reported locations.
    public init(
        button: PointerButton = .left,
        minimumDistance: Int = 0,
        coordinateSpace: CoordinateSpace = .local
    ) {
        self.button = button
        self.minimumDistance = max(minimumDistance, 0)
        self.coordinateSpace = coordinateSpace
    }
}

/// Transaction metadata supplied while updating or resetting recognition state.
///
/// ``GestureState`` and ``ShortcutState`` share this value so their update and
/// reset callbacks can distinguish continuous samples from terminal lifecycle
/// transitions.
public nonisolated struct Transaction: Sendable {

    /// Whether the transaction represents a continuous recognition sample.
    public var isContinuous: Bool

    /// Creates a noncontinuous transaction.
    public init() {
        isContinuous = false
    }
}

final class RecognitionStateStorage<Value> {

    let initialValue: Value

    let state: State<Value>

    let resetTransaction: Transaction

    let resetAction: ((Value, inout Transaction) -> Void)?

    init(
        initialValue: Value,
        resetTransaction: Transaction,
        resetAction: ((Value, inout Transaction) -> Void)?
    ) {
        self.initialValue = initialValue
        self.state = State(wrappedValue: initialValue)
        self.resetTransaction = resetTransaction
        self.resetAction = resetAction
    }

    var value: Value {
        get {
            state.wrappedValue
        }
        set {
            state.wrappedValue = newValue
        }
    }

    func materialize() {
        state.materialize()
    }

    func reset() {
        var transaction = resetTransaction
        resetAction?(value, &transaction)
        value = initialValue
    }
}

/// Transient state whose lifetime is tied to an attached gesture sequence.
///
/// SwiftTUI restores the initial value after success, failure, cancellation,
/// disabling, or removal. Assignments are performed only by a gesture's
/// `updating` closure.
@propertyWrapper
public struct GestureState<Value>: DynamicProperty {

    let storage: RecognitionStateStorage<Value>

    /// The current transient gesture value.
    public var wrappedValue: Value {
        storage.value
    }

    /// The gesture state value used by ``Gesture/updating(_:body:)``.
    public var projectedValue: GestureState<Value> {
        self
    }

    /// Creates gesture state with an initial value.
    ///
    /// - Parameter value: The value restored when recognition ends.
    public init(wrappedValue value: Value) {
        storage = RecognitionStateStorage(
            initialValue: value,
            resetTransaction: Transaction(),
            resetAction: nil
        )
    }

    /// Creates gesture state with an initial value.
    ///
    /// - Parameter value: The value restored when recognition ends.
    public init(initialValue value: Value) {
        self.init(wrappedValue: value)
    }

    /// Creates gesture state with a transaction used for automatic reset.
    ///
    /// - Parameters:
    ///   - value: The value restored when recognition ends.
    ///   - resetTransaction: The transaction supplied during reset.
    public init(wrappedValue value: Value, resetTransaction: Transaction) {
        storage = RecognitionStateStorage(
            initialValue: value,
            resetTransaction: resetTransaction,
            resetAction: nil
        )
    }

    /// Creates gesture state with a transaction used for automatic reset.
    ///
    /// - Parameters:
    ///   - value: The value restored when recognition ends.
    ///   - resetTransaction: The transaction supplied during reset.
    public init(initialValue value: Value, resetTransaction: Transaction) {
        self.init(wrappedValue: value, resetTransaction: resetTransaction)
    }

    /// Creates gesture state with a reset callback.
    ///
    /// The callback receives the final transient value and a mutable
    /// noncontinuous transaction before SwiftTUI restores the initial value.
    ///
    /// - Parameters:
    ///   - value: The value restored when recognition ends.
    ///   - reset: The callback performed once for each completed or cancelled sequence.
    public init(
        wrappedValue value: Value,
        reset: @escaping (Value, inout Transaction) -> Void
    ) {
        storage = RecognitionStateStorage(
            initialValue: value,
            resetTransaction: Transaction(),
            resetAction: reset
        )
    }

    /// Creates gesture state with a reset callback.
    ///
    /// - Parameters:
    ///   - value: The value restored when recognition ends.
    ///   - reset: The callback performed once for each completed or cancelled sequence.
    public init(
        initialValue value: Value,
        reset: @escaping (Value, inout Transaction) -> Void
    ) {
        self.init(wrappedValue: value, reset: reset)
    }
}

extension GestureState where Value: ExpressibleByNilLiteral {

    /// Creates gesture state whose initial value is `nil`.
    public init() {
        self.init(wrappedValue: nil)
    }
}

extension GestureState: DynamicStateProperty {

    func materialize() {
        storage.materialize()
    }
}

/// Updates transient gesture state while forwarding the base gesture's value.
public struct GestureStateGesture<Base: Gesture, State>: Gesture {

    /// The value forwarded from the base gesture.
    public typealias Value = Base.Value

    /// The uninhabited body of this primitive gesture node.
    public typealias Body = Never

    /// The gesture whose samples update state.
    public let base: Base

    /// The transient state updated for each sample.
    public let state: GestureState<State>

    /// The callback that mutates transient state for a recognized sample.
    public let update: (Value, inout State, inout Transaction) -> Void

    /// Creates a gesture-state update node.
    ///
    /// - Parameters:
    ///   - base: The gesture supplying values.
    ///   - state: The transient state to update.
    ///   - update: The mutation applied for each sample.
    public init(
        base: Base,
        state: GestureState<State>,
        update: @escaping (Value, inout State, inout Transaction) -> Void
    ) {
        self.base = base
        self.state = state
        self.update = update
    }
}

struct ChangedGesture<Base: Gesture>: Gesture where Base.Value: Equatable {

    typealias Value = Base.Value

    typealias Body = Never

    let base: Base

    let action: (Value) -> Void
}

struct EndedGesture<Base: Gesture>: Gesture {

    typealias Value = Base.Value

    typealias Body = Never

    let base: Base

    let action: (Value) -> Void
}

extension Gesture where Value: Equatable {

    /// Performs an action when a gesture's changed value differs from its prior value.
    ///
    /// - Parameter action: The action performed for distinct changed values.
    /// - Returns: A gesture that observes changed values.
    public func onChanged(
        _ action: @escaping (Value) -> Void
    ) -> some Gesture<Value> {
        ChangedGesture(base: self, action: action)
    }
}

extension Gesture {

    /// Performs an action only after successful gesture recognition.
    ///
    /// Failure and cancellation don't invoke the action.
    ///
    /// - Parameter action: The action performed with the successful value.
    /// - Returns: A gesture that observes successful completion.
    public func onEnded(
        _ action: @escaping (Value) -> Void
    ) -> some Gesture<Value> {
        EndedGesture(base: self, action: action)
    }

    /// Updates transient state before changed-value callbacks run.
    ///
    /// - Parameters:
    ///   - state: The gesture state to update.
    ///   - body: The mutation performed with the gesture value and transaction.
    /// - Returns: A gesture that updates transient state for each sample.
    public func updating<State>(
        _ state: GestureState<State>,
        body: @escaping (Value, inout State, inout Transaction) -> Void
    ) -> GestureStateGesture<Self, State> {
        GestureStateGesture(base: self, state: state, update: body)
    }
}

/// Gives one gesture precedence and falls back only after recognition failure.
public nonisolated struct ExclusiveGesture<First: Gesture, Second: Gesture>: Gesture {

    /// A value produced by the branch that succeeds.
    public enum Value {

        /// A successful value from the first gesture.
        case first(First.Value)

        /// A successful value from the second gesture.
        case second(Second.Value)
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The gesture with the first opportunity to recognize.
    public let first: First

    /// The gesture enabled only after the first gesture fails.
    public let second: Second

    /// Creates an exclusive gesture composition.
    ///
    /// - Parameters:
    ///   - first: The gesture with precedence.
    ///   - second: The gesture used after recognition failure.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

extension ExclusiveGesture: Equatable where First: Equatable, Second: Equatable {}

extension ExclusiveGesture: Sendable where First: Sendable, Second: Sendable {}

extension ExclusiveGesture.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

extension ExclusiveGesture.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

/// Runs two gestures independently against the same input sequence.
public nonisolated struct SimultaneousGesture<First: Gesture, Second: Gesture>: Gesture {

    /// The final optional values from both gesture branches.
    public struct Value {

        /// The first gesture's last successful value, if any.
        public let first: First.Value?

        /// The second gesture's last successful value, if any.
        public let second: Second.Value?

        /// Creates a simultaneous gesture value.
        ///
        /// - Parameters:
        ///   - first: The first gesture's optional value.
        ///   - second: The second gesture's optional value.
        public init(first: First.Value?, second: Second.Value?) {
            self.first = first
            self.second = second
        }
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The first independently recognizing gesture.
    public let first: First

    /// The second independently recognizing gesture.
    public let second: Second

    /// Creates a simultaneous gesture composition.
    ///
    /// - Parameters:
    ///   - first: The first gesture.
    ///   - second: The second gesture.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

extension SimultaneousGesture: Equatable where First: Equatable, Second: Equatable {}

extension SimultaneousGesture: Sendable where First: Sendable, Second: Sendable {}

extension SimultaneousGesture.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

extension SimultaneousGesture.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

/// Requires one gesture to succeed before a second gesture can recognize.
public nonisolated struct SequenceGesture<First: Gesture, Second: Gesture>: Gesture {

    /// The current successful stage of a gesture sequence.
    public enum Value {

        /// The first gesture has succeeded and the second is active.
        case first(First.Value)

        /// The sequence retains the first value and optionally reports a second value.
        case second(First.Value, Second.Value?)
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The gesture that must succeed first.
    public let first: First

    /// The gesture enabled after the first succeeds.
    public let second: Second

    /// Creates a sequential gesture composition.
    ///
    /// - Parameters:
    ///   - first: The gesture that must succeed first.
    ///   - second: The gesture enabled after first-stage success.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

extension SequenceGesture: Equatable where First: Equatable, Second: Equatable {}

extension SequenceGesture: Sendable where First: Sendable, Second: Sendable {}

extension SequenceGesture.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

extension SequenceGesture.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

extension Gesture {

    /// Gives this gesture precedence over a fallback gesture.
    ///
    /// - Parameter other: The gesture enabled after this gesture fails.
    /// - Returns: An exclusive gesture composition.
    public nonisolated func exclusively<Other: Gesture>(
        before other: Other
    ) -> ExclusiveGesture<Self, Other> {
        ExclusiveGesture(self, other)
    }

    /// Runs this gesture and another gesture independently.
    ///
    /// - Parameter other: The simultaneous gesture sibling.
    /// - Returns: A simultaneous gesture composition.
    public nonisolated func simultaneously<Other: Gesture>(
        with other: Other
    ) -> SimultaneousGesture<Self, Other> {
        SimultaneousGesture(self, other)
    }

    /// Requires this gesture before another gesture.
    ///
    /// - Parameter other: The gesture enabled after this gesture succeeds.
    /// - Returns: A sequential gesture composition.
    public nonisolated func sequenced<Other: Gesture>(
        before other: Other
    ) -> SequenceGesture<Self, Other> {
        SequenceGesture(self, other)
    }
}
