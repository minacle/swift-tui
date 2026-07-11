/// A container that aligns child views in terminal-cell rows and columns.
///
/// Place cells inside ``GridRow`` values. SwiftTUI gives every column the width
/// of its widest nonspanning requirement, then distributes any additional width
/// required by spanning cells. Every row uses the height of its tallest cell,
/// and smaller cells are aligned within those rectangles. A direct child that
/// is not in a `GridRow` becomes a full-width row spanning all columns.
///
/// Flexible cells can divide extra proposed columns or rows. Use
/// ``View/gridCellUnsizedAxes(_:)`` when a flexible cell should retain its
/// natural size instead of expanding the grid on an axis.
public nonisolated struct Grid<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: Alignment

    let horizontalSpacing: Int?

    let verticalSpacing: Int?

    let content: Content

    /// Creates a grid with the specified alignment and terminal-cell spacing.
    ///
    /// A `nil` spacing value uses the default ``ViewSpacing`` distance: two
    /// columns horizontally or one row vertically. Negative explicit values
    /// are clamped to zero.
    ///
    /// - Parameters:
    ///   - alignment: The fallback horizontal and vertical guides for cell
    ///     content that has no row, column, or anchor override.
    ///   - horizontalSpacing: Blank columns between adjacent grid columns, or
    ///     `nil` for two columns.
    ///   - verticalSpacing: Blank rows between adjacent grid rows, or `nil` for
    ///     one row.
    ///   - content: A builder that creates ``GridRow`` values and optional
    ///     full-width children in source order.
    public init(
        alignment: Alignment = .center,
        horizontalSpacing: Int? = nil,
        verticalSpacing: Int? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing.map { max($0, 0) }
        self.verticalSpacing = verticalSpacing.map { max($0, 0) }
        self.content = content()
    }
}

/// A horizontal row of cells in a ``Grid``.
///
/// Each direct child produced by `content` is one cell; an ``EmptyView`` does
/// not reserve a cell. Outside a grid, `GridRow` is transparent and its children
/// participate directly in the surrounding container.
public nonisolated struct GridRow<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let alignment: VerticalAlignment?

    let content: Content

    /// Creates a row of grid cells.
    ///
    /// - Parameters:
    ///   - alignment: The vertical guide for every cell in this row, or `nil`
    ///     to use the grid's vertical alignment.
    ///   - content: A builder whose nonempty direct children become successive
    ///     cells.
    public init(
        alignment: VerticalAlignment? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }
}

private nonisolated struct GridCellColumnsView<Content: View>: View,
    LayoutModifierRenderable, LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let count: Int

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingGridCellColumns(count)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ViewResolver.block(from: content, in: proposal, path: path, runtime: runtime)
    }
}

private nonisolated struct GridCellAnchorView<Content: View>: View,
    LayoutModifierRenderable, LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let anchor: UnitPoint

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingGridCellAnchor(anchor)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ViewResolver.block(from: content, in: proposal, path: path, runtime: runtime)
    }
}

private nonisolated struct GridCellUnsizedAxesView<Content: View>: View,
    LayoutModifierRenderable, LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let axes: Axis.Set

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingGridCellUnsizedAxes(axes)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ViewResolver.block(from: content, in: proposal, path: path, runtime: runtime)
    }
}

private nonisolated struct GridColumnAlignmentView<Content: View>: View,
    LayoutModifierRenderable, LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let alignment: HorizontalAlignment

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingGridColumnAlignment(alignment)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ViewResolver.block(from: content, in: proposal, path: path, runtime: runtime)
    }
}

public extension View {

    /// Tells a cell in a grid row to span the specified number of columns.
    ///
    /// The span begins at the cell's normal source-order column and includes
    /// intervening grid spacing. Values less than one are treated as one. This
    /// modifier has no layout effect outside a grid.
    ///
    /// - Parameter count: The number of columns occupied by the cell.
    /// - Returns: A view with the requested grid-column span.
    nonisolated func gridCellColumns(_ count: Int) -> some View {
        GridCellColumnsView(content: self, count: max(count, 1))
    }

