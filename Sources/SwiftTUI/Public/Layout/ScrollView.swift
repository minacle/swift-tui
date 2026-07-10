import Foundation
import Terminal

/// A scrollable axis.
public nonisolated enum Axis: Sendable {

    /// Horizontal scrolling over terminal columns.
    case horizontal

    /// Vertical scrolling over terminal rows.
    case vertical

    /// A set of scrollable axes.
    public struct Set: OptionSet, Sendable {

        /// The raw option-set storage value.
        public let rawValue: Int

        /// Creates a set from a raw option-set value.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Enables horizontal scrolling.
        public static let horizontal = Set(rawValue: 1 << 0)

        /// Enables vertical scrolling.
        public static let vertical = Set(rawValue: 1 << 1)
    }
}

/// An edge of a terminal rectangle.
public nonisolated enum Edge: Equatable, Hashable, Sendable {

    /// The top row.
    case top

    /// The bottom row.
    case bottom

    /// The leading column.
    case leading

    /// The trailing column.
    case trailing
}

/// A normalized point in a two-dimensional rectangle.
public nonisolated struct UnitPoint: Equatable, Hashable, Sendable {

    /// The horizontal location, where `0` is leading and `1` is trailing.
    public let x: Double

    /// The vertical location, where `0` is top and `1` is bottom.
    public let y: Double

    /// Creates a unit point.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// The top-leading point.
    public static let zero = UnitPoint(x: 0, y: 0)

    /// The center point.
    public static let center = UnitPoint(x: 0.5, y: 0.5)

    /// The top-center point.
    public static let top = UnitPoint(x: 0.5, y: 0)

    /// The bottom-center point.
    public static let bottom = UnitPoint(x: 0.5, y: 1)

    /// The leading-center point.
    public static let leading = UnitPoint(x: 0, y: 0.5)

    /// The trailing-center point.
    public static let trailing = UnitPoint(x: 1, y: 0.5)

    /// The top-leading point.
    public static let topLeading = UnitPoint(x: 0, y: 0)

    /// The top-trailing point.
    public static let topTrailing = UnitPoint(x: 1, y: 0)

    /// The bottom-leading point.
    public static let bottomLeading = UnitPoint(x: 0, y: 1)

    /// The bottom-trailing point.
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

/// A terminal-native point in scrollable content.
public nonisolated struct ScrollPoint: Equatable, Sendable {

    /// The horizontal content offset in terminal columns.
    public let x: Int

    /// The vertical content offset in terminal rows.
    public let y: Int

    /// Creates a scroll point.
    ///
    /// Negative values are clamped to zero.
    public init(x: Int = 0, y: Int = 0) {
        self.x = max(x, 0)
        self.y = max(y, 0)
    }
}

/// A semantic position within a scroll view.
///
/// A scroll position can be automatic, a concrete content point, or an edge
/// request that the renderer resolves for the current viewport.
public nonisolated struct ScrollPosition: Equatable, Sendable {

    private enum Storage: Equatable, Sendable {

        case automatic

        case point(ScrollPoint)

        case edge(Edge)
    }

    private var storage: Storage

    /// The concrete content point, if this position stores one.
    public var point: ScrollPoint? {
        guard case .point(let point) = storage else {
            return nil
        }

        return point
    }

    /// The horizontal content offset, if this position stores a point.
    public var x: Int? {
        point?.x
    }

    /// The vertical content offset, if this position stores a point.
    public var y: Int? {
        point?.y
    }

    /// The requested edge, if this position stores an edge.
    public var edge: Edge? {
        guard case .edge(let edge) = storage else {
            return nil
        }

        return edge
    }

    /// Creates an automatic scroll position.
    public init() {
        self.storage = .automatic
    }

    /// Creates a position at a concrete content point.
    public init(point: ScrollPoint) {
        self.storage = .point(point)
    }

    /// Creates a position with a horizontal content offset.
    public init(x: Int) {
        self.init(point: ScrollPoint(x: x))
    }

    /// Creates a position with a vertical content offset.
    public init(y: Int) {
        self.init(point: ScrollPoint(y: y))
    }

    /// Creates a position with horizontal and vertical content offsets.
    public init(x: Int, y: Int) {
        self.init(point: ScrollPoint(x: x, y: y))
    }

    /// Creates a position that requests an edge of the scrollable content.
    public init(edge: Edge) {
        self.storage = .edge(edge)
    }

    /// Updates the position to a concrete content point.
    public mutating func scrollTo(point: ScrollPoint) {
        storage = .point(point)
    }

    /// Updates the position to a horizontal content offset.
    public mutating func scrollTo(x: Int) {
        storage = .point(ScrollPoint(x: x))
    }

    /// Updates the position to a vertical content offset.
    public mutating func scrollTo(y: Int) {
        storage = .point(ScrollPoint(y: y))
    }

    /// Updates the position to horizontal and vertical content offsets.
    public mutating func scrollTo(x: Int, y: Int) {
        storage = .point(ScrollPoint(x: x, y: y))
    }

    /// Updates the position to request an edge of the scrollable content.
    public mutating func scrollTo(edge: Edge) {
        storage = .edge(edge)
    }
}

/// A scrollable view.
///
/// `ScrollView` clips its content to the proposed terminal-cell viewport and
/// allows horizontal, vertical, or two-axis scrolling.
public nonisolated struct ScrollView<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let axes: Axis.Set

    let content: Content

    /// Creates a scroll view.
    ///
    /// - Parameters:
    ///   - axes: The axes that can scroll. The default is vertical.
    ///   - content: A view builder that creates the scrollable content.
    public init(
        _ axes: Axis.Set = .vertical,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.content = content()
    }
}

