public extension Edge {

    /// An efficient set of terminal rectangle edges.
    nonisolated struct Set: OptionSet, ExpressibleByArrayLiteral, Sendable {

        /// The raw option-set storage value.
        public let rawValue: Int

        /// Creates an edge set from a raw option-set value.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Creates a set containing one edge.
        public init(_ edge: Edge) {
            switch edge {
            case .top:
                self = .top
            case .leading:
                self = .leading
            case .bottom:
                self = .bottom
            case .trailing:
                self = .trailing
            }
        }

        /// Creates a set from an array literal of edge sets.
        public init(arrayLiteral elements: Edge.Set...) {
            self = elements.reduce(Edge.Set(rawValue: 0)) {
                $0.union($1)
            }
        }

        /// The top edge.
        public static let top = Edge.Set(rawValue: 1 << 0)

        /// The leading edge.
        public static let leading = Edge.Set(rawValue: 1 << 1)

        /// The bottom edge.
        public static let bottom = Edge.Set(rawValue: 1 << 2)

        /// The trailing edge.
        public static let trailing = Edge.Set(rawValue: 1 << 3)

        /// The leading and trailing edges.
        public static let horizontal: Edge.Set = [.leading, .trailing]

        /// The top and bottom edges.
        public static let vertical: Edge.Set = [.top, .bottom]

        /// All edges.
        public static let all: Edge.Set = [.horizontal, .vertical]
    }
}

