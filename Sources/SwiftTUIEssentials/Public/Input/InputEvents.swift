public import Foundation
public import Terminal

/// A frame of reference for zero-based terminal-cell coordinates reported by
/// pointer input APIs.
///
/// Use ``local`` for coordinates relative to the event view's rendered hit
/// region, ``global`` for coordinates relative to the rendered root, or
/// ``named(_:)`` for coordinates relative to a named ancestor.
///
/// Named values use `AnyHashable` behind an unchecked-sendable storage box.
/// The public `Sendable` conformance doesn't make mutable reference state
/// captured by an arbitrary hashable identifier concurrency-safe; use an
/// immutable sendable identifier when moving a coordinate space across tasks.
public nonisolated struct CoordinateSpace: Equatable, Hashable, Sendable {

    enum Storage: Equatable, Hashable, @unchecked Sendable {

        case local

        case global

        case named(AnyHashable)
    }

    let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    var name: AnyHashable? {
        guard case .named(let name) = storage else {
            return nil
        }

        return name
    }

    /// Coordinates whose origin is the top-leading cell of the event view's
    /// rendered hit region.
    public static let local = CoordinateSpace(storage: .local)

    /// Coordinates whose origin is the top-leading cell of the rendered root
    /// view.
    public static let global = CoordinateSpace(storage: .global)

    /// Creates a coordinate-space identifier that resolves against a named
    /// ancestor.
    ///
    /// Install the same value with ``View/coordinateSpace(_:)`` on an ancestor
    /// of the input handler. Reporting an event when no matching ancestor is
    /// rendered traps.
    ///
    /// - Parameter name: A hashable identifier compared using `AnyHashable`
    ///   equality.
    /// - Returns: A named coordinate-space identifier.
    public static func named<ID>(_ name: ID) -> CoordinateSpace where ID: Hashable {
        CoordinateSpace(storage: .named(AnyHashable(name)))
    }
}

/// A set of modifier flags reported with terminal key and pointer input.
///
/// Terminal protocols differ in which modifiers they can report. The presence
/// of a flag means SwiftTUI received that modifier; absence doesn't guarantee
/// that the physical modifier wasn't pressed.
public nonisolated struct EventModifiers: OptionSet, Sendable {

    /// The bit pattern backing this option set.
    public let rawValue: Int

    /// Creates modifier flags from a bit pattern.
    ///
    /// Unknown bits are preserved but aren't included in ``all``.
    ///
    /// - Parameter rawValue: The bit pattern to store.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The Caps Lock modifier.
    public static let capsLock = EventModifiers(rawValue: 1 << 0)

    /// The Shift modifier.
    public static let shift = EventModifiers(rawValue: 1 << 1)

    /// The Control modifier.
    public static let control = EventModifiers(rawValue: 1 << 2)

    /// The Option modifier.
    public static let option = EventModifiers(rawValue: 1 << 3)

    /// The Command modifier.
    public static let command = EventModifiers(rawValue: 1 << 4)

    /// The numeric keypad modifier.
    public static let numericPad = EventModifiers(rawValue: 1 << 5)

    /// The union of all modifier flags defined by this SwiftTUI version.
    public static let all: EventModifiers = [
        .capsLock,
        .shift,
        .control,
        .option,
        .command,
        .numericPad,
    ]
}

