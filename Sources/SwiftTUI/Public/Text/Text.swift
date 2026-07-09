public import Foundation
public import Terminal

/// A terminal SGR color.
///
/// This is the color protocol from the `Terminal` package, re-exported through
/// SwiftTUI for text styling APIs.
public typealias Color = Terminal.SGR.Color

/// A style that can be applied to terminal foreground or background content.
///
/// SwiftTUI currently implements shape styles for terminal color values only.
public protocol ShapeStyle: Sendable {

    var _swiftTUIAnyColor: AnyColor { get }
}

public extension ShapeStyle where Self: Color {

    var _swiftTUIAnyColor: AnyColor {
        AnyColor(self)
    }
}

extension Color16: ShapeStyle {
}

extension Color256: ShapeStyle {
}

extension TrueColor: ShapeStyle {
}

extension AnyColor: ShapeStyle {
}

public extension AnyColor {

    /// A type-erased default terminal color.
    @_disfavoredOverload
    static var `default`: Self {
        Self(DefaultColor.default)
    }

    /// Creates a type-erased color from a 16-color terminal SGR color.
    ///
    /// - Parameter color: The 16-color terminal SGR color to erase.
    /// - Returns: A type-erased terminal SGR color.
    static func color16(_ color: Color16) -> Self {
        Self(color)
    }

    /// Creates a type-erased color from a 256-color terminal SGR index.
    ///
    /// - Parameter rawValue: The 256-color terminal SGR index to erase.
    /// - Returns: A type-erased terminal SGR color.
    static func color256(_ rawValue: UInt8) -> Self {
        Self(Color256(rawValue: rawValue))
    }

    /// Creates a type-erased color from a 256-color terminal SGR color.
    ///
    /// - Parameter color: The 256-color terminal SGR color to erase.
    /// - Returns: A type-erased terminal SGR color.
    static func color256(_ color: Color256) -> Self {
        Self(color)
    }

    /// Creates a type-erased color from true-color terminal SGR components.
    ///
    /// - Parameters:
    ///   - red: The red channel value.
    ///   - green: The green channel value.
    ///   - blue: The blue channel value.
    /// - Returns: A type-erased terminal SGR color.
    static func trueColor(red: UInt8, green: UInt8, blue: UInt8) -> Self {
        Self(TrueColor(red: red, green: green, blue: blue))
    }

    /// Creates a type-erased color from a true-color terminal SGR color.
    ///
    /// - Parameter color: The true-color terminal SGR color to erase.
    /// - Returns: A type-erased terminal SGR color.
    static func trueColor(_ color: TrueColor) -> Self {
        Self(color)
    }
}

/// The horizontal alignment of attributed text within its proposed width.
public nonisolated enum AttributedTextAlignment: Hashable, Sendable {

    /// Align each line to the left edge of its proposed width.
    case left

    /// Align each line to the center of its proposed width.
    case center

    /// Align each line to the right edge of its proposed width.
    case right
}

public enum SwiftTUIForegroundColorAttribute: AttributedStringKey {

    public typealias Value = AnyColor

    public static let name = "SwiftTUIForegroundColor"
}

public enum SwiftTUIBackgroundColorAttribute: AttributedStringKey {

    public typealias Value = AnyColor

    public static let name = "SwiftTUIBackgroundColor"
}

public enum SwiftTUIAlignmentAttribute: AttributedStringKey {

    public typealias Value = AttributedTextAlignment

    public static let name = "SwiftTUIAlignment"
}

public extension AttributeScopes {

    struct SwiftTUIAttributes: AttributeScope {

        public let foregroundColor: SwiftTUIForegroundColorAttribute

        public let backgroundColor: SwiftTUIBackgroundColorAttribute

        public let alignment: SwiftTUIAlignmentAttribute
    }

    var swiftTUI: SwiftTUIAttributes.Type {
        SwiftTUIAttributes.self
    }
}

public extension AttributeDynamicLookup {

    nonisolated subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.SwiftTUIAttributes, T>
    ) -> T {
        self[T.self]
    }
}

