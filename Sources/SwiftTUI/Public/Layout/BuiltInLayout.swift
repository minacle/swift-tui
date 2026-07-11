/// A horizontal container that can participate in conditional layouts.
public nonisolated struct HStackLayout: Layout, Sendable {

    /// The vertical alignment of subviews.
    public var alignment: VerticalAlignment

    /// The number of terminal columns between adjacent subviews.
    public var spacing: Int?

    /// Creates a horizontal stack layout.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int? = nil
    ) {
        self.alignment = alignment
        self.spacing = spacing
    }

    /// The horizontal orientation of this stack layout.
    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }

    /// Returns the size required by the horizontal arrangement.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        LinearLayoutSolver.horizontal(
            proposal: proposal,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        ).size
    }

    /// Places subviews from leading to trailing.
    public func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        LinearLayoutSolver.horizontal(
            proposal: ProposedViewSize(bounds.size),
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        ).place(in: bounds, subviews: subviews)
    }
}

/// A vertical container that can participate in conditional layouts.
public nonisolated struct VStackLayout: Layout, Sendable {

    /// The horizontal alignment of subviews.
    public var alignment: HorizontalAlignment

    /// The number of terminal rows between adjacent subviews.
    public var spacing: Int?

    /// Creates a vertical stack layout.
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int? = nil
    ) {
        self.alignment = alignment
        self.spacing = spacing
    }

    /// The vertical orientation of this stack layout.
    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }

    /// Returns the size required by the vertical arrangement.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        LinearLayoutSolver.vertical(
            proposal: proposal,
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        ).size
    }

    /// Places subviews from top to bottom.
    public func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        LinearLayoutSolver.vertical(
            proposal: ProposedViewSize(bounds.size),
            subviews: subviews,
            alignment: alignment,
            spacing: spacing
        ).place(in: bounds, subviews: subviews)
    }
}

/// An overlaying container that can participate in conditional layouts.
public nonisolated struct ZStackLayout: Layout, Sendable {

    /// The alignment of subviews within the overlay.
    public var alignment: Alignment

    /// Creates an overlaying stack layout.
    public init(alignment: Alignment = .center) {
        self.alignment = alignment
    }

    /// Returns the size required by the overlay.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        OverlayLayoutSolver(
            proposal: proposal,
            subviews: subviews,
            alignment: alignment
        ).size
    }

    /// Places every subview at the configured alignment.
    public func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        OverlayLayoutSolver(
            proposal: ProposedViewSize(bounds.size),
            subviews: subviews,
            alignment: alignment
        ).place(in: bounds, subviews: subviews)
    }
}

/// A two-dimensional grid that can participate in conditional layouts.
public nonisolated struct GridLayout: Layout, Sendable {

    /// The default alignment of content in each cell.
    public var alignment: Alignment

    /// The number of terminal columns between adjacent cells.
    public var horizontalSpacing: Int?

    /// The number of terminal rows between adjacent rows.
    public var verticalSpacing: Int?

    /// Creates a grid layout.
    public init(
        alignment: Alignment = .center,
        horizontalSpacing: Int? = nil,
        verticalSpacing: Int? = nil
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    /// Returns the size required when the layout is invoked directly.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        LinearLayoutSolver.horizontal(
            proposal: proposal,
            subviews: subviews,
            alignment: alignment.vertical,
            spacing: horizontalSpacing
        ).size
    }

    /// Places direct subviews as one grid row.
    public func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        LinearLayoutSolver.horizontal(
            proposal: ProposedViewSize(bounds.size),
            subviews: subviews,
            alignment: alignment.vertical,
            spacing: horizontalSpacing
        ).place(in: bounds, subviews: subviews)
    }
}

private nonisolated struct LinearLayoutSolution {

    struct Placement {

        var point: Point

        var proposal: ProposedViewSize
    }

    var size: Size

    var placements: [Placement]

    func place(in bounds: Rect, subviews: LayoutSubviews) {
        for (subview, placement) in zip(subviews, placements) {
            subview.place(
                at: Point(
                    column: bounds.origin.column + placement.point.column,
                    row: bounds.origin.row + placement.point.row
                ),
                proposal: placement.proposal
            )
        }
    }
}

