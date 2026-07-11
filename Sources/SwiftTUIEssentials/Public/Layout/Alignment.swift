/// A type that defines the default value for a custom alignment guide.
public protocol AlignmentID {

    /// Returns the default terminal-cell coordinate for the guide.
    ///
    /// - Parameter context: The measured dimensions of the aligned view.
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

/// A horizontal alignment position in terminal-cell coordinates.
///
/// SwiftTUI currently uses a left-to-right coordinate system, so leading is
/// always the left edge and trailing is always the right edge.
public nonisolated struct HorizontalAlignment: Equatable, Sendable {

    let key: AlignmentKey

    init(key: AlignmentKey) {
        self.key = key
    }

    /// Creates a custom horizontal alignment from an alignment identifier.
    public init(_ id: any AlignmentID.Type) {
        key = AlignmentKey(id, axis: .horizontal)
    }

    /// Merges explicit alignment values by averaging the non-`nil` values.
    ///
    /// Fractional terminal-cell results are truncated toward zero.
    public func combineExplicit<S>(_ values: S) -> Int?
    where S: Sequence, S.Element == Int? {
        let values = values.compactMap { $0 }
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / values.count
    }

    /// The leading edge of a view.
    public static let leading = HorizontalAlignment(LeadingAlignment.self)

    /// The horizontal center of a view.
    public static let center = HorizontalAlignment(HorizontalCenterAlignment.self)

    /// The trailing edge of a view.
    public static let trailing = HorizontalAlignment(TrailingAlignment.self)
}

/// A vertical alignment position in terminal-cell coordinates.
///
/// Terminal text-baseline guides aren't currently provided.
public nonisolated struct VerticalAlignment: Equatable, Sendable {

    let key: AlignmentKey

    init(key: AlignmentKey) {
        self.key = key
    }

    /// Creates a custom vertical alignment from an alignment identifier.
    public init(_ id: any AlignmentID.Type) {
        key = AlignmentKey(id, axis: .vertical)
    }

    /// Merges explicit alignment values by averaging the non-`nil` values.
    ///
    /// Fractional terminal-cell results are truncated toward zero.
    public func combineExplicit<S>(_ values: S) -> Int?
    where S: Sequence, S.Element == Int? {
        let values = values.compactMap { $0 }
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / values.count
    }

    /// The top edge of a view.
    public static let top = VerticalAlignment(TopAlignment.self)

    /// The vertical center of a view.
    public static let center = VerticalAlignment(VerticalCenterAlignment.self)

    /// The bottom edge of a view.
    public static let bottom = VerticalAlignment(BottomAlignment.self)
}

/// An alignment in both terminal axes.
public nonisolated struct Alignment: Equatable, Sendable {

    /// The horizontal alignment component.
    public let horizontal: HorizontalAlignment

    /// The vertical alignment component.
    public let vertical: VerticalAlignment

    /// Creates an alignment from horizontal and vertical components.
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

    /// Overrides a horizontal alignment guide for this view.
    ///
    /// - Parameters:
    ///   - guide: The guide to override.
    ///   - computeValue: A closure that returns a terminal-column coordinate.
    /// - Returns: A view with the explicit alignment guide.
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

    /// Overrides a vertical alignment guide for this view.
    ///
    /// - Parameters:
    ///   - guide: The guide to override.
    ///   - computeValue: A closure that returns a terminal-row coordinate.
    /// - Returns: A view with the explicit alignment guide.
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
