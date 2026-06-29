import Foundation

/// A scrollable axis.
public enum Axis: Sendable {

    case horizontal

    case vertical

    /// A set of scrollable axes.
    public struct Set: OptionSet, Sendable {

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let horizontal = Set(rawValue: 1 << 0)

        public static let vertical = Set(rawValue: 1 << 1)
    }
}

/// An edge of a terminal rectangle.
public enum Edge: Equatable, Hashable, Sendable {

    case top

    case bottom

    case leading

    case trailing
}

/// A terminal-native point in scrollable content.
public struct ScrollPoint: Equatable, Sendable {

    public let x: Int

    public let y: Int

    public init(x: Int = 0, y: Int = 0) {
        self.x = max(x, 0)
        self.y = max(y, 0)
    }
}

/// A semantic position within a scroll view.
public struct ScrollPosition: Equatable, Sendable {

    private enum Storage: Equatable, Sendable {

        case automatic

        case point(ScrollPoint)

        case edge(Edge)
    }

    private var storage: Storage

    public var point: ScrollPoint? {
        guard case .point(let point) = storage else {
            return nil
        }

        return point
    }

    public var x: Int? {
        point?.x
    }

    public var y: Int? {
        point?.y
    }

    public var edge: Edge? {
        guard case .edge(let edge) = storage else {
            return nil
        }

        return edge
    }

    public init() {
        self.storage = .automatic
    }

    public init(point: ScrollPoint) {
        self.storage = .point(point)
    }

    public init(x: Int) {
        self.init(point: ScrollPoint(x: x))
    }

    public init(y: Int) {
        self.init(point: ScrollPoint(y: y))
    }

    public init(x: Int, y: Int) {
        self.init(point: ScrollPoint(x: x, y: y))
    }

    public init(edge: Edge) {
        self.storage = .edge(edge)
    }

    public mutating func scrollTo(point: ScrollPoint) {
        storage = .point(point)
    }

    public mutating func scrollTo(x: Int) {
        storage = .point(ScrollPoint(x: x))
    }

    public mutating func scrollTo(y: Int) {
        storage = .point(ScrollPoint(y: y))
    }

    public mutating func scrollTo(x: Int, y: Int) {
        storage = .point(ScrollPoint(x: x, y: y))
    }

    public mutating func scrollTo(edge: Edge) {
        storage = .edge(edge)
    }
}

/// A scrollable view.
public struct ScrollView<Content: View>: View {

    public typealias Body = Never

    let axes: Axis.Set

    let content: Content

    public init(
        _ axes: Axis.Set = .vertical,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.content = content()
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

    /// Associates a binding to a scroll position with scroll views within this view.
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
        guard let contentBlock = ViewResolver.block(
            from: content,
            in: contentProposal(from: proposal),
            path: path + [0],
            runtime: runtime
        ) else {
            return nil
        }

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
            binding: binding
        )
        if binding != nil
            && !LayoutMeasurementContext.isMeasuring
            && runtime?.isSuppressingRenderRegistrations != true
            && (position.point != nil || position.edge != nil) {
            ScrollPositionContext.updateCurrentPosition(to: ScrollPosition(point: result.point))
        }

        var block = result.block
        block.scrollRegions.append(RenderedScrollRegion(path: path, frame: block.bounds))
        return block
    }

    private func contentProposal(from proposal: RenderProposal?) -> RenderProposal {
        RenderProposal(
            columns: axes.contains(.horizontal) ? nil : proposal?.columns,
            rows: axes.contains(.vertical) ? nil : proposal?.rows
        )
    }
}

private enum ScrollPositionContext {

    private static let threadKey = "SwiftTUI.ScrollPositionContext"

    static var currentPosition: ScrollPosition {
        currentBinding?.wrappedValue ?? ScrollPosition()
    }

    static func withPosition<Value>(
        _ position: Binding<ScrollPosition>,
        perform operation: () -> Value
    ) -> Value {
        let previous = currentBinding
        currentBinding = position
        defer {
            currentBinding = previous
        }

        return operation()
    }

    static func updateCurrentPosition(to position: ScrollPosition) {
        guard let binding = currentBinding, binding.wrappedValue != position else {
            return
        }

        binding.wrappedValue = position
    }

    static var currentBinding: Binding<ScrollPosition>? {
        get {
            Thread.current.threadDictionary[threadKey] as? Binding<ScrollPosition>
        }
        set {
            let dictionary = Thread.current.threadDictionary
            if let newValue {
                dictionary[threadKey] = newValue
            }
            else {
                dictionary.removeObject(forKey: threadKey)
            }
        }
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
                cursor: cursor(
                    from: content.cursor,
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
                )
            ),
            point: ScrollPoint(x: clampedX, y: clampedY),
            maximumPoint: maximumPoint
        )
    }

    private static func cursor(
        from cursor: RenderedCursor?,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        constrainToBounds: Bool
    ) -> RenderedCursor? {
        guard let cursor else {
            return nil
        }

        let row = cursor.row - y
        let column = cursor.column - x
        guard row >= 0, row < height, column >= 0, column <= width else {
            return nil
        }

        return RenderedCursor(
            row: row,
            column: constrainToBounds ? min(column, width - 1) : column
        )
    }

    private static func maxHorizontalOffset(for content: RenderedBlock, width: Int) -> Int {
        let cursorAllowance = content.cursor == nil || content.width < width ? 0 : 1
        var offset = max(content.width - width + cursorAllowance, 0)
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
