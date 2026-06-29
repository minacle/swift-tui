/// A terminal-native size measured in character cells.
public struct GeometrySize: Equatable, Sendable {

    public let columns: Int

    public let rows: Int

    public init(columns: Int = 0, rows: Int = 0) {
        self.columns = max(columns, 0)
        self.rows = max(rows, 0)
    }
}

/// A terminal-native point measured in character cells.
public struct GeometryPoint: Equatable, Sendable {

    public let column: Int

    public let row: Int

    public init(column: Int = 0, row: Int = 0) {
        self.column = max(column, 0)
        self.row = max(row, 0)
    }
}

/// A terminal-native rectangle measured in character cells.
public struct GeometryFrame: Equatable, Sendable {

    public let origin: GeometryPoint

    public let size: GeometrySize

    public init(
        origin: GeometryPoint = GeometryPoint(),
        size: GeometrySize = GeometrySize()
    ) {
        self.origin = origin
        self.size = size
    }
}

/// A proxy for access to the terminal size of a geometry reader.
public struct GeometryProxy: Equatable, Sendable {

    public let size: GeometrySize

    public var columns: Int {
        size.columns
    }

    public var rows: Int {
        size.rows
    }

    public var frame: GeometryFrame {
        GeometryFrame(size: size)
    }

    public init(size: GeometrySize = GeometrySize()) {
        self.size = size
    }

    public init(columns: Int = 0, rows: Int = 0) {
        self.init(size: GeometrySize(columns: columns, rows: rows))
    }
}

/// A container view that defines its content as a function of its terminal size.
public struct GeometryReader<Content: View>: View {

    public typealias Body = Never

    public let content: (GeometryProxy) -> Content

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
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

extension GeometryReader: GeometryReaderRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let proxy = GeometryProxy(
            columns: proposal?.columns ?? 0,
            rows: proposal?.rows ?? 0
        )
        guard let block = ViewResolver.block(
            from: content(proxy),
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
