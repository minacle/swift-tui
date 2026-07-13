public import Terminal

/// Indicates whether an input action stops or permits later input processing.
///
/// This result describes propagation, not whether an action produced a side
/// effect. An action can update state and still return ``ignored`` so later
/// input events, gestures, ancestor handlers, and key fallbacks can inspect the
/// same raw input.
public nonisolated enum InputEventResult: Equatable, Hashable, Sendable {

    /// Stops the remaining consumable work outside the current composite.
    case handled

    /// Permits the remaining consumable work to inspect the input.
    case ignored
}

/// An input event that invokes an action after its base event recognizes.
///
/// Nested recognition actions run from the innermost event outward. Every
/// action in the same composite runs before a handled result is applied to
/// consumers outside the composite.
public nonisolated struct RecognizedInputEvent<Base: InputEvent>: InputEvent {

    /// The value produced by the base event.
    public typealias Value = Base.Value

    /// The uninhabited body of this primitive recognition node.
    public typealias Body = Never

    /// The event whose recognized values invoke this node's action.
    public let base: Base

    let action: (Value) -> InputEventResult

    init(base: Base, action: @escaping (Value) -> InputEventResult) {
        self.base = base
        self.action = action
    }
}

extension RecognizedInputEvent: KeyEvent where Base: KeyEvent {}

extension RecognizedInputEvent: PointerEvent where Base: PointerEvent {}

extension InputEvent {

    /// Adds an action that receives values recognized by this input event.
    ///
    /// Returning ``InputEventResult/handled`` stops subsequent consumable work
    /// outside this composite after all nested recognition actions finish.
    ///
    /// - Parameter action: The action to invoke for each recognized value.
    /// - Returns: An input event that performs `action` after recognition.
    public func onRecognized(
        _ action: @escaping (Value) -> InputEventResult
    ) -> RecognizedInputEvent<Self> {
        RecognizedInputEvent(base: self, action: action)
    }
}

/// Selects when a deferred input event runs within its attachment tier.
public nonisolated enum DeferredInputEventPriority: Equatable, Hashable, Sendable {

    /// Runs after immediate input events and before gestures in the same tier.
    case eager

    /// Runs after gestures in the same tier.
    case lazy
}

/// Moves an input event to an explicit deferred stage within an attachment tier.
///
/// If deferred events are nested, the outermost event determines the effective
/// stage for the complete child recognition graph.
public nonisolated struct DeferredInputEvent<Base: InputEvent>: InputEvent {

    /// The value produced by the base event.
    public typealias Value = Base.Value

    /// The uninhabited body of this primitive scheduling node.
    public typealias Body = Never

    /// The event whose recognition graph is deferred.
    public let base: Base

    /// The stage used within the attachment tier.
    public let priority: DeferredInputEventPriority

    /// Creates a deferred input event.
    ///
    /// - Parameters:
    ///   - base: The event graph to schedule.
    ///   - priority: The stage used within the attachment tier.
    public nonisolated init(base: Base, priority: DeferredInputEventPriority) {
        self.base = base
        self.priority = priority
    }
}

extension DeferredInputEvent: KeyEvent where Base: KeyEvent {}

extension DeferredInputEvent: PointerEvent where Base: PointerEvent {}

extension DeferredInputEvent: Equatable where Base: Equatable {}

extension DeferredInputEvent: Sendable where Base: Sendable {}

extension InputEvent {

    /// Schedules this event in a deferred stage of its attachment tier.
    ///
    /// - Parameter priority: The required eager or lazy stage. This parameter
    ///   has no default so scheduling intent remains explicit.
    /// - Returns: A deferred input event with the same recognized value.
    public nonisolated func deferred(
        priority: DeferredInputEventPriority
    ) -> DeferredInputEvent<Self> {
        DeferredInputEvent(base: self, priority: priority)
    }
}

/// A pointer movement measured in zero-based terminal-cell coordinates.
///
/// A non-`nil` button identifies a button held during motion. A `nil` button
/// represents passive pointer movement; hover remains a separate observation
/// API.
public nonisolated struct PointerMotion: Equatable, Sendable {

    /// The button held during movement, or `nil` for buttonless movement.
    public let button: PointerButton?

    /// The terminal-cell location in the coordinate space requested by a handler.
    public let location: Point

    /// The modifier keys reported with the movement.
    public let modifiers: EventModifiers

    /// Creates a pointer-motion value.
    ///
    /// - Parameters:
    ///   - button: The held pointer button, or `nil` for buttonless movement.
    ///   - location: The zero-based terminal-cell location.
    ///   - modifiers: The reported modifier flags. The default is no modifiers.
    public init(
        button: PointerButton?,
        location: Point,
        modifiers: EventModifiers = []
    ) {
        self.button = button
        self.location = location
        self.modifiers = modifiers
    }
}

