import Foundation
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
}

/// A 16-color terminal SGR color.
public typealias Color16 = Terminal.SGR.Color16

/// A 256-color terminal SGR color.
public typealias Color256 = Terminal.SGR.Color256

/// A true-color terminal SGR color.
public typealias TrueColor = Terminal.SGR.TrueColor

extension Color16: ShapeStyle {
}

extension Color256: ShapeStyle {
}

extension TrueColor: ShapeStyle {
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

    /// The string rendered by this text view.
    public let content: String

    /// Creates a text view from a string.
    ///
    /// - Parameter content: The string to render in the terminal.
    public init(_ content: String) {
        self.content = content
    }
}

nonisolated struct AnyColor: Color {

    let background: String

    let foreground: String

    init<C: Color>(_ color: C) {
        self.background = color.background
        self.foreground = color.foreground
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
    func backgroundStyle(_ style: Color16) -> some View {
        backgroundStyle(AnyColor(style))
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A 256-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    func backgroundStyle(_ style: Color256) -> some View {
        backgroundStyle(AnyColor(style))
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A true-color terminal SGR style.
    /// - Returns: A view that renders descendant text with the given style.
    func backgroundStyle(_ style: TrueColor) -> some View {
        backgroundStyle(AnyColor(style))
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: The terminal default color reset style.
    /// - Returns: A view that renders descendant text with the given style.
    func backgroundStyle(_ style: DefaultColor) -> some View {
        backgroundStyle(AnyColor(style))
    }

    /// Sets the terminal background style for text within this view.
    ///
    /// SwiftTUI currently accepts terminal color styles only.
    ///
    /// - Parameter style: A terminal SGR color style.
    /// - Returns: A view that renders descendant text with the given style.
    func backgroundStyle<S>(_ style: S) -> some View
    where S: Color & ShapeStyle {
        backgroundStyle(AnyColor(style))
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

    private func foregroundStyle(_ style: AnyColor) -> some View {
        transformEnvironment(\.textStyle) {
            $0.foregroundStyle = style
        }
    }

    private func backgroundStyle(_ style: AnyColor) -> some View {
        transformEnvironment(\.textStyle) {
            $0.backgroundStyle = style
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
}

private struct TextStyleKey: EnvironmentKey {

    nonisolated static let defaultValue = TextStyle.plain
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
