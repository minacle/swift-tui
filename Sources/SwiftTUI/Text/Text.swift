import Foundation

/// A view that displays text in the terminal.
public struct Text: View, Equatable, Sendable {

    public typealias Body = Never

    public let content: String

    public init(_ content: String) {
        self.content = content
    }
}

/// A terminal foreground color.
public enum TerminalColor: Equatable, Sendable {

    case `default`

    case black

    case red

    case green

    case yellow

    case blue

    case magenta

    case cyan

    case white

    case brightBlack

    case brightRed

    case brightGreen

    case brightYellow

    case brightBlue

    case brightMagenta

    case brightCyan

    case brightWhite
}

struct TextStyle: Equatable, Sendable {

    var color: TerminalColor?

    var isBold: Bool

    var isDim: Bool = false

    static let plain = TextStyle(color: nil, isBold: false)

    var isPlain: Bool {
        color == nil && !isBold && !isDim
    }
}

struct TextLineLimit: Equatable, Sendable {

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

    /// Sets the terminal foreground color for text within this view.
    func color(_ color: TerminalColor) -> some View {
        transformEnvironment(\.textStyle) {
            $0.color = color
        }
    }

    /// Sets whether text within this view renders in bold.
    func bold(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isBold = isActive
        }
    }

    /// Sets whether text within this view renders dimmed.
    func dim(_ isActive: Bool = true) -> some View {
        transformEnvironment(\.textStyle) {
            $0.isDim = isActive
        }
    }

    /// Limits the number of lines used to render text within this view.
    func lineLimit(_ number: Int?) -> some View {
        lineLimit(number, reservesSpace: false)
    }

    /// Limits the number of lines used to render text within this view.
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

    static let defaultValue = TextStyle.plain
}

enum TextLineLimitContext {

    private static let threadKey = "SwiftTUI.TextLineLimitContext"

    static var current: TextLineLimit {
        get {
            Thread.current.threadDictionary[threadKey] as? TextLineLimit
                ?? TextLineLimit(number: nil, reservesSpace: false)
        }
        set {
            Thread.current.threadDictionary[threadKey] = newValue
        }
    }

    static func withLineLimit<Value>(
        _ lineLimit: TextLineLimit,
        perform operation: () -> Value
    ) -> Value {
        let previous = current
        current = lineLimit
        defer {
            current = previous
        }

        return operation()
    }
}
