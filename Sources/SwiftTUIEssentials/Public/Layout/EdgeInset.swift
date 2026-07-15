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
        case .top, .bottom:
            return ExplicitAlignmentQueryContext.withKeys([
                HorizontalAlignment.center.key,
            ]) {
                renderedBlock(
                    content: contentChild,
                    inset: insetChild,
                    edge: edge,
                    spacing: spacing,
                    proposal: proposal
                )
            }
        case .leading, .trailing:
            return ExplicitAlignmentQueryContext.withKeys([
                VerticalAlignment.center.key,
            ]) {
                renderedBlock(
                    content: contentChild,
                    inset: insetChild,
                    edge: edge,
                    spacing: spacing,
                    proposal: proposal
                )
            }
        }
    }

    /// Resolves the inset's fixed thickness before rendering the modified view
    /// once at its final major-axis size, then lets the stack compositor reuse
    /// both results. A child is rendered again only when its layout traits
    /// require filling a larger, naturally resolved minor axis.
    private static func renderedBlock(
        content: StackChild,
        inset: StackChild,
        edge: Edge,
        spacing: Int,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let insetProposal = childProposal(
            length: nil,
            traits: inset.traits,
            edge: edge,
            proposal: proposal
        )
        let insetElement = inset.render(insetProposal, false)
        let insetLength = elementLength(insetElement, edge: edge)
        let gap = isRenderable(insetElement) ? spacing : 0
        let contentLength = proposedLength(proposal, edge: edge).map {
            max($0 - insetLength - gap, 0)
        }
        let contentProposal = childProposal(
            length: isFlexible(content, edge: edge) ? contentLength : nil,
            traits: content.traits,
            edge: edge,
            proposal: proposal
        )
        let contentElement = content.render(contentProposal, false)
        guard let block = compositedBlock(
            content: frozen(content, element: contentElement),
            inset: frozen(inset, element: insetElement),
            edge: edge,
            spacing: spacing,
            proposal: proposal
        ) else {
            return nil
        }

        let minorLength: Int
        switch edge {
        case .top, .bottom:
            minorLength = block.width
        case .leading, .trailing:
            minorLength = block.height
        }
        let filledContent = filledMinorAxisElement(
            contentElement,
            child: content,
            initialProposal: contentProposal,
            minorLength: minorLength,
            edge: edge
        )
        let filledInset = filledMinorAxisElement(
            insetElement,
            child: inset,
            initialProposal: insetProposal,
            minorLength: minorLength,
            edge: edge
        )
        guard filledContent != contentElement || filledInset != insetElement else {
            return block
        }

        return compositedBlock(
            content: frozen(content, element: filledContent),
            inset: frozen(inset, element: filledInset),
            edge: edge,
            spacing: spacing,
            proposal: proposal
        ) ?? block
    }

    private static func compositedBlock(
        content: StackChild?,
        inset: StackChild?,
        edge: Edge,
        spacing: Int,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let children: [StackChild]

        switch edge {
        case .top, .leading:
            children = [inset, content].compactMap { $0 }
        case .bottom, .trailing:
            children = [content, inset].compactMap { $0 }
        }

        switch edge {
        case .top, .bottom:
            return StackRenderer.vertical(
                children,
                alignment: .center,
                spacing: spacing,
                proposal: proposal
            )
        case .leading, .trailing:
            return StackRenderer.horizontal(
                children,
                alignment: .center,
                spacing: spacing,
                proposal: proposal
            )
        }
    }

    private static func filledMinorAxisElement(
        _ element: RenderedElement?,
        child: StackChild,
        initialProposal: RenderProposal,
        minorLength: Int,
        edge: Edge
    ) -> RenderedElement? {
        guard isRenderable(element), child.traits.fillsStackMinorAxis else {
            return element
        }

        let proposal: RenderProposal
        switch edge {
        case .top, .bottom:
            guard child.traits.flexibleAxes.contains(.horizontal),
                  initialProposal.columns != minorLength else {
                return element
            }
            proposal = RenderProposal(
                columns: minorLength,
                rows: elementLength(element, edge: edge)
            )
        case .leading, .trailing:
            guard child.traits.flexibleAxes.contains(.vertical),
                  initialProposal.rows != minorLength else {
                return element
            }
            proposal = RenderProposal(
                columns: elementLength(element, edge: edge),
                rows: minorLength
            )
        }

        return child.render(proposal, false) ?? element
    }

    private static func childProposal(
        length: Int?,
        traits: LayoutTraits,
        edge: Edge,
        proposal: RenderProposal?
    ) -> RenderProposal {
        switch edge {
        case .top, .bottom:
            return RenderProposal(
                columns: traits.flexibleAxes.contains(.horizontal)
                    || !traits.flexibleAxes.contains(.vertical) ? proposal?.columns : nil,
                rows: length
            )
        case .leading, .trailing:
            return RenderProposal(
                columns: length,
                rows: traits.flexibleAxes.contains(.vertical)
                    || !traits.flexibleAxes.contains(.horizontal) ? proposal?.rows : nil
            )
        }
    }

    private static func proposedLength(
        _ proposal: RenderProposal?,
        edge: Edge
    ) -> Int? {
        switch edge {
        case .top, .bottom:
            return proposal?.rows
        case .leading, .trailing:
            return proposal?.columns
        }
    }

    private static func elementLength(
        _ element: RenderedElement?,
        edge: Edge
    ) -> Int {
        switch (edge, element) {
        case (.top, .block(let block)), (.bottom, .block(let block)):
            return block.height
        case (.leading, .block(let block)), (.trailing, .block(let block)):
            return block.width
        case (_, .spacer(let minLength)):
            return minLength
        case (_, nil):
            return 0
        }
    }

    private static func isRenderable(_ element: RenderedElement?) -> Bool {
        switch element {
        case .block(let block):
            return block.width > 0 || block.height > 0
        case .spacer:
            return true
        case nil:
            return false
        }
    }

    private static func isFlexible(_ child: StackChild, edge: Edge) -> Bool {
        switch edge {
        case .top, .bottom:
            return !child.suppressesVerticalFlexInParentStack
                && child.traits.flexibleAxes.contains(.vertical)
        case .leading, .trailing:
            return child.traits.flexibleAxes.contains(.horizontal)
        }
    }

    private static func frozen(
        _ child: StackChild,
        element: RenderedElement?
    ) -> StackChild? {
        guard let element else {
            return nil
        }

        return StackChild(
            traits: child.traits,
            isSpacer: child.isSpacer,
            isEmptyView: child.isEmptyView,
            suppressesVerticalFlexInParentStack: child.suppressesVerticalFlexInParentStack,
            render: { _, _ in element }
        )
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

extension View {

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
    public func edgeInset<Inset: View>(
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
