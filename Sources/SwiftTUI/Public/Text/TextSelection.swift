import Terminal

/// A value that represents a selection of text.
public nonisolated struct TextSelection: Equatable, Hashable {

    /// The indices of the current selection.
    public nonisolated enum Indices: Equatable, Hashable {

        /// The range of a single selection.
        ///
        /// An empty range represents an insertion point.
        case selection(Range<String.Index>)
    }

    /// The indices of the current selection.
    public var indices: Indices

    /// Creates a selection at an insertion point.
    ///
    /// - Parameter insertionPoint: The index where text is inserted.
    public init(insertionPoint: String.Index) {
        self.init(range: insertionPoint..<insertionPoint)
    }

    /// Creates a selection over a range of text.
    ///
    /// - Parameter range: The range of selected text.
    public init(range: Range<String.Index>) {
        self.indices = .selection(range)
    }

    /// Whether the selection represents an insertion point.
    public var isInsertion: Bool {
        switch indices {
        case .selection(let range):
            range.isEmpty
        }
    }
}

/// A behavior that determines how keyboard navigation continues a pointer selection.
public nonisolated enum TextSelectionNavigationBehavior: Equatable, Hashable, Sendable {

    /// Continues selection from the endpoint where the pointer drag finished.
    case dragEndpoint

    /// Chooses the active endpoint from the first Shift-modified navigation direction.
    case navigationDirection
}

/// A type-erased shape style value.
@frozen
public nonisolated struct AnyShapeStyle: ShapeStyle, Sendable {

    @usableFromInline
    let color: AnyColor

    /// Creates a type-erased shape style.
    ///
    /// - Parameter style: The shape style to erase.
    public init<S>(_ style: S) where S: ShapeStyle {
        color = style._swiftTUIAnyColor
    }

    /// The terminal color representation used to render this style.
    public nonisolated var _swiftTUIAnyColor: AnyColor {
        color
    }
}

/// A type that describes whether text can be selected.
public nonisolated protocol TextSelectability {

    /// Whether this value enables text selection.
    static var allowsSelection: Bool {
        get
    }
}

/// A value that enables text selection.
public nonisolated struct EnabledTextSelectability: TextSelectability {

    public static let allowsSelection = true

    internal init() {
    }
}

/// A value that disables text selection.
public nonisolated struct DisabledTextSelectability: TextSelectability {

    public static let allowsSelection = false

    internal init() {
    }
}

public extension TextSelectability where Self == EnabledTextSelectability {

    /// A selectability value that enables text selection.
    static var enabled: EnabledTextSelectability {
        EnabledTextSelectability()
    }
}

public extension TextSelectability where Self == DisabledTextSelectability {

    /// A selectability value that disables text selection.
    static var disabled: DisabledTextSelectability {
        DisabledTextSelectability()
    }
}

public extension View {

    /// Controls whether people can select text within this view.
    nonisolated func textSelection<S>(_ selectability: S) -> some View
    where S: TextSelectability {
        EnvironmentValueView(
            content: self,
            keyPath: \.isTextSelectionEnabled,
            value: S.allowsSelection
        )
    }

    /// Sets how keyboard navigation continues a selection created by pointer dragging.
    ///
    /// - Parameter behavior: The navigation behavior to apply to editable text.
    /// - Returns: A view with the updated text-selection navigation behavior.
    nonisolated func textSelectionNavigationBehavior(
        _ behavior: TextSelectionNavigationBehavior
    ) -> some View {
        EnvironmentValueView(
            content: self,
            keyPath: \.textSelectionNavigationBehavior,
            value: behavior
        )
    }

    /// Sets the foreground style used for selected text.
    ///
    /// Pass an optional style so that `nil` preserves each selected character's
    /// original foreground style.
    func textSelectionForegroundStyle<S>(_ style: S?) -> some View
    where S: ShapeStyle {
        environment(\.textSelectionForegroundStyle, style.map(AnyShapeStyle.init))
    }
}

public extension EnvironmentValues {

