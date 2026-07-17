import SwiftTUIRuns
import Terminal

/// A value that represents one insertion point or contiguous range in a
/// specific string.
///
/// `TextSelection` stores `String.Index` values rather than integer offsets.
/// Create and interpret the indices against the same current string value.
/// Editable controls reject a range whose indices can't be converted into
/// their current bound text.
public nonisolated struct TextSelection: Equatable, Hashable {

    /// The index representation of the current selection.
    public nonisolated enum Indices: Equatable, Hashable {

        /// A contiguous range in the selected string.
        ///
        /// An empty range represents an insertion point.
        case selection(Range<String.Index>)
    }

    /// The insertion point or range represented by this value.
    ///
    /// Assign only indices valid for the text that will consume the selection.
    public var indices: Indices

    /// Creates an empty selection range at an insertion point.
    ///
    /// - Parameter insertionPoint: An index in the string that will consume
    ///   this selection.
    public init(insertionPoint: String.Index) {
        self.init(range: insertionPoint..<insertionPoint)
    }

    /// Creates a selection over a contiguous string range.
    ///
    /// - Parameter range: A range whose bounds belong to the string that will
    ///   consume this selection.
    public init(range: Range<String.Index>) {
        self.indices = .selection(range)
    }

    /// Indicates whether the stored range is empty and therefore represents an
    /// insertion point.
    public var isInsertion: Bool {
        switch indices {
        case .selection(let range):
            range.isEmpty
        }
    }
}

/// Determines which endpoint moves when Shift-modified keyboard navigation
/// continues a pointer-created selection.
public nonisolated enum TextSelectionNavigationBehavior: Equatable, Hashable, Sendable {

    /// Keeps the original pointer-down anchor and moves the endpoint where the
    /// drag finished.
    case dragEndpoint

    /// Uses the first Shift-modified navigation direction to choose the moving
    /// endpoint, reanchoring at the opposite edge of the dragged range.
    case navigationDirection
}

/// A type-erased terminal color shape style.
///
/// SwiftTUI's ``ShapeStyle`` protocol currently represents colors only, so
/// erasure preserves a type-erased terminal color without retaining the
/// concrete style type.
@frozen
public nonisolated struct AnyShapeStyle: ShapeStyle, Sendable {

    @usableFromInline
    let color: AnyColor

    /// Erases a terminal color shape style.
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

    /// Indicates whether this type enables pointer selection highlighting.
    static var allowsSelection: Bool {
        get
    }
}

/// A value that enables text selection.
public nonisolated struct EnabledTextSelectability: TextSelectability {

    /// The protocol witness indicating that this type enables selection.
    public static let allowsSelection = true

    internal init() {
    }
}

/// A value that disables text selection.
public nonisolated struct DisabledTextSelectability: TextSelectability {

    /// The protocol witness indicating that this type disables selection.
    public static let allowsSelection = false

    internal init() {
    }
}

extension TextSelectability where Self == EnabledTextSelectability {

    /// A selectability value that enables text selection.
    public static var enabled: EnabledTextSelectability {
        EnabledTextSelectability()
    }
}

extension TextSelectability where Self == DisabledTextSelectability {

    /// A selectability value that disables text selection.
    public static var disabled: DisabledTextSelectability {
        DisabledTextSelectability()
    }
}

extension View {

    /// Controls whether static descendant text registers pointer-selection
    /// regions.
    ///
    /// Selection is disabled by default. Enabling it lets a primary-button drag
    /// highlight one static `Text` target at a time. This modifier doesn't
    /// expose the selected range through a binding and doesn't automatically
    /// copy selected text to the terminal clipboard. Disabled or hidden views
    /// don't register selection interaction.
    ///
    /// - Parameter selectability: A value whose type determines whether static
    ///   text selection is enabled.
    /// - Returns: A view with the selection setting applied to descendants.
    public nonisolated func textSelection<S>(_ selectability: S) -> some View
    where S: TextSelectability {
        EnvironmentValueView(
            content: self,
            keyPath: \.isTextSelectionEnabled,
            value: S.allowsSelection
        )
    }

    /// Sets how editable text continues a pointer-created selection with
    /// Shift-modified keyboard navigation.
    ///
    /// - Parameter behavior: The navigation behavior to apply to editable text.
    /// - Returns: A view with the updated text-selection navigation behavior.
    public nonisolated func textSelectionNavigationBehavior(
        _ behavior: TextSelectionNavigationBehavior
    ) -> some View {
        EnvironmentValueView(
            content: self,
            keyPath: \.textSelectionNavigationBehavior,
            value: behavior
        )
    }

    /// Sets the foreground color used for selected text.
    ///
    /// Pass an optional style so that `nil` preserves each selected character's
    /// original foreground color. Selection background comes from the current
    /// tint; clearing tint removes that background independently.
    ///
    /// - Parameter style: The selected-text foreground color, or `nil` to keep
    ///   each character's existing foreground.
    /// - Returns: A view with the selected-text foreground override.
    public func textSelectionForegroundStyle<S>(_ style: S?) -> some View
    where S: ShapeStyle {
        environment(\.textSelectionForegroundStyle, style.map(AnyShapeStyle.init))
    }
}

extension EnvironmentValues {

    /// The behavior used when keyboard navigation continues a pointer selection.
    ///
    /// macOS builds default to
    /// ``TextSelectionNavigationBehavior/navigationDirection``. Non-Apple
    /// builds such as Linux default to
    /// ``TextSelectionNavigationBehavior/dragEndpoint``.
    public nonisolated var textSelectionNavigationBehavior: TextSelectionNavigationBehavior {
        get {
            self[TextSelectionNavigationBehaviorKey.self]
        }
        set {
            self[TextSelectionNavigationBehaviorKey.self] = newValue
        }
    }

    /// The optional foreground color applied to selected text.
    ///
    /// The default is `nil`, which preserves each selected character's
    /// foreground color.
    public nonisolated var textSelectionForegroundStyle: AnyShapeStyle? {
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

extension TextSelection {

    fileprivate func characterOffsets(in text: String) -> Range<Int>? {
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
        let layout = RunGroup(text).layout()

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
                if
                    let foregroundStyle,
                    let resolvedForegroundStyle = foregroundStyle
                        ._swiftTUIAnyColor
                        .resolvingAccentColor(to: tint)
                {
                    characterStyle.foregroundStyle = resolvedForegroundStyle
                }
            }
            if pendingStyle != characterStyle {
                flush()
                pendingColumn = column
                pendingStyle = characterStyle
            }

            pendingText.append(character)
            column += layout.columns(
                in: RunIndex(characterOffset: index)
                    ..< RunIndex(characterOffset: index + 1)
            )
        }
        flush()
        return runs
    }
}