/// A key value that can be matched against keyboard input.
///
/// `KeyEquivalent` stores a single character. Special keys use Unicode scalar
/// values from the private-use/control ranges used by SwiftTUI's terminal input
/// parser. Constructing a value doesn't validate whether the active terminal
/// can generate that key.
public nonisolated struct KeyEquivalent: Equatable, Hashable, Sendable,
    ExpressibleByExtendedGraphemeClusterLiteral,
    ExpressibleByStringLiteral,
    ExpressibleByUnicodeScalarLiteral
{

    /// The single character represented by this key equivalent.
    public let character: Character

    /// Creates a key equivalent from one character.
    ///
    /// - Parameter character: The character to match.
    public init(_ character: Character) {
        self.character = character
    }

    /// Creates a key equivalent from a string literal containing one extended
    /// grapheme cluster.
    ///
    /// - Parameter value: The one-character literal to store.
    /// - Precondition: `value.count == 1`.
    public init(stringLiteral value: String) {
        self.init(Self.character(from: value))
    }

    /// Creates a key equivalent from one extended grapheme cluster literal.
    ///
    /// - Parameter value: The one-character literal to store.
    /// - Precondition: `value.count == 1`.
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(Self.character(from: value))
    }

    /// Creates a key equivalent from one Unicode scalar literal.
    ///
    /// - Parameter value: The one-character literal to store.
    /// - Precondition: `value.count == 1`.
    public init(unicodeScalarLiteral value: String) {
        self.init(Self.character(from: value))
    }

    /// The Up Arrow key.
    public static let upArrow = KeyEquivalent("\u{F700}")

    /// The Down Arrow key.
    public static let downArrow = KeyEquivalent("\u{F701}")

    /// The Left Arrow key.
    public static let leftArrow = KeyEquivalent("\u{F702}")

    /// The Right Arrow key.
    public static let rightArrow = KeyEquivalent("\u{F703}")

    /// The Clear key.
    public static let clear = KeyEquivalent("\u{F739}")

    /// The Delete or Backspace key.
    public static let delete = KeyEquivalent("\u{0008}")

    /// The Forward Delete key.
    public static let deleteForward = KeyEquivalent("\u{F728}")

    /// The End key.
    public static let end = KeyEquivalent("\u{F72B}")

    /// The Escape key.
    public static let escape = KeyEquivalent("\u{001B}")

    /// The Home key.
    public static let home = KeyEquivalent("\u{F729}")

    /// The Page Down key.
    public static let pageDown = KeyEquivalent("\u{F72D}")

    /// The Page Up key.
    public static let pageUp = KeyEquivalent("\u{F72C}")

    /// The Return key.
    public static let `return` = KeyEquivalent("\u{000D}")

    /// The Space key.
    public static let space = KeyEquivalent("\u{0020}")

    /// The Tab key.
    public static let tab = KeyEquivalent("\u{0009}")

    private static func character(from value: String) -> Character {
        precondition(value.count == 1, "KeyEquivalent requires exactly one character.")

        return value.first!
    }
}

/// A normalized terminal key event delivered through SwiftTUI input handling.
///
/// Focused handlers receive the event first, beginning at the focused view and
/// continuing through its ancestors until one returns ``Result/handled``.
/// Handlers at the same identity path run in registration order. If the focused
/// chain ignores the event, SwiftTUI offers it to global handlers, ordered by
/// deepest rendered path first and then registration order.
public nonisolated struct KeyPress: Equatable, Sendable {

    /// Options for matching different phases of a key-press event.
    public nonisolated struct Phases: OptionSet, Sendable {

        /// The bit pattern backing this option set.
        public let rawValue: Int

        /// Creates key-press phase flags from a bit pattern.
        ///
        /// Unknown bits are preserved but aren't included in ``all``.
        ///
        /// - Parameter rawValue: The bit pattern to store.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The initial key-down phase.
        public static let down = Phases(rawValue: 1 << 0)

        /// The key-up phase.
        public static let up = Phases(rawValue: 1 << 1)

        /// A repeated key-down phase generated while a key is held.
        public static let `repeat` = Phases(rawValue: 1 << 2)

        /// All key-press phases.
        public static let all: Phases = [.down, .up, .repeat]
    }

    /// Indicates whether a key handler stops or continues event propagation.
    public nonisolated enum Result: Equatable, Hashable, Sendable {

        /// The handler consumed the event and propagation should stop.
        case handled

        /// The handler didn't consume the event. Dispatch continues with later
        /// matching handlers registered at the same view path, then with
        /// matching ancestor handlers, and finally with global handlers.
        case ignored
    }

    /// The single normalized key used for key-equivalent matching.
    public let key: KeyEquivalent

    /// The text payload generated by the event.
    ///
    /// This string is empty when the event has no text representation and can
    /// contain more than one Unicode scalar for composed or protocol-provided
    /// input.
    public let characters: String

    /// The modifier keys active for this event.
    public let modifiers: EventModifiers

    /// The phase flag reported for this event.
    public let phase: Phases

    /// Creates a key-press event.
    ///
    /// - Parameters:
    ///   - key: The normalized key value.
    ///   - characters: The generated text payload, or an empty string for no
    ///     text.
    ///   - modifiers: The reported modifier flags. The default is no modifiers.
    ///   - phase: The event phase. The default is ``Phases/down``.
    public init(
        key: KeyEquivalent,
        characters: String,
        modifiers: EventModifiers = [],
        phase: Phases = .down
    ) {
        self.key = key
        self.characters = characters
        self.modifiers = modifiers
        self.phase = phase
    }
}

