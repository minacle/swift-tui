/// A layout value that arranges subviews in a horizontal terminal-cell row.
///
/// Invoke this value with a view builder to use ``HStack``'s rendering path, or
/// erase it with ``AnyLayout`` for a layout that can change at runtime. Direct
/// calls to the `Layout` witness methods use a flat solver that shares finite
/// remaining columns among every horizontally flexible proxy, including
/// ``Spacer`` values. That direct-call allocator doesn't apply `HStack`'s
/// content-before-spacer priority.
public nonisolated struct HStackLayout: Layout, Sendable {

    /// The vertical guide used to align subviews of different heights.
    public var alignment: VerticalAlignment

    /// The preferred number of blank columns between adjacent subviews.
    ///
    /// `nil` resolves each gap from the adjacent views' ``ViewSpacing`` values.
    /// An explicit negative value remains observable through this property but
    /// is treated as zero during measurement and rendering.
    public var spacing: Int?

    /// Creates a horizontal stack layout.
    ///
    /// - Parameters:
    ///   - alignment: The vertical guide used to align children. The default is
    ///     ``VerticalAlignment/center``.
    ///   - spacing: An explicit number of blank columns between children, or
    ///     `nil` to use their spacing preferences. Rendering treats negative
    ///     values as zero.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int? = nil
    ) {
        self.alignment = alignment
        self.spacing = spacing
    }

    /// Properties that identify this as a horizontal stack-like layout.
    ///
    /// The horizontal orientation makes ``Spacer`` flexible only in columns
    /// and makes divider views render vertically within this container.
    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }

    /// Measures the horizontal arrangement under a parent proposal.
    ///
    /// Children initially receive an unspecified column proposal and the
    /// proposed row count. If the parent supplies extra columns, flexible
    /// children share that remainder after spacing is reserved.
    ///
    /// - Parameters:
    ///   - proposal: The proposed terminal columns and rows. An unspecified
    ///     dimension lets the layout use its natural size on that axis.
    ///   - subviews: The children to measure in leading-to-trailing order.
    ///   - cache: The empty cache required by ``Layout``.
    /// - Returns: The sum of child widths and gaps, and the height required to
    ///   align every child on `alignment`.
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

    /// Places subviews from leading to trailing in the supplied bounds.
    ///
    /// Placement uses `bounds.size` as the resolved proposal, so the `proposal`
    /// argument does not independently change placement.
    ///
    /// - Parameters:
    ///   - bounds: The terminal-cell rectangle in which to place the children.
    ///   - proposal: The original parent proposal, retained for ``Layout``
    ///     conformance.
    ///   - subviews: The children to place in source order.
    ///   - cache: The empty cache required by ``Layout``.
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

/// A layout value that arranges subviews in a vertical terminal-cell column.
///
/// Invoke this value with a view builder to use ``VStack``'s rendering path, or
/// erase it with ``AnyLayout`` for a layout that can change at runtime. Direct
/// calls to the `Layout` witness methods use a flat solver that shares finite
/// remaining rows among every vertically flexible proxy, including ``Spacer``
/// values. That direct-call allocator doesn't apply `VStack`'s
/// content-before-spacer priority.
public nonisolated struct VStackLayout: Layout, Sendable {

    /// The horizontal guide used to align subviews of different widths.
    public var alignment: HorizontalAlignment

    /// The preferred number of blank rows between adjacent subviews.
    ///
    /// `nil` resolves each gap from the adjacent views' ``ViewSpacing`` values.
    /// An explicit negative value remains observable through this property but
    /// is treated as zero during measurement and rendering.
    public var spacing: Int?

    /// Creates a vertical stack layout.
    ///
    /// - Parameters:
    ///   - alignment: The horizontal guide used to align children. The default
    ///     is ``HorizontalAlignment/center``.
    ///   - spacing: An explicit number of blank rows between children, or `nil`
    ///     to use their spacing preferences. Rendering treats negative values
    ///     as zero.
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int? = nil
    ) {
        self.alignment = alignment
        self.spacing = spacing
    }

    /// Properties that identify this as a vertical stack-like layout.
    ///
    /// The vertical orientation makes ``Spacer`` flexible only in rows and
    /// makes divider views render horizontally within this container.
    public static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }

    /// Measures the vertical arrangement under a parent proposal.
    ///
    /// Children initially receive the proposed column count and an unspecified
    /// row proposal. If the parent supplies extra rows, flexible children share
    /// that remainder after spacing is reserved.
    ///
    /// - Parameters:
    ///   - proposal: The proposed terminal columns and rows. An unspecified
    ///     dimension lets the layout use its natural size on that axis.
    ///   - subviews: The children to measure in top-to-bottom order.
    ///   - cache: The empty cache required by ``Layout``.
    /// - Returns: The width required to align every child on `alignment`, and
    ///   the sum of child heights and gaps.
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

    /// Places subviews from top to bottom in the supplied bounds.
    ///
    /// Placement uses `bounds.size` as the resolved proposal, so the `proposal`
    /// argument does not independently change placement.
    ///
    /// - Parameters:
    ///   - bounds: The terminal-cell rectangle in which to place the children.
    ///   - proposal: The original parent proposal, retained for ``Layout``
    ///     conformance.
    ///   - subviews: The children to place in source order.
    ///   - cache: The empty cache required by ``Layout``.
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

