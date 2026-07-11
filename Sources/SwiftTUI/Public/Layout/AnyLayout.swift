/// A type-erased instance of the layout protocol.
///
/// Use `AnyLayout` to select between layout types while preserving the
/// identity and state of the views arranged by the layout.
public nonisolated struct AnyLayout: Layout, Sendable {

    /// The type-erased cache used by the wrapped layout.
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
    public init<L: Layout>(_ layout: L) {
        box = ConcreteAnyLayoutBox(layout: layout)
    }

    /// Creates the wrapped layout's cache.
    public func makeCache(subviews: Subviews) -> Cache {
        box.makeCache(subviews: subviews)
    }

    /// Updates the wrapped layout's cache or replaces it after a type change.
    public func updateCache(_ cache: inout Cache, subviews: Subviews) {
        guard cache.layoutType == box.layoutType else {
            cache = box.makeCache(subviews: subviews)
            return
        }
        box.updateCache(&cache.storage, subviews: subviews)
    }

    /// Returns the spacing preferred by the wrapped layout.
    public func spacing(
        subviews: Subviews,
        cache: inout Cache
    ) -> ViewSpacing {
        box.spacing(
            subviews: subviews,
            cache: &cache.storage
        )
    }

    /// Returns the size required by the wrapped layout.
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

    /// Returns an explicit horizontal guide from the wrapped layout.
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

    /// Returns an explicit vertical guide from the wrapped layout.
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
