/// A type-erased layout value that can switch concrete layout algorithms.
///
/// Use `AnyLayout` to select between layout types while preserving the
/// identity and state of the views arranged at the same position in the view
/// hierarchy. The wrapper forwards measurement, placement, spacing, alignment,
/// cache, and built-in stack-orientation behavior to its current layout.
///
/// The wrapped layout type may change between renders. When that happens,
/// SwiftTUI creates a compatible cache for the new type rather than passing the
/// old layout's cache across the type boundary.
///
/// ```swift
/// let useVerticalLayout = true
/// let layout = useVerticalLayout
///     ? AnyLayout(VStackLayout(spacing: 1))
///     : AnyLayout(HStackLayout(spacing: 2))
///
/// layout {
///     Text("Status")
///     Text("Ready")
/// }
/// ```
public nonisolated struct AnyLayout: Layout, Sendable {

    /// Opaque cache storage owned by an ``AnyLayout`` value.
    ///
    /// Obtain a cache from ``AnyLayout/makeCache(subviews:)`` and keep it on the
    /// same layout path. If the wrapped concrete type changes, call
    /// ``AnyLayout/updateCache(_:subviews:)`` before passing the cache to any
    /// other layout callback. The value keeps the concrete cache type hidden
    /// and has no public initializer.
    public struct Cache {

        fileprivate var layoutType: ObjectIdentifier

        fileprivate var storage: Any

        fileprivate init(layoutType: ObjectIdentifier, storage: Any) {
            self.layoutType = layoutType
            self.storage = storage
        }
    }

    private let box: AnyLayoutBox

    /// Creates a type-erased value that wraps the specified layout.
    ///
    /// - Parameter layout: The concrete layout whose behavior and cache are
    ///   forwarded by this value.
    public init<L: Layout>(_ layout: L) {
        box = ConcreteAnyLayoutBox(layout: layout)
    }

    /// Creates the wrapped layout's initial cache.
    ///
    /// - Parameter subviews: The current proxies for the layout's children.
    /// - Returns: Opaque storage initialized by the wrapped layout.
    public func makeCache(subviews: Subviews) -> Cache {
        box.makeCache(subviews: subviews)
    }

    /// Updates the wrapped layout's cache for the current subviews.
    ///
    /// If the cache belongs to a different concrete layout type, this method
    /// discards it and calls that current layout's `makeCache(subviews:)`
    /// implementation. Otherwise it forwards to `updateCache(_:subviews:)`.
    ///
    /// - Parameters:
    ///   - cache: The opaque cache to update or replace.
    ///   - subviews: The current proxies for the layout's children.
    public func updateCache(_ cache: inout Cache, subviews: Subviews) {
        guard cache.layoutType == box.layoutType else {
            cache = box.makeCache(subviews: subviews)
            return
        }
        box.updateCache(&cache.storage, subviews: subviews)
    }

    /// Returns the outer spacing preferred by the wrapped layout.
    ///
    /// - Parameters:
    ///   - subviews: The children whose spacing the layout can inspect.
    ///   - cache: The wrapped layout's mutable cache. Mutations remain visible
    ///     to subsequent layout callbacks in the same pass.
    /// - Returns: The preferred terminal-cell spacing around the composite.
    public func spacing(
        subviews: Subviews,
        cache: inout Cache
    ) -> ViewSpacing {
        box.spacing(
            subviews: subviews,
            cache: &cache.storage
        )
    }

    /// Returns the terminal-cell size required by the wrapped layout.
    ///
    /// - Parameters:
    ///   - proposal: The parent proposal forwarded to the wrapped layout.
    ///   - subviews: The child proxies available for measurement.
    ///   - cache: The wrapped layout's mutable cache.
    /// - Returns: The size reported by the wrapped layout.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Size {
        box.sizeThatFits(
            proposal: proposal,
            subviews: subviews,
            cache: &cache.storage
        )
    }

    /// Places subviews using the wrapped layout.
    ///
    /// - Parameters:
    ///   - bounds: The layout rectangle, including its origin in the layout's
    ///     local terminal-cell coordinate space.
    ///   - proposal: The original proposal received from the parent.
    ///   - subviews: The child proxies to place.
    ///   - cache: The wrapped layout's mutable cache.
    public func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        box.placeSubviews(
            in: bounds,
            proposal: proposal,
            subviews: subviews,
            cache: &cache.storage
        )
    }

    /// Returns the wrapped layout's explicit horizontal guide.
    ///
    /// - Parameters:
    ///   - guide: The horizontal guide requested by an ancestor.
    ///   - bounds: The resolved layout bounds.
    ///   - proposal: The original parent proposal.
    ///   - subviews: The child proxies used by the layout.
    ///   - cache: The wrapped layout's mutable cache.
    /// - Returns: The guide's column in the layout coordinate space, or `nil`
    ///   when the wrapped layout provides no container-level value.
    public func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int? {
        box.explicitAlignment(
            of: guide,
            in: bounds,
            proposal: proposal,
            subviews: subviews,
            cache: &cache.storage
        )
    }

    /// Returns the wrapped layout's explicit vertical guide.
    ///
    /// - Parameters:
    ///   - guide: The vertical guide requested by an ancestor.
    ///   - bounds: The resolved layout bounds.
    ///   - proposal: The original parent proposal.
    ///   - subviews: The child proxies used by the layout.
    ///   - cache: The wrapped layout's mutable cache.
    /// - Returns: The guide's row in the layout coordinate space, or `nil`
    ///   when the wrapped layout provides no container-level value.
    public func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Int? {
        box.explicitAlignment(
            of: guide,
            in: bounds,
            proposal: proposal,
            subviews: subviews,
            cache: &cache.storage
        )
    }
}

