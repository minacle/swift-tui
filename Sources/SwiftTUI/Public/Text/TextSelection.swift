import Terminal

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

private struct IsTextSelectionEnabledKey: EnvironmentKey {

    nonisolated static let defaultValue = false
}

final class TextSelectionState {

    private let invalidate: () -> Void

    private(set) var anchor: Int?

    private(set) var offset: Int

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
        update(anchor: clamped(offset, upperBound: upperBound), offset: offset, upperBound: upperBound)
    }

    func move(to offset: Int, upperBound: Int, selecting: Bool = false) {
        let anchor = selecting ? self.anchor ?? self.offset : nil
        update(anchor: anchor, offset: offset, upperBound: upperBound)
    }

    func collapse(to offset: Int, upperBound: Int) {
        update(anchor: nil, offset: offset, upperBound: upperBound)
    }

    func clearSelection(upperBound: Int) {
        update(anchor: nil, offset: offset, upperBound: upperBound)
    }

    func clamp(upperBound: Int, clearsSelection: Bool = false) {
        update(
            anchor: clearsSelection ? nil : anchor,
            offset: offset,
            upperBound: upperBound
        )
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
