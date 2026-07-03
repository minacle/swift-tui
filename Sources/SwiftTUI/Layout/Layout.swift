/// A proposed terminal-cell size for a view.
///
/// `nil` means the corresponding terminal-cell dimension is unspecified.
public nonisolated struct ProposedViewSize: Equatable, Sendable {

    /// The proposed width in terminal columns, or `nil` when unspecified.
    public var columns: Int?

    /// The proposed height in terminal rows, or `nil` when unspecified.
    public var rows: Int?

    /// Creates a proposed size.
    ///
    /// Negative values are clamped to zero.
    ///
    /// - Parameters:
    ///   - columns: The proposed width in terminal columns.
    ///   - rows: The proposed height in terminal rows.
    public init(columns: Int? = nil, rows: Int? = nil) {
        self.columns = columns.map { max($0, 0) }
        self.rows = rows.map { max($0, 0) }
    }

    /// A proposal with both dimensions unspecified.
    public static let unspecified = ProposedViewSize()

    /// A proposal with zero columns and zero rows.
    public static let zero = ProposedViewSize(columns: 0, rows: 0)
}

/// The measured dimensions of a layout subview.
public nonisolated struct LayoutSubviewDimensions: Equatable, Sendable {

    /// The measured size of the subview.
    public let size: GeometrySize

    /// The measured width in terminal columns.
    public var columns: Int {
        size.columns
    }

    /// The measured height in terminal rows.
    public var rows: Int {
        size.rows
    }

    /// The measured width in terminal columns.
    public var width: Int {
        size.columns
    }

    /// The measured height in terminal rows.
    public var height: Int {
        size.rows
    }

    /// Creates measured dimensions from a geometry size.
    ///
    /// - Parameter size: The measured terminal-cell size.
    public init(size: GeometrySize) {
        self.size = size
    }
}

/// A proxy that represents one subview of a layout.
public nonisolated struct LayoutSubview: Equatable {

    let index: Int

    let child: StackChild

    let placements: LayoutPlacementStore

    /// The layout priority assigned to this subview.
    public var priority: Double {
        child.traits.priority
    }

    /// Measures this subview with a proposed terminal-cell size.
    ///
    /// - Parameter proposal: The size proposal to pass to the subview.
    /// - Returns: The subview's measured terminal-cell size.
    public func sizeThatFits(_ proposal: ProposedViewSize) -> GeometrySize {
        child.render(proposal.renderProposal, true)?.layoutSize(
            proposal: proposal.renderProposal
        ) ?? GeometrySize()
    }

    /// Measures this subview and returns layout dimensions.
    ///
    /// - Parameter proposal: The size proposal to pass to the subview.
    /// - Returns: The subview's measured dimensions.
    public func dimensions(in proposal: ProposedViewSize) -> LayoutSubviewDimensions {
        LayoutSubviewDimensions(size: sizeThatFits(proposal))
    }

    /// Places this subview within the layout's bounds.
    ///
    /// - Parameters:
    ///   - point: The placement point in terminal-cell coordinates.
    ///   - anchor: The anchor within the subview aligned to `point`.
    ///   - proposal: The proposal used when rendering the placed subview.
    public func place(
        at point: GeometryPoint,
        anchor: Alignment = .topLeading,
        proposal: ProposedViewSize = .unspecified
    ) {
        placements.place(
            LayoutPlacement(
                index: index,
                point: point,
                anchor: anchor,
                proposal: proposal
            )
        )
    }
}

/// A collection of proxies that represent the subviews of a layout view.
public nonisolated struct LayoutSubviews: Equatable, RandomAccessCollection, @unchecked Sendable {

    /// The collection index type.
    public typealias Index = Int

    let elements: [LayoutSubview]

    /// The index of the first subview.
    public var startIndex: Int {
        elements.startIndex
    }

    /// The index one past the last subview.
    public var endIndex: Int {
        elements.endIndex
    }

    /// Accesses a layout subview by position.
    public subscript(position: Int) -> LayoutSubview {
        elements[position]
    }
}

public extension LayoutSubview {

    /// Compares subviews by their identity within the current layout pass.
    nonisolated static func == (lhs: LayoutSubview, rhs: LayoutSubview) -> Bool {
        lhs.index == rhs.index
    }
}

/// A type that defines the geometry of a collection of views.
///
/// Implement `Layout` to measure and place child views in terminal-cell
/// coordinates. SwiftTUI calls measurement before placement during rendering.
@preconcurrency
public nonisolated protocol Layout: Sendable {

    /// The mutable cache type used across a layout pass.
    associatedtype Cache = Void

    /// The collection type passed to layout methods.
    typealias Subviews = LayoutSubviews

    /// Returns the size required by the layout.
    ///
    /// - Parameters:
    ///   - proposal: The size proposed by the parent.
    ///   - subviews: The child subviews to measure.
    ///   - cache: Mutable layout cache for this pass.
    /// - Returns: The layout's terminal-cell size.
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> GeometrySize

    /// Places child subviews within the resolved layout bounds.
    ///
    /// - Parameters:
    ///   - bounds: The terminal-cell rectangle assigned to the layout.
    ///   - proposal: The original size proposed by the parent.
    ///   - subviews: The child subviews to place.
    ///   - cache: Mutable layout cache for this pass.
    func placeSubviews(
        in bounds: GeometryFrame,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    )

    /// Creates an initial cache for the current child collection.
    ///
    /// - Parameter subviews: The child subviews available to the layout.
    /// - Returns: The cache value used by subsequent layout calls.
    func makeCache(subviews: Subviews) -> Cache

    /// Updates an existing cache for the current child collection.
    ///
    /// - Parameters:
    ///   - cache: The cache value to update.
    ///   - subviews: The child subviews available to the layout.
    func updateCache(_ cache: inout Cache, subviews: Subviews)
}

