/// Horizontal alignment for views arranged in a ``VStack``.
public enum HorizontalAlignment: Equatable, Sendable {

    case leading

    case center

    case trailing
}

/// Vertical alignment for views arranged in an ``HStack``.
public enum VerticalAlignment: Equatable, Sendable {

    case top

    case center

    case bottom
}

/// A view that arranges its children from left to right.
public struct HStack<Content: View>: View {

    public typealias Body = Never

    let alignment: VerticalAlignment

    let spacing: Int

    let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = max(spacing, 0)
        self.content = content()
    }
}

/// A view that arranges its children from top to bottom.
public struct VStack<Content: View>: View {

    public typealias Body = Never

    let alignment: HorizontalAlignment

    let spacing: Int

    let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = max(spacing, 0)
        self.content = content()
    }
}