/// The default terminal color.
///
/// Use this value to reset styled text back to the terminal's configured
/// foreground or background color.
public nonisolated enum DefaultColor: Color, ShapeStyle {

    /// The terminal's default foreground or background color.
    case `default`

    /// The SGR background color code for the default terminal background.
    public var background: String {
        "49"
    }

    /// The SGR foreground color code for the default terminal foreground.
    public var foreground: String {
        "39"
    }
}

/// A view that displays text in the terminal.
///
/// `Text` renders its string content using terminal character-cell layout.
/// Unicode display width is considered during wrapping, clipping, and cursor
/// placement around adjacent controls.
public nonisolated struct Text: View, Equatable, Sendable {

    /// The body type for this primitive view.
    public typealias Body = Never

    nonisolated let runs: [TextRun]

    /// The string rendered by this text view.
    public var content: String {
        runs.map(\.text).joined()
    }

    nonisolated var hasAttributedAlignment: Bool {
        runs.contains { $0.alignment != nil }
    }

    /// Creates a text view from a string.
    ///
    /// - Parameter content: The string to render in the terminal.
    public init<S>(_ content: S) where S: StringProtocol {
        self.runs = [TextRun(text: String(content))]
    }

    /// Creates a text view from a string without localization.
    ///
    /// - Parameter content: The string to render in the terminal.
    public init(verbatim content: String) {
        self.init(content)
    }

    /// Creates a text view from attributed string content.
    ///
    /// SwiftTUI renders the attributed string's characters and maps supported
    /// Foundation attributes to terminal SGR text styles.
    ///
    /// - Parameter attributedContent: The attributed string to render.
    public init(_ attributedContent: AttributedString) {
        self.runs = TextRun.runs(from: attributedContent)
    }
}

nonisolated struct TextRun: Equatable, Sendable {

    var text: String

    var style: TextStyle

    var link: URL?

    var alignment: AttributedTextAlignment?

    init(
        text: String,
        style: TextStyle = .plain,
        link: URL? = nil,
        alignment: AttributedTextAlignment? = nil
    ) {
        self.text = text
        self.style = style
        self.link = link
        self.alignment = alignment
    }

    static func runs(from attributedString: AttributedString) -> [TextRun] {
        attributedString.runs.compactMap { run -> TextRun? in
            let text = String(attributedString.characters[run.range])
            guard !text.isEmpty else {
                return nil
            }

            var style = TextStyle()
#if canImport(Darwin)
            style = TextStyle(inlinePresentationIntent: run.inlinePresentationIntent)
#endif
            style.foregroundStyle = run.foregroundColor
            style.backgroundStyle = run.backgroundColor

            return TextRun(
                text: text,
                style: style,
                link: run.link,
                alignment: run.alignment
            )
        }
    }
}

nonisolated struct TextStyle: Equatable, Sendable {

    var foregroundStyle: AnyColor? = nil

    var backgroundStyle: AnyColor? = nil

    var isBold: Bool = false

    var isDim: Bool = false

    var isItalic: Bool = false

    var isUnderline: Bool = false

    var isStrikethrough: Bool = false

    static let plain = TextStyle()

    var isPlain: Bool {
        foregroundStyle == nil
            && backgroundStyle == nil
            && !isBold
            && !isDim
            && !isItalic
            && !isUnderline
            && !isStrikethrough
    }

    init() {
    }

#if canImport(Darwin)
    init(inlinePresentationIntent: InlinePresentationIntent?) {
        guard let inlinePresentationIntent else {
            return
        }

        isBold = inlinePresentationIntent.contains(.stronglyEmphasized)
        isItalic = inlinePresentationIntent.contains(.emphasized)
        isStrikethrough = inlinePresentationIntent.contains(.strikethrough)
    }
#endif

    func merged(with override: TextStyle) -> TextStyle {
        TextStyle(
            foregroundStyle: override.foregroundStyle ?? foregroundStyle,
            backgroundStyle: override.backgroundStyle ?? backgroundStyle,
            isBold: isBold || override.isBold,
            isDim: isDim || override.isDim,
            isItalic: isItalic || override.isItalic,
            isUnderline: isUnderline || override.isUnderline,
            isStrikethrough: isStrikethrough || override.isStrikethrough
        )
    }

    init(
        foregroundStyle: AnyColor? = nil,
        backgroundStyle: AnyColor? = nil,
        isBold: Bool = false,
        isDim: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false
    ) {
        self.foregroundStyle = foregroundStyle
        self.backgroundStyle = backgroundStyle
        self.isBold = isBold
        self.isDim = isDim
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
    }
}