/// A primitive matcher for pointer motion.
public nonisolated struct PointerMotionEvent: PointerEvent, Equatable, Sendable {

    /// A constraint applied to the button carried by pointer motion.
    public enum Filter: Equatable, Sendable {

        /// Matches buttonless and button-bearing motion.
        case any

        /// Matches motion whose button is `nil`.
        case buttonless

        /// Matches motion carrying any button.
        case pressed

        /// Matches motion carrying one of the specified buttons.
        ///
        /// An empty set never matches.
        ///
        /// - Parameter buttons: The accepted buttons.
        case buttons(Set<PointerButton>)
    }

    /// The pointer-motion value produced by this matcher.
    public typealias Value = PointerMotion

    /// The uninhabited body of this primitive matcher.
    public typealias Body = Never

    /// The button constraint applied during recognition.
    public let filter: Filter

    /// The coordinate space requested for recognized locations.
    public let coordinateSpace: CoordinateSpace

    /// Creates a pointer-motion matcher.
    ///
    /// - Parameters:
    ///   - filter: The accepted button state. The default accepts all motion.
    ///   - coordinateSpace: The coordinate space used for recognized locations.
    public init(
        _ filter: Filter = .any,
        coordinateSpace: CoordinateSpace = .local
    ) {
        self.filter = filter
        self.coordinateSpace = coordinateSpace
    }

    func matches(_ motion: PointerMotion) -> Bool {
        switch filter {
        case .any:
            true
        case .buttonless:
            motion.button == nil
        case .pressed:
            motion.button != nil
        case .buttons(let buttons):
            motion.button.map(buttons.contains) ?? false
        }
    }
}

/// A raw scroll-wheel delta and pointer location in terminal cells.
///
/// `delta` describes input direction and magnitude, not a content offset. The
/// current SGR parser emits one-cell deltas on one axis, while constructed
/// values can represent larger or diagonal input.
public nonisolated struct PointerScroll: Equatable, Sendable {

    /// The signed raw terminal-cell delta.
    public let delta: Size

    /// The terminal-cell location in the coordinate space requested by a handler.
    public let location: Point

    /// The modifier keys reported with the scroll input.
    public let modifiers: EventModifiers

    /// The axes containing a nonzero delta component.
    public var axes: Axis.Set {
        var axes: Axis.Set = []
        if delta.columns != 0 {
            axes.insert(.horizontal)
        }
        if delta.rows != 0 {
            axes.insert(.vertical)
        }
        return axes
    }

    /// Creates a pointer-scroll value.
    ///
    /// - Parameters:
    ///   - delta: The signed raw terminal-cell delta.
    ///   - location: The zero-based terminal-cell location.
    ///   - modifiers: The reported modifier flags. The default is no modifiers.
    public init(
        delta: Size,
        location: Point,
        modifiers: EventModifiers = []
    ) {
        self.delta = delta
        self.location = location
        self.modifiers = modifiers
    }
}

/// A primitive matcher for scroll input on selected terminal axes.
public nonisolated struct PointerScrollEvent: PointerEvent, Equatable, Sendable {

    /// The pointer-scroll value produced by this matcher.
    public typealias Value = PointerScroll

    /// The uninhabited body of this primitive matcher.
    public typealias Body = Never

    /// The axes accepted during recognition.
    ///
    /// An empty set never matches.
    public let axes: Axis.Set

    /// The coordinate space requested for recognized locations.
    public let coordinateSpace: CoordinateSpace

    /// Creates a pointer-scroll matcher.
    ///
    /// - Parameters:
    ///   - axes: The accepted axes. The default accepts horizontal and vertical input.
    ///   - coordinateSpace: The coordinate space used for recognized locations.
    public init(
        _ axes: Axis.Set = [.horizontal, .vertical],
        coordinateSpace: CoordinateSpace = .local
    ) {
        self.axes = axes
        self.coordinateSpace = coordinateSpace
    }

    func matches(_ scroll: PointerScroll) -> Bool {
        !axes.intersection(scroll.axes).isEmpty
    }
}

