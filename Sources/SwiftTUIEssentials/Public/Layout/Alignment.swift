/// A type that defines the fallback coordinate for a custom alignment guide.
///
/// Define an identifier type and use it to create a ``HorizontalAlignment`` or
/// ``VerticalAlignment``. SwiftTUI asks the identifier for a default only when
/// a view has not supplied an explicit value with an `alignmentGuide`
/// modifier.
///
/// Coordinates are measured in terminal cells in the aligned view's local
/// coordinate space. Column and row zero are the leading and top edges,
/// respectively. A guide may return a coordinate outside the view's bounds;
/// stack layout can grow to align such guides rather than clamping the value.
public protocol AlignmentID {

    /// Returns the fallback terminal-cell coordinate for the guide.
    ///
    /// SwiftTUI can call this method more than once while measuring and placing
    /// a view. The implementation should derive its result only from `context`.
    ///
    /// - Parameter context: The view's measured size and any explicit alignment
    ///   guides available in its local coordinate space.
    /// - Returns: A column or row coordinate, according to the axis of the
    ///   alignment that uses this identifier.
    nonisolated static func defaultValue(in context: ViewDimensions) -> Int
}

nonisolated enum AlignmentAxis: Hashable, Sendable {
    case horizontal
    case vertical
}

nonisolated struct AlignmentKey: Hashable, @unchecked Sendable {

    let id: ObjectIdentifier

    let axis: AlignmentAxis

    private let defaultValue: (ViewDimensions) -> Int

    init<ID: AlignmentID>(_ id: ID.Type, axis: AlignmentAxis) {
        self.id = ObjectIdentifier(id)
        self.axis = axis
        self.defaultValue = { ID.defaultValue(in: $0) }
    }

    func value(in context: ViewDimensions) -> Int {
        defaultValue(context)
    }

    static func == (lhs: AlignmentKey, rhs: AlignmentKey) -> Bool {
        lhs.id == rhs.id && lhs.axis == rhs.axis
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(axis)
    }
}

/// A horizontal guide used to align views by terminal column.
///
/// SwiftTUI currently uses a left-to-right coordinate system, so leading is
/// always column zero and trailing is the measured column count. Custom guides
/// use an ``AlignmentID`` type as their identity.
public nonisolated struct HorizontalAlignment: Equatable, Sendable {

    let key: AlignmentKey

    init(key: AlignmentKey) {
        self.key = key
    }

    /// Creates a horizontal guide from an alignment identifier.
    ///
    /// - Parameter id: The identifier that supplies the guide's fallback
    ///   column when a view has no explicit value.
    public init(_ id: any AlignmentID.Type) {
        key = AlignmentKey(id, axis: .horizontal)
    }

    /// Merges explicit column coordinates into one guide value.
    ///
    /// The method ignores missing values and returns `nil` if every element is
    /// `nil`. Because terminal coordinates are integral, a fractional average
    /// is truncated toward zero.
    ///
    /// - Parameter values: Explicit guide coordinates from aligned descendants.
    /// - Returns: Their integer average, or `nil` when no explicit coordinate
    ///   is present.
    /// - Precondition: The sum of the non-`nil` coordinates is representable as
    ///   an `Int`.
    public func combineExplicit<S>(_ values: S) -> Int?
    where S: Sequence, S.Element == Int? {
        let values = values.compactMap { $0 }
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / values.count
    }

    /// The leading edge at column zero.
    public static let leading = HorizontalAlignment(LeadingAlignment.self)

    /// The horizontal center at half the measured column count.
    public static let center = HorizontalAlignment(HorizontalCenterAlignment.self)

    /// The trailing edge at the measured column count.
    public static let trailing = HorizontalAlignment(TrailingAlignment.self)
}

/// A vertical guide used to align views by terminal row.
///
/// The top edge is row zero and the bottom edge is the measured row count.
/// Terminal text-baseline guides aren't currently provided.
public nonisolated struct VerticalAlignment: Equatable, Sendable {

    let key: AlignmentKey

    init(key: AlignmentKey) {
        self.key = key
    }

    /// Creates a vertical guide from an alignment identifier.
    ///
    /// - Parameter id: The identifier that supplies the guide's fallback row
    ///   when a view has no explicit value.
    public init(_ id: any AlignmentID.Type) {
        key = AlignmentKey(id, axis: .vertical)
    }

    /// Merges explicit row coordinates into one guide value.
    ///
    /// The method ignores missing values and returns `nil` if every element is
    /// `nil`. Because terminal coordinates are integral, a fractional average
    /// is truncated toward zero.
    ///
    /// - Parameter values: Explicit guide coordinates from aligned descendants.
    /// - Returns: Their integer average, or `nil` when no explicit coordinate
    ///   is present.
    /// - Precondition: The sum of the non-`nil` coordinates is representable as
    ///   an `Int`.
    public func combineExplicit<S>(_ values: S) -> Int?
    where S: Sequence, S.Element == Int? {
        let values = values.compactMap { $0 }
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / values.count
    }

    /// The top edge at row zero.
    public static let top = VerticalAlignment(TopAlignment.self)

    /// The vertical center at half the measured row count.
    public static let center = VerticalAlignment(VerticalCenterAlignment.self)

    /// The bottom edge at the measured row count.
    public static let bottom = VerticalAlignment(BottomAlignment.self)
}

