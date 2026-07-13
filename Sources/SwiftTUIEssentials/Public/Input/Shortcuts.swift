/// A declarative recognizer that produces values from logical key sequences.
///
/// A shortcut stores recognition configuration independently of low-level
/// ``KeyEvent`` matching. Attach a shortcut to a view to participate in
/// focused shortcut routing, or compose it with other shortcuts before
/// attachment. With focus, only shortcuts on the root-to-focus path are
/// eligible; without focus, only shortcuts attached directly at the rendered
/// root are eligible. Primitive shortcuts use `Never` as their body.
///
/// Shortcut success claims competing shortcut attachments but doesn't consume
/// the underlying key sample. Low-level key events, focused and global key
/// handlers, and key resolution can continue to observe that sample.
///
/// ```swift
/// struct SaveShortcut: Shortcut {
///     typealias Value = Void
///
///     var body: some Shortcut<Void> {
///         TapShortcut("s", modifiers: .control)
///     }
/// }
///
/// Text("Editor")
///     .shortcut(
///         SaveShortcut().onEnded {
///             print("Save")
///         }
///     )
/// ```
@MainActor
@preconcurrency
public protocol Shortcut<Value> {

    /// The value produced as the shortcut recognizes or completes.
    associatedtype Value

    /// The shortcut that defines this shortcut's recognition behavior.
    associatedtype Body: Shortcut

    /// The shortcut's declarative composition.
    ///
    /// SwiftTUI can reevaluate a custom body during rendering, so callers must
    /// not rely on evaluation for side effects. Primitive shortcuts receive an
    /// uninhabited default implementation that must not be evaluated.
    var body: Body { get }

    /// Lowers this shortcut into SwiftTUI's recognition graph.
    ///
    /// SwiftTUI supplies this implementation for custom shortcuts whose
    /// `Value` equals `Body.Value`. This underscored public witness enforces
    /// that relationship during conformance checking without runtime casts.
    /// Pass shortcuts to a view attachment instead of calling this hook
    /// directly.
    func _makeShortcut() -> _ShortcutDefinition<Value>
}

extension Shortcut where Body == Never {

    /// Marks a primitive shortcut as having no composed body.
    ///
    /// - Precondition: This property must not be evaluated.
    public var body: Never {
        fatalError("Primitive shortcuts do not have a body.")
    }
}

/// Makes `Never` the terminal body of primitive shortcuts.
extension Never: Shortcut {}

/// Recognizes one or more completed presses of a logical key combination.
///
/// A press starts with an exactly matching key-down and completes with an
/// exactly matching key-up. Repeat phases never increase ``count``. Consecutive
/// presses must complete no more than 0.5 seconds apart; unrelated keys don't
/// clear a partial count before that deadline. A new key-down before the active
/// press ends supersedes that press.
public nonisolated struct TapShortcut: Shortcut, Equatable, Sendable {

    /// The completion value produced by a tap shortcut.
    public typealias Value = Void

    /// The uninhabited body of this primitive shortcut.
    public typealias Body = Never

    /// The normalized logical key required for recognition.
    public var key: KeyEquivalent

    /// The modifier set required on every participating phase.
    public var modifiers: EventModifiers

    /// The number of completed presses required for recognition.
    public var count: Int

    /// Creates a tap shortcut.
    ///
    /// - Parameters:
    ///   - key: The normalized logical key to recognize.
    ///   - modifiers: The exact modifier set required on key-down, repeat, and
    ///     key-up. The default requires no modifiers.
    ///   - count: The number of consecutive presses required. The default is
    ///     one.
    /// - Precondition: `count >= 1`.
    public init(
        _ key: KeyEquivalent,
        modifiers: EventModifiers = [],
        count: Int = 1
    ) {
        precondition(count >= 1, "TapShortcut count must be greater than zero.")
        self.key = key
        self.modifiers = modifiers
        self.count = count
    }
}