/// Tries one input event and uses a fallback only when the first doesn't match.
public nonisolated struct ExclusiveInputEvent<First: InputEvent, Second: InputEvent>: InputEvent {

    /// A value recognized by the selected branch.
    public enum Value {

        /// A value recognized by the first event.
        case first(First.Value)

        /// A value recognized by the second event.
        case second(Second.Value)
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The event that receives the first opportunity to match.
    public let first: First

    /// The event evaluated only when `first` doesn't match.
    public let second: Second

    /// Creates an exclusive input-event composition.
    ///
    /// - Parameters:
    ///   - first: The event with the first matching opportunity.
    ///   - second: The fallback event.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

extension ExclusiveInputEvent: KeyEvent where First: KeyEvent, Second: KeyEvent {}

extension ExclusiveInputEvent: PointerEvent where First: PointerEvent, Second: PointerEvent {}

extension ExclusiveInputEvent.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

extension ExclusiveInputEvent.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

/// Offers the same raw input to two explicitly simultaneous input events.
public nonisolated struct SimultaneousInputEvent<First: InputEvent, Second: InputEvent>: InputEvent {

    /// The values recognized by the simultaneous branches.
    public struct Value {

        /// The first event's value, or `nil` when it didn't match.
        public let first: First.Value?

        /// The second event's value, or `nil` when it didn't match.
        public let second: Second.Value?

        /// Creates a simultaneous recognition value.
        ///
        /// - Parameters:
        ///   - first: The first event's optional value.
        ///   - second: The second event's optional value.
        public init(first: First.Value?, second: Second.Value?) {
            self.first = first
            self.second = second
        }
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The event evaluated first.
    public let first: First

    /// The event evaluated second even when the first handles the input.
    public let second: Second

    /// Creates a simultaneous input-event composition.
    ///
    /// - Parameters:
    ///   - first: The event evaluated first.
    ///   - second: The event evaluated second.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

extension SimultaneousInputEvent: KeyEvent where First: KeyEvent, Second: KeyEvent {}

extension SimultaneousInputEvent: PointerEvent where First: PointerEvent, Second: PointerEvent {}

extension SimultaneousInputEvent.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

extension SimultaneousInputEvent.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

/// Recognizes two input events on separate raw inputs in order.
public nonisolated struct SequenceInputEvent<First: InputEvent, Second: InputEvent>: InputEvent {

    /// The values retained when both sequence stages complete.
    public struct Value {

        /// The first stage's retained value.
        public let first: First.Value

        /// The second stage's completion value.
        public let second: Second.Value

        /// Creates a completed sequence value.
        ///
        /// - Parameters:
        ///   - first: The retained first-stage value.
        ///   - second: The second-stage value.
        public init(first: First.Value, second: Second.Value) {
            self.first = first
            self.second = second
        }
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The event that arms the sequence.
    public let first: First

    /// The event that completes an armed sequence on a later raw input.
    public let second: Second

    /// Creates a sequential input-event composition.
    ///
    /// - Parameters:
    ///   - first: The event that arms the sequence.
    ///   - second: The event that completes the sequence.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

extension SequenceInputEvent: KeyEvent where First: KeyEvent, Second: KeyEvent {}

extension SequenceInputEvent: PointerEvent where First: PointerEvent, Second: PointerEvent {}

extension SequenceInputEvent.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

extension SequenceInputEvent.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

extension InputEvent {

    /// Gives this event precedence over a fallback event.
    ///
    /// - Parameter other: The event tried only when this event doesn't match.
    /// - Returns: An exclusive input-event composition.
    public nonisolated func exclusively<Other: InputEvent>(
        before other: Other
    ) -> ExclusiveInputEvent<Self, Other> {
        ExclusiveInputEvent(self, other)
    }

    /// Offers each raw input to this event and another event as siblings.
    ///
    /// - Parameter other: The event evaluated after this event for the same input.
    /// - Returns: A simultaneous input-event composition.
    public nonisolated func simultaneously<Other: InputEvent>(
        with other: Other
    ) -> SimultaneousInputEvent<Self, Other> {
        SimultaneousInputEvent(self, other)
    }

    /// Requires this event before another event on a later raw input.
    ///
    /// - Parameter other: The event that completes the armed sequence.
    /// - Returns: A sequential input-event composition.
    public nonisolated func sequenced<Other: InputEvent>(
        before other: Other
    ) -> SequenceInputEvent<Self, Other> {
        SequenceInputEvent(self, other)
    }
}
