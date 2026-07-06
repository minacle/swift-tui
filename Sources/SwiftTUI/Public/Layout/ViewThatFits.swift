/// A view that renders the first child whose ideal size fits the proposed size.
///
/// `ViewThatFits` evaluates its children in declaration order. It measures each
/// child at its ideal size on the constrained axes, then renders the first child
/// whose measured size fits within the corresponding proposed terminal-cell
/// dimensions.
public nonisolated struct ViewThatFits<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let axes: Axis.Set

    let content: Content

    /// Creates a view that chooses the first child that fits along the given axes.
    ///
    /// - Parameters:
    ///   - axes: The axes used to test whether a child fits. Passing an empty set
    ///     chooses the first renderable child.
    ///   - content: A view builder that provides alternatives in preference order.
    public init(
        in axes: Axis.Set = [.horizontal, .vertical],
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.content = content()
    }
}

protocol ViewThatFitsRenderable {

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

extension ViewThatFits: ViewThatFitsRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: axes)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        renderedElement(in: proposal, path: path, runtime: runtime)?
            .renderedBlock(proposal: proposal)
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        let children = ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )

        guard let child = selectedChild(from: children, proposal: proposal) else {
            return nil
        }

        return child.render(proposal, false)
    }

    private func selectedChild(
        from children: [StackChild],
        proposal: RenderProposal?
    ) -> StackChild? {
        if axes.isEmpty {
            return children.first {
                $0.render(proposal, true) != nil
            }
        }

        var fallback: StackChild?
        let measurementProposal = RenderProposal(
            columns: axes.contains(.horizontal) ? nil : proposal?.columns,
            rows: axes.contains(.vertical) ? nil : proposal?.rows
        )

        for child in children {
            guard let element = child.render(measurementProposal, true) else {
                continue
            }

            fallback = child
            if element.fits(in: proposal, axes: axes) {
                return child
            }
        }

        return fallback
    }
}

private extension RenderedElement {

    func fits(in proposal: RenderProposal?, axes: Axis.Set) -> Bool {
        let size = measuredSize(proposal: proposal)

        if axes.contains(.horizontal),
           let columns = proposal?.columns,
           size.columns > columns {
            return false
        }

        if axes.contains(.vertical),
           let rows = proposal?.rows,
           size.rows > rows {
            return false
        }

        return true
    }

    func measuredSize(proposal: RenderProposal?) -> GeometrySize {
        switch self {
        case .block(let block):
            GeometrySize(columns: block.width, rows: block.height)
        case .spacer(let minLength):
            GeometrySize(
                columns: max(proposal?.columns ?? minLength, minLength),
                rows: max(proposal?.rows ?? minLength, minLength)
            )
        }
    }

    func renderedBlock(proposal: RenderProposal?) -> RenderedBlock? {
        switch self {
        case .block(let block):
            return block
        case .spacer(let minLength):
            let width = max(proposal?.columns ?? minLength, minLength)
            let height = max(proposal?.rows ?? minLength, minLength)
            guard width > 0 || height > 0 else {
                return nil
            }

            let renderedHeight = max(height, 1)
            return RenderedBlock(
                runs: [],
                width: width,
                height: renderedHeight,
                paddedRows: Set(0..<renderedHeight)
            )
        }
    }
}
