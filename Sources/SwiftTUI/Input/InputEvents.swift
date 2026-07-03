public import Foundation

/// A set of key modifiers that can accompany an input event.
public struct EventModifiers: OptionSet, Sendable {

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
public struct KeyEquivalent: Equatable, Hashable, Sendable,
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
public struct KeyPress: Equatable, Sendable {

    /// Options for matching different phases of a key-press event.
    public struct Phases: OptionSet, Sendable {

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
    public enum Result: Equatable, Hashable, Sendable {

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
                action: action
            )
        )
    }

    /// Performs an action if the user presses a key while this view has focus.
    ///
    /// - Parameters:
    ///   - key: The key to match.
    ///   - action: The action to perform for matching key-down or repeat events.
    /// - Returns: A view with a focused key handler attached.
    func onKeyPress(
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
    func onKeyPress(
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
    func onKeyPress(
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
    func onKeyPress(
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
    func onKeyPress(
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

final class InputRuntime {

    private struct GlobalKeyPressHandler {

        var path: [Int]

        var order: Int

        var handler: KeyPressHandler
    }

    private var handlersByPath: [[Int]: [KeyPressHandler]] = [:]

    private var globalHandlers: [GlobalKeyPressHandler] = []

    private var tapHandlersByPath: [[Int]: [TapGestureHandler]] = [:]

    private var hitRegions: [RenderedHitRegion] = []

    private var scrollRegions: [RenderedScrollRegion] = []

    private var focusRegions: [RenderedFocusRegion] = []

    private var rootFrame = TextFrame(text: "", row: 1, column: 1)

    private var pressedTapTarget: [Int]?

    private var tapSequence: TapSequence?

    private let tapTimeout: TimeInterval = 0.5

    var nextTapDeadline: Date? {
        tapSequence?.deadline
    }

    func beginRender() {
        handlersByPath = [:]
        globalHandlers = []
        tapHandlersByPath = [:]
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
        focus: ([Int]) -> Bool,
        scroll: ([Int], MouseEvent) -> KeyPress.Result
    ) -> KeyPress.Result {
        _ = dispatchExpiredTapActions(at: date, perform: perform)

        if mouseEvent.button.isScrollWheel {
            pressedTapTarget = nil
            return dispatchScroll(mouseEvent, scroll: scroll)
        }

        guard mouseEvent.button == .left else {
            pressedTapTarget = nil
            return .ignored
        }

        switch mouseEvent.phase {
        case .down:
            let focused = focusTargets(at: mouseEvent).contains {
                focus($0)
            }
            pressedTapTarget = tapTarget(at: mouseEvent)
            return focused || pressedTapTarget != nil ? .handled : .ignored
        case .up:
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