/// A proxy value that supports programmatic scrolling of descendant scroll views.
public struct ScrollViewProxy {

    private let context: StateActionContext?

    init(context: StateActionContext?) {
        self.context = context
    }

    /// Scrolls to the first descendant scroll view child with the given identifier.
    ///
    /// If `anchor` is `nil`, SwiftTUI scrolls by the minimum amount needed to
    /// reveal the identified view. If `anchor` is non-`nil`, SwiftTUI aligns the
    /// same unit point in the target view and scroll viewport.
    public func scrollTo<ID>(_ id: ID, anchor: UnitPoint? = nil) where ID: Hashable {
        guard let context else {
            preconditionFailure(
                "ScrollViewProxy may not be used outside a ScrollViewReader action."
            )
        }

        context.scrollTo(id: AnyHashable(id), anchor: anchor)
    }
}

/// A view that provides programmatic scrolling through a scroll view proxy.
public struct ScrollViewReader<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let content: (ScrollViewProxy) -> Content

    let statePath: [Int]?

    /// Creates a scroll view reader.
    ///
    /// - Parameter content: A view builder that receives a scroll proxy.
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.content = content
        self.statePath = StateContext.currentPath
    }
}

struct IdentifiedView<Content: View>: View, LayoutModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let id: AnyHashable

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard case .block(let block) = renderedElement(
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        let childIndex = runtime?.explicitIDChildIndex(at: path, id: id) ?? 0
        let childPath = path + [childIndex]
        let element = ViewResolver.element(
            from: content,
            in: proposal,
            path: childPath,
            runtime: runtime
        )

        if runtime?.isSuppressingRenderRegistrations != true {
            runtime?.finishExplicitIDRender(at: path, activeID: id)
        }

        guard case .block(var block) = element else {
            return element
        }

        block.identifiedRegions.append(RenderedIdentifiedRegion(id: id, frame: block.bounds))
        return .block(block)
    }
}

