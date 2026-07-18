public import Terminal

/// The local terminal-cell geometry supplied by a ``GeometryReader``.
///
/// The proxy describes the reader's proposal, not the size eventually chosen
/// by its content. An axis that has no concrete proposal is represented as
/// zero. Its coordinate space always begins at the top-leading cell.
public nonisolated struct GeometryProxy: Equatable, Sendable {

    /// The concrete portion of the size proposed to the geometry reader.
    ///
    /// An unspecified proposal dimension appears as zero in this value.
    public let size: Size

    /// The proposed width in terminal columns, or zero when unspecified.
    public var columns: Int {
        size.columns
    }

    /// The proposed height in terminal rows, or zero when unspecified.
    public var rows: Int {
        size.rows
    }

    /// The reader's local frame, with a top-leading zero origin.
    public var frame: Rect {
        Rect(origin: .zero, size: size)
    }

    /// Creates a geometry proxy from a terminal-cell size.
    ///
    /// This public initializer is useful for testing geometry-dependent view
    /// builders. It stores the supplied size without normalization.
    ///
    /// - Parameter size: The terminal-cell size represented by the proxy. The
    ///   default is zero columns by zero rows.
    public init(size: Size = Size()) {
        self.size = size
    }

    /// Creates a geometry proxy from terminal columns and rows.
    ///
    /// Values are stored without clamping.
    ///
    /// - Parameters:
    ///   - columns: The represented width. The default is zero.
    ///   - rows: The represented height. The default is zero.
    public init(columns: Int = 0, rows: Int = 0) {
        self.init(size: Size(columns: columns, rows: rows))
    }
}

/// A container view that defines its content as a function of its terminal size.
///
/// `GeometryReader` is flexible in both axes and passes the concrete parent
/// proposal to its content closure. A missing proposal axis appears as zero in
/// the proxy while remaining unspecified when the content itself is rendered;
/// content can therefore use its natural size on that axis.
///
/// When both resolved dimensions are positive, the reader occupies each
/// specified dimension exactly, padding smaller content and clipping larger
/// content from the top-leading origin. If either resolved dimension is zero or
/// negative, the reader produces an empty zero-sized block. If the content
/// produces no rendered block, the reader also produces no block. Carets and
/// interaction regions outside a nonempty frame are clipped with the visible
/// content.
///
/// ```swift
/// GeometryReader { proxy in
///     Text("\(proxy.columns)x\(proxy.rows)")
/// }
/// .frame(width: 20, height: 4)
/// ```
public nonisolated struct GeometryReader<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// The content builder evaluated with the current local geometry.
    ///
    /// SwiftTUI may evaluate this closure during layout measurement as well as
    /// rendering. Keep the builder free of externally visible side effects.
    public let content: (GeometryProxy) -> Content

    let statePath: [Int]?

    /// Creates a geometry reader whose content depends on its proposal.
    ///
    /// - Parameter content: A view builder that receives the current terminal
    ///   geometry proxy. The closure may be evaluated more than once per update.
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
            caret: frameCaret(block.caret, width: targetWidth, height: targetHeight),
            textInputAnchor: frameTextInputAnchor(
                block.textInputAnchor,
                width: targetWidth,
                height: targetHeight
            ),
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
            ),
            coordinateSpaceRegions: frameCoordinateSpaceRegions(
                block.coordinateSpaceRegions,
                width: targetWidth,
                height: targetHeight
            ),
            explicitAlignments: block.explicitAlignments
        )
    }

    private func frameCaret(
        _ caret: RenderedCaret?,
        width: Int,
        height: Int
    ) -> RenderedCaret? {
        guard let caret,
              caret.row >= 0,
              caret.row < height,
              caret.column >= 0,
              caret.column <= width else {
            return nil
        }

        return RenderedCaret(
            row: caret.row,
            column: min(caret.column, width - 1)
        )
    }

    private func frameTextInputAnchor(
        _ anchor: RenderedTextInputAnchor?,
        width: Int,
        height: Int
    ) -> RenderedTextInputAnchor? {
        guard let anchor,
              anchor.row >= 0,
              anchor.row < height,
              anchor.column >= 0,
              anchor.column <= width else {
            return nil
        }

        return RenderedTextInputAnchor(
            focusPath: anchor.focusPath,
            generation: anchor.generation,
            isFocused: anchor.isFocused,
            hasFocusViewport: anchor.hasFocusViewport,
            row: anchor.row,
            column: min(anchor.column, width - 1)
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

    private func frameCoordinateSpaceRegions(
        _ coordinateSpaceRegions: [RenderedCoordinateSpaceRegion],
        width: Int,
        height: Int
    ) -> [RenderedCoordinateSpaceRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return coordinateSpaceRegions.compactMap {
            $0.clipped(to: bounds)
        }
    }
}
