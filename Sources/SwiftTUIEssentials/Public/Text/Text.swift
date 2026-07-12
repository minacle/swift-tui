public import Foundation
public import SwiftTUIRuns
public import Terminal

/// A terminal SGR color.
///
/// This is the color protocol from the `Terminal` package, re-exported through
/// SwiftTUI for text styling APIs.
public typealias Color = Terminal.SGR.Color

/// A style that can be applied to terminal foreground or background content.
///
/// SwiftTUI currently implements shape styles for terminal color values only.
public nonisolated protocol ShapeStyle: Sendable {

    /// The type-erased terminal color SwiftTUI uses to render this style.
    ///
    /// SwiftTUI reads this property when it converts a generic shape style to
    /// ``AnyColor``, such as when a style is passed to a fill or selection-style
    /// API. The current protocol has no non-color style representation.
    nonisolated var _swiftTUIAnyColor: AnyColor { get }
}

/// Supplies the standard color-to-``AnyColor`` conversion for terminal color
/// shape styles.
extension ShapeStyle where Self: Color {

    /// Erases this terminal color for SwiftTUI styling operations.
    public nonisolated var _swiftTUIAnyColor: AnyColor {
        AnyColor(self)
    }
}

/// Makes 16-color terminal SGR values available as SwiftTUI shape styles.
extension Color16: ShapeStyle {
}

/// Makes 256-color terminal SGR values available as SwiftTUI shape styles.
extension Color256: ShapeStyle {
}

/// Makes true-color terminal SGR values available as SwiftTUI shape styles.
extension TrueColor: ShapeStyle {
}

/// Makes type-erased terminal colors available as SwiftTUI shape styles.
extension AnyColor: ShapeStyle {
}

/// Provides named factories for type-erased terminal colors.
extension AnyColor {

    /// A type-erased default terminal color.
    @_disfavoredOverload
    public static var `default`: Self {
        Self(DefaultColor.default)
    }

    /// Creates a type-erased color from a 16-color terminal SGR color.
    ///
    /// - Parameter color: The 16-color terminal SGR color to erase.
    /// - Returns: A type-erased terminal SGR color.
    public static func color16(_ color: Color16) -> Self {
        Self(color)
    }

    /// Creates a type-erased color from a 256-color terminal SGR index.
    ///
    /// - Parameter rawValue: The 256-color terminal SGR index to erase.
    /// - Returns: A type-erased terminal SGR color.
    public static func color256(_ rawValue: UInt8) -> Self {
        Self(Color256(rawValue: rawValue))
    }

    /// Creates a type-erased color from a 256-color terminal SGR color.
    ///
    /// - Parameter color: The 256-color terminal SGR color to erase.
    /// - Returns: A type-erased terminal SGR color.
    public static func color256(_ color: Color256) -> Self {
        Self(color)
    }

    /// Creates a type-erased color from true-color terminal SGR components.
    ///
    /// - Parameters:
    ///   - red: The red channel value.
    ///   - green: The green channel value.
    ///   - blue: The blue channel value.
    /// - Returns: A type-erased terminal SGR color.
    public static func trueColor(red: UInt8, green: UInt8, blue: UInt8) -> Self {
        Self(TrueColor(red: red, green: green, blue: blue))
    }

    /// Creates a type-erased color from a true-color terminal SGR color.
    ///
    /// - Parameter color: The true-color terminal SGR color to erase.
    /// - Returns: A type-erased terminal SGR color.
    public static func trueColor(_ color: TrueColor) -> Self {
        Self(color)
    }
}

/// The physical horizontal alignment of attributed text within its proposed
/// terminal-column width.
///
/// When ``Text`` contains an explicit attributed alignment and receives a
/// finite column proposal, it aligns within and reports that proposed width.
public nonisolated enum AttributedTextAlignment: Hashable, Sendable {

    /// Align each line to the left edge of its proposed width.
    case left

    /// Align each line to the center of its proposed width.
    case center

    /// Align each line to the right edge of its proposed width.
    case right
}