/// A layout value that overlays subviews in the same terminal-cell rectangle.
///
/// Invoke this value with a view builder to obtain the same arrangement as a
/// ``ZStack``. Children with larger ``View/zIndex(_:)`` values render above
/// children with smaller values; equal values retain source order.
public nonisolated struct ZStackLayout: Layout, Sendable {

    /// The guides used to position every subview within the overlay bounds.
    public var alignment: Alignment

    /// Creates an overlay layout.
    ///
    /// - Parameter alignment: The horizontal and vertical guides used to place
    ///   each child. The default centers children on both axes.
    public init(alignment: Alignment = .center) {
        self.alignment = alignment
    }

    /// Measures the terminal-cell size required by the overlay.
    ///
    /// A specified proposal dimension becomes the container dimension on that
    /// axis. An unspecified dimension resolves to the largest corresponding
    /// child dimension.
    ///
    /// - Parameters:
    ///   - proposal: The proposed overlay size.
    ///   - subviews: The overlaid children to measure.
    ///   - cache: The empty cache required by ``Layout``.
    /// - Returns: The resolved overlay size.
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

    /// Places every subview at the configured alignment in `bounds`.
    ///
    /// Placement uses `bounds.size` as the child proposal. Content outside the
    /// resolved bounds is clipped when SwiftTUI composites the layout.
    ///
    /// - Parameters:
    ///   - bounds: The terminal-cell rectangle shared by the children.
    ///   - proposal: The original parent proposal, retained for ``Layout``
    ///     conformance.
    ///   - subviews: The children to place.
    ///   - cache: The empty cache required by ``Layout``.
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

/// A layout value that arranges ``GridRow`` content in a two-dimensional grid.
///
/// Invoke this value with a view builder to obtain the same row, spanning, and
/// cell-modifier behavior as ``Grid``. Direct calls to its ``Layout`` witness
/// methods receive only a flat `Subviews` collection and therefore measure and
/// place that collection as a single horizontal row.
public nonisolated struct GridLayout: Layout, Sendable {

    /// The default horizontal and vertical guides for content in each cell.
    public var alignment: Alignment

    /// The preferred number of blank columns between adjacent grid cells.
    ///
    /// When this value is invoked as a grid view, `nil` uses the default two
    /// columns. A direct flat `Layout` witness call instead resolves each gap
    /// from the adjacent subviews' actual ``ViewSpacing`` values. A negative
    /// stored value is treated as zero during rendering.
    public var horizontalSpacing: Int?

    /// The preferred number of blank rows between adjacent grid rows.
    ///
    /// When this value is invoked as a grid view, `nil` uses the default one
    /// row. Direct flat `Layout` witness calls contain only one row and don't
    /// use this property. A negative stored value is treated as zero during
    /// rendering.
    public var verticalSpacing: Int?

    /// Creates a grid layout.
    ///
    /// - Parameters:
    ///   - alignment: The fallback alignment for cells that do not override a
    ///     row, column, or cell anchor.
    ///   - horizontalSpacing: Blank columns between cells, or `nil` for the
    ///     grid view's two-column default and adjacent spacing preferences in
    ///     direct flat witness calls. Rendering treats negative values as zero.
    ///   - verticalSpacing: Blank rows between grid rows, or `nil` for the grid
    ///     view's one-row default. Direct flat witness calls don't use this
    ///     value. Rendering treats negative values as zero.
    public init(
        alignment: Alignment = .center,
        horizontalSpacing: Int? = nil,
        verticalSpacing: Int? = nil
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    /// Measures direct `Subviews` as one horizontal row.
    ///
    /// The two-dimensional `GridRow` structure is available when this value is
    /// invoked as a view; a direct protocol call has no row metadata. With
    /// `horizontalSpacing == nil`, the direct path resolves gaps from adjacent
    /// subview spacing rather than using the grid view's two-column default.
    ///
    /// - Parameters:
    ///   - proposal: The proposed terminal-cell size.
    ///   - subviews: The flat children to measure from leading to trailing.
    ///   - cache: The empty cache required by ``Layout``.
    /// - Returns: The size of the resulting single-row arrangement.
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

    /// Places direct `Subviews` as one horizontal row.
    ///
    /// Placement uses `bounds.size`; `verticalSpacing` has no effect on this
    /// flat protocol path because it contains only one row.
    ///
    /// - Parameters:
    ///   - bounds: The terminal-cell rectangle in which to place the row.
    ///   - proposal: The original parent proposal, retained for ``Layout``
    ///     conformance.
    ///   - subviews: The flat children to place from leading to trailing.
    ///   - cache: The empty cache required by ``Layout``.
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
