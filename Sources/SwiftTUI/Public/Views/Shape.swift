public import Terminal

/// A 2D terminal-cell shape that can be used as a view.
public protocol Shape: View {
}

/// A view that draws a shape and can provide that shape for further drawing.
public protocol ShapeView<Content>: View where Content: Shape {

    /// The type of shape this view provides.
    associatedtype Content: Shape

    /// The shape drawn by this view.
    nonisolated var shape: Content { get }
}

/// A rectangular shape aligned inside the frame of the view containing it.
public nonisolated struct Rectangle: Shape {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates a rectangle shape.
    public init() {}
}

/// A shape with a translation offset transform applied to it.
public nonisolated struct OffsetShape<Content: Shape>: Shape {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// The shape to offset.
    public let shape: Content

    /// The terminal-cell offset applied to the shape.
    public let offset: Point

    /// Creates an offset shape.
    ///
    /// - Parameters:
    ///   - shape: The shape to offset.
    ///   - offset: The terminal-cell offset to apply.
    public init(shape: Content, offset: Point) {
        self.shape = shape
        self.offset = offset
    }
}

/// A style for rasterizing terminal-cell shapes.
public nonisolated struct FillStyle: Equatable, Sendable {

    /// Whether the even-odd fill rule should be used.
    public let isEOFilled: Bool

    /// Whether antialiasing should be used.
    public let isAntialiased: Bool

    /// Creates a fill style.
    ///
    /// Terminal-cell rectangle rasterization currently stores these settings
    /// without changing output.
    public init(eoFill: Bool = false, antialiased: Bool = true) {
        self.isEOFilled = eoFill
        self.isAntialiased = antialiased
    }
}

/// A shape provider that fills its shape.
public nonisolated struct FillShapeView<Content: Shape, Background: View>: ShapeView {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// The shape drawn by this view.
    public let shape: Content

    /// The terminal color used to fill the shape, or `nil` for foreground fill.
    public let style: AnyColor?

    /// The fill style used when filling the shape.
    public let fillStyle: FillStyle

    /// The background shape view drawn underneath this fill.
    public let background: Background

    /// Creates a filled shape view.
    ///
    /// - Parameters:
    ///   - shape: The shape to fill.
    ///   - style: The terminal fill color, or `nil` for foreground fill.
    ///   - fillStyle: The fill style options to store with the view.
    ///   - background: A background shape view to draw underneath this fill.
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

    /// Returns the same shape drawn from a terminal-cell rect of the given size.
    ///
    /// This does not change the layout size of views created from the shape.
    func size(_ size: Size) -> some Shape {
        SizedShape(shape: self, size: size)
    }

    /// Returns the same shape drawn from a terminal-cell rect of the given size.
    ///
    /// This does not change the layout size of views created from the shape.
    func size(width: Int, height: Int) -> some Shape {
        size(Size(columns: width, rows: height))
    }

    /// Changes the relative position of this shape using a terminal-cell point.
    func offset(_ offset: Point) -> OffsetShape<Self> {
        OffsetShape(shape: self, offset: offset)
    }

    /// Changes the relative position of this shape using terminal-cell offsets.
    func offset(x: Int = 0, y: Int = 0) -> OffsetShape<Self> {
        offset(Point(column: x, row: y))
    }

    /// Fills this shape with a terminal color.
    func fill(_ content: AnyColor, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        FillShapeView(shape: self, style: content, fillStyle: style, background: EmptyView())
    }

    /// Fills this shape with a terminal color.
    func fill(_ content: Color16, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with a terminal color.
    func fill(_ content: Color256, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with a terminal color.
    func fill(_ content: TrueColor, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with the default terminal color.
    func fill(
        _ content: DefaultColor,
        style: FillStyle = FillStyle()
    ) -> FillShapeView<Self, EmptyView> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with a terminal color shape style.
    func fill<S>(_ content: S, style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView>
    where S: Color & ShapeStyle {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with the current foreground style.
    func fill(style: FillStyle = FillStyle()) -> FillShapeView<Self, EmptyView> {
        FillShapeView(shape: self, style: nil, fillStyle: style, background: EmptyView())
    }
}

public extension ShapeView {

    /// Fills this shape with a terminal color over this shape view.
    func fill(_ content: AnyColor, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        FillShapeView(shape: shape, style: content, fillStyle: style, background: self)
    }

    /// Fills this shape with a terminal color over this shape view.
    func fill(_ content: Color16, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with a terminal color over this shape view.
    func fill(_ content: Color256, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with a terminal color over this shape view.
    func fill(_ content: TrueColor, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with the default terminal color over this shape view.
    func fill(
        _ content: DefaultColor,
        style: FillStyle = FillStyle()
    ) -> FillShapeView<Content, Self> {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with a terminal color shape style over this shape view.
    func fill<S>(_ content: S, style: FillStyle = FillStyle()) -> FillShapeView<Content, Self>
    where S: Color & ShapeStyle {
        fill(AnyColor(content), style: style)
    }

    /// Fills this shape with the current foreground style over this shape view.
    func fill(style: FillStyle = FillStyle()) -> FillShapeView<Content, Self> {
        FillShapeView(shape: shape, style: nil, fillStyle: style, background: self)
    }
}

protocol ShapeRenderable {

    func renderedShapeRects(in rect: RenderedRect) -> [RenderedRect]
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

    func renderedShapeRects(in rect: RenderedRect) -> [RenderedRect] {
        rect.isEmpty ? [] : [rect]
    }
}

extension OffsetShape: ShapeRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    func renderedShapeRects(in rect: RenderedRect) -> [RenderedRect] {
        guard let shape = shape as? any ShapeRenderable else {
            return []
        }

        return shape.renderedShapeRects(in: rect).map {
            $0.offsetBy(x: offset.column, y: offset.row)
        }
    }
}

extension SizedShape: ShapeRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    func renderedShapeRects(in rect: RenderedRect) -> [RenderedRect] {
        guard let shape = shape as? any ShapeRenderable else {
            return []
        }

        let sizedRect = RenderedRect(
            x: rect.x,
            y: rect.y,
            width: size.columns,
            height: size.rows
        )
        return shape.renderedShapeRects(in: sizedRect)
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

        let runs = shape.renderedShapeRects(in: bounds)
            .compactMap { $0.clipped(to: bounds) }
            .flatMap { fillRuns(in: $0, style: style) }
        return RenderedBlock(
            runs: runs,
            width: bounds.width,
            height: bounds.height,
            paddedRows: Set(0..<bounds.height)
        )
    }

    private static func fillRuns(in rect: RenderedRect, style: AnyColor) -> [RenderedRun] {
        guard !rect.isEmpty else {
            return []
        }

        let text = String(repeating: "█", count: rect.width)
        return (rect.y..<(rect.y + rect.height)).map {
            RenderedRun(
                text: text,
                row: $0,
                column: rect.x,
                style: TextStyle(foregroundStyle: style)
            )
        }
    }
}
