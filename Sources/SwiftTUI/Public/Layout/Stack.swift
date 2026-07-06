/// Horizontal alignment for views arranged in a ``VStack``.
public nonisolated enum HorizontalAlignment: Equatable, Sendable {

    /// Align children to the leading terminal column.
    case leading

    /// Center children horizontally.
    case center

    /// Align children to the trailing terminal column.
    case trailing
}

/// Vertical alignment for views arranged in an ``HStack``.
public nonisolated enum VerticalAlignment: Equatable, Sendable {

    /// Align children to the top terminal row.
    case top

    /// Center children vertically.
    case center

    /// Align children to the bottom terminal row.
    case bottom
}

/// A view that arranges its children from left to right.
///
/// `HStack` measures its children in terminal cells and inserts a fixed number
/// of blank columns between adjacent children.
public nonisolated struct HStack<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: VerticalAlignment

    let spacing: Int

    let content: Content

    /// Creates a horizontal stack.
    ///
    /// - Parameters:
    ///   - alignment: The vertical alignment used for children with different heights.
    ///   - spacing: The number of blank terminal columns between children.
    ///   - content: A view builder that creates the stack's children.
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
///
/// `VStack` measures its children in terminal cells and inserts a fixed number
/// of blank rows between adjacent children.
public nonisolated struct VStack<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: HorizontalAlignment

    let spacing: Int

    let content: Content

    /// Creates a vertical stack.
    ///
    /// - Parameters:
    ///   - alignment: The horizontal alignment used for children with different widths.
    ///   - spacing: The number of blank terminal rows between children.
    ///   - content: A view builder that creates the stack's children.
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

/// A view that overlays its children, aligning them in both axes.
///
/// Later children are rendered above earlier children unless ``View/zIndex(_:)``
/// changes their front-to-back order.
public nonisolated struct ZStack<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: Alignment

    let content: Content

    /// Creates an overlay stack.
    ///
    /// - Parameters:
    ///   - alignment: The alignment used to place each child within the stack.
    ///   - content: A view builder that creates the stack's children.
    public init(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }
}