/// The inset distances for the sides of a terminal rectangle.
public nonisolated struct EdgeInsets: Equatable, Sendable {

    /// The inset from the top edge in terminal rows.
    public let top: Int

    /// The inset from the leading edge in terminal columns.
    public let leading: Int

    /// The inset from the bottom edge in terminal rows.
    public let bottom: Int

    /// The inset from the trailing edge in terminal columns.
    public let trailing: Int

    /// Creates zero insets.
    public init() {
        self.init(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

    /// Creates explicit terminal-cell insets.
    ///
    /// Negative values are clamped to zero.
    ///
    /// - Parameters:
    ///   - top: The top inset in rows.
    ///   - leading: The leading inset in columns.
    ///   - bottom: The bottom inset in rows.
    ///   - trailing: The trailing inset in columns.
    public init(top: Int, leading: Int, bottom: Int, trailing: Int) {
        self.top = max(top, 0)
        self.leading = max(leading, 0)
        self.bottom = max(bottom, 0)
        self.trailing = max(trailing, 0)
    }

    init(edges: Edge.Set, length: Int) {
        self.init(
            top: edges.contains(.top) ? length : 0,
            leading: edges.contains(.leading) ? length : 0,
            bottom: edges.contains(.bottom) ? length : 0,
            trailing: edges.contains(.trailing) ? length : 0
        )
    }

    var horizontal: Int {
        leading + trailing
    }

    var vertical: Int {
        top + bottom
    }
}

/// A transparent modifier that proposes a fixed terminal size to its content.
struct FrameView<Content: View>: View, LayoutModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let width: Int?

    let height: Int?

    let alignment: Alignment

    var layoutTraits: LayoutTraits {
        var traits = ViewResolver.layoutTraits(from: content)
        if width != nil {
            traits = traits.removingFlexibleAxes(.horizontal)
        }
        if height != nil {
            traits = traits.removingFlexibleAxes(.vertical)
        }
        return traits
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard let block = ViewResolver.block(
            from: content,
            in: RenderProposal(
                columns: width ?? proposal?.columns,
                rows: height ?? proposal?.rows
            ),
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        return block.framed(
            width: width ?? proposal?.columns ?? block.width,
            height: height ?? proposal?.rows ?? block.height,
            alignment: alignment
        )
    }
}

/// A transparent modifier that constrains the terminal size proposed to its content.
struct ConstrainedFrameView<Content: View>: View, LayoutModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let minWidth: Int?

    let idealWidth: Int?

    let maxWidth: Int?

    let minHeight: Int?

    let idealHeight: Int?

    let maxHeight: Int?

    let alignment: Alignment

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
            .settingMaximumSize(columns: maxWidth, rows: maxHeight)
    }

    init(
        content: Content,
        minWidth: Int?,
        idealWidth: Int?,
        maxWidth: Int?,
        minHeight: Int?,
        idealHeight: Int?,
        maxHeight: Int?,
        alignment: Alignment
    ) {
        self.content = content
        self.minWidth = minWidth.map { max($0, 0) }
        self.idealWidth = idealWidth.map { max($0, 0) }
        self.maxWidth = Self.maximum(maxWidth, minimum: self.minWidth)
        self.minHeight = minHeight.map { max($0, 0) }
        self.idealHeight = idealHeight.map { max($0, 0) }
        self.maxHeight = Self.maximum(maxHeight, minimum: self.minHeight)
        self.alignment = alignment
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let traits = layoutTraits
        let usesFlexibleMaximumWidth = usesFlexibleMaximum(
            proposal?.columns,
            ideal: idealWidth,
            maximum: maxWidth,
            isFlexible: traits.flexibleAxes.contains(.horizontal)
        )
        let usesFlexibleMaximumHeight = usesFlexibleMaximum(
            proposal?.rows,
            ideal: idealHeight,
            maximum: maxHeight,
            isFlexible: traits.flexibleAxes.contains(.vertical)
        )
        let childProposal = RenderProposal(
            columns: proposedLength(
                proposal?.columns,
                ideal: idealWidth,
                minimum: minWidth,
                maximum: maxWidth,
                isFlexible: traits.flexibleAxes.contains(.horizontal)
            ),
            rows: proposedLength(
                proposal?.rows,
                ideal: idealHeight,
                minimum: minHeight,
                maximum: maxHeight,
                isFlexible: traits.flexibleAxes.contains(.vertical)
            )
        )
        guard let block = ViewResolver.block(
            from: content,
            in: childProposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        let naturalBlock = naturalBlock(
            if: usesFlexibleMaximumWidth || usesFlexibleMaximumHeight,
            proposal: RenderProposal(
                columns: usesFlexibleMaximumWidth
                    ? naturalProposedLength(
                        proposal?.columns,
                        ideal: idealWidth,
                        minimum: minWidth,
                        maximum: maxWidth
                    )
                    : childProposal.columns,
                rows: usesFlexibleMaximumHeight
                    ? naturalProposedLength(
                        proposal?.rows,
                        ideal: idealHeight,
                        minimum: minHeight,
                        maximum: maxHeight
                    )
                    : childProposal.rows
            ),
            path: path,
            runtime: runtime
        )

        let resolvedWidth = resolvedLength(
                content: contentLength(
                    constrained: block.width,
                    natural: naturalBlock?.width,
                    usesFlexibleMaximum: usesFlexibleMaximumWidth
                ),
                proposal: proposal?.columns,
                ideal: idealWidth,
                minimum: minWidth,
                maximum: maxWidth
            )
        let resolvedHeight = resolvedLength(
                content: contentLength(
                    constrained: block.height,
                    natural: naturalBlock?.height,
                    usesFlexibleMaximum: usesFlexibleMaximumHeight
                ),
                proposal: proposal?.rows,
                ideal: idealHeight,
                minimum: minHeight,
                maximum: maxHeight
            )
        let finalBlock: RenderedBlock
        if usesFlexibleMaximumWidth || usesFlexibleMaximumHeight {
            finalBlock = ViewResolver.block(
                from: content,
                in: RenderProposal(
                    columns: usesFlexibleMaximumWidth ? resolvedWidth : childProposal.columns,
                    rows: usesFlexibleMaximumHeight ? resolvedHeight : childProposal.rows
                ),
                path: path,
                runtime: runtime
            ) ?? block
        }
        else {
            finalBlock = block
        }

        return finalBlock.framed(
            width: resolvedWidth,
            height: resolvedHeight,
            alignment: alignment
        )
    }

    private static func maximum(_ maximum: Int?, minimum: Int?) -> Int? {
        guard let maximum else {
            return nil
        }

        return max(maximum, minimum ?? 0)
    }

    private func usesFlexibleMaximum(
        _ proposal: Int?,
        ideal: Int?,
        maximum: Int?,
        isFlexible: Bool
    ) -> Bool {
        proposal == nil && ideal == nil && maximum != nil && isFlexible
    }

    private func proposedLength(
        _ proposal: Int?,
        ideal: Int?,
        minimum: Int?,
        maximum: Int?,
        isFlexible: Bool
    ) -> Int? {
        clamp(proposal ?? ideal ?? (isFlexible ? maximum : nil), minimum: minimum, maximum: maximum)
    }

    private func naturalProposedLength(
        _ proposal: Int?,
        ideal: Int?,
        minimum: Int?,
        maximum: Int?
    ) -> Int? {
        clamp(proposal ?? ideal, minimum: minimum, maximum: maximum)
    }

    private func contentLength(
        constrained: Int,
        natural: Int?,
        usesFlexibleMaximum: Bool
    ) -> Int {
        usesFlexibleMaximum ? natural ?? constrained : constrained
    }

    private func naturalBlock(
        if shouldMeasure: Bool,
        proposal: RenderProposal,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard shouldMeasure else {
            return nil
        }

        let render = {
            ViewResolver.block(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        return LayoutMeasurementContext.withMeasurement {
            runtime?.withoutRenderRegistrations(render) ?? render()
        }
    }

    private func resolvedLength(
        content: Int,
        proposal: Int?,
        ideal: Int?,
        minimum: Int?,
        maximum: Int?
    ) -> Int {
        let length: Int
        if let proposal, minimum != nil, maximum != nil {
            length = proposal
        }
        else if let proposal, minimum != nil, proposal < content {
            length = proposal
        }
        else if let proposal, maximum != nil, proposal > content {
            length = proposal
        }
        else {
            length = content
        }

        return clamp(length, minimum: minimum, maximum: maximum) ?? 0
    }

    private func clamp(_ length: Int?, minimum: Int?, maximum: Int?) -> Int? {
        guard var length else {
            return nil
        }

        if let minimum {
            length = max(length, minimum)
        }
        if let maximum {
            length = min(length, maximum)
        }

        return length
    }
}

/// A transparent modifier that removes selected proposed dimensions from its content.
struct FixedSizeView<Content: View>: View, LayoutModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let horizontal: Bool

    let vertical: Bool

    var layoutTraits: LayoutTraits {
        var traits = ViewResolver.layoutTraits(from: content)
        if horizontal {
            traits = traits.removingFlexibleAxes(.horizontal)
        }
        if vertical {
            traits = traits.removingFlexibleAxes(.vertical)
        }
        return traits
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ViewResolver.block(
            from: content,
            in: RenderProposal(
                columns: horizontal ? nil : proposal?.columns,
                rows: vertical ? nil : proposal?.rows
            ),
            path: path,
            runtime: runtime
        )
    }
}

/// A transparent modifier that adds terminal-cell padding around its content.
struct PaddingView<Content: View>: View, LayoutModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let insets: EdgeInsets

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard let block = ViewResolver.block(
            from: content,
            in: RenderProposal(
                columns: proposal?.columns.map {
                    max($0 - insets.horizontal, 0)
                },
                rows: proposal?.rows.map {
                    max($0 - insets.vertical, 0)
                }
            ),
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        return block.padded(by: insets)
    }

    private func paddedChild(_ child: StackChild) -> StackChild {
        var paddedChild = child
        paddedChild.render = { proposal, suppressRegistrations in
            let proposal = RenderProposal(
                columns: proposal?.columns.map {
                    max($0 - insets.horizontal, 0)
                },
                rows: proposal?.rows.map {
                    max($0 - insets.vertical, 0)
                }
            )
            guard let element = child.render(proposal, suppressRegistrations) else {
                return nil
            }
            switch element {
            case .block(let block):
                return .block(block.padded(by: insets))
            case .spacer:
                return element
            }
        }
        return paddedChild
    }
}

extension PaddingView: FlattenableViewContent where Content: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        stackChildren(
            in: proposal,
            path: path,
            runtime: runtime
        ).compactMap { $0.render(proposal, false) }
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        content.stackChildren(
            in: proposal,
            path: path,
            runtime: runtime
        ).map(paddedChild)
    }
}

