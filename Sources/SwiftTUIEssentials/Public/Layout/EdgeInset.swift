/// A transparent modifier that places content beside an edge of a view.
struct EdgeInsetView<Content: View, Inset: View>: View, LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let edge: Edge

    let spacing: Int

    let inset: Inset

    var layoutTraits: LayoutTraits {
        EdgeInsetRenderer.layoutTraits(for: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        EdgeInsetRenderer.renderedBlock(
            content: content,
            inset: inset,
            edge: edge,
            spacing: spacing,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

enum EdgeInsetRenderer {

    static func renderedBlock<Content: View, Inset: View>(
        content: Content,
        inset: Inset,
        edge: Edge,
        spacing: Int,
        proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let contentChild = stackChild(
            from: content,
            traits: layoutTraits(for: content),
            path: path + [0],
            runtime: runtime
        )
        let insetChild = stackChild(
            from: inset,
            traits: insetTraits(for: inset, edge: edge),
            path: path + [1],
            runtime: runtime
        )

        switch edge {
        case .top:
            return StackRenderer.vertical(
                [insetChild, contentChild],
                alignment: .center,
                spacing: spacing,
                proposal: proposal
            )
        case .bottom:
            return StackRenderer.vertical(
                [contentChild, insetChild],
                alignment: .center,
                spacing: spacing,
                proposal: proposal
            )
        case .leading:
            return StackRenderer.horizontal(
                [insetChild, contentChild],
                alignment: .center,
                spacing: spacing,
                proposal: proposal
            )
        case .trailing:
            return StackRenderer.horizontal(
                [contentChild, insetChild],
                alignment: .center,
                spacing: spacing,
                proposal: proposal
            )
        }
    }

    static func layoutTraits<Content: View>(for content: Content) -> LayoutTraits {
        guard content is ViewGroup || content is any FlattenableViewContent else {
            return ViewResolver.layoutTraits(from: content)
        }

        return ViewResolver.stackLayoutTraits(
            from: content,
            propagatedAxes: [.horizontal, .vertical],
            spacerAxis: .vertical
        )
    }

    private static func insetTraits<Inset: View>(
        for inset: Inset,
        edge: Edge
    ) -> LayoutTraits {
        let axis: Axis.Set = switch edge {
        case .top, .bottom:
            .vertical
        case .leading, .trailing:
            .horizontal
        }
        return layoutTraits(for: inset).removingFlexibleAxes(axis)
    }

    private static func stackChild<Content: View>(
        from content: Content,
        traits: LayoutTraits,
        path: [Int],
        runtime: StateRuntime?
    ) -> StackChild {
        StackChild(
            traits: traits,
            isSpacer: content is Spacer,
            suppressesVerticalFlexInParentStack: content is any VerticalStackFlexSuppressing,
            render: { proposal, suppressRegistrations in
                let render = {
                    ViewResolver.element(
                        from: content,
                        in: proposal,
                        path: path,
                        runtime: runtime
                    )
                }

                if suppressRegistrations {
                    return LayoutMeasurementContext.withMeasurement {
                        runtime?.withoutRenderRegistrations(render) ?? render()
                    }
                }

                return render()
            }
        )
    }
}

public extension View {

    /// Places content beside an edge of this view and reduces the space
    /// proposed to this view by the content's size.
    ///
    /// The inset uses its natural thickness along the selected edge and is
    /// offered the available length on the perpendicular axis. For example, a
    /// top inset is measured at its natural row count and can expand across the
    /// available columns. If the builder produces no rendered view, SwiftTUI
    /// adds neither inset space nor the requested gap.
    ///
    /// The modifier preserves this view's layout flexibility and translates
    /// the rendered caret and interaction regions with their content. Apply
    /// multiple edge insets to accumulate them; later modifiers occupy the
    /// outermost available edge. For perpendicular insets, modifier order also
    /// determines which inset occupies the shared corner.
    ///
    /// - Parameters:
    ///   - edge: The single edge beside which the supplemental content appears.
    ///   - spacing: The number of blank terminal cells between the inset and
    ///     this view. Negative values are clamped to zero.
    ///   - content: A view builder that creates one supplemental inset region.
    ///     Multiple builder children are grouped into that region.
    /// - Returns: A view with the supplemental content placed beside the
    ///   selected edge.
    func edgeInset<Inset: View>(
        _ edge: Edge,
        spacing: Int = 0,
        @ViewBuilder content: () -> Inset
    ) -> some View {
        EdgeInsetView(
            content: self,
            edge: edge,
            spacing: max(spacing, 0),
            inset: content()
        )
    }
}