struct ScrollPositionView<Content: View>: View, ScrollPositionModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let position: Binding<ScrollPosition>

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ScrollPositionContext.withPosition(position) {
            ViewResolver.block(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        ScrollPositionContext.withPosition(position) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

protocol ScrollRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

protocol ScrollPositionModifierRenderable {

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

public extension View {

    /// Binds this view's identity to a hashable value.
    ///
    /// SwiftTUI uses this identity for subtree state and as a scroll target for
    /// ``ScrollViewProxy/scrollTo(_:anchor:)``.
    func id<ID>(_ id: ID) -> some View where ID: Hashable {
        IdentifiedView(content: self, id: AnyHashable(id))
    }

    /// Associates a binding to a scroll position with scroll views within this view.
    ///
    /// - Parameter position: A binding read and updated by descendant scroll views.
    /// - Returns: A view that supplies scroll position state to descendant scroll views.
    func scrollPosition(_ position: Binding<ScrollPosition>) -> some View {
        ScrollPositionView(content: self, position: position)
    }
}

extension ScrollView: ScrollRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        var flexibleAxes = axes
        if axes.contains(.vertical) {
            flexibleAxes.insert(.horizontal)
        }
        return LayoutTraits(flexibleAxes: flexibleAxes)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let contentBlock = ViewResolver.block(
            from: content,
            in: contentProposal(from: proposal),
            path: path + [0],
            runtime: runtime
        ) ?? RenderedBlock(lines: [])

        let binding = ScrollPositionContext.currentBinding
        let position = binding?.wrappedValue
            ?? runtime?.scrollPoint(at: path).map { ScrollPosition(point: $0) }
            ?? ScrollPosition()
        let result = ScrollViewRenderer.render(
            contentBlock,
            axes: axes,
            position: position,
            proposal: proposal
        )
        runtime?.registerScrollView(
            at: path,
            axes: axes,
            point: result.point,
            maximumPoint: result.maximumPoint,
            viewportSize: Size(columns: result.block.width, rows: result.block.height),
            identifiedRegions: contentBlock.identifiedRegions,
            binding: binding
        )
        if binding != nil
            && !LayoutMeasurementContext.isMeasuring
            && runtime?.isSuppressingInteractiveRenderRegistrations != true
            && (position.point != nil || position.edge != nil) {
            ScrollPositionContext.updateCurrentPosition(to: ScrollPosition(point: result.point))
        }

        var block = result.block
        if EnvironmentRenderContext.current.isEnabled {
            block.scrollRegions.append(RenderedScrollRegion(path: path, frame: block.bounds))
        }
        return block
    }

    private func contentProposal(from proposal: RenderProposal?) -> RenderProposal {
        RenderProposal(
            columns: axes.contains(.horizontal) ? nil : proposal?.columns,
            rows: axes.contains(.vertical) ? nil : proposal?.rows
        )
    }
}

extension ScrollViewReader: ScrollRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content(ScrollViewProxy(context: nil)))
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let proxy = runtime.map {
            ScrollViewProxy(context: StateActionContext(runtime: $0, path: path))
        } ?? ScrollViewProxy(context: nil)
        let resolvedContent: Content
        if let statePath, let runtime {
            resolvedContent = runtime.withView(at: statePath, mode: .render) {
                content(proxy)
            }
        }
        else {
            resolvedContent = content(proxy)
        }

        return ViewResolver.block(
            from: resolvedContent,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

private enum ScrollPositionContext {

    private struct TaskBinding: @unchecked Sendable {

        var binding: Binding<ScrollPosition>?
    }

    @TaskLocal
    private static var taskBinding = TaskBinding(binding: nil)

    static var currentPosition: ScrollPosition {
        currentBinding?.wrappedValue ?? ScrollPosition()
    }

    static func withPosition<Value>(
        _ position: Binding<ScrollPosition>,
        perform operation: () -> Value
    ) -> Value {
        $taskBinding.withValue(TaskBinding(binding: position)) {
            return operation()
        }
    }

    static func updateCurrentPosition(to position: ScrollPosition) {
        guard let binding = currentBinding, binding.wrappedValue != position else {
            return
        }

        binding.wrappedValue = position
    }

    static var currentBinding: Binding<ScrollPosition>? {
        taskBinding.binding
    }
}

enum ScrollViewRenderer {

    struct Result {

        var block: RenderedBlock

        var point: ScrollPoint

        var maximumPoint: ScrollPoint
    }

    static func render(
        _ content: RenderedBlock,
        axes: Axis.Set,
        position: ScrollPosition,
        proposal: RenderProposal?
    ) -> Result {
        let width = proposal?.columns ?? content.width
        let height = proposal?.rows ?? content.height
        guard width > 0, height > 0 else {
            return Result(
                block: RenderedBlock(lines: []),
                point: ScrollPoint(),
                maximumPoint: ScrollPoint()
            )
        }

        let maximumPoint = ScrollPoint(
            x: axes.contains(.horizontal) ? maxHorizontalOffset(for: content, width: width) : 0,
            y: axes.contains(.vertical) ? max(content.height - height, 0) : 0
        )
        let point = resolvedPoint(
            from: position,
            content: content,
            width: width,
            height: height
        )
        let x = axes.contains(.horizontal) ? point.x : 0
        let y = axes.contains(.vertical) ? point.y : 0
        let clampedX = min(x, maximumPoint.x)
        let clampedY = min(y, maximumPoint.y)
        let bounds = RenderedRect(width: width, height: height)
        let runs = content.runs.flatMap {
            $0.offsetBy(x: -clampedX, y: -clampedY).clipped(to: bounds)
        }

        return Result(
            block: RenderedBlock(
                runs: runs,
                width: width,
                height: height,
                paddedRows: Set(0..<height),
                caret: caret(
                    from: content.caret,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height,
                    constrainToBounds: proposal?.columns != nil
                ),
                hitRegions: hitRegions(
                    from: content.hitRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                scrollRegions: scrollRegions(
                    from: content.scrollRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                focusRegions: focusRegions(
                    from: content.focusRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                identifiedRegions: identifiedRegions(
                    from: content.identifiedRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                coordinateSpaceRegions: coordinateSpaceRegions(
                    from: content.coordinateSpaceRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                )
            ),
            point: ScrollPoint(x: clampedX, y: clampedY),
            maximumPoint: maximumPoint
        )
    }

    private static func caret(
        from caret: RenderedCaret?,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        constrainToBounds: Bool
    ) -> RenderedCaret? {
        guard let caret else {
            return nil
        }

        let row = caret.row - y
        let column = caret.column - x
        guard row >= 0, row < height, column >= 0, column <= width else {
            return nil
        }

        return RenderedCaret(
            row: row,
            column: constrainToBounds ? min(column, width - 1) : column
        )
    }

    private static func maxHorizontalOffset(for content: RenderedBlock, width: Int) -> Int {
        let caretAllowance = content.caret == nil || content.width < width ? 0 : 1
        var offset = max(content.width - width + caretAllowance, 0)
        while offset > 0 && content.lines.contains(where: { line in
            !TerminalText.isCharacterBoundary(line, atColumn: offset)
        }) {
            offset += 1
        }
        return offset
    }

    private static func hitRegions(
        from regions: [RenderedHitRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedHitRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func scrollRegions(
        from regions: [RenderedScrollRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedScrollRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func focusRegions(
        from regions: [RenderedFocusRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedFocusRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func identifiedRegions(
        from regions: [RenderedIdentifiedRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedIdentifiedRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func coordinateSpaceRegions(
        from regions: [RenderedCoordinateSpaceRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedCoordinateSpaceRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func resolvedPoint(
        from position: ScrollPosition,
        content: RenderedBlock,
        width: Int,
        height: Int
    ) -> ScrollPoint {
        if let point = position.point {
            return point
        }

        switch position.edge {
        case .top:
            return ScrollPoint(y: 0)
        case .bottom:
            return ScrollPoint(y: max(content.height - height, 0))
        case .leading:
            return ScrollPoint(x: 0)
        case .trailing:
            return ScrollPoint(x: max(content.width - width, 0))
        case nil:
            return ScrollPoint()
        }
    }
}