/// An alignment position for plain multiline text along the horizontal
/// terminal axis.
///
/// Plain ``Text`` aligns its lines within the widest rendered line's natural
/// width; a finite column proposal can wrap the text but doesn't expand that
/// alignment width. Multiline ``EditableText`` instead aligns within the
/// finite proposed column width when one is present.
public nonisolated enum TextAlignment: CaseIterable, Hashable, Sendable {

    /// Align text to the leading terminal edge, currently the left edge.
    case leading

    /// Center text between the terminal edges.
    case center

    /// Align text to the trailing terminal edge, currently the right edge.
    case trailing
}

/// An attributed-string key that sets a terminal foreground color.
///
/// Access this attribute through the SwiftTUI attribute scope when building an
/// `AttributedString`. ``Text`` applies the value to the corresponding runs
/// when it renders them.
public enum SwiftTUIForegroundColorAttribute: AttributedStringKey {

    /// The type of foreground color stored by this attribute.
    public typealias Value = AnyColor

    /// The stable name of the foreground-color attribute.
    public static let name = "SwiftTUIForegroundColor"
}

/// An attributed-string key that sets a terminal background color.
///
/// Access this attribute through the SwiftTUI attribute scope when building an
/// `AttributedString`. ``Text`` applies the value to the corresponding runs
/// when it renders them.
public enum SwiftTUIBackgroundColorAttribute: AttributedStringKey {

    /// The type of background color stored by this attribute.
    public typealias Value = AnyColor

    /// The stable name of the background-color attribute.
    public static let name = "SwiftTUIBackgroundColor"
}

/// An attributed-string key that aligns a paragraph in terminal columns.
///
/// The attribute stores an ``AttributedTextAlignment`` value. ``Text`` uses
/// that value when laying out the attributed paragraph in a proposed width.
public enum SwiftTUIAlignmentAttribute: AttributedStringKey {

    /// The type of text alignment stored by this attribute.
    public typealias Value = AttributedTextAlignment

    /// The stable name of the text-alignment attribute.
    public static let name = "SwiftTUIAlignment"
}

/// Adds SwiftTUI terminal styling keys to Foundation attributed-string scopes.
extension AttributeScopes {

    /// The Foundation attribute scope containing SwiftTUI's supported terminal
    /// foreground, background, and paragraph-alignment keys.
    public struct SwiftTUIAttributes: AttributeScope {

        /// The key-path member for a run's terminal foreground color.
        public let foregroundColor: SwiftTUIForegroundColorAttribute

        /// The key-path member for a run's terminal background color.
        public let backgroundColor: SwiftTUIBackgroundColorAttribute

        /// The key-path member for attributed paragraph alignment.
        public let alignment: SwiftTUIAlignmentAttribute
    }

    /// The SwiftTUI attributed-string scope type used by dynamic lookup.
    public var swiftTUI: SwiftTUIAttributes.Type {
        SwiftTUIAttributes.self
    }
}

/// Enables dynamic-member access to keys in the SwiftTUI attributed-string
/// scope.
extension AttributeDynamicLookup {