private nonisolated enum LinearLayoutSolver {

    static func horizontal(
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        alignment: VerticalAlignment,
        spacing: Int?
    ) -> LinearLayoutSolution {
        let childProposal = ProposedViewSize(columns: nil, rows: proposal.rows)
        var dimensions = subviews.map { $0.dimensions(in: childProposal) }
        let gaps = spacingGaps(
            subviews: subviews,
            spacing: spacing,
            axis: .horizontal
        )
        distributeExtra(
            proposedLength: proposal.columns,
            spacing: gaps.reduce(0, +),
            axis: .horizontal,
            subviews: subviews,
            dimensions: &dimensions
        )
        let line = dimensions.map { $0[alignment] }.max() ?? 0
        let height = dimensions.map {
            line - $0[alignment] + $0.rows
        }.max() ?? 0
        var x = 0
        let placements = dimensions.enumerated().map { index, dimension in
            defer {
                x += dimension.columns + (gaps.indices.contains(index) ? gaps[index] : 0)
            }
            return LinearLayoutSolution.Placement(
                point: Point(column: x, row: line - dimension[alignment]),
                proposal: ProposedViewSize(
                    columns: dimension.columns,
                    rows: max(height, dimension.rows)
                )
            )
        }
        let width = dimensions.reduce(0) { $0 + $1.columns } + gaps.reduce(0, +)
        return LinearLayoutSolution(
            size: Size(columns: width, rows: height),
            placements: placements
        )
    }

    static func vertical(
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        alignment: HorizontalAlignment,
        spacing: Int?
    ) -> LinearLayoutSolution {
        let childProposal = ProposedViewSize(columns: proposal.columns, rows: nil)
        var dimensions = subviews.map { $0.dimensions(in: childProposal) }
        let gaps = spacingGaps(
            subviews: subviews,
            spacing: spacing,
            axis: .vertical
        )
        distributeExtra(
            proposedLength: proposal.rows,
            spacing: gaps.reduce(0, +),
            axis: .vertical,
            subviews: subviews,
            dimensions: &dimensions
        )
        let line = dimensions.map { $0[alignment] }.max() ?? 0
        let width = dimensions.map {
            line - $0[alignment] + $0.columns
        }.max() ?? 0
        var y = 0
        let placements = dimensions.enumerated().map { index, dimension in
            defer {
                y += dimension.rows + (gaps.indices.contains(index) ? gaps[index] : 0)
            }
            return LinearLayoutSolution.Placement(
                point: Point(column: line - dimension[alignment], row: y),
                proposal: ProposedViewSize(
                    columns: max(width, dimension.columns),
                    rows: dimension.rows
                )
            )
        }
        let height = dimensions.reduce(0) { $0 + $1.rows } + gaps.reduce(0, +)
        return LinearLayoutSolution(
            size: Size(columns: width, rows: height),
            placements: placements
        )
    }

    private static func spacingGaps(
        subviews: LayoutSubviews,
        spacing: Int?,
        axis: Axis
    ) -> [Int] {
        guard subviews.count > 1 else {
            return []
        }
        if let spacing {
            return Array(repeating: max(spacing, 0), count: subviews.count - 1)
        }
        return subviews.indices.dropLast().map {
            subviews[$0].spacing.distance(to: subviews[$0 + 1].spacing, along: axis)
        }
    }

    private static func distributeExtra(
        proposedLength: Int?,
        spacing: Int,
        axis: Axis,
        subviews: LayoutSubviews,
        dimensions: inout [ViewDimensions]
    ) {
        guard let proposedLength else {
            return
        }
        let flexible = subviews.indices.filter {
            let subview = subviews[$0]
            let axisSet: Axis.Set = axis == .horizontal ? .horizontal : .vertical
            return subview.child.isSpacer
                || subview.child.traits.flexibleAxes.contains(axisSet)
        }
        guard !flexible.isEmpty else {
            return
        }
        let current = dimensions.reduce(0) {
            $0 + (axis == .horizontal ? $1.columns : $1.rows)
        } + spacing
        let extra = max(proposedLength - current, 0)
        for (offset, index) in flexible.enumerated() {
            let increment = extra / flexible.count + (offset < extra % flexible.count ? 1 : 0)
            let dimension = dimensions[index]
            dimensions[index] = ViewDimensions(
                columns: dimension.columns + (axis == .horizontal ? increment : 0),
                rows: dimension.rows + (axis == .vertical ? increment : 0),
                explicitAlignments: dimension.explicitAlignments
            )
        }
    }
}