    /// The behavior used when keyboard navigation continues a pointer selection.
    ///
    /// iOS, macOS, tvOS, visionOS, and watchOS default to
    /// ``TextSelectionNavigationBehavior/navigationDirection``. Other platforms
    /// default to ``TextSelectionNavigationBehavior/dragEndpoint``.
    nonisolated var textSelectionNavigationBehavior: TextSelectionNavigationBehavior {
        get {
            self[TextSelectionNavigationBehaviorKey.self]
        }
        set {
            self[TextSelectionNavigationBehaviorKey.self] = newValue
        }
    }

    /// The optional foreground style applied to selected text.
    nonisolated var textSelectionForegroundStyle: AnyShapeStyle? {
        get {
            self[TextSelectionForegroundStyleKey.self]
        }
        set {
            self[TextSelectionForegroundStyleKey.self] = newValue
        }
    }
}

extension EnvironmentValues {

    nonisolated var isTextSelectionEnabled: Bool {
        get {
            self[IsTextSelectionEnabledKey.self]
        }
        set {
            self[IsTextSelectionEnabledKey.self] = newValue
        }
    }
}

private struct TextSelectionForegroundStyleKey: EnvironmentKey {

    nonisolated static let defaultValue: AnyShapeStyle? = nil
}

private struct TextSelectionNavigationBehaviorKey: EnvironmentKey {

    nonisolated static var defaultValue: TextSelectionNavigationBehavior {
        #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS) || os(watchOS)
        .navigationDirection
        #else
        .dragEndpoint
        #endif
    }
}

private struct IsTextSelectionEnabledKey: EnvironmentKey {

    nonisolated static let defaultValue = false
}

enum TextSelectionNavigationDirection {

    case backward

    case forward
}

final class TextSelectionState {

    private let invalidate: () -> Void

    private(set) var anchor: Int?

    private(set) var offset: Int

    private var awaitsNavigationEndpoint = false

    private var lastObservedBindingSelection: TextSelection??

    private var wasBoundControlFocused = false

    var range: Range<Int>? {
        guard let anchor, anchor != offset else {
            return nil
        }

        return min(anchor, offset)..<max(anchor, offset)
    }

    init(offset: Int, invalidate: @escaping () -> Void) {
        self.offset = offset
        self.invalidate = invalidate
    }

    func begin(at offset: Int, upperBound: Int) {
        awaitsNavigationEndpoint = false
        update(anchor: clamped(offset, upperBound: upperBound), offset: offset, upperBound: upperBound)
    }

    func move(to offset: Int, upperBound: Int, selecting: Bool = false) {
        awaitsNavigationEndpoint = false
        let anchor = selecting ? self.anchor ?? self.offset : nil
        update(anchor: anchor, offset: offset, upperBound: upperBound)
    }

    func extendFromPointer(to offset: Int, upperBound: Int) {
        let anchor = self.anchor ?? self.offset
        update(anchor: anchor, offset: offset, upperBound: upperBound)
        awaitsNavigationEndpoint = range != nil
    }

    func prepareForSelectionNavigation(
        toward direction: TextSelectionNavigationDirection,
        behavior: TextSelectionNavigationBehavior,
        upperBound: Int
    ) {
        guard awaitsNavigationEndpoint else {
            return
        }

        awaitsNavigationEndpoint = false
        guard behavior == .navigationDirection, let range else {
            return
        }

        switch direction {
        case .backward:
            update(
                anchor: range.upperBound,
                offset: range.lowerBound,
                upperBound: upperBound
            )
        case .forward:
            update(
                anchor: range.lowerBound,
                offset: range.upperBound,
                upperBound: upperBound
            )
        }
    }

    func collapse(to offset: Int, upperBound: Int) {
        awaitsNavigationEndpoint = false
        update(anchor: nil, offset: offset, upperBound: upperBound)
    }

    func clearSelection(upperBound: Int) {
        awaitsNavigationEndpoint = false
        update(anchor: nil, offset: offset, upperBound: upperBound)
    }

    func clamp(upperBound: Int, clearsSelection: Bool = false) {
        update(
            anchor: clearsSelection ? nil : anchor,
            offset: offset,
            upperBound: upperBound
        )
        if clearsSelection || range == nil {
            awaitsNavigationEndpoint = false
        }
    }

