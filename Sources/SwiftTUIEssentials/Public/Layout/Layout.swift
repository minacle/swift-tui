public import Terminal

/// Metadata that changes how SwiftTUI treats a custom layout container.
///
/// Return a configured value from ``Layout/layoutProperties`` when a custom
/// layout has stack-like behavior that its method signatures cannot express.
public nonisolated struct LayoutProperties: Sendable {

    /// The major axis of a stack-like layout container.
    ///
    /// A value of `nil` indicates an unknown orientation or a layout that
    /// isn't one-dimensional. A horizontal or vertical value constrains
    /// ``Spacer`` maximum-size measurement to that major axis and selects the
    /// perpendicular line direction for divider views while they are inside
    /// the layout.
    public var stackOrientation: Axis?

    /// Creates properties for a layout with no declared stack orientation.
    public init() {
        stackOrientation = nil
    }
}

/// A proposed terminal-cell size for a view.
///
/// `nil` means the corresponding terminal-cell dimension is unspecified, so a
/// view can report its natural size on that axis. Values, including negative
/// values, are preserved by this type; renderers clamp only where their own
/// contracts require a nonnegative buffer size.
public nonisolated struct ProposedViewSize: Equatable, Sendable {

    /// The proposed width in terminal columns, or `nil` when unspecified.
    public var columns: Int?

    /// The proposed height in terminal rows, or `nil` when unspecified.
    public var rows: Int?

    /// Creates a proposed size without normalizing either dimension.
    ///
    /// - Parameters:
    ///   - columns: The proposed width in terminal columns, or `nil` to leave
    ///     the horizontal dimension unspecified.
    ///   - rows: The proposed height in terminal rows, or `nil` to leave the
    ///     vertical dimension unspecified.
    public init(columns: Int?, rows: Int?) {
        self.columns = columns
        self.rows = rows
    }

    /// A proposal with both dimensions unspecified.
    public static let unspecified = ProposedViewSize(columns: nil, rows: nil)

    /// A proposal with zero columns and zero rows.
    public static let zero = ProposedViewSize(columns: 0, rows: 0)

    /// A proposal that asks for each subview's maximum size on both axes.
    ///
    /// During ``LayoutSubview`` measurement, SwiftTUI treats `Int.max` as a
    /// maximum-size query. Fixed children report their intrinsic size, bounded
    /// children report their maximum, and unbounded flexible children can
    /// report `Int.max`. That normalization applies to `sizeThatFits` and
    /// `dimensions` measurement only. Passing this proposal to
    /// ``LayoutSubview/place(at:anchor:proposal:)`` forwards `Int.max` to the
    /// renderer and can attempt an impractically large allocation.
    public static let max = ProposedViewSize(columns: Int.max, rows: Int.max)

    /// Creates a fully specified proposal from a terminal-cell size.
    ///
    /// The initializer preserves the size's values, including negatives.
    ///
    /// - Parameter size: The columns and rows to propose.
    public init(_ size: Size) {
        self.init(columns: size.columns, rows: size.rows)
    }

    /// Replaces only unspecified dimensions with a concrete fallback size.
    ///
    /// Already specified values, including zero and negative values, are
    /// preserved.
    ///
    /// - Parameter size: The fallback for `nil` dimensions. The default is ten
    ///   columns by ten rows.
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

/// A measured view's size and alignment guides in local terminal-cell coordinates.
///
/// Use this value inside custom-layout and alignment-guide callbacks. The
/// leading and top origins are zero; built-in trailing and bottom guides equal
/// `columns` and `rows`, respectively. Explicit guides can lie outside those
/// bounds.
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

    /// Returns a horizontal guide's explicit value or its identifier fallback.
    ///
    /// - Parameter guide: The horizontal guide to resolve.
    public subscript(guide: HorizontalAlignment) -> Int {
        self[explicit: guide] ?? guide.key.value(in: self)
    }

    /// Returns a vertical guide's explicit value or its identifier fallback.
    ///
    /// - Parameter guide: The vertical guide to resolve.
    public subscript(guide: VerticalAlignment) -> Int {
        self[explicit: guide] ?? guide.key.value(in: self)
    }

    /// Returns an explicitly assigned horizontal guide without applying a fallback.
    ///
    /// SwiftTUI may resolve a nested custom layout's guide lazily when this
    /// subscript is first queried.
    ///
    /// - Parameter guide: The horizontal guide to query.
    public subscript(explicit guide: HorizontalAlignment) -> Int? {
        explicitAlignments[guide.key]
            ?? explicitAlignmentResolver?.resolve(guide.key)
    }

    /// Returns an explicitly assigned vertical guide without applying a fallback.
    ///
    /// SwiftTUI may resolve a nested custom layout's guide lazily when this
    /// subscript is first queried.
    ///
    /// - Parameter guide: The vertical guide to query.
    public subscript(explicit guide: VerticalAlignment) -> Int? {
        explicitAlignments[guide.key]
            ?? explicitAlignmentResolver?.resolve(guide.key)
    }

    /// Compares measured sizes and already materialized explicit guides.
    ///
    /// Lazy guide resolvers and the values they return are not part of equality;
    /// only guides already stored in each value's eager alignment dictionary
    /// participate.
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

/// A key for a value supplied by a child to its custom layout container.
public protocol LayoutValueKey {

    /// The value type stored for this key.
    associatedtype Value

    /// The value returned when a subview has not set this key.
    nonisolated static var defaultValue: Value { get }
}

/// A key for metadata supplied by a view to its nearest layout container.
public protocol ContainerValueKey {

    /// The value type stored for this key.
    associatedtype Value

    /// The value returned when a subview has not set this key.
    nonisolated static var defaultValue: Value { get }
}

/// Container metadata associated with one layout subview.
///
/// Read this value from ``LayoutSubview/containerValues``. Keys are identified
/// by their concrete key types, and tags are additionally identified by the
/// concrete type of their hashable value.
public nonisolated struct ContainerValues {

    var storage = ContainerValueStorage()

    /// Accesses the container value associated with the specified key type.
    ///
    /// Reading a key that the view did not set returns `Key.defaultValue`.
    ///
    /// - Parameter key: The key type whose value to read or replace.
    public subscript<Key: ContainerValueKey>(key: Key.Type) -> Key.Value {
        get {
            storage.value(for: key)
        }
        set {
            storage.set(newValue, for: key)
        }
    }

    /// Returns the tag stored for the specified concrete type.
    ///
    /// - Parameter type: The exact tag type to retrieve. `Value.self` and
    ///   `Optional<Value>.self` are distinct lookups.
    /// - Returns: The tag for `type`, or `nil` when the view has no matching tag.
    public func tag<Value: Hashable>(for type: Value.Type) -> Value? {
        storage.tag(for: type)
    }

    /// Returns whether the values contain an equal tag of the same type.
    ///
    /// - Parameter tag: The tag to find.
    /// - Returns: `true` when a matching tag of the same type is present.
    public func hasTag<Value: Hashable>(_ tag: Value) -> Bool {
        storage.hasTag(tag)
    }
}

/// A pass-scoped proxy for one child of a custom layout.
///
/// Use a proxy only during the ``Layout`` callbacks that receive it. Its
/// identity, measurements, and placement storage belong to the current layout
/// pass; do not retain the value or use it from another task or later render.
/// Use the proposal chosen by the layout when calling
/// ``place(at:anchor:proposal:)``; placement can render a child without a prior
/// explicit measurement call.
public nonisolated struct LayoutSubview: Equatable {

    let index: Int

    let child: StackChild

    let placements: LayoutPlacementStore

    let measurements: LayoutMeasurementStore

    let stackOrientation: Axis?

    /// The layout priority assigned to this subview, or zero by default.
    public var priority: Double {
        child.traits.priority
    }

    /// The subview's preferred spacing at its unspecified size.
    ///
    /// Accessing this property can measure the subview. SwiftTUI may reuse the
    /// measurement within the current render pass when the child, proposal, and
    /// requested alignment-guide set match.
    public var spacing: ViewSpacing {
        measurement(in: .unspecified).spacing
    }

    /// The container values and tag associated with this subview.
    public var containerValues: ContainerValues {
        child.traits.containerValues
    }

    /// Returns the layout value associated with the specified key.
    ///
    /// - Parameter key: The key type to read. If the child did not set the key,
    ///   the result is `K.defaultValue`.
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value {
        child.traits.layoutValue(for: key)
    }

    /// Measures this subview with a proposed terminal-cell size.
    ///
    /// Measurements for the same child, proposal, and requested alignment-guide
    /// set are reused within one render pass and recalculated in later passes. A
    /// ``ProposedViewSize/max`` dimension performs a maximum-size query without
    /// rendering an enormous buffer.
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

    /// Measures this subview and returns its size and alignment guides.
    ///
    /// This method shares the pass-local measurement cache used by
    /// ``sizeThatFits(_:)``. Explicit custom-layout guides can be requested
    /// lazily when the returned dimensions are subscripted.
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

    /// Records this subview's placement within the layout's bounds.
    ///
    /// `point` identifies the location to which the subview's `anchor` guide is
    /// aligned. The final rendered child is clipped to the layout's reported
    /// bounds. Calling this method again for the same proxy replaces its earlier
    /// placement in the current pass; omitting the call leaves the child
    /// unrendered.
    ///
    /// - Parameters:
    ///   - point: A point in the layout container's local terminal-cell
    ///     coordinate space.
    ///   - anchor: The subview guides aligned to `point`. The default is the
    ///     top-leading corner.
    ///   - proposal: The proposal used to render the placed subview. The default
    ///     leaves both dimensions unspecified. Use a concrete proposal derived
    ///     from measurement; passing ``ProposedViewSize/max`` can forward
    ///     `Int.max` into allocating renderers.
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

/// A pass-scoped random-access collection of custom-layout subview proxies.
///
/// The collection is valid only for the ``Layout`` callback that receives it.
/// Do not retain it, pass it to another task, or assume that its indices or
/// proxy identities remain stable across render passes. Its unchecked
/// `Sendable` conformance supports the layout protocol's isolation model; it is
/// not a thread-safety guarantee for deferred use.
public nonisolated struct LayoutSubviews: Equatable, RandomAccessCollection, @unchecked Sendable {

    /// The zero-based integer index type used by this collection.
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

    /// Accesses a layout subview at a valid collection position.
    ///
    /// - Parameter position: An index in `startIndex..<endIndex`.
    /// - Precondition: `position` must be a valid index of this collection.
    public subscript(position: Int) -> LayoutSubview {
        elements[position]
    }
}

public extension LayoutSubview {

    /// Compares proxies by their child index within the current layout pass.
    ///
    /// Equality has no meaning across distinct layout passes or containers.
    nonisolated static func == (lhs: LayoutSubview, rhs: LayoutSubview) -> Bool {
        lhs.index == rhs.index
    }
}

/// A type that defines the geometry of a collection of views.
///
/// Implement `Layout` to measure and place child views in terminal-cell
/// coordinates. During a render pass SwiftTUI resolves the layout's spacing,
/// calls ``sizeThatFits(proposal:subviews:cache:)``, and then calls
/// ``placeSubviews(in:proposal:subviews:cache:)`` with bounds based on the
/// reported size. It may also request explicit guides needed by an ancestor.
/// Do not depend on an exact call count.
///
/// The same mutable cache is shared by these callbacks in a pass and can persist
/// at the layout's identity path across later passes. Subview proxies are not
/// persistent: never store `Subviews` or ``LayoutSubview`` values in that cache.
@preconcurrency
public nonisolated protocol Layout: Sendable {

    /// Mutable layout-owned data shared across callbacks and render passes.
    ///
    /// Store derived measurements or other values that can be refreshed by
    /// ``updateCache(_:subviews:)``. Do not store pass-scoped subview proxies.
    associatedtype Cache = Void

    /// The pass-scoped child collection passed to layout callbacks.
    typealias Subviews = LayoutSubviews

    /// Properties that characterize every instance of this layout type.
    ///
    /// Use `stackOrientation` only for a genuinely stack-like algorithm; the
    /// default leaves the orientation unknown.
    static var layoutProperties: LayoutProperties { get }

    /// Returns the terminal-cell size required by the layout.
    ///
    /// Measure children with ``LayoutSubview/sizeThatFits(_:)`` or
    /// ``LayoutSubview/dimensions(in:)``. SwiftTUI clamps negative returned
    /// dimensions to zero at the final render-buffer boundary, but layouts
    /// should normally return meaningful nonnegative sizes.
    ///
    /// - Parameters:
    ///   - proposal: The parent proposal. A `nil` axis is unspecified; see
    ///     ``ProposedViewSize`` for maximum-size query semantics.
    ///   - subviews: Pass-scoped child proxies to measure. Do not retain them.
    ///   - cache: Mutable layout storage shared with spacing, placement, and
    ///     explicit-alignment callbacks.
    /// - Returns: The container's width in columns and height in rows.
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Size

    /// Returns the preferred spacing around the composite layout.
    ///
    /// - Parameters:
    ///   - subviews: Pass-scoped children whose preferences can be combined.
    ///   - cache: Mutable storage shared with the other layout callbacks.
    /// - Returns: Spacing exposed to adjacent views outside this container.
    func spacing(
        subviews: Subviews,
        cache: inout Cache
    ) -> ViewSpacing

    /// Records child placements within the resolved layout bounds.
    ///
    /// A child is rendered only if this method calls its `place` method. Final
    /// content, caret positions, and interaction regions are translated by the
    /// placement and clipped to `bounds`.
    ///
    /// - Parameters:
    ///   - bounds: The terminal-cell rectangle assigned from the size returned
    ///     by `sizeThatFits`. Placement points use this coordinate space.
    ///   - proposal: The original size proposed by the parent, which can differ
    ///     from `bounds.size`.
    ///   - subviews: Pass-scoped child proxies to place. Do not retain them.
    ///   - cache: Mutable storage shared with the other layout callbacks.
    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    )

    /// Returns a container-level horizontal alignment guide requested by an ancestor.
    ///
    /// SwiftTUI calls this method on demand for guides actually used by an
    /// ancestor. The result is expressed in the same coordinate space as
    /// `bounds`, not necessarily relative to zero.
    ///
    /// - Parameters:
    ///   - guide: The horizontal guide to resolve.
    ///   - bounds: The resolved layout bounds.
    ///   - proposal: The original parent proposal.
    ///   - subviews: Pass-scoped child proxies available for guide calculation.
    ///   - cache: Mutable storage shared with the other layout callbacks.
    /// - Returns: The guide's column in `bounds` coordinates, or `nil` to
    ///   provide no container-level override.
    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int?

    /// Returns a container-level vertical alignment guide requested by an ancestor.
    ///
    /// SwiftTUI calls this method on demand for guides actually used by an
    /// ancestor. The result is expressed in the same coordinate space as
    /// `bounds`, not necessarily relative to zero.
    ///
    /// - Parameters:
    ///   - guide: The vertical guide to resolve.
    ///   - bounds: The resolved layout bounds.
    ///   - proposal: The original parent proposal.
    ///   - subviews: Pass-scoped child proxies available for guide calculation.
    ///   - cache: Mutable storage shared with the other layout callbacks.
    /// - Returns: The guide's row in `bounds` coordinates, or `nil` to provide
    ///   no container-level override.
    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int?

    /// Creates an initial cache when the layout appears at a runtime path.
    ///
    /// SwiftTUI also calls this method when the concrete layout type at that
    /// path changes. The resulting cache can persist across render passes until
    /// the layout disappears. Do not retain `subviews` or individual proxies in
    /// the returned value.
    ///
    /// - Parameter subviews: The current pass's child proxies, available only
    ///   while creating the cache.
    /// - Returns: Layout-owned storage for subsequent callbacks.
    func makeCache(subviews: Subviews) -> Cache

    /// Refreshes a persistent cache for the current render pass.
    ///
    /// SwiftTUI calls this for a compatible cache on a subsequent pass before
    /// measurement and placement. The default implementation replaces `cache`
    /// with a newly created value. Do not retain `subviews` in the cache.
    ///
    /// - Parameters:
    ///   - cache: The existing layout-owned storage to update in place.
    ///   - subviews: The current pass's child proxies, available only during
    ///     this callback.
    func updateCache(_ cache: inout Cache, subviews: Subviews)
}

public extension Layout where Cache == Void {

    /// Creates the empty cache used by layouts whose `Cache` is `Void`.
    ///
    /// - Parameter subviews: The current pass's child proxies. The default
    ///   implementation does not inspect or retain them.
    nonisolated func makeCache(subviews: Subviews) {}
}

public extension Layout {

    /// The default layout properties, with an unknown stack orientation.
    nonisolated static var layoutProperties: LayoutProperties {
        LayoutProperties()
    }

    /// Returns default spacing unioned with every subview's preferences.
    ///
    /// - Parameters:
    ///   - subviews: The pass-scoped children whose outer preferences are
    ///     combined.
    ///   - cache: Mutable layout storage. The default implementation does not
    ///     modify it.
    /// - Returns: A spacing value containing the maximum of the default and
    ///   every subview preference on each edge. It therefore remains at least
    ///   two columns horizontally and one row vertically.
    nonisolated func spacing(
        subviews: Subviews,
        cache: inout Cache
    ) -> ViewSpacing {
        subviews.reduce(ViewSpacing()) {
            $0.union($1.spacing)
        }
    }

    /// Provides no container-level horizontal alignment override.
    ///
    /// Returning `nil` allows explicit guides composited from placed subviews
    /// to remain available to ancestors.
    ///
    /// - Returns: Always `nil`.
    nonisolated func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int? {
        nil
    }

    /// Provides no container-level vertical alignment override.
    ///
    /// Returning `nil` allows explicit guides composited from placed subviews
    /// to remain available to ancestors.
    ///
    /// - Returns: Always `nil`.
    nonisolated func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int? {
        nil
    }

    /// Replaces the existing cache with a newly created cache.
    ///
    /// Override this method to update expensive storage in place. The default
    /// calls ``makeCache(subviews:)`` and assigns its result to `cache`.
    ///
    /// - Parameters:
    ///   - cache: The cache value to replace.
    ///   - subviews: The current pass's children used to create the replacement.
    nonisolated func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = makeCache(subviews: subviews)
    }

    /// Creates a view that arranges content using this layout value.
    ///
    /// The layout value participates in the view hierarchy at this call site;
    /// runtime cache lifetime and descendant state identity are tied to that
    /// hierarchy path.
    ///
    /// - Parameter content: A builder that creates the direct layout children.
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

nonisolated struct ContainerValueView<Content: View, Value>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let keyPath: WritableKeyPath<ContainerValues, Value>

    let value: Value

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingContainerValue(keyPath, value: value)
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

nonisolated struct TagValueView<Content: View, Value: Hashable>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let tag: Value

    let includeOptional: Bool

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingTag(tag, includeOptional: includeOptional)
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
    /// The default priority is zero. SwiftTUI stores the value as metadata and
    /// does not impose ordering or allocation behavior; each custom layout
    /// decides how, or whether, to interpret it.
    ///
    /// - Parameter value: The priority value exposed through
    ///   ``LayoutSubview/priority``. The value is stored without normalization.
    /// - Returns: A view with the given layout priority.
    func layoutPriority(_ value: Double) -> some View {
        LayoutPriorityView(content: self, priority: value)
    }

    /// Controls the front-to-back display order of overlapping views.
    ///
    /// Larger values render above smaller values. Views with the same value
    /// preserve their source or placement order. The modifier affects only
    /// containers that composite overlapping content, such as ``ZStack``,
    /// ``Grid``, and custom layouts with overlapping placements; it does not
    /// move a view in the terminal-cell plane.
    ///
    /// - Parameter value: The relative z-axis ordering for this view.
    /// - Returns: A view with the given z-index.
    func zIndex(_ value: Double) -> some View {
        ZIndexView(content: self, zIndex: value)
    }

    /// Associates a value with a custom layout property.
    ///
    /// Custom layouts can read the value from each child through
    /// ``LayoutSubview/subscript(_:)``. Values are keyed by the concrete key
    /// type. Applying the same key again replaces its value for the modified
    /// view, while an unset key reads as `K.defaultValue`.
    ///
    /// - Parameters:
    ///   - key: The concrete layout value key type.
    ///   - value: The value to associate with this view.
    /// - Returns: A view with the specified layout value.
    func layoutValue<K: LayoutValueKey>(
        key: K.Type,
        value: K.Value
    ) -> some View {
        LayoutValueView(content: self, key: key, value: value)
    }

    /// Sets a container value for this view.
    ///
    /// The view's nearest layout container can read the value through
    /// ``LayoutSubview/containerValues``. The modifier is transparent to
    /// rendering and affects only the modified view's metadata as a direct
    /// layout child.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path selecting the container value to update.
    ///   - value: The value to associate with this view.
    /// - Returns: A view with the specified container value.
    nonisolated func containerValue<Value>(
        _ keyPath: WritableKeyPath<ContainerValues, Value>,
        _ value: Value
    ) -> some View {
        ContainerValueView(content: self, keyPath: keyPath, value: value)
    }

    /// Sets a tag value for this view.
    ///
    /// Layout containers can query the tag through
    /// ``ContainerValues/tag(for:)`` or ``ContainerValues/hasTag(_:)``. Tags are
    /// type-sensitive: equal values of different hashable types are distinct.
    /// Applying a new tag of the same type replaces the previous one.
    ///
    /// - Parameters:
    ///   - tag: A hashable value that identifies the view to its container.
    ///   - includeOptional: Whether to also store the same tag under
    ///     `Optional<Value>.self`. The default is `true`; pass `false` when an
    ///     optional lookup must not match this nonoptional tag.
    /// - Returns: A view with the specified tag.
    nonisolated func tag<Value: Hashable>(
        _ tag: Value,
        includeOptional: Bool = true
    ) -> some View {
        TagValueView(
            content: self,
            tag: tag,
            includeOptional: includeOptional
        )
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
        let adapter = layout as? any BuiltInLayoutAdapter
        let properties = adapter?.resolvedLayoutProperties ?? L.layoutProperties
        return StackAxisContext.withAxis(properties.stackOrientation) {
            if let adapter, let kind = adapter.builtInLayoutKind {
                let children: [StackChild]
                let gridItems: [GridItem]
                switch kind {
                case .horizontal:
                    children = ViewResolver.stackChildren(
                        from: content,
                        in: RenderProposal(rows: proposal?.rows),
                        path: path + [0],
                        runtime: runtime
                    )
                    gridItems = []
                case .vertical:
                    children = ViewResolver.stackChildren(
                        from: content,
                        in: RenderProposal(columns: proposal?.columns),
                        path: path + [0],
                        runtime: runtime
                    )
                    gridItems = []
                case .overlay:
                    children = ViewResolver.stackChildren(
                        from: content,
                        in: proposal,
                        path: path + [0],
                        runtime: runtime
                    )
                    gridItems = []
                case .grid:
                    children = []
                    gridItems = ViewResolver.gridItems(
                        from: content,
                        in: proposal,
                        path: path + [0],
                        runtime: runtime
                    )
                }
                return adapter.renderedBlock(
                    children: children,
                    gridItems: gridItems,
                    proposal: proposal
                )
            }

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
                        stackOrientation: properties.stackOrientation
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

extension LayoutContainer: LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        guard let adapter = layout as? any BuiltInLayoutAdapter,
              let kind = adapter.builtInLayoutKind else {
            return LayoutTraits()
        }

        switch kind {
        case .horizontal:
            return StackAxisContext.withAxis(.horizontal) {
                ViewResolver.stackLayoutTraits(
                    from: content,
                    propagatedAxes: [.horizontal, .vertical],
                    spacerAxis: .horizontal
                )
            }
        case .vertical:
            return StackAxisContext.withAxis(.vertical) {
                ViewResolver.stackLayoutTraits(
                    from: content,
                    propagatedAxes: [.horizontal, .vertical],
                    spacerAxis: .vertical
                )
            }
        case .overlay:
            return StackAxisContext.withAxis(nil) {
                ViewResolver.stackLayoutTraits(
                    from: content,
                    propagatedAxes: [.horizontal, .vertical],
                    spacerAxis: nil
                )
            }
        case .grid:
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