/// Recognizes a logical key combination held for a minimum duration.
///
/// Recognition starts from an exactly matching key-down. Repeat phases keep
/// the press active without producing additional changed values or completion
/// actions. Releasing the key before ``minimumDuration`` causes failure. A
/// phase with different modifiers doesn't terminate the active press, while a
/// new key-down supersedes it.
public nonisolated struct LongPressShortcut: Shortcut, Equatable, Sendable {

    /// The Boolean value produced while the shortcut is pressing and when it succeeds.
    public typealias Value = Bool

    /// The uninhabited body of this primitive shortcut.
    public typealias Body = Never

    /// The normalized logical key required for recognition.
    public var key: KeyEquivalent

    /// The modifier set required on every participating phase.
    public var modifiers: EventModifiers

    /// The duration in seconds that the key must remain pressed.
    public var minimumDuration: Double

    /// Creates a long-press shortcut.
    ///
    /// - Parameters:
    ///   - key: The normalized logical key to recognize.
    ///   - modifiers: The exact modifier set required on key-down, repeat, and
    ///     key-up. The default requires no modifiers.
    ///   - minimumDuration: The required hold duration in seconds. Negative
    ///     values are treated as zero. The default is `0.5`.
    public init(
        _ key: KeyEquivalent,
        modifiers: EventModifiers = [],
        minimumDuration: Double = 0.5
    ) {
        self.key = key
        self.modifiers = modifiers
        self.minimumDuration = max(minimumDuration, 0)
    }
}

/// Transient state whose lifetime is tied to an attached shortcut sequence.
///
/// After the state is updated, SwiftTUI restores its initial value exactly once
/// after success, failure, competition loss, disabling, removal, configuration
/// replacement, focus or scene loss, or input-session shutdown. Assignments are
/// performed only by a shortcut's ``Shortcut/updating(_:body:)`` closure.
@propertyWrapper
public struct ShortcutState<Value>: DynamicProperty {

    let storage: RecognitionStateStorage<Value>

    /// The current transient shortcut value.
    public var wrappedValue: Value {
        storage.value
    }

    /// The shortcut state value used by ``Shortcut/updating(_:body:)``.
    public var projectedValue: ShortcutState<Value> {
        self
    }

    /// Creates shortcut state with an initial value.
    ///
    /// - Parameter value: The value restored when recognition ends.
    public init(wrappedValue value: Value) {
        storage = RecognitionStateStorage(
            initialValue: value,
            resetTransaction: Transaction(),
            resetAction: nil
        )
    }

    /// Creates shortcut state with an initial value.
    ///
    /// - Parameter value: The value restored when recognition ends.
    public init(initialValue value: Value) {
        self.init(wrappedValue: value)
    }

    /// Creates shortcut state with a transaction used for automatic reset.
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

    /// Creates shortcut state with a transaction used for automatic reset.
    ///
    /// - Parameters:
    ///   - value: The value restored when recognition ends.
    ///   - resetTransaction: The transaction supplied during reset.
    public init(initialValue value: Value, resetTransaction: Transaction) {
        self.init(wrappedValue: value, resetTransaction: resetTransaction)
    }

    /// Creates shortcut state with a reset callback.
    ///
    /// The callback receives the final transient value and a mutable
    /// noncontinuous transaction before SwiftTUI restores the initial value.
    ///
    /// - Parameters:
    ///   - value: The value restored when recognition ends.
    ///   - reset: The callback performed once after an updated sequence ends
    ///     or is cancelled.
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

    /// Creates shortcut state with a reset callback.
    ///
    /// - Parameters:
    ///   - value: The value restored when recognition ends.
    ///   - reset: The callback performed once after an updated sequence ends
    ///     or is cancelled.
    public init(
        initialValue value: Value,
        reset: @escaping (Value, inout Transaction) -> Void
    ) {
        self.init(wrappedValue: value, reset: reset)
    }
}

extension ShortcutState where Value: ExpressibleByNilLiteral {

