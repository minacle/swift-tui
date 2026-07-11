public import Terminal

/// A two-dimensional shape whose fill is rasterized into terminal cells.
///
/// SwiftTUI's built-in rectangle and the public wrappers produced by this file
/// are flexible on both layout axes and draw within the finite columns and rows
/// proposed by their container. For those shapes, an unspecified proposed axis
/// provides zero drawing extent. An external conformance can provide an
/// ordinary ``View/body``, but conformance alone doesn't opt that type into the
/// built-in rasterizer or flexible-axis behavior.
public protocol Shape: View {
}

/// A rendered shape layer that exposes its underlying shape for another fill.
///
/// Calling `fill` on a shape view adds a new fill above the existing layer. In
/// overlapping cells, the later fill is visible.
public protocol ShapeView<Content>: View where Content: Shape {

    /// The concrete underlying shape available for further fills.
    associatedtype Content: Shape

    /// The underlying shape geometry shared by this view's fill layers.
    nonisolated var shape: Content { get }
}

/// A rectangular shape that fills its proposed terminal-cell bounds.
///
/// The rectangle establishes its proposed bounds even when it has no color. It
/// emits full-block glyphs only when an explicit fill or the inherited
/// foreground resolves to a terminal color; otherwise it produces no glyphs
/// within those bounds. Apply ``edge(style:)`` to represent selected outer
/// edges with half-block and quarter-block glyphs once a color resolves.
public nonisolated struct Rectangle: Shape {

    /// The body type for this directly rendered primitive shape.
    public typealias Body = Never

    let halfCellEdgeStyle: RectangleHalfCellEdgeStyle

    /// Creates a full-cell rectangle with no half-cell edge insets.
    public init() {
        halfCellEdgeStyle = RectangleHalfCellEdgeStyle()
    }

    private init(halfCellEdgeStyle: RectangleHalfCellEdgeStyle) {
        self.halfCellEdgeStyle = halfCellEdgeStyle
    }

    /// Returns this rectangle with a replacement half-cell edge style.
    ///
    /// Repeated calls replace the previous edge style rather than combining
    /// edge sets.
    ///
    /// - Parameter style: The set of outer edges to render at half-cell depth.
    /// - Returns: A rectangle carrying `style`.
    public func edge(style: RectangleHalfCellEdgeStyle) -> Rectangle {
        Rectangle(halfCellEdgeStyle: style)
    }
}

/// A style that renders selected rectangle edges at half-cell depth.
///
/// Horizontal edges use upper or lower half blocks, vertical edges use left or
/// right half blocks, and intersecting selected edges use quarter blocks. If
/// both opposing edges are selected on a one-cell axis, the shape has no filled
/// area on that axis.
public nonisolated struct RectangleHalfCellEdgeStyle: Equatable, Sendable {

    /// The outer edges to render at half-cell depth.
    public var edges: Edge.Set

    /// Creates a half-cell rectangle edge style.
    ///
    /// - Parameter edges: The edges to render at half-cell depth. The default
    ///   empty set leaves a full-block rectangle unchanged.
    public init(edges: Edge.Set = []) {
        self.edges = edges
    }
}

/// A shape translated relative to its unchanged layout bounds.
///
/// Positive column and row offsets move drawing toward the trailing and bottom
/// edges. Drawing outside the proposed bounds is clipped; the translation
/// doesn't expand or reposition the view's layout frame.
public nonisolated struct OffsetShape<Content: Shape>: Shape {

    /// The body type for this directly rendered primitive shape.
    public typealias Body = Never

    /// The shape to offset.
    public let shape: Content

    /// The terminal-cell column and row translation applied to drawing.
    public let offset: Point

    /// Creates an offset shape.
    ///
    /// - Parameters:
    ///   - shape: The shape to offset.
    ///   - offset: The column and row translation to apply without changing
    ///     layout bounds.
    public init(shape: Content, offset: Point) {
        self.shape = shape
        self.offset = offset
    }
}

/// Stores fill-rule and antialiasing preferences for a filled shape.
///
/// SwiftTUI's current terminal rectangle rasterizer doesn't change output for
/// either preference. The values are preserved on ``FillShapeView`` for API
/// compatibility and future rasterizers.
public nonisolated struct FillStyle: Equatable, Sendable {

    /// The requested even-odd fill-rule setting.
    public let isEOFilled: Bool

    /// The requested antialiasing setting.
    public let isAntialiased: Bool

    /// Creates a fill style.
    ///
    /// Terminal-cell rectangle rasterization currently stores these settings
    /// without changing output.
    ///
    /// - Parameters:
    ///   - eoFill: The requested even-odd fill rule. The default is `false`.
    ///   - antialiased: The requested antialiasing setting. The default is
    ///     `true`.
    public init(eoFill: Bool = false, antialiased: Bool = true) {
        self.isEOFilled = eoFill
        self.isAntialiased = antialiased
    }
}

