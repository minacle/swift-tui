import Terminal

struct BackgroundView<Content: View, Background: View>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let alignment: Alignment

    let background: Background

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayerModifierRenderer.renderedBlock(
            content: content,
            decoration: background,
            placement: .background,
            alignment: alignment,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

struct BackgroundStyleView<Content: View>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let style: AnyColor

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard let contentBlock = ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        return contentBlock.fillingBackground(style)
    }
}

struct OverlayView<Content: View, Overlay: View>: View,
    LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let alignment: Alignment

    let overlay: Overlay

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayerModifierRenderer.renderedBlock(
            content: content,
            decoration: overlay,
            placement: .overlay,
            alignment: alignment,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

private extension RenderedBlock {

    func fillingBackground(_ backgroundStyle: AnyColor) -> RenderedBlock {
        guard width > 0, height > 0 else {
            return self
        }

        let bounds = RenderedRect(width: width, height: height)
        let clippedRuns = runs.flatMap {
            $0.clipped(to: bounds)
        }.sorted {
            if $0.row == $1.row {
                return $0.column < $1.column
            }
            return $0.row < $1.row
        }

        var runsByRow: [Int: [RenderedRun]] = [:]
        for run in clippedRuns {
            runsByRow[run.row, default: []].append(run)
        }

        var filledRuns: [RenderedRun] = []
        for row in 0..<height {
            var column = 0
            for run in runsByRow[row] ?? [] {
                if column < run.column {
                    appendBackgroundRun(
                        row: row,
                        column: column,
                        width: run.column - column,
                        style: backgroundStyle,
                        to: &filledRuns
                    )
                }

                var styledRun = run
                if styledRun.style.backgroundStyle == nil {
                    styledRun.style.backgroundStyle = backgroundStyle
                }
                append(styledRun, to: &filledRuns)
                column = max(column, run.column + run.width)
            }

            if column < width {
                appendBackgroundRun(
                    row: row,
                    column: column,
                    width: width - column,
                    style: backgroundStyle,
                    to: &filledRuns
                )
            }
        }

        return RenderedBlock(
            runs: filledRuns,
            width: width,
            height: height,
            paddedRows: Set(0..<height),
            cursor: cursor,
            hitRegions: hitRegions,
            scrollRegions: scrollRegions,
            focusRegions: focusRegions,
            identifiedRegions: identifiedRegions,
            coordinateSpaceRegions: coordinateSpaceRegions
        )
    }

    func appendBackgroundRun(
        row: Int,
        column: Int,
        width: Int,
        style: AnyColor,
        to runs: inout [RenderedRun]
    ) {
        guard width > 0 else {
            return
        }

        append(
            RenderedRun(
                text: String(repeating: " ", count: width),
                row: row,
                column: column,
                style: TextStyle(backgroundStyle: style)
            ),
            to: &runs
        )
    }

    func append(_ run: RenderedRun, to runs: inout [RenderedRun]) {
        guard let last = runs.last,
              last.row == run.row,
              last.column + last.width == run.column,
              last.style == run.style,
              last.link == run.link else {
            runs.append(run)
            return
        }

        runs[runs.count - 1] = RenderedRun(
            text: last.text + run.text,
            row: last.row,
            column: last.column,
            style: last.style,
            link: last.link
        )
    }
}

enum LayerModifierPlacement {

    case background

    case overlay
}

enum LayerModifierRenderer {

    static func backgroundBlock(width: Int, height: Int, style: AnyColor) -> RenderedBlock {
        guard width > 0, height > 0 else {
            return RenderedBlock(lines: [])
        }

        return RenderedBlock(
            runs: (0..<height).map {
                RenderedRun(
                    text: String(repeating: " ", count: width),
                    row: $0,
                    style: TextStyle(backgroundStyle: style)
                )
            },
            width: width,
            height: height,
            paddedRows: Set(0..<height)
        )
    }

    static func renderedBlock<Content: View, Decoration: View>(
        content: Content,
        decoration: Decoration,
        placement: LayerModifierPlacement,
        alignment: Alignment,
        proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard let contentBlock = ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        let bounds = contentBlock.bounds
        let decorationBlock = ViewResolver.block(
            from: ZStack(alignment: .center) {
                decoration
            },
            in: nil,
            path: path + [1],
            runtime: runtime
        )?.aligned(
            in: bounds,
            alignment: alignment
        )

        switch placement {
        case .background:
            return RenderedBlock.composited(
                [decorationBlock, contentBlock].compactMap { $0 },
                width: contentBlock.width,
                height: contentBlock.height,
                paddedRows: contentBlock.paddedRows
            )
        case .overlay:
            return RenderedBlock.composited(
                [contentBlock, decorationBlock].compactMap { $0 },
                width: contentBlock.width,
                height: contentBlock.height,
                paddedRows: contentBlock.paddedRows
            )
        }
    }
}

public extension View {

    /// Sets the view's background to a terminal shape style.
    ///
    /// SwiftTUI fills the modified view's rendered bounds with the style.
    ///
    /// - Parameter style: A 16-color terminal SGR style.
    /// - Returns: A view with the given background style behind it.
    func background(_ style: Color16) -> some View {
        background(AnyColor(style))
    }

    /// Sets the view's background to a terminal shape style.
    ///
    /// SwiftTUI fills the modified view's rendered bounds with the style.
    ///
    /// - Parameter style: A 256-color terminal SGR style.
    /// - Returns: A view with the given background style behind it.
    func background(_ style: Color256) -> some View {
        background(AnyColor(style))
    }

    /// Sets the view's background to a terminal shape style.
    ///
    /// SwiftTUI fills the modified view's rendered bounds with the style.
    ///
    /// - Parameter style: A true-color terminal SGR style.
    /// - Returns: A view with the given background style behind it.
    func background(_ style: TrueColor) -> some View {
        background(AnyColor(style))
    }

    /// Sets the view's background to a terminal shape style.
    ///
    /// SwiftTUI fills the modified view's rendered bounds with the style.
    ///
    /// - Parameter style: The terminal default color reset style.
    /// - Returns: A view with the given background style behind it.
    func background(_ style: DefaultColor) -> some View {
        background(AnyColor(style))
    }

    /// Sets the view's background to a terminal shape style.
    ///
    /// SwiftTUI fills the modified view's rendered bounds with the style.
    ///
    /// - Parameter style: A type-erased terminal SGR color style.
    /// - Returns: A view with the given background style behind it.
    func background(_ style: AnyColor) -> some View {
        BackgroundStyleView(content: self, style: style)
    }

    /// Sets the view's background to a terminal shape style.
    ///
    /// SwiftTUI fills the modified view's rendered bounds with the style.
    ///
    /// - Parameter style: A terminal shape style.
    /// - Returns: A view with the given background style behind it.
    func background<S>(_ style: S) -> some View where S: ShapeStyle {
        BackgroundStyleView(content: self, style: style._swiftTUIAnyColor)
    }

    /// Layers view-builder content behind this view.
    ///
    /// The modified view keeps control of the rendered size. Background
    /// content is aligned within that size and clipped to the same bounds.
    ///
    /// - Parameters:
    ///   - alignment: The alignment used to place the background stack.
    ///   - content: A view builder that creates the background views.
    /// - Returns: A view with the given background content.
    func background<Background: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Background
    ) -> some View {
        BackgroundView(
            content: self,
            alignment: alignment,
            background: content()
        )
    }

    /// Layers view-builder content in front of this view.
    ///
    /// The modified view keeps control of the rendered size. Overlay content
    /// is aligned within that size and clipped to the same bounds.
    ///
    /// - Parameters:
    ///   - alignment: The alignment used to place the overlay stack.
    ///   - content: A view builder that creates the overlay views.
    /// - Returns: A view with the given overlay content.
    func overlay<Overlay: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Overlay
    ) -> some View {
        OverlayView(
            content: self,
            alignment: alignment,
            overlay: content()
        )
    }
}
