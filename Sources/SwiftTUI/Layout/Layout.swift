/// A proposed terminal-cell size for a view.
public struct ProposedViewSize: Equatable, Sendable {

    public var columns: Int?

    public var rows: Int?

    public init(columns: Int? = nil, rows: Int? = nil) {
        self.columns = columns.map { max($0, 0) }
        self.rows = rows.map { max($0, 0) }
    }

    public static let unspecified = ProposedViewSize()

    public static let zero = ProposedViewSize(columns: 0, rows: 0)
}

/// The measured dimensions of a layout subview.
public struct LayoutSubviewDimensions: Equatable, Sendable {

    public let size: GeometrySize

    public var columns: Int {
        size.columns
    }

    public var rows: Int {
        size.rows
    }

    public var width: Int {
        size.columns
    }

    public var height: Int {
        size.rows
    }

    public init(size: GeometrySize) {
        self.size = size
    }
}

/// A proxy that represents one subview of a layout.
public struct LayoutSubview {

    let index: Int

    let child: StackChild

    let placements: LayoutPlacementStore

    public var priority: Double {
        child.traits.priority
    }

    public func sizeThatFits(_ proposal: ProposedViewSize) -> GeometrySize {
        child.render(proposal.renderProposal, true)?.layoutSize(
            proposal: proposal.renderProposal
        ) ?? GeometrySize()
    }

    public func dimensions(in proposal: ProposedViewSize) -> LayoutSubviewDimensions {
        LayoutSubviewDimensions(size: sizeThatFits(proposal))
    }

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
public struct LayoutSubviews: RandomAccessCollection {

    public typealias Index = Int

    let elements: [LayoutSubview]

    public var startIndex: Int {
        elements.startIndex
    }

    public var endIndex: Int {
        elements.endIndex
    }

    public subscript(position: Int) -> LayoutSubview {
        elements[position]
    }
}

/// A type that defines the geometry of a collection of views.
public protocol Layout {

    associatedtype Cache = Void

    typealias Subviews = LayoutSubviews

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> GeometrySize

    func placeSubviews(
        in bounds: GeometryFrame,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    )

    func makeCache(subviews: Subviews) -> Cache

    func updateCache(_ cache: inout Cache, subviews: Subviews)
}

public extension Layout where Cache == Void {

    func makeCache(subviews: Subviews) {}
}

public extension Layout {

    func updateCache(_ cache: inout Cache, subviews: Subviews) {}

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

final class LayoutPlacementStore {

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

    var renderProposal: RenderProposal {
        RenderProposal(columns: columns, rows: rows)
    }
}

private extension RenderedElement {

    func layoutSize(proposal: RenderProposal) -> GeometrySize {
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
