struct HiddenView<Content: View>: View, HiddenModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        renderHidden(in: runtime) {
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
        renderHidden(in: runtime) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    private func renderHidden(
        in runtime: StateRuntime?,
        _ render: () -> RenderedBlock?
    ) -> RenderedBlock? {
        let block = runtime?.withoutInteractiveRenderRegistrations(render) ?? render()
        return block?.hidden()
    }

    private func renderHidden(
        in runtime: StateRuntime?,
        _ render: () -> RenderedElement?
    ) -> RenderedElement? {
        let element = runtime?.withoutInteractiveRenderRegistrations(render) ?? render()
        switch element {
        case .block(let block):
            return .block(block.hidden())
        case .spacer, nil:
            return element
        }
    }
}

protocol HiddenModifierRenderable {

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

private extension RenderedBlock {

    func hidden() -> RenderedBlock {
        RenderedBlock(
            runs: [],
            width: width,
            height: height
        )
    }
}

public extension View {

    /// Hides this view while preserving its terminal-cell layout footprint.
    ///
    /// Hidden views remain in the view hierarchy and affect layout, but do not
    /// render terminal output or register interactive regions.
    ///
    /// - Returns: A hidden view.
    func hidden() -> some View {
        HiddenView(content: self)
    }
}