    /// Specifies a custom anchor for aligning a view in its grid cell.
    ///
    /// The anchor overrides the grid's default alignment and any row or column
    /// guide for this cell. SwiftTUI applies the same normalized point to the
    /// free horizontal and vertical space, truncating fractional cell offsets
    /// toward zero. ``UnitPoint`` values are not clamped to the unit square.
    ///
    /// - Parameter anchor: The unit point used to position the view within its
    ///   allocated cell rectangle.
    /// - Returns: A view with the requested grid-cell anchor.
    nonisolated func gridCellAnchor(_ anchor: UnitPoint) -> some View {
        GridCellAnchorView(content: self, anchor: anchor)
    }

    /// Prevents a grid from offering extra space on the specified axes.
    ///
    /// The cell's natural size still contributes to intrinsic column widths and
    /// row heights. On a selected axis, however, the cell neither marks the
    /// corresponding grid track as flexible nor receives that track's expanded
    /// proposal.
    ///
    /// - Parameter axes: The axes on which the cell keeps its natural proposal.
    /// - Returns: A view excluded from flexible grid expansion on those axes.
    nonisolated func gridCellUnsizedAxes(_ axes: Axis.Set) -> some View {
        GridCellUnsizedAxesView(content: self, axes: axes)
    }

    /// Overrides the horizontal alignment of the grid column containing this view.
    ///
    /// The override applies to every ordinary cell in the column. If multiple
    /// cells provide an override, the first one encountered in row source order
    /// determines the column guide. Full-width rows do not define a column
    /// alignment.
    ///
    /// - Parameter guide: The horizontal guide used by the containing column.
    /// - Returns: A view that proposes this guide for its grid column.
    nonisolated func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View {
        GridColumnAlignmentView(content: self, alignment: guide)
    }
}

enum GridItem {

    case row(alignment: VerticalAlignment?, cells: [StackChild])

    case fullWidth(StackChild)

    func mappingCells(_ transform: (StackChild) -> StackChild) -> GridItem {
        switch self {
        case .row(let alignment, let cells):
            .row(alignment: alignment, cells: cells.map(transform))
        case .fullWidth(let cell):
            .fullWidth(transform(cell))
        }
    }
}

protocol GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem]
}

extension GridRow: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        [
            .row(
                alignment: alignment,
                cells: StackAxisContext.withAxis(nil) {
                    ViewResolver.stackChildren(
                        from: content,
                        in: nil,
                        path: path + [0],
                        runtime: runtime
                    ).filter { !$0.isEmptyView }
                }
            ),
        ]
    }
}

extension GridCellColumnsView: GridContentRenderable where Content: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        content.gridItems(in: proposal, path: path, runtime: runtime).map {
            $0.mappingCells { child in
                var child = child
                child.traits = child.traits.settingGridCellColumns(count)
                return child
            }
        }
    }
}

extension GridCellAnchorView: GridContentRenderable where Content: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        content.gridItems(in: proposal, path: path, runtime: runtime).map {
            $0.mappingCells { child in
                var child = child
                child.traits = child.traits.settingGridCellAnchor(anchor)
                return child
            }
        }
    }
}

extension GridCellUnsizedAxesView: GridContentRenderable
where Content: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        content.gridItems(in: proposal, path: path, runtime: runtime).map {
            $0.mappingCells { child in
                var child = child
                child.traits = child.traits.settingGridCellUnsizedAxes(axes)
                return child
            }
        }
    }
}

extension GridColumnAlignmentView: GridContentRenderable
where Content: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        content.gridItems(in: proposal, path: path, runtime: runtime).map {
            $0.mappingCells { child in
                var child = child
                child.traits = child.traits.settingGridColumnAlignment(alignment)
                return child
            }
        }
    }
}

extension Grid: LayoutTraitRenderable, StackRenderable {

    var layoutTraits: LayoutTraits {
        let axes = ViewResolver.gridItems(
            from: content,
            in: nil,
            path: [],
            runtime: nil
        ).reduce(into: Axis.Set()) { axes, item in
            switch item {
            case .row(_, let cells):
                for cell in cells {
                    axes.formUnion(GridRenderer.flexibleAxes(for: cell))
                }
            case .fullWidth(let cell):
                axes.formUnion(GridRenderer.flexibleAxes(for: cell))
            }
        }
        return LayoutTraits(flexibleAxes: axes)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutContainer(
            layout: GridLayout(
                alignment: alignment,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing
            ),
            content: content
        ).renderedBlock(in: proposal, path: path, runtime: runtime)
    }
}

