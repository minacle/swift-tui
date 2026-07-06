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

enum LayerModifierPlacement {

    case background

    case overlay
}

enum LayerModifierRenderer {

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
