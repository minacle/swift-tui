public import Terminal

/// Layout-specific properties of a layout container.
public nonisolated struct LayoutProperties: Sendable {

    /// The orientation of a stack-like layout container.
    ///
    /// A value of `nil` indicates an unknown orientation or a layout that
    /// isn't one-dimensional.
    public var stackOrientation: Axis?

    /// Creates a default set of layout properties.
    public init() {
        stackOrientation = nil
    }
}

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
    /// - Parameters:
    ///   - columns: The proposed width in terminal columns.
    ///   - rows: The proposed height in terminal rows.
    public init(columns: Int?, rows: Int?) {
        self.columns = columns
        self.rows = rows
    }

    /// A proposal with both dimensions unspecified.
    public static let unspecified = ProposedViewSize(columns: nil, rows: nil)

    /// A proposal with zero columns and zero rows.
    public static let zero = ProposedViewSize(columns: 0, rows: 0)

    /// A proposal with the maximum integer value in both dimensions.
    public static let max = ProposedViewSize(columns: Int.max, rows: Int.max)

    /// Creates a fully specified proposal from a terminal-cell size.
    ///
    /// - Parameter size: The proposed terminal-cell size.
    public init(_ size: Size) {
        self.init(columns: size.columns, rows: size.rows)
    }

    /// Replaces unspecified dimensions with a concrete terminal-cell size.
    ///
    /// - Parameter size: The values to use for unspecified dimensions.
    /// - Returns: A fully specified terminal-cell size.
    public func replacingUnspecifiedDimensions(
        by size: Size = Size(columns: 10, rows: 10)
    ) -> Size {
        Size(
            columns: columns ?? size.columns,
            rows: rows ?? size.rows
        )
    }
}

/// A view's size and alignment guides in its own terminal-cell coordinate space.
public nonisolated struct ViewDimensions: Equatable, Sendable {

    /// The measured number of terminal columns.
    public let columns: Int

    /// The measured number of terminal rows.
    public let rows: Int

    let explicitAlignments: [AlignmentKey: Int]

    private let explicitAlignmentResolver: ExplicitAlignmentResolver?

    init(
        columns: Int,
        rows: Int,
        explicitAlignments: [AlignmentKey: Int] = [:],
        explicitAlignmentResolver: ExplicitAlignmentResolver? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.explicitAlignments = explicitAlignments
        self.explicitAlignmentResolver = explicitAlignmentResolver
    }

    /// Gets an explicit horizontal guide or its default value.
    public subscript(guide: HorizontalAlignment) -> Int {
        self[explicit: guide] ?? guide.key.value(in: self)
    }

    /// Gets an explicit vertical guide or its default value.
    public subscript(guide: VerticalAlignment) -> Int {
        self[explicit: guide] ?? guide.key.value(in: self)
    }

    /// Gets an explicitly assigned horizontal guide.
    public subscript(explicit guide: HorizontalAlignment) -> Int? {
        explicitAlignments[guide.key]
            ?? explicitAlignmentResolver?.resolve(guide.key)
    }

    /// Gets an explicitly assigned vertical guide.
    public subscript(explicit guide: VerticalAlignment) -> Int? {
        explicitAlignments[guide.key]
            ?? explicitAlignmentResolver?.resolve(guide.key)
    }

    /// Compares dimensions and their already resolved explicit guides.
    public static func == (lhs: ViewDimensions, rhs: ViewDimensions) -> Bool {
        lhs.columns == rhs.columns
            && lhs.rows == rhs.rows
            && lhs.explicitAlignments == rhs.explicitAlignments
    }
}

nonisolated final class ExplicitAlignmentResolver: @unchecked Sendable {

    private let resolveValue: (AlignmentKey) -> Int?

    init(resolveValue: @escaping (AlignmentKey) -> Int?) {
        self.resolveValue = resolveValue
    }

    func resolve(_ key: AlignmentKey) -> Int? {
        resolveValue(key)
    }
}

/// A key for accessing a layout value of a layout container's subviews.
public protocol LayoutValueKey {

    /// The type of value associated with this key.
    associatedtype Value

    /// The value returned for subviews that do not set this key.
    nonisolated static var defaultValue: Value { get }
}

