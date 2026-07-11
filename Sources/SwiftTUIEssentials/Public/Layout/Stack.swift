/// A view that arranges its children from left to right.
///
/// `HStack` measures its children in terminal cells and inserts automatic or
/// explicit blank columns between adjacent children. It proposes the available
/// rows while first measuring children at their natural widths. If any
/// non-spacer content is horizontally flexible, those children share the
/// remaining proposed columns before ``Spacer`` values. Otherwise, spacers
/// share the remainder after their minimum lengths are reserved.
///
/// The stack's height includes the space needed to align custom guides that lie
/// outside a child's bounds. It does not expand to a taller parent proposal
/// unless a child is vertically flexible.
public nonisolated struct HStack<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: VerticalAlignment

    let spacing: Int?

    let content: Content

    /// Creates a horizontal stack.
    ///
    /// - Parameters:
    ///   - alignment: The vertical guide used for children with different
    ///     heights. The default is center.
    ///   - spacing: The number of blank terminal columns between children, or
    ///     `nil` to use the maximum shared-edge preference from each adjacent
    ///     pair. Negative values are clamped to zero.
    ///   - content: A view builder that creates the stack's children.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing.map { max($0, 0) }
        self.content = content()
    }
}

/// A view that arranges its children from top to bottom.
///
/// `VStack` measures its children in terminal cells and inserts automatic or
/// explicit blank rows between adjacent children. It proposes the available
/// columns while first measuring children at their natural heights. If any
/// non-spacer content is vertically flexible, those children share the
/// remaining proposed rows before ``Spacer`` values. Otherwise, spacers share
/// the remainder after their minimum lengths are reserved.
///
/// The stack's width includes the space needed to align custom guides that lie
/// outside a child's bounds. It does not expand to a wider parent proposal
/// unless a child is horizontally flexible.
public nonisolated struct VStack<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: HorizontalAlignment

    let spacing: Int?

    let content: Content

    /// Creates a vertical stack.
    ///
    /// - Parameters:
    ///   - alignment: The horizontal guide used for children with different
    ///     widths. The default is center.
    ///   - spacing: The number of blank terminal rows between children, or
    ///     `nil` to use the maximum shared-edge preference from each adjacent
    ///     pair. Negative values are clamped to zero.
    ///   - content: A view builder that creates the stack's children.
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing.map { max($0, 0) }
        self.content = content()
    }
}

/// A view that overlays its children, aligning them in both axes.
///
/// Later children are rendered above earlier children unless ``View/zIndex(_:)``
/// changes their front-to-back order. On an unspecified axis the stack uses the
/// largest child dimension; on a specified axis it occupies the proposal and
/// aligns each child within it. Content outside the resulting bounds is clipped.
public nonisolated struct ZStack<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: Alignment

    let content: Content

    /// Creates an overlay stack.
    ///
    /// - Parameters:
    ///   - alignment: The horizontal and vertical guides used to place each
    ///     child. The default centers children on both axes.
    ///   - content: A view builder that creates the stack's children.
    public init(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }
}