    func synchronize(
        with binding: Binding<TextSelection?>?,
        in text: String,
        force: Bool = false
    ) {
        guard let binding else {
            lastObservedBindingSelection = nil
            wasBoundControlFocused = false
            return
        }

        let boundSelection = binding.wrappedValue
        guard force || lastObservedBindingSelection != .some(boundSelection) else {
            return
        }

        lastObservedBindingSelection = .some(boundSelection)
        awaitsNavigationEndpoint = false
        guard
            let boundSelection,
            let range = boundSelection.characterOffsets(in: text)
        else {
            update(anchor: nil, offset: offset, upperBound: text.count)
            return
        }

        update(
            anchor: range.isEmpty ? nil : range.lowerBound,
            offset: range.upperBound,
            upperBound: text.count
        )
    }

    func publish(
        to binding: Binding<TextSelection?>?,
        in text: String
    ) {
        guard let binding else {
            return
        }

        binding.wrappedValue = textSelection(in: text)
        lastObservedBindingSelection = .some(binding.wrappedValue)
    }

    func publishOnFocus(
        _ isFocused: Bool,
        to binding: Binding<TextSelection?>?,
        in text: String
    ) {
        guard let binding else {
            wasBoundControlFocused = false
            return
        }

        if isFocused && !wasBoundControlFocused {
            publish(to: binding, in: text)
        }
        wasBoundControlFocused = isFocused
    }

    private func update(anchor: Int?, offset: Int, upperBound: Int) {
        let oldAnchor = self.anchor
        let oldOffset = self.offset
        self.anchor = anchor.map { clamped($0, upperBound: upperBound) }
        self.offset = clamped(offset, upperBound: upperBound)
        if self.anchor != oldAnchor || self.offset != oldOffset {
            invalidate()
        }
    }

    private func clamped(_ offset: Int, upperBound: Int) -> Int {
        min(max(offset, 0), max(upperBound, 0))
    }

    private func textSelection(in text: String) -> TextSelection {
        let lowerOffset = range?.lowerBound ?? offset
        let upperOffset = range?.upperBound ?? offset
        let lowerBound = text.index(text.startIndex, offsetBy: lowerOffset)
        let upperBound = text.index(text.startIndex, offsetBy: upperOffset)
        return TextSelection(range: lowerBound..<upperBound)
    }
}

private extension TextSelection {

    func characterOffsets(in text: String) -> Range<Int>? {
        let range: Range<String.Index>
        switch indices {
        case .selection(let selection):
            range = selection
        }

        guard
            let lowerBound = String.Index(range.lowerBound, within: text),
            let upperBound = String.Index(range.upperBound, within: text)
        else {
            return nil
        }

        let lowerOffset = text.distance(from: text.startIndex, to: lowerBound)
        let upperOffset = text.distance(from: text.startIndex, to: upperBound)
        guard lowerOffset <= upperOffset else {
            return nil
        }

        return lowerOffset..<upperOffset
    }
}

enum TextSelectionRenderer {

    static func runs(
        text: String,
        row: Int = 0,
        baseOffset: Int = 0,
        style: TextStyle,
        selection: Range<Int>?,
        tint: AnyColor?,
        foregroundStyle: AnyShapeStyle?
    ) -> [RenderedRun] {
        var runs: [RenderedRun] = []
        var pendingText = ""
        var pendingColumn = 0
        var pendingStyle: TextStyle?
        var column = 0

        func flush() {
            guard !pendingText.isEmpty, let pendingStyle else {
                return
            }

            runs.append(
                RenderedRun(
                    text: pendingText,
                    row: row,
                    column: pendingColumn,
                    style: pendingStyle
                )
            )
            pendingText = ""
        }

        for (index, character) in text.enumerated() {
            var characterStyle = style
            if selection?.contains(baseOffset + index) == true {
                if let tint {
                    characterStyle.backgroundStyle = tint
                }
                if let foregroundStyle {
                    characterStyle.foregroundStyle = foregroundStyle._swiftTUIAnyColor
                }
            }
            if pendingStyle != characterStyle {
                flush()
                pendingColumn = column
                pendingStyle = characterStyle
            }

            let characterText = String(character)
            pendingText += characterText
            column += TerminalText.columnWidth(characterText)
        }
        flush()
        return runs
    }
}