public extension Layout where Cache == Void {

    /// Creates the default empty cache for layouts that do not define one.
    nonisolated func makeCache(subviews: Subviews) {}
}

public extension Layout {

    /// Default cache update for layouts that do not need cache maintenance.
    nonisolated func updateCache(_ cache: inout Cache, subviews: Subviews) {}

    /// Creates a view that arranges content using this layout.
    ///
    /// - Parameter content: The child views to measure and place.
    /// - Returns: A view backed by this custom layout value.
    func callAsFunction<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        LayoutContainer(layout: self, content: content())
    }
}

struct LayoutPriorityView<Content: View>: View, LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let priority: Double

    var layoutTraits: LayoutTraits {
        var traits = ViewResolver.layoutTraits(from: content)
        traits.priority = priority
        return traits
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
        )
    }
}

public extension View {

    /// Sets the priority that custom layouts can read for this child.
    ///
    /// - Parameter value: The priority value exposed through
    ///   ``LayoutSubview/priority``.
    /// - Returns: A view with the given layout priority.
    func layoutPriority(_ value: Double) -> some View {
        LayoutPriorityView(content: self, priority: value)
    }
}

struct LayoutContainer<L: Layout, Content: View>: View {

    typealias Body = Never

    let layout: L

    let content: Content
}

protocol LayoutRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement?
}

extension LayoutContainer: LayoutRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let proposedSize = ProposedViewSize(proposal)
        let placements = LayoutPlacementStore()
        let subviews = LayoutSubviews(
            elements: ViewResolver.stackChildren(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            ).enumerated().map { index, child in
                LayoutSubview(index: index, child: child, placements: placements)
            }
        )

        var cache = layout.makeCache(subviews: subviews)
        layout.updateCache(&cache, subviews: subviews)

        let size = layout.sizeThatFits(
            proposal: proposedSize,
            subviews: subviews,
            cache: &cache
        )
        let bounds = GeometryFrame(size: size)
        layout.placeSubviews(
            in: bounds,
            proposal: proposedSize,
            subviews: subviews,
            cache: &cache
        )

        return placedBlock(
            size: size,
            placements: placements.placements,
            subviews: subviews
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
    }

    private func placedBlock(
        size: GeometrySize,
        placements: [LayoutPlacement],
        subviews: LayoutSubviews
    ) -> RenderedBlock {
        let bounds = RenderedRect(width: size.columns, height: size.rows)
        let blocks = placements.compactMap { placement -> RenderedBlock? in
            guard subviews.indices.contains(placement.index),
                  let block = subviews[placement.index]
                    .child
                    .render(placement.proposal.renderProposal, false)?
                    .renderedBlock(proposal: placement.proposal.renderProposal) else {
                return nil
            }

            return block.offsetBy(
                x: xOffset(for: block, placement: placement),
                y: yOffset(for: block, placement: placement),
                clippedTo: bounds
            )
        }

        return RenderedBlock(
            runs: blocks.flatMap(\.runs),
            width: size.columns,
            height: size.rows,
            paddedRows: Set(0..<size.rows),
            cursor: blocks.compactMap(\.cursor).first,
            hitRegions: blocks.flatMap(\.hitRegions),
            scrollRegions: blocks.flatMap(\.scrollRegions),
            focusRegions: blocks.flatMap(\.focusRegions)
        )
    }

    private func xOffset(for block: RenderedBlock, placement: LayoutPlacement) -> Int {
        switch placement.anchor.horizontal {
        case .leading:
            placement.point.column
        case .center:
            placement.point.column - (block.width / 2)
        case .trailing:
            placement.point.column - block.width
        }
    }

    private func yOffset(for block: RenderedBlock, placement: LayoutPlacement) -> Int {
        switch placement.anchor.vertical {
        case .top:
            placement.point.row
        case .center:
            placement.point.row - (block.height / 2)
        case .bottom:
            placement.point.row - block.height
        }
    }
}

nonisolated final class LayoutPlacementStore {

    private(set) var placements: [LayoutPlacement] = []

    func place(_ placement: LayoutPlacement) {
        placements.removeAll {
            $0.index == placement.index
        }
        placements.append(placement)
    }
}

struct LayoutPlacement {

    var index: Int

    var point: GeometryPoint

    var anchor: Alignment

    var proposal: ProposedViewSize
}

private extension ProposedViewSize {

    init(_ proposal: RenderProposal?) {
        self.init(columns: proposal?.columns, rows: proposal?.rows)
    }

    nonisolated var renderProposal: RenderProposal {
        RenderProposal(columns: columns, rows: rows)
    }
}

private extension RenderedElement {

    nonisolated func layoutSize(proposal: RenderProposal) -> GeometrySize {
        switch self {
        case .block(let block):
            return GeometrySize(columns: block.width, rows: block.height)
        case .spacer(let minLength):
            return GeometrySize(
                columns: max(proposal.columns ?? minLength, minLength),
                rows: max(proposal.rows ?? minLength, minLength)
            )
        }
    }

    func renderedBlock(proposal: RenderProposal) -> RenderedBlock? {
        switch self {
        case .block(let block):
            return block
        case .spacer(let minLength):
            let height = max(proposal.rows ?? minLength, minLength)
            return RenderedBlock(
                runs: [],
                width: max(proposal.columns ?? minLength, minLength),
                height: max(height, 1),
                paddedRows: Set(0..<max(height, 1))
            )
        }
    }
}
