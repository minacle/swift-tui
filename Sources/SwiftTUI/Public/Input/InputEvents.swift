public import Foundation
public import Terminal

/// A frame of reference for terminal-cell coordinates.
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

    /// The local coordinate space of the current view.
    public static let local = CoordinateSpace(storage: .local)

    /// The global coordinate space at the root of the view hierarchy.
    public static let global = CoordinateSpace(storage: .global)

    /// Creates a named coordinate space.
    public static func named<ID>(_ name: ID) -> CoordinateSpace where ID: Hashable {
        CoordinateSpace(storage: .named(AnyHashable(name)))
    }
}

/// A set of key modifiers that can accompany an input event.
public nonisolated struct EventModifiers: OptionSet, Sendable {

    /// The raw option-set storage value.
    public let rawValue: Int

    /// Creates modifier options from a raw option-set value.
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

    /// All known key modifiers.
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
/// parser.
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

    /// Creates a key equivalent from a one-character string literal.
    public init(stringLiteral value: String) {
        self.init(Self.character(from: value))
    }

    /// Creates a key equivalent from an extended grapheme cluster literal.
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(Self.character(from: value))
    }

    /// Creates a key equivalent from a Unicode scalar literal.
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

/// A hardware keyboard event delivered to a focused view.
public nonisolated struct KeyPress: Equatable, Sendable {

    /// Options for matching different phases of a key-press event.
    public nonisolated struct Phases: OptionSet, Sendable {

        /// The raw option-set storage value.
        public let rawValue: Int

        /// Creates key-press phases from a raw option-set value.
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

    /// A result value that indicates whether an action consumed the event.
    public nonisolated enum Result: Equatable, Hashable, Sendable {

        /// The handler consumed the event and propagation should stop.
        case handled

        /// The handler did not consume the event.
        case ignored
    }

    /// The normalized key value.
    public let key: KeyEquivalent

    /// The text characters generated by the key press, if any.
    public let characters: String

    /// The modifier keys active for this event.
    public let modifiers: EventModifiers

    /// The key-press phase.
    public let phase: Phases

    /// Creates a key-press event.
    ///
    /// - Parameters:
    ///   - key: The normalized key value.
    ///   - characters: The generated text characters, if any.
    ///   - modifiers: The active modifier keys.
    ///   - phase: The key-press phase.
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

/// The current terminal-cell hover state and pointer location.
public enum HoverPhase: Equatable, Sendable {

    /// The pointer is inside the view at the specified terminal-cell location.
    case active(Point)

    /// The pointer exited the view.
    case ended
}


public extension View {

    /// Performs an action when this view recognizes a tap gesture.
    ///
    /// The view registers its rendered terminal frame as a hit region. Mouse
    /// input that completes the requested tap count inside that frame runs the
    /// action.
    ///
    /// - Parameters:
    ///   - count: The number of consecutive taps required. Must be at least one.
    ///   - action: The action to perform.
    /// - Returns: A view with a tap gesture handler attached.
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

    /// Performs an action when the pointer enters or exits this view's frame.
    ///
    /// The view registers its rendered terminal frame as a hover region. Mouse
    /// motion inside that frame passes `true`; motion outside after entry
    /// passes `false`.
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
    /// The active phase reports terminal-cell coordinates in the requested
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
    /// The view registers its rendered terminal frame as a hit region. Mouse
    /// input that remains pressed inside the allowed movement distance for at
    /// least `minimumDuration` runs the action.
    ///
    /// - Parameters:
    ///   - minimumDuration: The minimum duration of the long press.
    ///   - maximumDistance: The maximum terminal-cell extent the press can move
    ///     before the gesture fails.
    ///   - action: The action to perform when the long press is recognized.
    ///   - onPressingChanged: A closure to run when pressing starts or ends.
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
    /// Descendant tap-location handlers can request coordinates relative to
    /// this view by using ``CoordinateSpace/named(_:)``.
    func coordinateSpace(_ name: CoordinateSpace) -> some View {
        precondition(name.name != nil, "coordinateSpace(_:) requires a named coordinate space.")

        return CoordinateSpaceView(content: self, coordinateSpace: name)
    }

    /// Performs an action if the user presses a key while this view has focus.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - action: The action to perform for matching key-down or repeat events.
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

    /// Performs an action if the user presses any key while this view has focus.
    ///
    /// - Parameters:
    ///   - phases: The key phases to match.
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

    /// Performs an action if the user presses a key while this view has focus.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - phases: The key phases to match.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a focused key handler attached.
    nonisolated func onKeyPress(
        _ key: KeyEquivalent,
        phases: KeyPress.Phases,
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        onKeyPress(keys: [key], phases: phases, action: action)
    }

    /// Performs an action if the user presses one or more keys while this view has focus.
    ///
    /// - Parameters:
    ///   - keys: The set of keys to match.
    ///   - phases: The key phases to match.
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

    /// Performs an action if the user presses keys that generate matching characters.
    ///
    /// - Parameters:
    ///   - characters: The character set that all generated Unicode scalars
    ///     must belong to.
    ///   - phases: The key phases to match.
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

    /// Performs an action if the user presses a key, regardless of focus.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - action: The action to perform for matching key-down or repeat events.
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

    /// Performs an action if the user presses any key, regardless of focus.
    ///
    /// - Parameters:
    ///   - phases: The key phases to match.
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

    /// Performs an action if the user presses a key, regardless of focus.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - phases: The key phases to match.
    ///   - action: The action to perform for matching key presses.
    /// - Returns: A view with a global key handler attached.
    func onGlobalKeyPress(
        _ key: KeyEquivalent,
        phases: KeyPress.Phases,
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        onGlobalKeyPress(keys: [key], phases: phases, action: action)
    }

    /// Performs an action if the user presses one or more keys, regardless of focus.
    ///
    /// - Parameters:
    ///   - keys: The set of keys to match.
    ///   - phases: The key phases to match.
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

    /// Performs an action if the user presses keys that generate matching characters, regardless of focus.
    ///
    /// - Parameters:
    ///   - characters: The character set that all generated Unicode scalars
    ///     must belong to.
    ///   - phases: The key phases to match.
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