extension PaddingView: GridContentRenderable where Content: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        content.gridItems(in: proposal, path: path, runtime: runtime).map {
            $0.mappingCells(paddedChild)
        }
    }
}

protocol LayoutModifierRenderable {

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

extension LayoutModifierRenderable {

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
    }
}

public extension View {

    /// Adds padding to specific terminal-cell edges of this view.
    ///
    /// - Parameters:
    ///   - edges: The edges that receive padding.
    ///   - length: The number of terminal cells to add. `nil` uses one cell.
    /// - Returns: A view padded on the selected edges.
    func padding(_ edges: Edge.Set = .all, _ length: Int? = nil) -> some View {
        PaddingView(
            content: self,
            insets: EdgeInsets(edges: edges, length: max(length ?? 1, 0))
        )
    }

    /// Adds equal terminal-cell padding to all edges of this view.
    ///
    /// - Parameter length: The number of terminal cells to add on every edge.
    /// - Returns: A view padded on all edges.
    func padding(_ length: Int) -> some View {
        padding(.all, length)
    }

    /// Adds terminal-cell padding using explicit edge insets.
    ///
    /// - Parameter insets: The explicit insets to add around the view.
    /// - Returns: A view padded by the given insets.
    func padding(_ insets: EdgeInsets) -> some View {
        PaddingView(content: self, insets: insets)
    }