/// A terminal pointer button that can participate in pointer-press events.
public nonisolated enum PointerButton: Equatable, Hashable, Sendable {

    /// The primary pointer button.
    case left

    /// The middle pointer button.
    case middle

    /// The secondary pointer button.
    case right

    /// A terminal pointer button not represented by a named case.
    ///
    /// - Parameter button: The terminal protocol's button identifier.
    case other(Int)
}

/// A pointer button event delivered inside a view's rendered hit region.
public nonisolated struct PointerPress: Equatable, Sendable {

    /// Options for matching different phases of a pointer-press event.
    public nonisolated struct Phases: OptionSet, Sendable {

        /// The bit pattern backing this option set.
        public let rawValue: Int

        /// Creates pointer-press phase flags from a bit pattern.
        ///
        /// Unknown bits are preserved but aren't included in ``all``.
        ///
        /// - Parameter rawValue: The bit pattern to store.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The pointer button-down phase.
        public static let down = Phases(rawValue: 1 << 0)

        /// The pointer button-up phase.
        public static let up = Phases(rawValue: 1 << 1)

        /// All pointer-press phases.
        public static let all: Phases = [.down, .up]
    }

    /// Indicates whether a pointer-press handler stops propagation to later
    /// matching regions and handlers.
    public nonisolated enum Result: Equatable, Hashable, Sendable {

        /// The handler consumed the event and propagation should stop.
        case handled

        /// The handler didn't consume the event, allowing another matching
        /// handler or region to inspect it.
        case ignored
    }

    /// The normalized button associated with this event.
    public let button: PointerButton

    /// The zero-based terminal-cell location in the handler's requested
    /// coordinate space.
    public let location: Point

    /// The modifier keys active for this event.
    public let modifiers: EventModifiers

    /// The pointer-press phase.
    public let phase: Phases

    /// Creates a pointer-press event.
    ///
    /// - Parameters:
    ///   - button: The pointer button associated with this press.
    ///   - location: The zero-based terminal-cell pointer location in the
    ///     coordinate space chosen by the handler.
    ///   - modifiers: The reported modifier flags. The default is no modifiers.
    ///   - phase: The pointer-press phase.
    public init(
        button: PointerButton,
        location: Point,
        modifiers: EventModifiers = [],
        phase: Phases
    ) {
        self.button = button
        self.location = location
        self.modifiers = modifiers
        self.phase = phase
    }
}

/// The current terminal-cell hover state and pointer location.
public enum HoverPhase: Equatable, Sendable {

    /// The pointer entered or moved within the view at the specified zero-based
    /// terminal-cell location.
    case active(Point)

    /// The pointer exited the view.
    case ended
}


public extension View {

    /// Performs an action when this view recognizes a tap gesture.
    ///
    /// The view registers its rendered terminal frame as a hit region. Pointer
    /// events that complete the requested tap count inside that frame run the
    /// action. When the same hit region has handlers for larger tap counts,
    /// SwiftTUI can defer a smaller-count action briefly while waiting for the
    /// sequence to continue.
    ///
    /// - Parameters:
    ///   - count: The number of consecutive taps required. Must be at least one.
    ///   - action: The action to perform.
    /// - Returns: A view with a tap gesture handler attached.
    /// - Precondition: `count >= 1`.
    func onTapGesture(
        count: Int = 1,
        perform action: @escaping () -> Void
    ) -> some View {
        precondition(count >= 1, "onTapGesture count must be greater than zero.")

        return TapGestureView(
            content: self,
            handler: TapGestureHandler(
                actionPath: StateContext.currentPath,
                count: count,
                action: .plain(action)
            )
        )
    }

    /// Performs an action when this view recognizes a tap gesture, passing the
    /// tap location in the requested terminal-cell coordinate space.
    ///
    /// - Parameters:
    ///   - count: The number of consecutive taps required. Must be at least one.
    ///   - coordinateSpace: The coordinate space for the reported location.
    ///   - action: The action to perform with the tap location.
    /// - Returns: A view with a tap gesture handler attached.
    /// - Precondition: `count >= 1`.
    func onTapGesture(
        count: Int = 1,
        coordinateSpace: CoordinateSpace = .local,
        perform action: @escaping (Point) -> Void
    ) -> some View {
        precondition(count >= 1, "onTapGesture count must be greater than zero.")

        return TapGestureView(
            content: self,
            handler: TapGestureHandler(
                actionPath: StateContext.currentPath,
                count: count,
                action: .location(coordinateSpace, action)
            )
        )
    }