    /// Resolves a SwiftTUI scope member to its attributed-string key type.
    ///
    /// - Parameter keyPath: A key path to a key declaration in
    ///   ``AttributeScopes/SwiftTUIAttributes``.
    /// - Returns: The key value used by Foundation's attributed-string dynamic
    ///   member lookup.
    public nonisolated subscript<T: AttributedStringKey>(
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
/// Unicode display width is considered during wrapping, clipping, and caret
/// placement around adjacent controls. Newline characters create source lines;
/// finite column proposals wrap those lines at Unicode line-break opportunities
/// and split an overlong unbreakable segment at character boundaries.
///
/// `Text` doesn't sanitize terminal control characters or escape sequences in
/// its input. Sanitize untrusted content before constructing a value to prevent
/// it from controlling the caller's terminal.
public nonisolated struct Text: View, Equatable, Sendable {

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    nonisolated let runGroup: RunGroup

    nonisolated let annotations: [TextAnnotation]

    /// The plain string obtained by concatenating all text runs.
    ///
    /// This property omits attributed styles and links.
    ///
    /// - Complexity: O(n), where n is the total number of characters across
    ///   the stored runs.
    public var content: String {
        runGroup.content
    }

    nonisolated var hasAttributedAlignment: Bool {
        annotations.contains { $0.alignment != nil }
    }

    /// Creates text from a string without localization or interpolation lookup.
    ///
    /// The initializer stores terminal control characters and escape sequences
    /// unchanged. Sanitize untrusted `content` before rendering it.
    ///
    /// - Parameter content: The string to render in the terminal.
    public init<S>(_ content: S) where S: StringProtocol {
        self.init(content: String(content))
    }

    /// Stores plain string content for the public plain-text initializers.
    internal init(content: String) {
        self.runGroup = RunGroup(content)
        self.annotations = []
    }

    /// Creates text from a recursive group of attributed terminal-text runs.
    ///
    /// Run attributes are merged with the text style inherited from the view
    /// environment. This initializer does not add links, alignment, selection,
    /// truncation, or terminal-input sanitization; those remain view-layer
    /// responsibilities.
    ///
    /// - Parameter content: The attributed runs to render as one text view.
    public init(_ content: RunGroup) {
        self.runGroup = content
        self.annotations = []
    }

    /// Creates text that renders a `String` verbatim.
    ///
    /// SwiftTUI's generic string initializer also renders without localization;
    /// this spelling makes that intent explicit at the call site.
    ///
    /// "Verbatim" doesn't imply terminal safety: control characters and escape
    /// sequences remain unchanged, so sanitize untrusted `content` first.
    ///
    /// - Parameter content: The string to render in the terminal.
    @available(*, deprecated, message: "Use init(_:) instead.")
    public init(verbatim content: String) {
        self.init(content: content)
    }

    /// Creates text from Foundation attributed-string content.
    ///
    /// SwiftTUI maps its custom foreground, background, and alignment keys and
    /// Foundation link attributes into terminal rendering. On Darwin,
    /// supported inline presentation intents also map strong emphasis,
    /// emphasis, and strikethrough to SGR styling. Unsupported attributes are
    /// ignored. Activating a link passes its URL to the current
    /// ``EnvironmentValues/openURL`` action without validation.
    /// Terminal control characters and escape sequences in attributed runs
    /// remain unchanged; sanitize untrusted text before constructing the view.
    ///
    /// - Parameter attributedContent: The attributed string to render.
    public init(_ attributedContent: AttributedString) {
        let converted = TextAnnotation.convert(attributedContent)
        self.runGroup = RunGroup {
            for run in converted.runs {
                run
            }
        }
        self.annotations = converted.annotations
    }
}

extension Text {

    /// Determines where SwiftTUI removes characters around a truncation marker.
    ///
    /// The marker is three ASCII period characters (`...`), not U+2026. When
    /// fewer than three columns are available, SwiftTUI emits only the number
    /// of periods that fit.
    public nonisolated enum TruncationMode: Equatable, Hashable, Sendable {

        /// Remove characters from the beginning, keeping the line's tail.
        case head

        /// Remove characters from the middle, keeping both ends when space
        /// permits.
        case middle

        /// Remove characters from the end, keeping the line's head.
        case tail
    }
}

nonisolated struct TextAnnotation: Equatable, Sendable {

    var link: URL?

    var alignment: AttributedTextAlignment?

    var range: Range<RunIndex>

    init(link: URL?, alignment: AttributedTextAlignment?, range: Range<RunIndex>) {
        self.link = link
        self.alignment = alignment
        self.range = range
    }

    static func convert(
        _ attributedString: AttributedString
    ) -> (runs: [Run], annotations: [TextAnnotation]) {
        var offset = 0
        var runs: [Run] = []
        var annotations: [TextAnnotation] = []
        for attributedRun in attributedString.runs {
            let text = String(attributedString.characters[attributedRun.range])
            guard !text.isEmpty else {
                continue
            }

            var style = TextStyle()
#if canImport(Darwin)
            style = TextStyle(inlinePresentationIntent: attributedRun.inlinePresentationIntent)
#endif
            style.foregroundStyle = attributedRun.foregroundColor
            style.backgroundStyle = attributedRun.backgroundColor
            let upperOffset = offset + text.count
            runs.append(Run(text, attributes: style.inheritingRunAttributes))
            annotations.append(
                TextAnnotation(
                    link: attributedRun.link,
                    alignment: attributedRun.alignment,
                    range: RunIndex(characterOffset: offset)
                        ..< RunIndex(characterOffset: upperOffset)
                )
            )
            offset = upperOffset
        }
        return (runs, annotations)
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

    var inheritingRunAttributes: RunAttributes {
        RunAttributes(
            foregroundColor: foregroundStyle,
            backgroundColor: backgroundStyle,
            isBold: isBold ? true : nil,
            isDim: isDim ? true : nil,
            isItalic: isItalic ? true : nil,
            isUnderline: isUnderline ? true : nil,
            isStrikethrough: isStrikethrough ? true : nil
        )
    }

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

    func merging(_ attributes: RunAttributes) -> TextStyle {
        TextStyle(
            foregroundStyle: attributes.foregroundColor ?? foregroundStyle,
            backgroundStyle: attributes.backgroundColor ?? backgroundStyle,
            isBold: attributes.isBold ?? isBold,
            isDim: attributes.isDim ?? isDim,
            isItalic: attributes.isItalic ?? isItalic,
            isUnderline: attributes.isUnderline ?? isUnderline,
            isStrikethrough: attributes.isStrikethrough ?? isStrikethrough
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
        render {
            ViewResolver.layoutTraits(from: content)
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        render {
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
        render {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    private func render<Value>(_ operation: () -> Value) -> Value {
        var environment = EnvironmentRenderContext.current
        environment.textLineLimit = lineLimit
        return EnvironmentRenderContext.withValues(environment, perform: operation)
    }
}

extension View {

    /// Sets the inherited base foreground color for this view's descendants.
    ///
    /// Plain ``Text`` runs use this color unless an attributed run supplies its
    /// own foreground. Terminal primitives also consume the base foreground,
    /// including ``Rectangle`` and default shape fills, and ``Box`` borders.
    ///
    /// - Parameter style: A 16-color terminal SGR style.
    /// - Returns: A view whose descendants inherit the given base foreground.
    public func foregroundStyle(_ style: Color16) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the inherited base foreground color for this view's descendants.
    ///
    /// Plain ``Text`` runs use this color unless an attributed run supplies its
    /// own foreground. Terminal primitives also consume the base foreground,
    /// including ``Rectangle`` and default shape fills, and ``Box`` borders.
    ///
    /// - Parameter style: A 256-color terminal SGR style.
    /// - Returns: A view whose descendants inherit the given base foreground.
    public func foregroundStyle(_ style: Color256) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the inherited base foreground color for this view's descendants.
    ///
    /// Plain ``Text`` runs use this color unless an attributed run supplies its
    /// own foreground. Terminal primitives also consume the base foreground,
    /// including ``Rectangle`` and default shape fills, and ``Box`` borders.
    ///
    /// - Parameter style: A true-color terminal SGR style.
    /// - Returns: A view whose descendants inherit the given base foreground.
    public func foregroundStyle(_ style: TrueColor) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the inherited base foreground color for this view's descendants.
    ///
    /// Plain ``Text`` runs use this color unless an attributed run supplies its
    /// own foreground. Terminal primitives also consume the base foreground,
    /// including ``Rectangle`` and default shape fills, and ``Box`` borders.
    ///
    /// - Parameter style: The terminal default color reset style.
    /// - Returns: A view whose descendants inherit the given base foreground.
    public func foregroundStyle(_ style: DefaultColor) -> some View {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the inherited base foreground color for this view's descendants.
    ///
    /// Plain ``Text`` runs use this color unless an attributed run supplies its
    /// own foreground. Terminal primitives also consume the base foreground,
    /// including ``Rectangle`` and default shape fills, and ``Box`` borders.
    ///
    /// - Parameter style: A terminal SGR color style.
    /// - Returns: A view whose descendants inherit the given base foreground.
    public func foregroundStyle<S>(_ style: S) -> some View
    where S: Color & ShapeStyle {
        foregroundStyle(AnyColor(style))
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    /// This overload is deprecated; use
    /// ``View/background(_:)-(Color16)`` to fill the modified view's rendered
    /// bounds.
    ///
    /// - Parameter style: A 16-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    public func backgroundStyle(_ style: Color16) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    /// This overload is deprecated; use
    /// ``View/background(_:)-(Color256)`` to fill the modified view's rendered
    /// bounds.
    ///
    /// - Parameter style: A 256-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    public func backgroundStyle(_ style: Color256) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    /// This overload is deprecated; use
    /// ``View/background(_:)-(TrueColor)`` to fill the modified view's rendered
    /// bounds.
    ///
    /// - Parameter style: A true-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    public func backgroundStyle(_ style: TrueColor) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    /// This overload is deprecated; use
    /// ``View/background(_:)-(DefaultColor)`` to fill the modified view's
    /// rendered bounds.
    ///
    /// - Parameter style: The terminal default color reset style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    public func backgroundStyle(_ style: DefaultColor) -> some View {
        _backgroundStyle(style)
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    /// This overload is deprecated; use ``View/background(_:)-(S)`` to fill the
    /// modified view's rendered bounds.
    ///
    /// - Parameter style: A terminal SGR color style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    public func backgroundStyle<S>(_ style: S) -> some View
    where S: Color & ShapeStyle {
        _backgroundStyle(style)
    }

    /// Sets the inherited base foreground color for this view's descendants.
    ///
    /// Plain ``Text`` runs use this color unless an attributed run supplies its
    /// own foreground. Terminal primitives also consume the base foreground,
    /// including ``Rectangle`` and default shape fills, and ``Box`` borders.
    ///
    /// - Parameter style: A type-erased terminal SGR color style.
    /// - Returns: A view whose descendants inherit the given base foreground.
    public func foregroundStyle(_ style: AnyColor) -> some View {
        transformEnvironment(\.textStyle) {
            $0.foregroundStyle = style
        }
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// This overload is deprecated; use
    /// ``View/background(_:)-(AnyColor)`` to fill the modified view's rendered
    /// bounds.
    ///
    /// - Parameter style: A type-erased terminal SGR color style.
    /// - Returns: A view that renders descendant text with the given style.
    @available(*, deprecated, renamed: "background(_:)")
    public func backgroundStyle(_ style: AnyColor) -> some View {
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

    /// Sets the tint for controls, links, and selected-text backgrounds.
    ///
    /// Passing `nil` also removes the tint background from selected text. It
    /// doesn't change the separately configured selected-text foreground.
    ///
    /// - Parameter tint: A 16-color terminal SGR style, or `nil` to clear the
    ///   tint and selected-text background.
    /// - Returns: A view with the updated tint environment.
    public func tint(_ tint: Color16?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    /// Sets the tint for controls, links, and selected-text backgrounds.
    ///
    /// Passing `nil` also removes the tint background from selected text. It
    /// doesn't change the separately configured selected-text foreground.
    ///
    /// - Parameter tint: A 256-color terminal SGR style, or `nil` to clear the
    ///   tint and selected-text background.
    /// - Returns: A view with the updated tint environment.
    public func tint(_ tint: Color256?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    /// Sets the tint for controls, links, and selected-text backgrounds.
    ///
    /// Passing `nil` also removes the tint background from selected text. It
    /// doesn't change the separately configured selected-text foreground.
    ///
    /// - Parameter tint: A true-color terminal SGR style, or `nil` to clear the
    ///   tint and selected-text background.
    /// - Returns: A view with the updated tint environment.
    public func tint(_ tint: TrueColor?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    /// Sets the tint for controls, links, and selected-text backgrounds.
    ///
    /// Passing `nil` also removes the tint background from selected text. It
    /// doesn't change the separately configured selected-text foreground.
    ///
    /// - Parameter tint: The default color reset style, or `nil` to clear the
    ///   tint and selected-text background.
    /// - Returns: A view with the updated tint environment.
    public func tint(_ tint: DefaultColor?) -> some View {
        self.tint(tint.map { AnyColor($0) })
    }

    private func tint(_ tint: AnyColor?) -> some View {
        transformEnvironment(\.tint) {
            $0 = tint
        }
    }

    /// Sets whether text within this view renders in bold.
    ///
    /// Passing `false` clears only the inherited bold flag. On Darwin, a
    /// strongly emphasized attributed-string run is merged afterward and can
    /// enable bold for that run again.
    ///
    /// - Parameter isActive: Pass `true` to enable bold SGR styling, or `false`
    ///   to clear the inherited bold flag.
    /// - Returns: A view with the updated text style environment.
    public func bold(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isBold = isActive
        }
    }

    /// Sets whether text within this view renders dimmed.
    ///
    /// - Parameter isActive: Pass `true` to enable dim SGR styling, or `false`
    ///   to clear dim styling for descendant text.
    /// - Returns: A view with the updated text style environment.
    public func dim(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isDim = isActive
        }
    }

    /// Sets whether text within this view renders in italics.
    ///
    /// Passing `false` clears only the inherited italic flag. On Darwin, an
    /// emphasized attributed-string run is merged afterward and can enable
    /// italics for that run again.
    ///
    /// - Parameter isActive: Pass `true` to enable italic SGR styling, or
    ///   `false` to clear the inherited italic flag.
    /// - Returns: A view with the updated text style environment.
    public func italic(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isItalic = isActive
        }
    }

    /// Sets whether text within this view renders underlined.
    ///
    /// - Parameter isActive: Pass `true` to enable underline SGR styling, or
    ///   `false` to clear underline styling for descendant text.
    /// - Returns: A view with the updated text style environment.
    public func underline(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isUnderline = isActive
        }
    }

    /// Sets whether text within this view renders with strikethrough.
    ///
    /// Passing `false` clears only the inherited strikethrough flag. On Darwin,
    /// a strikethrough attributed-string run is merged afterward and can enable
    /// the style for that run again.
    ///
    /// - Parameter isActive: Pass `true` to enable strikethrough SGR styling,
    ///   or `false` to clear the inherited strikethrough flag.
    /// - Returns: A view with the updated text style environment.
    public func strikethrough(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isStrikethrough = isActive
        }
    }

    /// Limits the number of lines used to render text within this view.
    ///
    /// - Parameter number: The maximum number of terminal rows to render, or
    ///   `nil` to remove an inherited limit.
    /// - Returns: A view that applies the line limit to descendant text.
    /// - Precondition: `number == nil || number! >= 1`.
    public func lineLimit(_ number: Int?) -> some View {
        lineLimit(number, reservesSpace: false)
    }

    /// Limits the number of lines used to render text within this view.
    ///
    /// - Parameters:
    ///   - number: The maximum number of terminal rows to render, or `nil` to
    ///     remove the limit. Non-`nil` values must be greater than zero.
    ///   - reservesSpace: When `true` and `number` is non-`nil`, reserve exactly
    ///     that many rows even when the text uses fewer rows.
    /// - Returns: A view that applies the line limit to descendant text.
    /// - Precondition: `number == nil || number! >= 1`.
    public func lineLimit(_ number: Int?, reservesSpace: Bool) -> some View {
        if let number {
            precondition(number >= 1, "lineLimit must be greater than zero.")
        }

        return LineLimitView(
            content: self,
            lineLimit: TextLineLimit(number: number, reservesSpace: reservesSpace)
        )
    }

    /// Sets how the last visible line of text is truncated.
    ///
    /// The setting affects text only when a line or row limit removes content.
    /// SwiftTUI marks the removal with up to three ASCII period characters,
    /// rather than U+2026.
    ///
    /// - Parameter mode: The location from which to remove text around the
    ///   ASCII-period marker.
    /// - Returns: A view with the specified truncation mode.
    public nonisolated func truncationMode(_ mode: Text.TruncationMode) -> some View {
        EnvironmentValueView(
            content: self,
            keyPath: \.truncationMode,
            value: mode
        )
    }

    /// Sets the horizontal alignment of multiline text.
    ///
    /// An explicit ``SwiftTUIAlignmentAttribute`` on attributed text takes
    /// precedence for the attributed paragraph. Plain ``Text`` aligns within
    /// its widest rendered line's natural width and doesn't expand to a finite
    /// proposal merely for alignment. Multiline ``EditableText`` aligns within
    /// finite proposed columns; attributed alignment also uses the proposed
    /// width when one is available.
    ///
    /// - Parameter alignment: The alignment to apply to text lines.
    /// - Returns: A view with the specified multiline text alignment.
    public nonisolated func multilineTextAlignment(_ alignment: TextAlignment) -> some View {
        EnvironmentValueView(
            content: self,
            keyPath: \.multilineTextAlignment,
            value: alignment
        )
    }
}

extension EnvironmentValues {

    /// The maximum number of terminal rows that text can occupy.
    ///
    /// A value less than one is treated as one. The default value is `nil`,
    /// which allows text to use as many rows as it needs.
    public nonisolated var lineLimit: Int? {
        get {
            textLineLimit.number
        }
        set {
            textLineLimit = TextLineLimit(
                number: newValue.map { max(1, $0) },
                reservesSpace: false
            )
        }
    }

    /// The mode used to truncate the last visible line of text.
    ///
    /// The default is ``Text/TruncationMode/tail``.
    public nonisolated var truncationMode: Text.TruncationMode {
        get {
            self[TruncationModeKey.self]
        }
        set {
            self[TruncationModeKey.self] = newValue
        }
    }

    /// The horizontal alignment used for multiline text without an attributed
    /// alignment override.
    ///
    /// The default is ``TextAlignment/leading``.
    public nonisolated var multilineTextAlignment: TextAlignment {
        get {
            self[MultilineTextAlignmentKey.self]
        }
        set {
            self[MultilineTextAlignmentKey.self] = newValue
        }
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

    nonisolated var textLineLimit: TextLineLimit {
        get {
            self[TextLineLimitKey.self]
        }
        set {
            self[TextLineLimitKey.self] = newValue
        }
    }
}

private struct TextStyleKey: EnvironmentKey {

    nonisolated static let defaultValue = TextStyle.plain
}

private struct TintKey: EnvironmentKey {

    nonisolated static let defaultValue: AnyColor? = AnyColor(Color16.blue)
}

private struct TextLineLimitKey: EnvironmentKey {

    nonisolated static let defaultValue = TextLineLimit(
        number: nil,
        reservesSpace: false
    )
}

private struct TruncationModeKey: EnvironmentKey {

    nonisolated static let defaultValue = Text.TruncationMode.tail
}

private struct MultilineTextAlignmentKey: EnvironmentKey {

    nonisolated static let defaultValue = TextAlignment.leading
}