    /// Positions this view within an invisible terminal-cell frame.
    ///
    /// - Parameters:
    ///   - width: The fixed frame width in terminal columns.
    ///   - height: The fixed frame height in terminal rows.
    ///   - alignment: The alignment used when the child is smaller than the frame.
    /// - Returns: A view rendered within the requested frame.
    func frame(
        width: Int? = nil,
        height: Int? = nil,
        alignment: Alignment = .center
    ) -> some View {
        FrameView(
            content: self,
            width: width.map { max($0, 0) },
            height: height.map { max($0, 0) },
            alignment: alignment
        )
    }

    /// Positions this view within an invisible constrained terminal-cell frame.
    ///
    /// - Parameters:
    ///   - minWidth: The minimum frame width in terminal columns.
    ///   - idealWidth: The proposed ideal width in terminal columns.
    ///   - maxWidth: The maximum frame width in terminal columns.
    ///   - minHeight: The minimum frame height in terminal rows.
    ///   - idealHeight: The proposed ideal height in terminal rows.
    ///   - maxHeight: The maximum frame height in terminal rows.
    ///   - alignment: The alignment used when the child is smaller than the frame.
    /// - Returns: A view rendered within the resolved constrained frame.
    func frame(
        minWidth: Int? = nil,
        idealWidth: Int? = nil,
        maxWidth: Int? = nil,
        minHeight: Int? = nil,
        idealHeight: Int? = nil,
        maxHeight: Int? = nil,
        alignment: Alignment = .center
    ) -> some View {
        ConstrainedFrameView(
            content: self,
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: alignment
        )
    }

    /// Fixes this view at its ideal terminal-cell size.
    ///
    /// - Returns: A view that ignores proposed width and height while measuring.
    func fixedSize() -> some View {
        fixedSize(horizontal: true, vertical: true)
    }

    /// Fixes this view at its ideal terminal-cell size in selected dimensions.
    ///
    /// - Parameters:
    ///   - horizontal: Whether to ignore proposed width.
    ///   - vertical: Whether to ignore proposed height.
    /// - Returns: A view that ignores selected proposed dimensions while measuring.
    func fixedSize(horizontal: Bool, vertical: Bool) -> some View {
        FixedSizeView(content: self, horizontal: horizontal, vertical: vertical)
    }
}