enum GridRenderer {

    private struct Cell {

        var child: StackChild

        var column: Int

        var span: Int

        var isFullWidth: Bool

        var sourceOrder: Int
    }

    private struct Row {

        var alignment: VerticalAlignment?

        var cells: [Cell]
    }

    static func flexibleAxes(for child: StackChild) -> Axis.Set {
        var axes = child.traits.flexibleAxes
        if child.isSpacer {
            axes.formUnion([.horizontal, .vertical])
        }
        axes.subtract(child.traits.gridCellUnsizedAxes)
        return axes
    }

    static func block(
        items: [GridItem],
        alignment: Alignment,
        horizontalSpacing: Int?,
        verticalSpacing: Int?,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let defaultSpacing = ViewSpacing()
        let horizontalSpacing = horizontalSpacing
            ?? defaultSpacing.distance(to: defaultSpacing, along: .horizontal)
        let verticalSpacing = verticalSpacing
            ?? defaultSpacing.distance(to: defaultSpacing, along: .vertical)
        let columnCount = items.reduce(0) { count, item in
            switch item {
            case .row(_, let cells):
                max(count, cells.reduce(0) { $0 + max($1.traits.gridCellColumns, 1) })
            case .fullWidth:
                max(count, 1)
            }
        }
        guard columnCount > 0 else {
            return nil
        }

        let rows = preparedRows(from: items, columnCount: columnCount)
        var columnWidths = intrinsicColumnWidths(
            for: rows,
            columnCount: columnCount,
            horizontalSpacing: horizontalSpacing
        )
        let flexibleColumns = flexibleColumnIndices(in: rows)
        distributeProposedLength(
            proposal?.columns,
            lengths: &columnWidths,
            flexibleIndices: flexibleColumns,
            spacing: horizontalSpacing
        )

        var rowHeights: [Int] = []
        for row in rows {
            var height = 0
            for cell in row.cells {
                let width = allocatedWidth(
                    for: cell,
                    columnWidths: columnWidths,
                    horizontalSpacing: horizontalSpacing
                )
                let cellProposal = RenderProposal(
                    columns: cell.child.traits.gridCellUnsizedAxes.contains(.horizontal)
                        ? nil
                        : width
                )
                if let block = renderedBlock(
                    for: cell.child,
                    proposal: cellProposal,
                    measuring: true
                ) {
                    height = max(height, block.height)
                }
            }
            rowHeights.append(height)
        }

        let flexibleRows = Set(rows.indices.filter { rowIndex in
            rows[rowIndex].cells.contains {
                flexibleAxes(for: $0.child).contains(.vertical)
            }
        })
        distributeProposedLength(
            proposal?.rows,
            lengths: &rowHeights,
            flexibleIndices: flexibleRows,
            spacing: verticalSpacing
        )

        let width = columnWidths.reduce(0, +)
            + max(columnCount - 1, 0) * horizontalSpacing
        let height = rowHeights.reduce(0, +)
            + max(rows.count - 1, 0) * verticalSpacing
        let bounds = RenderedRect(width: width, height: height)
        let columnOrigins = origins(for: columnWidths, spacing: horizontalSpacing)
        let rowOrigins = origins(for: rowHeights, spacing: verticalSpacing)
        let columnAlignments = resolvedColumnAlignments(
            in: rows,
            columnCount: columnCount
        )

        var placedBlocks: [(
            zIndex: Double,
            sourceOrder: Int,
            edges: Edge.Set,
            block: RenderedBlock
        )] = []
        for rowIndex in rows.indices {
            let row = rows[rowIndex]
            for cell in row.cells {
                let cellWidth = allocatedWidth(
                    for: cell,
                    columnWidths: columnWidths,
                    horizontalSpacing: horizontalSpacing
                )
                let cellHeight = rowHeights[rowIndex]
                let traits = cell.child.traits
                let cellProposal = RenderProposal(
                    columns: traits.gridCellUnsizedAxes.contains(.horizontal)
                        ? nil
                        : cellWidth,
                    rows: traits.gridCellUnsizedAxes.contains(.vertical)
                        ? nil
                        : cellHeight
                )
                guard let block = renderedBlock(
                    for: cell.child,
                    proposal: cellProposal,
                    measuring: false
                ) else {
                    continue
                }

                let offset: (x: Int, y: Int)
                if let anchor = traits.gridCellAnchor {
                    offset = (
                        Int(Double(cellWidth - block.width) * anchor.x),
                        Int(Double(cellHeight - block.height) * anchor.y)
                    )
                }
                else {
                    let alignment = defaultAlignment(
                        for: cell,
                        row: row,
                        gridAlignment: alignment,
                        columnAlignments: columnAlignments
                    )
                    offset = (
                        alignmentOffset(
                            for: block,
                            containerWidth: cellWidth,
                            alignment: alignment.horizontal
                        ),
                        alignmentOffset(
                            for: block,
                            containerHeight: cellHeight,
                            alignment: alignment.vertical
                        )
                    )
                }
                let x = columnOrigins[cell.column] + offset.x
                let y = rowOrigins[rowIndex] + offset.y
                var edges: Edge.Set = []
                if rowIndex == rows.startIndex {
                    edges.formUnion(.top)
                }
                if rowIndex == rows.index(before: rows.endIndex) {
                    edges.formUnion(.bottom)
                }
                if cell.column == 0 {
                    edges.formUnion(.leading)
                }
                if cell.column + cell.span >= columnCount {
                    edges.formUnion(.trailing)
                }
                placedBlocks.append(
                    (
                        zIndex: traits.zIndex,
                        sourceOrder: cell.sourceOrder,
                        edges: edges,
                        block: block.offsetBy(x: x, y: y, clippedTo: bounds)
                    )
                )
            }
        }

        let sortedPlacedBlocks = placedBlocks.sorted { lhs, rhs in
            lhs.zIndex == rhs.zIndex
                ? lhs.sourceOrder < rhs.sourceOrder
                : lhs.zIndex < rhs.zIndex
        }
        var spacing = ViewSpacing()
        for placedBlock in sortedPlacedBlocks {
            spacing.formUnion(placedBlock.block.spacing, edges: placedBlock.edges)
        }
        var block = RenderedBlock.composited(
            sortedPlacedBlocks.map(\.block),
            width: width,
            height: height,
            paddedRows: Set(0..<height)
        )
        block.spacing = spacing
        return block
    }