/// A rendered fill layer for a terminal-cell shape.
///
/// `background` is rendered first and this fill is composited above it. A
/// `nil` style resolves from the current foreground color; if neither provides
/// a color, this layer draws no block glyphs.
public nonisolated struct FillShapeView<Content: Shape, Background: View>: ShapeView {

    /// The body type for this directly rendered primitive shape view.
    public typealias Body = Never

    /// The shape drawn by this view.
    public let shape: Content

    /// The explicit fill color, or `nil` to resolve the current foreground
    /// color during rendering.
    public let style: AnyColor?

    /// The stored fill preferences associated with this layer.
    public let fillStyle: FillStyle

    /// The background view composited underneath this fill layer.
    ///
    /// `Background` can be any ``View``; it doesn't need to be another shape or
    /// shape view.
    public let background: Background

    /// Creates a filled shape view.
    ///
    /// - Parameters:
    ///   - shape: The shape to fill.
    ///   - style: The explicit terminal fill color, or `nil` to use the current
    ///     foreground color at render time.
    ///   - fillStyle: The fill preferences to retain with the layer. They don't
    ///     currently alter rectangle rasterization.
    ///   - background: Any view to composite underneath this fill layer.
    public init(
        shape: Content,
        style: AnyColor?,
        fillStyle: FillStyle,
        background: Background
    ) {
        self.shape = shape
        self.style = style
        self.fillStyle = fillStyle
        self.background = background
    }
}

struct SizedShape<Content: Shape>: Shape {

    typealias Body = Never

    let shape: Content

    let size: Size
}

public extension Shape {

    /// Constrains this shape's drawing rectangle without changing its layout
    /// bounds.
    ///
    /// The drawing starts at the original top-leading origin and is clipped to
    /// the proposed layout bounds. A nonpositive column or row value draws no
    /// fill while preserving the surrounding layout frame.
    ///
    /// - Parameter size: The drawing extent in terminal columns and rows.
    /// - Returns: A shape that uses `size` for rasterization only.
    func size(_ size: Size) -> some Shape {
        SizedShape(shape: self, size: size)
    }

    /// Constrains this shape's drawing rectangle without changing its layout
    /// bounds.
    ///
    /// - Parameters:
    ///   - width: The drawing extent in terminal columns. A nonpositive value
    ///     draws no fill.
    ///   - height: The drawing extent in terminal rows. A nonpositive value
    ///     draws no fill.
    /// - Returns: A shape that uses the supplied extent for rasterization only.
    func size(width: Int, height: Int) -> some Shape {
        size(Size(columns: width, rows: height))
    }

    /// Translates this shape's drawing without changing its layout bounds.
    ///
    /// Drawing moved outside those bounds is clipped.
    ///
    /// - Parameter offset: The terminal-column and row translation.
    /// - Returns: An offset shape sharing this shape's geometry.
    func offset(_ offset: Point) -> OffsetShape<Self> {
        OffsetShape(shape: self, offset: offset)
    }

    /// Translates this shape's drawing without changing its layout bounds.
    ///
    /// - Parameters:
    ///   - x: The terminal-column translation. The default is `0`.
    ///   - y: The terminal-row translation. The default is `0`.
    /// - Returns: An offset shape clipped to its eventual layout bounds.
    func offset(x: Int = 0, y: Int = 0) -> OffsetShape<Self> {
        offset(Point(column: x, row: y))
    }

    /// Creates the first fill layer for this shape with a type-erased terminal
    /// color.
    ///
    /// - Parameters:
    ///   - content: The explicit color for block glyphs.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view containing this fill over an empty background.
    func fill(_ content: AnyColor, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        FillShapeView(shape: self, style: content, fillStyle: style, background: EmptyView())
    }

