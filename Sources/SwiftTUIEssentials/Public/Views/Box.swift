/// A view that draws a box around its content using box drawing characters.
///
/// A regular-line border consumes one terminal row for each horizontal edge
/// and one terminal column for each vertical edge. The box proposes the
/// remaining interior size to its content and clips content that exceeds that
/// interior. Each axis resolves independently: a specified positive proposal
/// becomes the exact size on that axis, while an unspecified axis uses the
/// content's resolved size plus two cells. If either resolved dimension is zero
/// or negative, the entire box collapses to an empty zero-column, zero-row
/// block.
///
/// The border inherits foreground color, background color, and dim styling.
/// Other text attributes don't apply to the border glyphs.
public nonisolated struct Box<Content: View>: View, BoxRenderable,
    LayoutTraitRenderable
{

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let content: Content

    var boxDrawingSet: BoxDrawingSet {
        .regular
    }

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    /// Creates a regular-line border around view-builder content.
    ///
    /// - Parameter content: A builder evaluated immediately to create content
    ///   for the one-cell inset interior.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

public extension Box where Content == EmptyView {

    /// Creates a regular-line box with no interior content.
    ///
    /// Without a finite proposal, the result is two columns by two rows. Narrow
    /// or short proposals collapse the border to tee or cross glyphs.
    init() {
        self.init {
            EmptyView()
        }
    }
}

/// A view that draws a rounded box around its content using box drawing characters.
///
/// The one-cell border uses rounded corner glyphs with regular horizontal and
/// vertical lines. It follows the same sizing, clipping, and style propagation
/// as ``Box``; degenerate one-row or one-column proposals use regular tee and
/// cross glyphs because no corner area remains.
public nonisolated struct RoundedBox<Content: View>: View, BoxRenderable,
    LayoutTraitRenderable
{

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let content: Content

    var boxDrawingSet: BoxDrawingSet {
        .rounded
    }

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    /// Creates a rounded-corner border around view-builder content.
    ///
    /// - Parameter content: A builder evaluated immediately to create content
    ///   for the one-cell inset interior.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

public extension RoundedBox where Content == EmptyView {

    /// Creates a rounded-corner box with no interior content.
    ///
    /// Without a finite proposal, the result is two columns by two rows.
    init() {
        self.init {
            EmptyView()
        }
    }
}

/// A view that draws a heavy box around its content using box drawing characters.
///
/// The heavy-line border consumes one cell on every edge and follows the same
/// sizing, clipping, and style propagation as ``Box``.
public nonisolated struct HeavyBox<Content: View>: View, BoxRenderable,
    LayoutTraitRenderable
{

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let content: Content

    var boxDrawingSet: BoxDrawingSet {
        .heavy
    }

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    /// Creates a heavy-line border around view-builder content.
    ///
    /// - Parameter content: A builder evaluated immediately to create content
    ///   for the one-cell inset interior.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

public extension HeavyBox where Content == EmptyView {

    /// Creates a heavy-line box with no interior content.
    ///
    /// Without a finite proposal, the result is two columns by two rows.
    init() {
        self.init {
            EmptyView()
        }
    }
}

/// A view that draws a double-line box around its content using box drawing characters.
///
/// The double-line border consumes one cell on every edge and follows the same
/// sizing, clipping, and style propagation as ``Box``.
public nonisolated struct DoubleBox<Content: View>: View, BoxRenderable,
    LayoutTraitRenderable
{

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let content: Content

    var boxDrawingSet: BoxDrawingSet {
        .double
    }

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    /// Creates a double-line border around view-builder content.
    ///
    /// - Parameter content: A builder evaluated immediately to create content
    ///   for the one-cell inset interior.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

public extension DoubleBox where Content == EmptyView {

    /// Creates a double-line box with no interior content.
    ///
    /// Without a finite proposal, the result is two columns by two rows.
    init() {
        self.init {
            EmptyView()
        }
    }
}

protocol BoxRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

extension Box {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        BoxRenderer.renderedBlock(
            content: content,
            drawingSet: boxDrawingSet,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

extension RoundedBox {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        BoxRenderer.renderedBlock(
            content: content,
            drawingSet: boxDrawingSet,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

extension HeavyBox {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        BoxRenderer.renderedBlock(
            content: content,
            drawingSet: boxDrawingSet,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

extension DoubleBox {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        BoxRenderer.renderedBlock(
            content: content,
            drawingSet: boxDrawingSet,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

nonisolated struct BoxDrawingSet: Sendable {

    let topLeft: String

    let topRight: String

    let bottomLeft: String

    let bottomRight: String

    let horizontal: String

    let vertical: String

    let topTee: String

    let bottomTee: String

    let leftTee: String

    let rightTee: String

    let cross: String

    static let regular = BoxDrawingSet(
        topLeft: "┌",
        topRight: "┐",
        bottomLeft: "└",
        bottomRight: "┘",
        horizontal: "─",
        vertical: "│",
        topTee: "┬",
        bottomTee: "┴",
        leftTee: "├",
        rightTee: "┤",
        cross: "┼"
    )

    static let rounded = BoxDrawingSet(
        topLeft: "╭",
        topRight: "╮",
        bottomLeft: "╰",
        bottomRight: "╯",
        horizontal: "─",
        vertical: "│",
        topTee: "┬",
        bottomTee: "┴",
        leftTee: "├",
        rightTee: "┤",
        cross: "┼"
    )

    static let heavy = BoxDrawingSet(
        topLeft: "┏",
        topRight: "┓",
        bottomLeft: "┗",
        bottomRight: "┛",
        horizontal: "━",
        vertical: "┃",
        topTee: "┳",
        bottomTee: "┻",
        leftTee: "┣",
        rightTee: "┫",
        cross: "╋"
    )

    static let double = BoxDrawingSet(
        topLeft: "╔",
        topRight: "╗",
        bottomLeft: "╚",
        bottomRight: "╝",
        horizontal: "═",
        vertical: "║",
        topTee: "╦",
        bottomTee: "╩",
        leftTee: "╠",
        rightTee: "╣",
        cross: "╬"
    )
}

enum BoxRenderer {

    static func renderedBlock<Content: View>(
        content: Content,
        drawingSet: BoxDrawingSet,
        proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let contentProposal = RenderProposal(
            columns: proposal?.columns.map { max($0 - 2, 0) },
            rows: proposal?.rows.map { max($0 - 2, 0) }
        )
        let contentBlock = ViewResolver.block(
            from: content,
            in: contentProposal,
            path: path + [0],
            runtime: runtime
        )

        let width = proposal?.columns ?? ((contentBlock?.width ?? 0) + 2)
        let height = proposal?.rows ?? ((contentBlock?.height ?? 0) + 2)
        guard width > 0, height > 0 else {
            return RenderedBlock(lines: [])
        }

        let bounds = RenderedRect(width: width, height: height)
        let contentBounds = RenderedRect(
            width: max(width - 2, 0),
            height: max(height - 2, 0)
        )
        let clippedContent = contentBounds.isEmpty ? nil : contentBlock?
            .offsetBy(x: 0, y: 0, clippedTo: contentBounds)
            .offsetBy(x: 1, y: 1, clippedTo: bounds)
        let borderRuns = borderRuns(
            width: width,
            height: height,
            drawingSet: drawingSet,
            style: borderStyle(from: EnvironmentRenderContext.current.textStyle)
        )

        return RenderedBlock(
            runs: borderRuns + (clippedContent?.runs ?? []),
            width: width,
            height: height,
            paddedRows: Set(0..<height),
            caret: clippedContent?.caret,
            hitRegions: clippedContent?.hitRegions ?? [],
            scrollRegions: clippedContent?.scrollRegions ?? [],
            focusRegions: clippedContent?.focusRegions ?? [],
            coordinateSpaceRegions: clippedContent?.coordinateSpaceRegions ?? [],
            explicitAlignments: clippedContent?.explicitAlignments ?? [:]
        )
    }

    static func borderStyle(from style: TextStyle) -> TextStyle {
        var borderStyle = TextStyle.plain
        borderStyle.foregroundStyle = style.foregroundStyle
        borderStyle.backgroundStyle = style.backgroundStyle
        borderStyle.isDim = style.isDim
        return borderStyle
    }

    private static func borderRuns(
        width: Int,
        height: Int,
        drawingSet: BoxDrawingSet,
        style: TextStyle
    ) -> [RenderedRun] {
        if width == 1, height == 1 {
            return [RenderedRun(text: drawingSet.cross, style: style)]
        }

        if height == 1 {
            return [
                RenderedRun(
                    text: drawingSet.leftTee
                        + String(repeating: drawingSet.horizontal, count: max(width - 2, 0))
                        + drawingSet.rightTee,
                    style: style
                ),
            ]
        }

        if width == 1 {
            var runs = [
                RenderedRun(text: drawingSet.topTee, style: style),
            ]
            runs.append(
                contentsOf: (1..<(height - 1)).map {
                    RenderedRun(text: drawingSet.vertical, row: $0, style: style)
                }
            )
            runs.append(RenderedRun(text: drawingSet.bottomTee, row: height - 1, style: style))
            return runs
        }

        var runs = [
            RenderedRun(
                text: drawingSet.topLeft
                    + String(repeating: drawingSet.horizontal, count: max(width - 2, 0))
                    + drawingSet.topRight,
                style: style
            ),
        ]
        for row in 1..<(height - 1) {
            runs.append(RenderedRun(text: drawingSet.vertical, row: row, style: style))
            runs.append(
                RenderedRun(text: drawingSet.vertical, row: row, column: width - 1, style: style)
            )
        }
        runs.append(
            RenderedRun(
                text: drawingSet.bottomLeft
                    + String(repeating: drawingSet.horizontal, count: max(width - 2, 0))
                    + drawingSet.bottomRight,
                row: height - 1,
                style: style
            )
        )
        return runs
    }
}