    private static func preparedRows(
        from items: [GridItem],
        columnCount: Int
    ) -> [Row] {
        var sourceOrder = 0
        return items.map { item in
            switch item {
            case .row(let alignment, let children):
                var column = 0
                let cells = children.map { child in
                    let span = max(child.traits.gridCellColumns, 1)
                    defer {
                        column += span
                        sourceOrder += 1
                    }
                    return Cell(
                        child: child,
                        column: column,
                        span: span,
                        isFullWidth: false,
                        sourceOrder: sourceOrder
                    )
                }
                return Row(alignment: alignment, cells: cells)
            case .fullWidth(let child):
                defer {
                    sourceOrder += 1
                }
                return Row(
                    alignment: nil,
                    cells: [
                        Cell(
                            child: child,
                            column: 0,
                            span: columnCount,
                            isFullWidth: true,
                            sourceOrder: sourceOrder
                        ),
                    ]
                )
            }
        }
    }

    private static func intrinsicColumnWidths(
        for rows: [Row],
        columnCount: Int,
        horizontalSpacing: Int
    ) -> [Int] {
        var widths = Array(repeating: 0, count: columnCount)
        let cells = rows.flatMap(\.cells)
        for cell in cells where cell.span == 1 {
            let width = renderedBlock(
                for: cell.child,
                proposal: nil,
                measuring: true
            )?.width ?? 0
            widths[cell.column] = max(widths[cell.column], width)
        }
        for cell in cells where cell.span > 1 {
            let requiredWidth = renderedBlock(
                for: cell.child,
                proposal: nil,
                measuring: true
            )?.width ?? 0
            let range = cell.column..<min(cell.column + cell.span, columnCount)
            let currentWidth = range.reduce(0) { $0 + widths[$1] }
                + max(range.count - 1, 0) * horizontalSpacing
            distribute(
                max(requiredWidth - currentWidth, 0),
                across: Array(range),
                lengths: &widths
            )
        }
        return widths
    }