extension AnyLayout: BuiltInLayoutAdapter {

    var builtInLayoutKind: BuiltInLayoutKind? {
        box.builtInLayoutKind
    }

    var resolvedLayoutProperties: LayoutProperties {
        box.resolvedLayoutProperties
    }

    @MainActor
    func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        box.renderedBlock(
            children: children,
            gridItems: gridItems,
            proposal: proposal
        )
    }
}

private nonisolated class AnyLayoutBox: @unchecked Sendable {

    var layoutType: ObjectIdentifier {
        fatalError("AnyLayoutBox.layoutType must be overridden")
    }

    var builtInLayoutKind: BuiltInLayoutKind? {
        nil
    }

    var resolvedLayoutProperties: LayoutProperties {
        LayoutProperties()
    }

    func makeCache(subviews: LayoutSubviews) -> AnyLayout.Cache {
        fatalError("AnyLayoutBox.makeCache must be overridden")
    }

    func updateCache(_ cache: inout Any, subviews: LayoutSubviews) {
        fatalError("AnyLayoutBox.updateCache must be overridden")
    }

    func spacing(
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> ViewSpacing {
        fatalError("AnyLayoutBox.spacing must be overridden")
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> Size {
        fatalError("AnyLayoutBox.sizeThatFits must be overridden")
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) {
        fatalError("AnyLayoutBox.placeSubviews must be overridden")
    }

    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> Int? {
        fatalError("AnyLayoutBox.explicitAlignment must be overridden")
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> Int? {
        fatalError("AnyLayoutBox.explicitAlignment must be overridden")
    }

    @MainActor
    func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        nil
    }
}

private nonisolated final class ConcreteAnyLayoutBox<L: Layout>: AnyLayoutBox,
    @unchecked Sendable
{

    let layout: L

    init(layout: L) {
        self.layout = layout
    }

    override var layoutType: ObjectIdentifier {
        ObjectIdentifier(L.self)
    }

    override var builtInLayoutKind: BuiltInLayoutKind? {
        (layout as? any BuiltInLayoutAdapter)?.builtInLayoutKind
    }

    override var resolvedLayoutProperties: LayoutProperties {
        (layout as? any BuiltInLayoutAdapter)?.resolvedLayoutProperties
            ?? L.layoutProperties
    }

    override func makeCache(subviews: LayoutSubviews) -> AnyLayout.Cache {
        AnyLayout.Cache(
            layoutType: layoutType,
            storage: layout.makeCache(subviews: subviews)
        )
    }

    override func updateCache(_ cache: inout Any, subviews: LayoutSubviews) {
        withCache(&cache) {
            layout.updateCache(&$0, subviews: subviews)
        }
    }

    override func spacing(
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> ViewSpacing {
        withCache(&cache) {
            layout.spacing(subviews: subviews, cache: &$0)
        }
    }

    override func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> Size {
        withCache(&cache) {
            layout.sizeThatFits(
                proposal: proposal,
                subviews: subviews,
                cache: &$0
            )
        }
    }

    override func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) {
        withCache(&cache) {
            layout.placeSubviews(
                in: bounds,
                proposal: proposal,
                subviews: subviews,
                cache: &$0
            )
        }
    }

    override func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> Int? {
        withCache(&cache) {
            layout.explicitAlignment(
                of: guide,
                in: bounds,
                proposal: proposal,
                subviews: subviews,
                cache: &$0
            )
        }
    }

    override func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: LayoutSubviews,
        cache: inout Any
    ) -> Int? {
        withCache(&cache) {
            layout.explicitAlignment(
                of: guide,
                in: bounds,
                proposal: proposal,
                subviews: subviews,
                cache: &$0
            )
        }
    }

    @MainActor
    override func renderedBlock(
        children: [StackChild],
        gridItems: [GridItem],
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        (layout as? any BuiltInLayoutAdapter)?.renderedBlock(
            children: children,
            gridItems: gridItems,
            proposal: proposal
        )
    }

    private func withCache<Value>(
        _ cache: inout Any,
        operation: (inout L.Cache) -> Value
    ) -> Value {
        guard var typedCache = cache as? L.Cache else {
            fatalError("AnyLayout cache type does not match its wrapped layout")
        }
        defer {
            cache = typedCache
        }
        return operation(&typedCache)
    }
}
