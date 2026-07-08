public import Terminal

/// A proxy for access to the terminal size of a geometry reader.
public nonisolated struct GeometryProxy: Equatable, Sendable {

    /// The size proposed to the geometry reader.
    public let size: Size

    /// The proposed width in terminal columns.
    public var columns: Int {
        size.columns
    }

    /// The proposed height in terminal rows.
    public var rows: Int {
        size.rows
    }

    /// A frame with zero origin and this proxy's size.
    public var frame: Rect {
        Rect(origin: .zero, size: size)
    }

    /// Creates a geometry proxy from a terminal-cell size.
    public init(size: Size = Size()) {
        self.size = size
    }

    /// Creates a geometry proxy from terminal columns and rows.
    public init(columns: Int = 0, rows: Int = 0) {
        self.init(size: Size(columns: columns, rows: rows))
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