    private static func flexibleColumnIndices(in rows: [Row]) -> Set<Int> {
        rows.reduce(into: Set<Int>()) { indices, row in
            for cell in row.cells
            where flexibleAxes(for: cell.child).contains(.horizontal) {
                indices.formUnion(cell.column..<(cell.column + cell.span))
            }
        }
    }

    private static func distributeProposedLength(
        _ proposedLength: Int?,
        lengths: inout [Int],
        flexibleIndices: Set<Int>,
        spacing: Int
    ) {
        guard let proposedLength, !flexibleIndices.isEmpty else {
            return
        }
        let intrinsicLength = lengths.reduce(0, +)
            + max(lengths.count - 1, 0) * spacing
        distribute(
            max(proposedLength - intrinsicLength, 0),
            across: flexibleIndices.sorted(),
            lengths: &lengths
        )
    }

    private static func distribute(
        _ amount: Int,
        across indices: [Int],
        lengths: inout [Int]
    ) {
        guard amount > 0, !indices.isEmpty else {
            return
        }
        let quotient = amount / indices.count
        let remainder = amount % indices.count
        for (offset, index) in indices.enumerated() {
            lengths[index] += quotient + (offset < remainder ? 1 : 0)
        }
    }

    private static func allocatedWidth(
        for cell: Cell,
        columnWidths: [Int],
        horizontalSpacing: Int
    ) -> Int {
        let range = cell.column..<min(cell.column + cell.span, columnWidths.count)
        return range.reduce(0) { $0 + columnWidths[$1] }
            + max(range.count - 1, 0) * horizontalSpacing
    }

    private static func origins(for lengths: [Int], spacing: Int) -> [Int] {
        var offset = 0
        return lengths.map { length in
            defer {
                offset += length + spacing
            }
            return offset
        }
    }

    private static func resolvedColumnAlignments(
        in rows: [Row],
        columnCount: Int
    ) -> [HorizontalAlignment?] {
        var alignments = Array<HorizontalAlignment?>(repeating: nil, count: columnCount)
        for row in rows {
            for cell in row.cells where !cell.isFullWidth {
                guard alignments[cell.column] == nil,
                      let alignment = cell.child.traits.gridColumnAlignment else {
                    continue
                }
                alignments[cell.column] = alignment
            }
        }
        return alignments
    }

    private static func defaultAlignment(
        for cell: Cell,
        row: Row,
        gridAlignment: Alignment,
        columnAlignments: [HorizontalAlignment?]
    ) -> Alignment {
        let horizontal = cell.isFullWidth
            ? gridAlignment.horizontal
            : columnAlignments[cell.column] ?? gridAlignment.horizontal
        let vertical = row.alignment ?? gridAlignment.vertical
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private static func alignmentOffset(
        for block: RenderedBlock,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = containerWidth - block.width
        if alignment == .leading, block.viewDimensions[explicit: alignment] == nil {
            return 0
        }
        if alignment == .center, block.viewDimensions[explicit: alignment] == nil {
            return padding / 2
        }
        if alignment == .trailing, block.viewDimensions[explicit: alignment] == nil {
            return padding
        }
        let container = ViewDimensions(columns: containerWidth, rows: block.height)
        return container[alignment] - block.viewDimensions[alignment]
    }

    private static func alignmentOffset(
        for block: RenderedBlock,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = containerHeight - block.height
        if alignment == .top, block.viewDimensions[explicit: alignment] == nil {
            return 0
        }
        if alignment == .center, block.viewDimensions[explicit: alignment] == nil {
            return padding / 2
        }
        if alignment == .bottom, block.viewDimensions[explicit: alignment] == nil {
            return padding
        }
        let container = ViewDimensions(columns: block.width, rows: containerHeight)
        return container[alignment] - block.viewDimensions[alignment]
    }

    private static func renderedBlock(
        for child: StackChild,
        proposal: RenderProposal?,
        measuring: Bool
    ) -> RenderedBlock? {
        guard let element = child.render(proposal, measuring) else {
            return nil
        }
        switch element {
        case .block(let block):
            return block
        case .spacer(let minLength):
            let width = max(proposal?.columns ?? minLength, minLength)
            let height = max(proposal?.rows ?? minLength, minLength)
            guard width > 0 || height > 0 else {
                return nil
            }
            return RenderedBlock(
                runs: [],
                width: width,
                height: height,
                paddedRows: Set(0..<height)
            )
        }
    }
}