/// A pair of horizontal and vertical terminal-cell alignment guides.
///
/// Use an alignment to position or clip content within a frame, overlay, grid
/// cell, or custom-layout placement. Each component is resolved independently.
public nonisolated struct Alignment: Equatable, Sendable {

    /// The horizontal alignment component.
    public let horizontal: HorizontalAlignment

    /// The vertical alignment component.
    public let vertical: VerticalAlignment

    /// Creates an alignment from horizontal and vertical guides.
    ///
    /// - Parameters:
    ///   - horizontal: The guide used to resolve a column.
    ///   - vertical: The guide used to resolve a row.
    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// Top-leading alignment.
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)

    /// Top-center alignment.
    public static let top = Alignment(horizontal: .center, vertical: .top)

    /// Top-trailing alignment.
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)

    /// Center-leading alignment.
    public static let leading = Alignment(horizontal: .leading, vertical: .center)

    /// Center alignment in both axes.
    public static let center = Alignment(horizontal: .center, vertical: .center)

    /// Center-trailing alignment.
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)

    /// Bottom-leading alignment.
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)

    /// Bottom-center alignment.
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)

    /// Bottom-trailing alignment.
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

private nonisolated enum LeadingAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int { 0 }
}

private nonisolated enum HorizontalCenterAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int { context.columns / 2 }
}

private nonisolated enum TrailingAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int { context.columns }
}

private nonisolated enum TopAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int { 0 }
}

private nonisolated enum VerticalCenterAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int { context.rows / 2 }
}

private nonisolated enum BottomAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int { context.rows }
}

private struct HorizontalAlignmentGuideView<Content: View>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let guide: HorizontalAlignment

    let computeValue: @Sendable (ViewDimensions) -> Int

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )?.settingExplicitAlignment(guide, computeValue: computeValue)
    }
}

private struct VerticalAlignmentGuideView<Content: View>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let guide: VerticalAlignment

    let computeValue: @Sendable (ViewDimensions) -> Int

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )?.settingExplicitAlignment(guide, computeValue: computeValue)
    }
}

public extension View {

    /// Assigns an explicit horizontal alignment guide to this view.
    ///
    /// SwiftTUI passes the view's measured dimensions to `computeValue`. The
    /// returned column is in the view's local coordinate space and is not
    /// clamped to its bounds. Applying this modifier again for the same guide
    /// lets the outer closure read and replace the inner value.
    ///
    /// The closure may run during measurement and may run more than once; avoid
    /// using it for state changes or other side effects.
    ///
    /// - Parameters:
    ///   - guide: The horizontal guide to assign.
    ///   - computeValue: A closure that returns a local terminal-column
    ///     coordinate from the measured dimensions.
    /// - Returns: A view that reports the explicit guide to its parent layout.
    func alignmentGuide(
        _ guide: HorizontalAlignment,
        computeValue: @escaping @Sendable (ViewDimensions) -> Int
    ) -> some View {
        HorizontalAlignmentGuideView(
            content: self,
            guide: guide,
            computeValue: computeValue
        )
    }

    /// Assigns an explicit vertical alignment guide to this view.
    ///
    /// SwiftTUI passes the view's measured dimensions to `computeValue`. The
    /// returned row is in the view's local coordinate space and is not clamped
    /// to its bounds. Applying this modifier again for the same guide lets the
    /// outer closure read and replace the inner value.
    ///
    /// The closure may run during measurement and may run more than once; avoid
    /// using it for state changes or other side effects.
    ///
    /// - Parameters:
    ///   - guide: The vertical guide to assign.
    ///   - computeValue: A closure that returns a local terminal-row coordinate
    ///     from the measured dimensions.
    /// - Returns: A view that reports the explicit guide to its parent layout.
    func alignmentGuide(
        _ guide: VerticalAlignment,
        computeValue: @escaping @Sendable (ViewDimensions) -> Int
    ) -> some View {
        VerticalAlignmentGuideView(
            content: self,
            guide: guide,
            computeValue: computeValue
        )
    }
}