/// A proxy that represents one subview of a layout.
public nonisolated struct LayoutSubview: Equatable {

    let index: Int

    let child: StackChild

    let placements: LayoutPlacementStore

    let measurements: LayoutMeasurementStore

    let stackOrientation: Axis?

    /// The layout priority assigned to this subview.
    public var priority: Double {
        child.traits.priority
    }

    /// The preferred spacing around this subview.
    public var spacing: ViewSpacing {
        measurement(in: .unspecified).spacing
    }

    /// Gets the layout value associated with the specified key.
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value {
        child.traits.layoutValue(for: key)
    }

    /// Measures this subview with a proposed terminal-cell size.
    ///
    /// - Parameter proposal: The size proposal to pass to the subview.
    /// - Returns: The subview's measured terminal-cell size.
    public func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        measurement(in: proposal).size
    }

    private func measurement(
        in proposal: ProposedViewSize,
        requesting guide: AlignmentKey? = nil
    ) -> (
        size: Size,
        explicitAlignments: [AlignmentKey: Int],
        spacing: ViewSpacing
    ) {
        var alignmentKeys = ExplicitAlignmentQueryContext.keys
        if let guide {
            alignmentKeys.insert(guide)
        }
        return measurements.measurement(
            for: index,
            proposal: proposal,
            alignmentKeys: alignmentKeys
        ) {
            ExplicitAlignmentQueryContext.withKeys(alignmentKeys) {
                uncachedMeasurement(in: proposal)
            }
        }
    }

    private func uncachedMeasurement(
        in proposal: ProposedViewSize
    ) -> (
        size: Size,
        explicitAlignments: [AlignmentKey: Int],
        spacing: ViewSpacing
    ) {
        let renderProposal = proposal.renderProposal
        let measurementProposal = renderProposal.replacingMaximumDimensionsWithUnspecified
        let element = child.render(measurementProposal, true)
        let intrinsicSize = element?.layoutSize(proposal: measurementProposal) ?? Size()
        let block = element?.renderedBlock(proposal: measurementProposal)
        let explicitAlignments = block?.explicitAlignments ?? [:]

        return (
            Size(
                columns: measuredLength(
                    proposal: proposal.columns,
                    intrinsic: intrinsicSize.columns,
                    maximum: child.traits.maximumColumns,
                    isFlexible: isSpacerFlexible(on: .horizontal)
                        || child.traits.flexibleAxes.contains(.horizontal)
                ),
                rows: measuredLength(
                    proposal: proposal.rows,
                    intrinsic: intrinsicSize.rows,
                    maximum: child.traits.maximumRows,
                    isFlexible: isSpacerFlexible(on: .vertical)
                        || child.traits.flexibleAxes.contains(.vertical)
                )
            ),
            explicitAlignments,
            block?.spacing ?? ViewSpacing()
        )
    }

    private func measuredLength(
        proposal: Int?,
        intrinsic: Int,
        maximum: Int?,
        isFlexible: Bool
    ) -> Int {
        guard proposal == Int.max else {
            return intrinsic
        }
        if let maximum {
            return maximum
        }
        return isFlexible ? Int.max : intrinsic
    }

    /// Measures this subview and returns layout dimensions.
    ///
    /// - Parameter proposal: The size proposal to pass to the subview.
    /// - Returns: The subview's measured dimensions.
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions {
        let result = measurement(in: proposal)
        return ViewDimensions(
            columns: result.size.columns,
            rows: result.size.rows,
            explicitAlignments: result.explicitAlignments,
            explicitAlignmentResolver: ExplicitAlignmentResolver { guide in
                measurement(
                    in: proposal,
                    requesting: guide
                ).explicitAlignments[guide]
            }
        )
    }

    private func isSpacerFlexible(on axis: Axis) -> Bool {
        guard child.isSpacer else {
            return false
        }
        return stackOrientation == nil || stackOrientation == axis
    }

    /// Places this subview within the layout's bounds.
    ///
    /// - Parameters:
    ///   - point: The placement point in terminal-cell coordinates.
    ///   - anchor: The anchor within the subview aligned to `point`.
    ///   - proposal: The proposal used when rendering the placed subview.
    public func place(
        at point: Point,
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

    /// The mutable cache type shared across calls to a layout instance.
    associatedtype Cache = Void

    /// The collection type passed to layout methods.
    typealias Subviews = LayoutSubviews

    /// Properties that characterize this layout container.
    static var layoutProperties: LayoutProperties { get }

    /// Returns the size required by the layout.
    ///
    /// - Parameters:
    ///   - proposal: The size proposed by the parent.
    ///   - subviews: The child subviews to measure.
    ///   - cache: Mutable storage shared across layout calls.
    /// - Returns: The layout's terminal-cell size.
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Size

    /// Returns the preferred spacing around the composite view.
    func spacing(
        subviews: Subviews,
        cache: inout Cache
    ) -> ViewSpacing

    /// Places child subviews within the resolved layout bounds.
    ///
    /// - Parameters:
    ///   - bounds: The terminal-cell rectangle assigned to the layout.
    ///   - proposal: The original size proposed by the parent.
    ///   - subviews: The child subviews to place.
    ///   - cache: Mutable storage shared across layout calls.
    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    )

    /// Returns the explicit position of a horizontal alignment guide.
    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int?

    /// Returns the explicit position of a vertical alignment guide.
    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int?

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

    /// The default layout properties, with no stack orientation.
    nonisolated static var layoutProperties: LayoutProperties {
        LayoutProperties()
    }

    /// Returns the union of all subview spacing preferences.
    nonisolated func spacing(
        subviews: Subviews,
        cache: inout Cache
    ) -> ViewSpacing {
        subviews.reduce(ViewSpacing()) {
            $0.union($1.spacing)
        }
    }

    /// Uses the explicit horizontal guides supplied by placed subviews.
    nonisolated func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int? {
        nil
    }

    /// Uses the explicit vertical guides supplied by placed subviews.
    nonisolated func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int? {
        nil
    }

    /// Recreates the cache after the layout or its subviews change.
    nonisolated func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = makeCache(subviews: subviews)
    }

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
        ViewResolver.layoutTraits(from: content)
            .settingPriority(priority)
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

