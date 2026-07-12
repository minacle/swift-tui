import Terminal

/// A view that renders the first child whose ideal size fits the proposed size.
///
/// `ViewThatFits` evaluates its children in declaration order. It measures each
/// child that produces a non-`nil` rendered element at its ideal size on the
/// constrained axes, then selects the first element whose measured size fits
/// within the corresponding proposed terminal-cell dimensions. Unselected axes
/// continue to receive the parent proposal but don't participate in the fit
/// decision.
///
/// If no measured element fits, SwiftTUI selects the final non-`nil` element as
/// a fallback. A selected ``Spacer`` can materialize as no block for a zero-size
/// final proposal; in that case this view produces no output and doesn't try a
/// later alternative. Measurement of discarded candidates doesn't register
/// their focus, pointer, or scrolling regions.
///
/// ```swift
/// ViewThatFits(in: .horizontal) {
///     Text("Detailed status")
///     Text("Status")
/// }
/// ```
public nonisolated struct ViewThatFits<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let axes: Axis.Set

    let content: Content

    /// Creates a view that chooses the first child that fits along the given axes.
    ///
    /// - Parameters:
    ///   - axes: The axes used for ideal-size measurement and fit testing. The
    ///     default tests both axes. An empty set chooses the first child that
    ///     produces a non-`nil` rendered element without comparing sizes.
    ///   - content: A builder that provides alternatives from most to least
    ///     preferred.
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

extension RenderedElement {

    fileprivate func fits(in proposal: RenderProposal?, axes: Axis.Set) -> Bool {
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

    fileprivate func measuredSize(proposal: RenderProposal?) -> Size {
        switch self {
        case .block(let block):
            Size(columns: block.width, rows: block.height)
        case .spacer(let minLength):
            Size(
                columns: max(proposal?.columns ?? minLength, minLength),
                rows: max(proposal?.rows ?? minLength, minLength)
            )
        }
    }

    fileprivate func renderedBlock(proposal: RenderProposal?) -> RenderedBlock? {
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