    /// Creates shortcut state whose initial value is `nil`.
    public init() {
        self.init(wrappedValue: nil)
    }
}

extension ShortcutState: DynamicStateProperty {

    func materialize() {
        storage.materialize()
    }
}

/// Updates transient shortcut state while forwarding the base shortcut's value.
public struct ShortcutStateShortcut<Base: Shortcut, State>: Shortcut {

    /// The value forwarded from the base shortcut.
    public typealias Value = Base.Value

    /// The uninhabited body of this primitive shortcut node.
    public typealias Body = Never

    /// The shortcut whose samples update state.
    public let base: Base

    /// The transient state updated for each changed sample.
    public let state: ShortcutState<State>

    /// The callback that mutates transient state for a recognized sample.
    public let update: (Value, inout State, inout Transaction) -> Void

    /// Creates a shortcut-state update node.
    ///
    /// - Parameters:
    ///   - base: The shortcut supplying values.
    ///   - state: The transient state to update.
    ///   - update: The mutation applied for each changed sample.
    public init(
        base: Base,
        state: ShortcutState<State>,
        update: @escaping (Value, inout State, inout Transaction) -> Void
    ) {
        self.base = base
        self.state = state
        self.update = update
    }
}

struct ChangedShortcut<Base: Shortcut>: Shortcut where Base.Value: Equatable {

    typealias Value = Base.Value

    typealias Body = Never

    let base: Base

    let action: (Value) -> Void
}

struct EndedShortcut<Base: Shortcut>: Shortcut {

    typealias Value = Base.Value

    typealias Body = Never

    let base: Base

    let action: (Value) -> Void
}

extension Shortcut where Value: Equatable {

    /// Performs an action when a shortcut's changed value differs from its prior value.
    ///
    /// - Parameter action: The action performed for distinct changed values.
    /// - Returns: A shortcut that observes changed values.
    public func onChanged(
        _ action: @escaping (Value) -> Void
    ) -> some Shortcut<Value> {
        ChangedShortcut(base: self, action: action)
    }
}

extension Shortcut {

    /// Performs an action only after successful shortcut recognition.
    ///
    /// Failure and cancellation don't invoke the action. Completion claims
    /// competition only among shortcuts; low-level key handlers can continue
    /// to observe the input.
    ///
    /// - Parameter action: The action performed with the successful value.
    /// - Returns: A shortcut that observes successful completion.
    public func onEnded(
        _ action: @escaping (Value) -> Void
    ) -> some Shortcut<Value> {
        EndedShortcut(base: self, action: action)
    }

    /// Updates transient state before changed-value callbacks run.
    ///
    /// - Parameters:
    ///   - state: The shortcut state to update.
    ///   - body: The mutation performed with the shortcut value and transaction.
    /// - Returns: A shortcut that updates transient state for each changed sample.
    public func updating<State>(
        _ state: ShortcutState<State>,
        body: @escaping (Value, inout State, inout Transaction) -> Void
    ) -> ShortcutStateShortcut<Self, State> {
        ShortcutStateShortcut(base: self, state: state, update: body)
    }
}

extension View {

    /// Performs an action after one or more completed presses of a logical key combination.
    ///
    /// View-defined shortcuts compete along the focused path. For the same key
    /// combination, an inner tap count receives the first opportunity to
    /// recognize. If its count isn't reached before the inter-press timeout,
    /// the nearest fallback matching the completed count can run.
    ///
    /// - Parameters:
    ///   - key: The normalized logical key to recognize.
    ///   - modifiers: The exact modifier set required on every phase. The
    ///     default requires no modifiers.
    ///   - count: The number of completed presses required. Must be at least
    ///     one.
    ///   - action: The action performed after recognition succeeds.
    /// - Returns: A view with a view-defined tap shortcut.
    /// - Precondition: `count >= 1`.
    public func onTapShortcut(
        _ key: KeyEquivalent,
        modifiers: EventModifiers = [],
        count: Int = 1,
        perform action: @escaping () -> Void
    ) -> some View {
        precondition(count >= 1, "onTapShortcut count must be greater than zero.")
        return TapShortcutView(
            content: self,
            handler: TapShortcutHandler(
                actionPath: StateContext.currentPath,
                key: key,
                modifiers: modifiers,
                count: count,
                action: action
            )
        )
    }