struct ZIndexView<Content: View>: View, LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let zIndex: Double

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingZIndex(zIndex)
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

struct LayoutValueView<Content: View, K: LayoutValueKey>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let key: K.Type

    let value: K.Value

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingLayoutValue(key: key, value: value)
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

    /// Controls the front-to-back display order of overlapping views.
    ///
    /// Larger values render above smaller values. Views with the same value
    /// preserve their source order.
    ///
    /// - Parameter value: The relative z-axis ordering for this view.
    /// - Returns: A view with the given z-index.
    func zIndex(_ value: Double) -> some View {
        ZIndexView(content: self, zIndex: value)
    }

    /// Associates a value with a custom layout property.
    ///
    /// Custom layouts can read the value from each child through
    /// ``LayoutSubview/subscript(_:)``.
    ///
    /// - Parameters:
    ///   - key: The layout value key type.
    ///   - value: The value to associate with this view.
    /// - Returns: A view with the specified layout value.
    func layoutValue<K: LayoutValueKey>(
        key: K.Type,
        value: K.Value
    ) -> some View {
        LayoutValueView(content: self, key: key, value: value)
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
        StackAxisContext.withAxis(L.layoutProperties.stackOrientation) {
            let proposedSize = ProposedViewSize(proposal)
            let placements = LayoutPlacementStore()
            let measurements = runtime?.layoutMeasurementStore(at: path)
                ?? LayoutMeasurementStore()
            let subviews = LayoutSubviews(
                elements: ViewResolver.stackChildren(
                    from: content,
                    in: proposal,
                    path: path + [0],
                    runtime: runtime
                ).enumerated().map { index, child in
                    LayoutSubview(
                        index: index,
                        child: child,
                        placements: placements,
                        measurements: measurements,
                        stackOrientation: L.layoutProperties.stackOrientation
                    )
                }
            )

            if let runtime {
                return runtime.withLayoutCache(
                    for: layout,
                    subviews: subviews,
                    at: path
                ) {
                    render(
                        proposedSize: proposedSize,
                        placements: placements,
                        subviews: subviews,
                        cache: &$0
                    )
                }
            }

            var cache = layout.makeCache(subviews: subviews)
            return render(
                proposedSize: proposedSize,
                placements: placements,
                subviews: subviews,
                cache: &cache
            )
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
    }

    private func render(
        proposedSize: ProposedViewSize,
        placements: LayoutPlacementStore,
        subviews: LayoutSubviews,
        cache: inout L.Cache
    ) -> RenderedBlock {
        let spacing = layout.spacing(
            subviews: subviews,
            cache: &cache
        )
        let size = layout.sizeThatFits(
            proposal: proposedSize,
            subviews: subviews,
            cache: &cache
        )
        let bounds = Rect(origin: .zero, size: size)
        layout.placeSubviews(
            in: bounds,
            proposal: proposedSize,
            subviews: subviews,
            cache: &cache
        )

        var block = placedBlock(
            size: size,
            placements: placements.placements,
            subviews: subviews
        )
        block.spacing = spacing
        for key in ExplicitAlignmentQueryContext.keys {
            let value: Int?
            switch key.axis {
            case .horizontal:
                value = layout.explicitAlignment(
                    of: HorizontalAlignment(key: key),
                    in: bounds,
                    proposal: proposedSize,
                    subviews: subviews,
                    cache: &cache
                ).map { $0 - bounds.origin.column }
            case .vertical:
                value = layout.explicitAlignment(
                    of: VerticalAlignment(key: key),
                    in: bounds,
                    proposal: proposedSize,
                    subviews: subviews,
                    cache: &cache
                ).map { $0 - bounds.origin.row }
            }
            if let value {
                block.explicitAlignments[key] = value
            }
        }
        return block
    }

    private func placedBlock(
        size: Size,
        placements: [LayoutPlacement],
        subviews: LayoutSubviews
    ) -> RenderedBlock {
        let width = max(size.columns, 0)
        let height = max(size.rows, 0)
        let bounds = RenderedRect(width: width, height: height)
        let blocks = placements.enumerated()
            .sorted { lhs, rhs in
                let lhsPlacement = lhs.element
                let rhsPlacement = rhs.element
                let lhsZIndex = subviews.indices.contains(lhsPlacement.index)
                    ? subviews[lhsPlacement.index].child.traits.zIndex
                    : 0
                let rhsZIndex = subviews.indices.contains(rhsPlacement.index)
                    ? subviews[rhsPlacement.index].child.traits.zIndex
                    : 0

                if lhsZIndex == rhsZIndex {
                    return lhs.offset < rhs.offset
                }

                return lhsZIndex < rhsZIndex
            }
            .compactMap { _, placement -> RenderedBlock? in
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

        return RenderedBlock.composited(
            blocks,
            width: width,
            height: height,
            paddedRows: Set(0..<height)
        )
    }

    private func xOffset(for block: RenderedBlock, placement: LayoutPlacement) -> Int {
        placement.point.column - block.viewDimensions[placement.anchor.horizontal]
    }

    private func yOffset(for block: RenderedBlock, placement: LayoutPlacement) -> Int {
        placement.point.row - block.viewDimensions[placement.anchor.vertical]
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

nonisolated final class LayoutMeasurementStore {

    private struct Key: Hashable {

        var index: Int

        var proposal: ProposedViewSizeKey

        var alignmentKeys: Set<AlignmentKey>
    }

    private struct ProposedViewSizeKey: Hashable {

        var columns: Int?

        var rows: Int?

        init(_ proposal: ProposedViewSize) {
            columns = proposal.columns
            rows = proposal.rows
        }
    }

    typealias Measurement = (
        size: Size,
        explicitAlignments: [AlignmentKey: Int],
        spacing: ViewSpacing
    )

    private var measurements: [Key: Measurement] = [:]

    func measurement(
        for index: Int,
        proposal: ProposedViewSize,
        alignmentKeys: Set<AlignmentKey>,
        calculate: () -> Measurement
    ) -> Measurement {
        let key = Key(
            index: index,
            proposal: ProposedViewSizeKey(proposal),
            alignmentKeys: alignmentKeys
        )
        if let measurement = measurements[key] {
            return measurement
        }

        let measurement = calculate()
        measurements[key] = measurement
        return measurement
    }
}

struct LayoutPlacement {

    var index: Int

    var point: Point

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

private extension RenderProposal {

    nonisolated var replacingMaximumDimensionsWithUnspecified: RenderProposal {
        RenderProposal(
            columns: columns == Int.max ? nil : columns,
            rows: rows == Int.max ? nil : rows
        )
    }
}

private extension RenderedElement {

    nonisolated func layoutSize(proposal: RenderProposal) -> Size {
        switch self {
        case .block(let block):
            return Size(columns: block.width, rows: block.height)
        case .spacer(let minLength):
            return Size(
                columns: max(proposal.columns ?? minLength, minLength),
                rows: max(proposal.rows ?? minLength, minLength)
            )
        }
    }

    nonisolated func renderedBlock(proposal: RenderProposal) -> RenderedBlock? {
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