nonisolated struct TextLineLimit: Equatable, Sendable {

    let number: Int?

    let reservesSpace: Bool
}

struct LineLimitView<Content: View>: View, LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let lineLimit: TextLineLimit

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        TextLineLimitContext.withLineLimit(lineLimit) {
            ViewResolver.block(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        TextLineLimitContext.withLineLimit(lineLimit) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

public extension View {

    /// Sets the terminal foreground style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A 16-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    func foregroundStyle(_ style: Color16) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the terminal foreground style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A 256-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    func foregroundStyle(_ style: Color256) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the terminal foreground style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A true-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    func foregroundStyle(_ style: TrueColor) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the terminal foreground style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: The terminal default color reset style.
    /// - Returns: A view that renders descendant text with the given style.
    func foregroundStyle(_ style: DefaultColor) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the terminal foreground style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A terminal SGR color style.
    /// - Returns: A view that renders descendant text with the given style.
    func foregroundStyle<S>(_ style: S) -> some View
    where S: Color & ShapeStyle {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A 16-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    func backgroundStyle(_ style: Color16) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A 256-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    func backgroundStyle(_ style: Color256) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A true-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    func backgroundStyle(_ style: TrueColor) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: The terminal default color reset style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    func backgroundStyle(_ style: DefaultColor) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A terminal SGR color style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    func backgroundStyle<S>(_ style: S) -> some View
    where S: Color & ShapeStyle {
        _backgroundStyle(style)
    }

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    func color(_ color: Color16) -> some View {
        foregroundStyle(color)
    }

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    func color(_ color: Color256) -> some View {
        foregroundStyle(color)
    }

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    func color(_ color: TrueColor) -> some View {
        foregroundStyle(color)
    }

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    func color(_ color: DefaultColor) -> some View {
        foregroundStyle(color)
    }

    /// Sets the terminal foreground style for text within this view.
    ///
    /// - Parameter color: Any SGR color value accepted by the `Terminal` package.
    /// - Returns: A view that renders descendant text with the given color.
    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    func color<C: Color>(_ color: C) -> some View {
        transformEnvironment(\.textStyle) {
            $0.foregroundStyle = AnyColor(color)
        }
    }

    /// Sets the terminal foreground style for text within this view.
    ///
    /// - Parameter style: A type-erased terminal SGR color style.
    /// - Returns: A view that renders descendant text with the given style.
    func foregroundStyle(_ style: AnyColor) -> some View {
        transformEnvironment(\.textStyle) {
            $0.foregroundStyle = style
        }
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// - Parameter style: A type-erased terminal SGR color style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    func backgroundStyle(_ style: AnyColor) -> some View {
        _backgroundStyle(style)
    }

    internal func _backgroundStyle(_ style: Color16) -> some View {
        _backgroundStyle(AnyColor(style))
    }

    internal func _backgroundStyle(_ style: Color256) -> some View {
        _backgroundStyle(AnyColor(style))
    }

    internal func _backgroundStyle(_ style: TrueColor) -> some View {
        _backgroundStyle(AnyColor(style))
    }

    internal func _backgroundStyle(_ style: DefaultColor) -> some View {
        _backgroundStyle(AnyColor(style))
    }

    internal func _backgroundStyle<S>(_ style: S) -> some View
    where S: Color & ShapeStyle {
        _backgroundStyle(AnyColor(style))
    }

    internal func _backgroundStyle(_ style: AnyColor) -> some View {
        transformEnvironment(\.textStyle) {
            $0.backgroundStyle = style
        }
    }

    /// Sets the terminal tint color for controls and links within this view.
    ///
    /// - Parameter tint: A 16-color terminal SGR style, or `nil` to clear tint.
    /// - Returns: A view with the updated tint environment.
    func tint(_ tint: Color16?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    /// Sets the terminal tint color for controls and links within this view.
    ///
    /// - Parameter tint: A 256-color terminal SGR style, or `nil` to clear tint.
    /// - Returns: A view with the updated tint environment.
    func tint(_ tint: Color256?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    /// Sets the terminal tint color for controls and links within this view.
    ///
    /// - Parameter tint: A true-color terminal SGR style, or `nil` to clear tint.
    /// - Returns: A view with the updated tint environment.
    func tint(_ tint: TrueColor?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    /// Sets the terminal tint color for controls and links within this view.
    ///
    /// - Parameter tint: The default color reset style, or `nil` to clear tint.
    /// - Returns: A view with the updated tint environment.
    func tint(_ tint: DefaultColor?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    private func tint(_ tint: AnyColor?) -> some View {
        transformEnvironment(\.tint) {
            $0 = tint
        }
    }

    /// Sets whether text within this view renders in bold.
    ///
    /// - Parameter isActive: Pass `true` to enable bold SGR styling, or `false`
    ///   to clear bold styling for descendant text.
    /// - Returns: A view with the updated text style environment.
    func bold(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isBold = isActive
        }
    }

    /// Sets whether text within this view renders dimmed.
    ///
    /// - Parameter isActive: Pass `true` to enable dim SGR styling, or `false`
    ///   to clear dim styling for descendant text.
    /// - Returns: A view with the updated text style environment.
    func dim(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isDim = isActive
        }
    }

    /// Sets whether text within this view renders in italics.
    ///
    /// - Parameter isActive: Pass `true` to enable italic SGR styling, or
    ///   `false` to clear italic styling for descendant text.
    /// - Returns: A view with the updated text style environment.
    func italic(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isItalic = isActive
        }
    }

    /// Sets whether text within this view renders underlined.
    ///
    /// - Parameter isActive: Pass `true` to enable underline SGR styling, or
    ///   `false` to clear underline styling for descendant text.
    /// - Returns: A view with the updated text style environment.
    func underline(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isUnderline = isActive
        }
    }

    /// Sets whether text within this view renders with strikethrough.
    ///
    /// - Parameter isActive: Pass `true` to enable strikethrough SGR styling,
    ///   or `false` to clear strikethrough styling for descendant text.
    /// - Returns: A view with the updated text style environment.
    func strikethrough(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isStrikethrough = isActive
        }
    }

    /// Limits the number of lines used to render text within this view.
    ///
    /// - Parameter number: The maximum number of terminal rows to render, or
    ///   `nil` to remove the limit.
    /// - Returns: A view that applies the line limit to descendant text.
    func lineLimit(_ number: Int?) -> some View {
        lineLimit(number, reservesSpace: false)
    }

    /// Limits the number of lines used to render text within this view.
    ///
    /// - Parameters:
    ///   - number: The maximum number of terminal rows to render, or `nil` to
    ///     remove the limit. Non-`nil` values must be greater than zero.
    ///   - reservesSpace: Whether the renderer reserves rows up to the limit.
    /// - Returns: A view that applies the line limit to descendant text.
    func lineLimit(_ number: Int?, reservesSpace: Bool) -> some View {
        if let number {
            precondition(number >= 1, "lineLimit must be greater than zero.")
        }

        return LineLimitView(
            content: self,
            lineLimit: TextLineLimit(number: number, reservesSpace: reservesSpace)
        )
    }
}

extension EnvironmentValues {

    var textStyle: TextStyle {
        get {
            self[TextStyleKey.self]
        }
        set {
            self[TextStyleKey.self] = newValue
        }
    }

    var tint: AnyColor? {
        get {
            self[TintKey.self]
        }
        set {
            self[TintKey.self] = newValue
        }
    }
}

private struct TextStyleKey: EnvironmentKey {

    nonisolated static let defaultValue = TextStyle.plain
}

private struct TintKey: EnvironmentKey {

    nonisolated static let defaultValue: AnyColor? = nil
}

enum TextLineLimitContext {

    @TaskLocal
    private static var taskCurrent = TextLineLimit(
        number: nil,
        reservesSpace: false
    )

    static var current: TextLineLimit {
        taskCurrent
    }

    static func withLineLimit<Value>(
        _ lineLimit: TextLineLimit,
        perform operation: () -> Value
    ) -> Value {
        $taskCurrent.withValue(lineLimit) {
            return operation()
        }
    }
}