    /// Performs an action after a logical key combination remains pressed for a duration.
    ///
    /// Long-press shortcuts for the same key combination compete by deadline;
    /// the shortest duration wins, with the innermost modifier breaking ties.
    /// Releasing before a winner's deadline lets an eligible tap shortcut
    /// recognize as a fallback.
    ///
    /// - Parameters:
    ///   - key: The normalized logical key to recognize.
    ///   - modifiers: The exact modifier set required on every phase. The
    ///     default requires no modifiers.
    ///   - minimumDuration: The required hold duration in seconds. Negative
    ///     values are treated as zero. The default is `0.5`.
    ///   - action: The action performed after recognition succeeds.
    ///   - onPressingChanged: An optional callback that receives `true` on a
    ///     matching key-down and `false` on matching key-up or cancellation.
    ///     Each transition is delivered at most once per press sequence.
    /// - Returns: A view with a view-defined long-press shortcut.
    public func onLongPressShortcut(
        _ key: KeyEquivalent,
        modifiers: EventModifiers = [],
        minimumDuration: Double = 0.5,
        perform action: @escaping () -> Void,
        onPressingChanged: ((Bool) -> Void)? = nil
    ) -> some View {
        LongPressShortcutView(
            content: self,
            handler: LongPressShortcutHandler(
                actionPath: StateContext.currentPath,
                key: key,
                modifiers: modifiers,
                minimumDuration: max(minimumDuration, 0),
                action: action,
                onPressingChanged: onPressingChanged
            )
        )
    }
}