private nonisolated struct OverlayLayoutSolver {

    let proposal: ProposedViewSize

    let subviews: LayoutSubviews

    let alignment: Alignment

    var dimensions: [ViewDimensions] {
        subviews.map { $0.dimensions(in: proposal) }
    }

    var size: Size {
        let dimensions = dimensions
        return Size(
            columns: proposal.columns ?? dimensions.map(\.columns).max() ?? 0,
            rows: proposal.rows ?? dimensions.map(\.rows).max() ?? 0
        )
    }

    func place(in bounds: Rect, subviews: LayoutSubviews) {
        for (subview, dimension) in zip(subviews, dimensions) {
            let container = ViewDimensions(
                columns: bounds.size.columns,
                rows: bounds.size.rows
            )
            subview.place(
                at: Point(
                    column: bounds.origin.column
                        + container[alignment.horizontal]
                        - dimension[alignment.horizontal],
                    row: bounds.origin.row
                        + container[alignment.vertical]
                        - dimension[alignment.vertical]
                ),
                anchor: alignment,
                proposal: ProposedViewSize(bounds.size)
            )
        }
    }
}

enum BuiltInLayoutKind {

    case horizontal

    case vertical

    case overlay

    case grid
}

nonisolated protocol BuiltInLayoutAdapter {

    nonisolated var builtInLayoutKind: BuiltInLayoutKind? { get }

    nonisolated var resolvedLayoutProperties: LayoutProperties { get }

    @MainActor
    func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock?
}

extension HStackLayout: BuiltInLayoutAdapter {

    var builtInLayoutKind: BuiltInLayoutKind? { .horizontal }

    var resolvedLayoutProperties: LayoutProperties { Self.layoutProperties }

    @MainActor
    func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        StackRenderer.horizontal(
            children,
            alignment: alignment,
            spacing: spacing.map { max($0, 0) },
            proposal: proposal
        )
    }
}

extension VStackLayout: BuiltInLayoutAdapter {

    var builtInLayoutKind: BuiltInLayoutKind? { .vertical }

    var resolvedLayoutProperties: LayoutProperties { Self.layoutProperties }

    @MainActor
    func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        StackRenderer.vertical(
            children,
            alignment: alignment,
            spacing: spacing.map { max($0, 0) },
            proposal: proposal
        )
    }
}

extension ZStackLayout: BuiltInLayoutAdapter {

    var builtInLayoutKind: BuiltInLayoutKind? { .overlay }

    var resolvedLayoutProperties: LayoutProperties { Self.layoutProperties }

    @MainActor
    func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        ZStackRenderer.block(
            children,
            alignment: alignment,
            proposal: proposal
        )
    }
}

extension GridLayout: BuiltInLayoutAdapter {

    var builtInLayoutKind: BuiltInLayoutKind? { .grid }

    var resolvedLayoutProperties: LayoutProperties { Self.layoutProperties }

    @MainActor
    func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        GridRenderer.block(
            items: gridItems,
            alignment: alignment,
            horizontalSpacing: horizontalSpacing.map { max($0, 0) },
            verticalSpacing: verticalSpacing.map { max($0, 0) },
            proposal: proposal
        )
    }
}
