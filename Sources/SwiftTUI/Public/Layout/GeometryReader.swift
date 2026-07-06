/// A terminal-native size measured in character cells.
public nonisolated struct GeometrySize: Equatable, Sendable {

    /// The width in terminal columns.
    public let columns: Int

    /// The height in terminal rows.
    public let rows: Int

    /// Creates a terminal-cell size.
    ///
    /// Negative values are clamped to zero.
    public init(columns: Int = 0, rows: Int = 0) {
        self.columns = max(columns, 0)
        self.rows = max(rows, 0)
    }
}

/// A terminal-native point measured in character cells.
public nonisolated struct GeometryPoint: Equatable, Sendable {

    /// The zero-based terminal column.
    public let column: Int

    /// The zero-based terminal row.
    public let row: Int

    /// Creates a terminal-cell point.
    ///
    /// Negative values are clamped to zero.
    public init(column: Int = 0, row: Int = 0) {
        self.column = max(column, 0)
        self.row = max(row, 0)
    }
}

/// A terminal-native rectangle measured in character cells.
public nonisolated struct GeometryFrame: Equatable, Sendable {

    /// The frame origin in terminal-cell coordinates.
    public let origin: GeometryPoint

    /// The frame size in terminal cells.
    public let size: GeometrySize

    /// Creates a terminal-cell frame.
    ///
    /// - Parameters:
    ///   - origin: The frame origin.
    ///   - size: The frame size.
    public init(
        origin: GeometryPoint = GeometryPoint(),
        size: GeometrySize = GeometrySize()
    ) {
        self.origin = origin
        self.size = size
    }
}

/// A proxy for access to the terminal size of a geometry reader.
public nonisolated struct GeometryProxy: Equatable, Sendable {

    /// The size proposed to the geometry reader.
    public let size: GeometrySize

    /// The proposed width in terminal columns.
    public var columns: Int {
        size.columns
    }

    /// The proposed height in terminal rows.
    public var rows: Int {
        size.rows
    }

    /// A frame with zero origin and this proxy's size.
    public var frame: GeometryFrame {
        GeometryFrame(size: size)
    }

    /// Creates a geometry proxy from a terminal-cell size.
    public init(size: GeometrySize = GeometrySize()) {
        self.size = size
    }

    /// Creates a geometry proxy from terminal columns and rows.
    public init(columns: Int = 0, rows: Int = 0) {
        self.init(size: GeometrySize(columns: columns, rows: rows))
    }
}

/// A container view that defines its content as a function of its terminal size.
///
/// `GeometryReader` expands flexibly in both axes and passes the proposed
/// terminal-cell size to its content closure.
public nonisolated struct GeometryReader<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// The content builder evaluated with the current geometry proxy.
    public let content: (GeometryProxy) -> Content

    let statePath: [Int]?

    /// Creates a geometry reader.
    ///
    /// - Parameter content: A view builder that receives the current terminal
    ///   geometry proxy.
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
        self.statePath = StateContext.currentPath
    }
}

protocol GeometryReaderRenderable {

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

extension GeometryReader: GeometryReaderRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let proxy = GeometryProxy(
            columns: proposal?.columns ?? 0,
            rows: proposal?.rows ?? 0
        )
        let resolvedContent: Content
        if let statePath, let runtime {
            resolvedContent = runtime.withView(at: statePath, mode: .render) {
                content(proxy)
            }
        }
        else {
            resolvedContent = content(proxy)
        }
        guard let block = ViewResolver.block(
            from: resolvedContent,
            in: proposal,
            path: path + [0],
            runtime: runtime
        ) else {
            return nil
        }

        return frame(block, in: proposal)
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
    }

    private func frame(_ block: RenderedBlock, in proposal: RenderProposal?) -> RenderedBlock {
        let targetWidth = proposal?.columns ?? block.width
        let targetHeight = proposal?.rows ?? block.height
        guard targetWidth > 0, targetHeight > 0 else {
            return RenderedBlock(lines: [])
        }

        let bounds = RenderedRect(width: targetWidth, height: targetHeight)

        return RenderedBlock(
            runs: block.runs.flatMap {
                $0.clipped(to: bounds)
            },
            width: targetWidth,
            height: targetHeight,
            paddedRows: Set(0..<targetHeight),
            cursor: frameCursor(block.cursor, width: targetWidth, height: targetHeight),
            hitRegions: frameHitRegions(
                block.hitRegions,
                width: targetWidth,
                height: targetHeight
            ),
            scrollRegions: frameScrollRegions(
                block.scrollRegions,
                width: targetWidth,
                height: targetHeight
            ),
            focusRegions: frameFocusRegions(
                block.focusRegions,
                width: targetWidth,
                height: targetHeight
            )
        )
    }

    private func frameCursor(
        _ cursor: RenderedCursor?,
        width: Int,
        height: Int
    ) -> RenderedCursor? {
        guard let cursor,
              cursor.row >= 0,
              cursor.row < height,
              cursor.column >= 0,
              cursor.column <= width else {
            return nil
        }

        return RenderedCursor(
            row: cursor.row,
            column: min(cursor.column, width - 1)
        )
    }

    private func frameHitRegions(
        _ hitRegions: [RenderedHitRegion],
        width: Int,
        height: Int
    ) -> [RenderedHitRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return hitRegions.compactMap {
            $0.clipped(to: bounds)
        }
    }

    private func frameScrollRegions(
        _ scrollRegions: [RenderedScrollRegion],
        width: Int,
        height: Int
    ) -> [RenderedScrollRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return scrollRegions.compactMap {
            $0.clipped(to: bounds)
        }
    }

    private func frameFocusRegions(
        _ focusRegions: [RenderedFocusRegion],
        width: Int,
        height: Int
    ) -> [RenderedFocusRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return focusRegions.compactMap {
            $0.clipped(to: bounds)
        }
    }
}