/// Gives one shortcut precedence and falls back only after recognition failure.
///
/// The second shortcut receives the samples retained by the first branch only
/// when that branch reports failure. External cancellation doesn't activate
/// the fallback.
public nonisolated struct ExclusiveShortcut<First: Shortcut, Second: Shortcut>:
    Shortcut
{

    /// A value produced by the branch that succeeds.
    public enum Value {

        /// A successful value from the first shortcut.
        case first(First.Value)

        /// A successful value from the second shortcut.
        case second(Second.Value)
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The shortcut with the first opportunity to recognize.
    public let first: First

    /// The shortcut enabled only after the first shortcut fails.
    public let second: Second

    /// Creates an exclusive shortcut composition.
    ///
    /// - Parameters:
    ///   - first: The shortcut with precedence.
    ///   - second: The shortcut used after recognition failure.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

/// Provides value equality when both exclusive shortcut branches are equatable.
extension ExclusiveShortcut: Equatable where First: Equatable, Second: Equatable {}

/// Makes an exclusive shortcut transferable when both branches are transferable.
extension ExclusiveShortcut: Sendable where First: Sendable, Second: Sendable {}

/// Provides value equality when both exclusive shortcut results are equatable.
extension ExclusiveShortcut.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

/// Makes an exclusive shortcut result transferable when both results are transferable.
extension ExclusiveShortcut.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

/// Runs two shortcuts independently against the same logical key sequence.
///
/// A completed child value is retained until its sibling terminates. Key-up
/// terminates a sibling that never participated in the logical press sequence.
public nonisolated struct SimultaneousShortcut<First: Shortcut, Second: Shortcut>:
    Shortcut
{

    /// The final optional values from both shortcut branches.
    public struct Value {

        /// The first shortcut's last successful value, if any.
        public let first: First.Value?

        /// The second shortcut's last successful value, if any.
        public let second: Second.Value?

        /// Creates a simultaneous shortcut value.
        ///
        /// - Parameters:
        ///   - first: The first shortcut's optional value.
        ///   - second: The second shortcut's optional value.
        public init(first: First.Value?, second: Second.Value?) {
            self.first = first
            self.second = second
        }
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The first independently recognizing shortcut.
    public let first: First

    /// The second independently recognizing shortcut.
    public let second: Second

    /// Creates a simultaneous shortcut composition.
    ///
    /// - Parameters:
    ///   - first: The first shortcut.
    ///   - second: The second shortcut.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

/// Provides value equality when both simultaneous shortcut branches are equatable.
extension SimultaneousShortcut: Equatable where First: Equatable, Second: Equatable {}

/// Makes a simultaneous shortcut transferable when both branches are transferable.
extension SimultaneousShortcut: Sendable where First: Sendable, Second: Sendable {}

/// Provides value equality when both simultaneous shortcut results are equatable.
extension SimultaneousShortcut.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

/// Makes a simultaneous shortcut result transferable when both results are transferable.
extension SimultaneousShortcut.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

/// Requires one shortcut to succeed before a second shortcut can recognize.
///
/// The second shortcut begins with the sample after first-stage success. The
/// sequence adds no timeout and stays armed until the second stage succeeds,
/// fails, or the attachment is cancelled.
public nonisolated struct SequenceShortcut<First: Shortcut, Second: Shortcut>:
    Shortcut
{

    /// The current successful stage of a shortcut sequence.
    public enum Value {

        /// The first shortcut has succeeded and the second is active.
        case first(First.Value)

        /// The sequence retains the first value and optionally reports a second value.
        case second(First.Value, Second.Value?)
    }

    /// The uninhabited body of this primitive composition node.
    public typealias Body = Never

    /// The shortcut that must succeed first.
    public let first: First

    /// The shortcut enabled after the first succeeds.
    public let second: Second

    /// Creates a sequential shortcut composition.
    ///
    /// - Parameters:
    ///   - first: The shortcut that must succeed first.
    ///   - second: The shortcut enabled after first-stage success.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }
}

/// Provides value equality when both sequential shortcut branches are equatable.
extension SequenceShortcut: Equatable where First: Equatable, Second: Equatable {}

/// Makes a sequential shortcut transferable when both branches are transferable.
extension SequenceShortcut: Sendable where First: Sendable, Second: Sendable {}

/// Provides value equality when both sequential shortcut results are equatable.
extension SequenceShortcut.Value: Equatable
where First.Value: Equatable, Second.Value: Equatable {}

/// Makes a sequential shortcut result transferable when both results are transferable.
extension SequenceShortcut.Value: Sendable
where First.Value: Sendable, Second.Value: Sendable {}

extension Shortcut {

    /// Gives this shortcut precedence over a fallback shortcut.
    ///
    /// - Parameter other: The shortcut enabled after this shortcut fails.
    /// - Returns: An exclusive shortcut composition.
    public nonisolated func exclusively<Other: Shortcut>(
        before other: Other
    ) -> ExclusiveShortcut<Self, Other> {
        ExclusiveShortcut(self, other)
    }

    /// Runs this shortcut and another shortcut independently.
    ///
    /// - Parameter other: The simultaneous shortcut sibling.
    /// - Returns: A simultaneous shortcut composition.
    public nonisolated func simultaneously<Other: Shortcut>(
        with other: Other
    ) -> SimultaneousShortcut<Self, Other> {
        SimultaneousShortcut(self, other)
    }

    /// Requires this shortcut before another shortcut.
    ///
    /// The first value remains armed until the second shortcut succeeds,
    /// fails, or the attachment is cancelled; no extra sequence timeout is
    /// introduced.
    ///
    /// - Parameter other: The shortcut enabled after this shortcut succeeds.
    /// - Returns: A sequential shortcut composition.
    public nonisolated func sequenced<Other: Shortcut>(
        before other: Other
    ) -> SequenceShortcut<Self, Other> {
        SequenceShortcut(self, other)
    }
}