    /// Performs an action when the primary pointer button is pressed down
    /// inside this view's frame.
    ///
    /// - Parameter action: The action to perform for a matching pointer press.
    /// - Returns: A view with a pointer-press handler attached.
    nonisolated func onPointerPress(
        action: @escaping () -> PointerPress.Result
    ) -> some View {
        onPointerPress(.left, phases: .down, coordinateSpace: .local) {
            _ in

            action()
        }
    }

    /// Performs an action when matching pointer button presses occur inside
    /// this view's frame.
    ///
    /// The view registers its rendered terminal frame as a hit region. A
    /// ``PointerPress/Result/handled`` result stops later pointer-press handlers
    /// for the event. Pointer motion and scroll-wheel input don't produce
    /// pointer-press events.
    ///
    /// - Parameters:
    ///   - phases: The pointer-press phases to match. The default is
    ///     ``PointerPress/Phases/down``; an empty set never matches.
    ///   - buttons: The pointer buttons to match. The default contains only
    ///     ``PointerButton/left``; an empty set never matches.
    ///   - coordinateSpace: The coordinate space for reported zero-based
    ///     locations. The default is ``CoordinateSpace/local``.
    ///   - action: The action to perform for matching pointer presses.
    /// - Returns: A view with a pointer-press handler attached.
    @_disfavoredOverload
    nonisolated func onPointerPress(
        phases: PointerPress.Phases = .down,
        buttons: Set<PointerButton> = [.left],
        coordinateSpace: CoordinateSpace = .local,
        action: @escaping (PointerPress) -> PointerPress.Result
    ) -> some View {
        PointerPressView(
            content: self,
            handler: PointerPressHandler(
                actionPath: StateContext.currentPath,
                coordinateSpace: coordinateSpace,
                matches: {
                    buttons.contains($0.button) && phases.contains($0.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action when the specified pointer button is pressed down
    /// inside this view's frame.
    ///
    /// - Parameters:
    ///   - button: The pointer button to match.
    ///   - action: The action to perform for a matching pointer press.
    /// - Returns: A view with a pointer-press handler attached.
    nonisolated func onPointerPress(
        _ button: PointerButton,
        action: @escaping () -> PointerPress.Result
    ) -> some View {
        onPointerPress(button, phases: .down, coordinateSpace: .local) {
            _ in

            action()
        }
    }

    /// Performs an action when the specified pointer button and phases occur
    /// inside this view's frame.
    ///
    /// - Parameters:
    ///   - button: The pointer button to match.
    ///   - phases: The pointer-press phases to match. An empty set never
    ///     matches.
    ///   - coordinateSpace: The coordinate space for reported zero-based
    ///     locations. The default is ``CoordinateSpace/local``.
    ///   - action: The action to perform for matching pointer presses.
    /// - Returns: A view with a pointer-press handler attached.
    nonisolated func onPointerPress(
        _ button: PointerButton,
        phases: PointerPress.Phases,
        coordinateSpace: CoordinateSpace = .local,
        action: @escaping (PointerPress) -> PointerPress.Result
    ) -> some View {
        onPointerPress(
            buttons: [button],
            phases: phases,
            coordinateSpace: coordinateSpace,
            action: action
        )
    }

    /// Performs an action when any of the specified pointer buttons and phases
    /// occur inside this view's frame.
    ///
    /// - Parameters:
    ///   - buttons: The pointer buttons to match. An empty set never matches.
    ///   - phases: The pointer-press phases to match. The default is
    ///     ``PointerPress/Phases/down``; an empty set never matches.
    ///   - coordinateSpace: The coordinate space for reported zero-based
    ///     locations. The default is ``CoordinateSpace/local``.
    ///   - action: The action to perform for matching pointer presses.
    /// - Returns: A view with a pointer-press handler attached.
    nonisolated func onPointerPress(
        buttons: Set<PointerButton>,
        phases: PointerPress.Phases = .down,
        coordinateSpace: CoordinateSpace = .local,
        action: @escaping (PointerPress) -> PointerPress.Result
    ) -> some View {
        onPointerPress(
            phases: phases,
            buttons: buttons,
            coordinateSpace: coordinateSpace,
            action: action
        )
    }

    /// Performs an action when the pointer enters or exits this view's frame.
    ///
    /// The view registers its rendered terminal frame as a hover region. The
    /// action receives `true` once when pointer motion enters the region and
    /// `false` when later motion exits it. Movement that remains inside the
    /// region doesn't repeatedly invoke this Boolean form.
    ///
    /// - Parameter action: The action to perform with the current hover state.
    /// - Returns: A view with a hover handler attached.
    func onHover(perform action: @escaping (Bool) -> Void) -> some View {
        HoverGestureView(
            content: self,
            handler: HoverGestureHandler(
                actionPath: StateContext.currentPath,
                action: .state(action)
            )
        )
    }

    /// Performs an action when the pointer enters, moves within, or exits this
    /// view's frame.
    ///
    /// SwiftTUI emits ``HoverPhase/active(_:)`` on entry and subsequent pointer
    /// motion within the region, then ``HoverPhase/ended`` on exit. Active
    /// phases report zero-based terminal-cell coordinates in the requested
    /// coordinate space.
    ///
    /// - Parameters:
    ///   - coordinateSpace: The coordinate space for active hover locations.
    ///   - action: The action to perform with each hover phase.
    /// - Returns: A view with a continuous hover handler attached.
    func onContinuousHover(
        coordinateSpace: CoordinateSpace = .local,
        perform action: @escaping (HoverPhase) -> Void
    ) -> some View {
        HoverGestureView(
            content: self,
            handler: HoverGestureHandler(
                actionPath: StateContext.currentPath,
                action: .phase(coordinateSpace, action)
            )
        )
    }

    /// Adds an action to perform when this view recognizes a long press gesture.
    ///
    /// The view registers its rendered terminal frame as a hit region. Pointer
    /// events that keep the primary button pressed inside the allowed movement
    /// extent for at least `minimumDuration` run the action. Distance is tested
    /// independently along the terminal column and row axes rather than as a
    /// Euclidean radius.
    ///
    /// - Parameters:
    ///   - minimumDuration: The minimum duration of the long press, in seconds.
    ///     Negative values are treated as zero.
    ///   - maximumDistance: The maximum terminal-cell column and row extents
    ///     the press can move before the gesture fails. Negative components are
    ///     treated as zero. The default allows no cell movement.
    ///   - action: The action to perform when the long press is recognized.
    ///   - onPressingChanged: An optional closure that receives `true` on a
    ///     matching pointer-down and `false` on release, cancellation, or
    ///     movement beyond the allowed extent.
    /// - Returns: A view with a long-press gesture handler attached.
    func onLongPressGesture(
        minimumDuration: Double = 0.5,
        maximumDistance: Size = .zero,
        perform action: @escaping () -> Void,
        onPressingChanged: ((Bool) -> Void)? = nil
    ) -> some View {
        let normalizedMaximumDistance = Size(
            columns: max(maximumDistance.columns, 0),
            rows: max(maximumDistance.rows, 0)
        )
        return LongPressGestureView(
            content: self,
            handler: LongPressGestureHandler(
                actionPath: StateContext.currentPath,
                minimumDuration: max(minimumDuration, 0),
                maximumDistance: normalizedMaximumDistance,
                action: action,
                onPressingChanged: onPressingChanged
            )
        )
    }

    /// Assigns a name to this view's local coordinate space.
    ///
    /// Descendant pointer-location handlers can request coordinates relative to
    /// this view by using the same value returned from
    /// ``CoordinateSpace/named(_:)``. If nested ancestors reuse a name, the
    /// nearest matching ancestor supplies the origin.
    ///
    /// - Parameter name: A named coordinate-space value.
    /// - Returns: A view that registers the named space at its rendered bounds.
    /// - Precondition: `name` was created with ``CoordinateSpace/named(_:)``;
    ///   passing ``CoordinateSpace/local`` or ``CoordinateSpace/global`` traps.
    func coordinateSpace(_ name: CoordinateSpace) -> some View {
        precondition(name.name != nil, "coordinateSpace(_:) requires a named coordinate space.")

        return CoordinateSpaceView(content: self, coordinateSpace: name)
    }

    /// Performs an action for a matching key in this view's focused dispatch
    /// chain.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - action: The action to perform for matching key-down or repeat events.
    ///     Return ``KeyPress/Result/handled`` to stop ancestor and global
    ///     propagation.
    /// - Returns: A view with a focused key handler attached.
    nonisolated func onKeyPress(
        _ key: KeyEquivalent,
        action: @escaping () -> KeyPress.Result
    ) -> some View {
        onKeyPress(key, phases: [.down, .repeat]) {
            _ in

            action()
        }
    }

    /// Performs an action for any matching key phase in this view's focused
    /// dispatch chain.
    ///
    /// - Parameters:
    ///   - phases: The key phases to match. The default matches key-down and
    ///     repeat; an empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a focused key handler attached.
    nonisolated func onKeyPress(
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        KeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: {
                    phases.contains($0.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action for a matching key and phase in this view's focused
    /// dispatch chain.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - phases: The key phases to match. An empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a focused key handler attached.
    nonisolated func onKeyPress(
        _ key: KeyEquivalent,
        phases: KeyPress.Phases,
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        onKeyPress(keys: [key], phases: phases, action: action)
    }

    /// Performs an action for any key in a set while this view participates in
    /// focused dispatch.
    ///
    /// - Parameters:
    ///   - keys: The set of keys to match. An empty set never matches.
    ///   - phases: The key phases to match. The default matches key-down and
    ///     repeat; an empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a focused key handler attached.
    nonisolated func onKeyPress(
        keys: Set<KeyEquivalent>,
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        KeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: {
                    keys.contains($0.key) && phases.contains($0.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action for focused key events whose nonempty text payload
    /// contains only Unicode scalars in a character set.
    ///
    /// - Parameters:
    ///   - characters: The character set that all generated Unicode scalars
    ///     must belong to.
    ///   - phases: The key phases to match. The default matches key-down and
    ///     repeat; an empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a focused key handler attached.
    nonisolated func onKeyPress(
        characters: CharacterSet,
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        KeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: { keyPress in
                    !keyPress.characters.isEmpty
                        && keyPress.characters.unicodeScalars.allSatisfy {
                            characters.contains($0)
                        }
                        && phases.contains(keyPress.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action for a matching key after focused dispatch ignores the
    /// event.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - action: The action to perform for matching key-down or repeat events.
    ///     Return ``KeyPress/Result/handled`` to stop later global handlers.
    /// - Returns: A view with a global key handler attached.
    func onGlobalKeyPress(
        _ key: KeyEquivalent,
        action: @escaping () -> KeyPress.Result
    ) -> some View {
        onGlobalKeyPress(key, phases: [.down, .repeat]) {
            _ in

            action()
        }
    }

    /// Performs an action for any matching key phase after focused dispatch
    /// ignores the event.
    ///
    /// - Parameters:
    ///   - phases: The key phases to match. The default matches key-down and
    ///     repeat; an empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a global key handler attached.
    func onGlobalKeyPress(
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        GlobalKeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: {
                    phases.contains($0.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action for a matching key and phase after focused dispatch
    /// ignores the event.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - phases: The key phases to match. An empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a global key handler attached.
    func onGlobalKeyPress(
        _ key: KeyEquivalent,
        phases: KeyPress.Phases,
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        onGlobalKeyPress(keys: [key], phases: phases, action: action)
    }

    /// Performs an action for any key in a set after focused dispatch ignores
    /// the event.
    ///
    /// - Parameters:
    ///   - keys: The set of keys to match. An empty set never matches.
    ///   - phases: The key phases to match. The default matches key-down and
    ///     repeat; an empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a global key handler attached.
    func onGlobalKeyPress(
        keys: Set<KeyEquivalent>,
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        GlobalKeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: {
                    keys.contains($0.key) && phases.contains($0.phase)
                },
                action: action
            )
        )
    }

    /// Performs an action after focused dispatch for key events whose nonempty
    /// text payload contains only Unicode scalars in a character set.
    ///
    /// - Parameters:
    ///   - characters: The character set that all generated Unicode scalars
    ///     must belong to.
    ///   - phases: The key phases to match. The default matches key-down and
    ///     repeat; an empty set never matches.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a global key handler attached.
    func onGlobalKeyPress(
        characters: CharacterSet,
        phases: KeyPress.Phases = [.down, .repeat],
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        GlobalKeyPressView(
            content: self,
            handler: KeyPressHandler(
                actionPath: StateContext.currentPath,
                matches: { keyPress in
                    !keyPress.characters.isEmpty
                        && keyPress.characters.unicodeScalars.allSatisfy {
                            characters.contains($0)
                        }
                        && phases.contains(keyPress.phase)
                },
                action: action
            )
        )
    }
}