    /// Creates the first fill layer with a 16-color terminal SGR value.
    ///
    /// - Parameters:
    ///   - content: The explicit color for block glyphs.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view containing this fill over an empty background.
    func fill(_ content: Color16, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Creates the first fill layer with a 256-color terminal SGR value.
    ///
    /// - Parameters:
    ///   - content: The explicit color for block glyphs.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view containing this fill over an empty background.
    func fill(_ content: Color256, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Creates the first fill layer with a true-color terminal SGR value.
    ///
    /// - Parameters:
    ///   - content: The explicit color for block glyphs.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view containing this fill over an empty background.
    func fill(_ content: TrueColor, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Creates the first fill layer with the terminal's default foreground
    /// color.
    ///
    /// - Parameters:
    ///   - content: The default-color reset value.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view containing this fill over an empty background.
    func fill(
        _ content: DefaultColor,
        style: FillStyle = FillStyle()
    ) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Creates the first fill layer with a concrete terminal color shape style.
    ///
    /// - Parameters:
    ///   - content: The explicit color style for block glyphs.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view containing this fill over an empty background.
    func fill<S>(_ content: S, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView>
    where S: Color & ShapeStyle {
        fill(AnyColor(content), style: style)
    }

    /// Creates the first fill layer using the current foreground color.
    ///
    /// If no foreground color is present in the rendering environment, the
    /// layer reserves its proposed bounds but draws no block glyphs.
    ///
    /// - Parameter style: Fill preferences to retain; they don't currently
    ///   alter rectangle output.
    /// - Returns: A shape view that resolves its color during rendering.
    func fill(style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        FillShapeView(shape: self, style: nil, fillStyle: style, background: EmptyView())
    }
}

public extension ShapeView {

    /// Adds a type-erased terminal-color fill above this shape view.
    ///
    /// - Parameters:
    ///   - content: The explicit color for the new fill layer.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view that composites this view first and the new fill
    ///   second.
    func fill(_ content: AnyColor, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        FillShapeView(shape: shape, style: content, fillStyle: style, background: self)
    }

    /// Adds a 16-color terminal SGR fill above this shape view.
    ///
    /// - Parameters:
    ///   - content: The explicit color for the new fill layer.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view with the new fill composited last.
    func fill(_ content: Color16, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Adds a 256-color terminal SGR fill above this shape view.
    ///
    /// - Parameters:
    ///   - content: The explicit color for the new fill layer.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view with the new fill composited last.
    func fill(_ content: Color256, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Adds a true-color terminal SGR fill above this shape view.
    ///
    /// - Parameters:
    ///   - content: The explicit color for the new fill layer.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view with the new fill composited last.
    func fill(_ content: TrueColor, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Adds a default-terminal-color fill above this shape view.
    ///
    /// - Parameters:
    ///   - content: The default-color reset value for the new layer.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view with the new fill composited last.
    func fill(
        _ content: DefaultColor,
        style: FillStyle = FillStyle()
    ) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Adds a concrete terminal color shape style above this shape view.
    ///
    /// - Parameters:
    ///   - content: The explicit color style for the new layer.
    ///   - style: Fill preferences to retain; they don't currently alter
    ///     rectangle output.
    /// - Returns: A shape view with the new fill composited last.
    func fill<S>(_ content: S, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self>
    where S: Color & ShapeStyle {
        fill(AnyColor(content), style: style)
    }

    /// Adds a fill that resolves the current foreground color above this shape
    /// view.
    ///
    /// If no foreground color is present, the earlier shape view remains
    /// visible without new block glyphs.
    ///
    /// - Parameter style: Fill preferences to retain; they don't currently
    ///   alter rectangle output.
    /// - Returns: A shape view with a foreground-resolved layer composited last.
    func fill(style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        FillShapeView(shape: shape, style: nil, fillStyle: style, background: self)
    }
}

protocol ShapeRenderable {

    func renderedShapeRegions(in rect: RenderedRect) -> [RenderedShapeRegion]
}

nonisolated struct RenderedShapeRegion: Equatable, Sendable {

    var rect: RenderedRect

    var halfCellEdges: Edge.Set

    func offsetBy(x: Int, y: Int) -> RenderedShapeRegion {
        RenderedShapeRegion(
            rect: rect.offsetBy(x: x, y: y),
            halfCellEdges: halfCellEdges
        )
    }
}

protocol FillShapeRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

extension Rectangle: ShapeRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    func renderedShapeRegions(in rect: RenderedRect) -> [RenderedShapeRegion] {
        rect.isEmpty
            ? []
            : [RenderedShapeRegion(rect: rect, halfCellEdges: halfCellEdgeStyle.edges)]
    }
}

extension OffsetShape: ShapeRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    func renderedShapeRegions(in rect: RenderedRect) -> [RenderedShapeRegion] {
        guard let shape = shape as? any ShapeRenderable else {
            return []
        }

        return shape.renderedShapeRegions(in: rect).map {
            $0.offsetBy(x: offset.column, y: offset.row)
        }
    }
}

extension SizedShape: ShapeRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    func renderedShapeRegions(in rect: RenderedRect) -> [RenderedShapeRegion] {
        guard let shape = shape as? any ShapeRenderable else {
            return []
        }

        let sizedRect = RenderedRect(
            x: rect.x,
            y: rect.y,
            width: size.columns,
            height: size.rows
        )
        return shape.renderedShapeRegions(in: sizedRect)
    }
}

extension FillShapeView: FillShapeRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ShapeRenderer.filledBlock(
            shape: shape,
            style: style,
            background: background,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

enum ShapeRenderer {

    static func defaultBlock(
        shape: any ShapeRenderable,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        filledBlock(
            shape: shape,
            style: nil,
            proposal: proposal,
            backgroundBlock: nil
        )
    }

    static func filledBlock<Content: Shape, Background: View>(
        shape: Content,
        style: AnyColor?,
        background: Background,
        proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard let shape = shape as? any ShapeRenderable else {
            return renderedBlock(width: proposal?.columns ?? 0, height: proposal?.rows ?? 0)
        }

        let backgroundBlock = ViewResolver.block(
            from: background,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
        return filledBlock(
            shape: shape,
            style: style,
            proposal: proposal,
            backgroundBlock: backgroundBlock
        )
    }

    private static func filledBlock(
        shape: any ShapeRenderable,
        style: AnyColor?,
        proposal: RenderProposal?,
        backgroundBlock: RenderedBlock?
    ) -> RenderedBlock? {
        let width = proposal?.columns ?? 0
        let height = proposal?.rows ?? 0
        guard let baseBlock = renderedBlock(width: width, height: height) else {
            return nil
        }
        let bounds = RenderedRect(width: width, height: height)
        let fillBlock = fillBlock(
            shape: shape,
            bounds: bounds,
            style: style ?? EnvironmentRenderContext.current.textStyle.foregroundStyle
        )

        return RenderedBlock.composited(
            [backgroundBlock, fillBlock].compactMap { $0 },
            width: width,
            height: height,
            paddedRows: baseBlock.paddedRows
        )
    }

    private static func renderedBlock(width: Int, height: Int) -> RenderedBlock? {
        guard width > 0, height > 0 else {
            return RenderedBlock(lines: [])
        }

        return RenderedBlock(
            runs: [],
            width: width,
            height: height,
            paddedRows: Set(0..<height)
        )
    }

    private static func fillBlock(
        shape: any ShapeRenderable,
        bounds: RenderedRect,
        style: AnyColor?
    ) -> RenderedBlock {
        guard let style else {
            return RenderedBlock(
                runs: [],
                width: bounds.width,
                height: bounds.height,
                paddedRows: Set(0..<bounds.height)
            )
        }

        let runs = shape.renderedShapeRegions(in: bounds)
            .flatMap { fillRuns(in: $0, clippedTo: bounds, style: style) }
        return RenderedBlock(
            runs: runs,
            width: bounds.width,
            height: bounds.height,
            paddedRows: Set(0..<bounds.height)
        )
    }

    private static func fillRuns(
        in region: RenderedShapeRegion,
        clippedTo bounds: RenderedRect,
        style: AnyColor
    ) -> [RenderedRun] {
        let originalRect = region.rect
        let originalEdges = region.halfCellEdges
        guard
            !(originalRect.width == 1 && originalEdges.isSuperset(of: .horizontal)),
            !(originalRect.height == 1 && originalEdges.isSuperset(of: .vertical)),
            let rect = originalRect.clipped(to: bounds)
        else {
            return []
        }

        var visibleEdges = originalEdges
        if rect.x != originalRect.x {
            visibleEdges.remove(.leading)
        }
        if rect.y != originalRect.y {
            visibleEdges.remove(.top)
        }
        if rect.x + rect.width != originalRect.x + originalRect.width {
            visibleEdges.remove(.trailing)
        }
        if rect.y + rect.height != originalRect.y + originalRect.height {
            visibleEdges.remove(.bottom)
        }

        return (rect.y..<(rect.y + rect.height)).map { row in
            let text = (rect.x..<(rect.x + rect.width)).map { column in
                fillGlyph(atColumn: column, row: row, in: rect, edges: visibleEdges)
            }.joined()
            return RenderedRun(
                text: text,
                row: row,
                column: rect.x,
                style: TextStyle(foregroundStyle: style)
            )
        }
    }

    private static func fillGlyph(
        atColumn column: Int,
        row: Int,
        in rect: RenderedRect,
        edges: Edge.Set
    ) -> String {
        let isTop = row == rect.y && edges.contains(.top)
        let isBottom = row == rect.y + rect.height - 1 && edges.contains(.bottom)
        let isLeading = column == rect.x && edges.contains(.leading)
        let isTrailing = column == rect.x + rect.width - 1 && edges.contains(.trailing)

        return switch (isTop, isBottom, isLeading, isTrailing) {
        case (true, false, true, false):
            "▗"
        case (true, false, false, true):
            "▖"
        case (false, true, true, false):
            "▝"
        case (false, true, false, true):
            "▘"
        case (true, false, false, false):
            "▄"
        case (false, true, false, false):
            "▀"
        case (false, false, true, false):
            "▐"
        case (false, false, false, true):
            "▌"
        default:
            "█"
        }
    }
}
