public extension Edge {

    /// An efficient set of terminal rectangle edges.
    struct Set: OptionSet, ExpressibleByArrayLiteral, Sendable {

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

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

        public init(arrayLiteral elements: Edge.Set...) {
            self = elements.reduce(Edge.Set(rawValue: 0)) {
                $0.union($1)
            }
        }

        public static let top = Edge.Set(rawValue: 1 << 0)

        public static let leading = Edge.Set(rawValue: 1 << 1)

        public static let bottom = Edge.Set(rawValue: 1 << 2)

        public static let trailing = Edge.Set(rawValue: 1 << 3)

        public static let horizontal: Edge.Set = [.leading, .trailing]

        public static let vertical: Edge.Set = [.top, .bottom]

        public static let all: Edge.Set = [.horizontal, .vertical]
    }
}

/// The inset distances for the sides of a terminal rectangle.
public struct EdgeInsets: Equatable, Sendable {

    public let top: Int

    public let leading: Int

    public let bottom: Int

    public let trailing: Int

    public init() {
        self.init(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

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

/// An alignment in both terminal axes.
public struct Alignment: Equatable, Sendable {

    public let horizontal: HorizontalAlignment

    public let vertical: VerticalAlignment

    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)

    public static let top = Alignment(horizontal: .center, vertical: .top)

    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)

    public static let leading = Alignment(horizontal: .leading, vertical: .center)

    public static let center = Alignment(horizontal: .center, vertical: .center)

    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)

    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)

    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)

    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
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
        let childProposal = RenderProposal(
            columns: proposedLength(
                proposal?.columns,
                ideal: idealWidth,
                minimum: minWidth,
                maximum: maxWidth
            ),
            rows: proposedLength(
                proposal?.rows,
                ideal: idealHeight,
                minimum: minHeight,
                maximum: maxHeight
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

        return block.framed(
            width: resolvedLength(
                content: block.width,
                proposal: proposal?.columns,
                ideal: idealWidth,
                minimum: minWidth,
                maximum: maxWidth
            ),
            height: resolvedLength(
                content: block.height,
                proposal: proposal?.rows,
                ideal: idealHeight,
                minimum: minHeight,
                maximum: maxHeight
            ),
            alignment: alignment
        )
    }

    private static func maximum(_ maximum: Int?, minimum: Int?) -> Int? {
        guard let maximum else {
            return nil
        }

        return max(maximum, minimum ?? 0)
    }

    private func proposedLength(
        _ proposal: Int?,
        ideal: Int?,
        minimum: Int?,
        maximum: Int?
    ) -> Int? {
        clamp(proposal ?? ideal, minimum: minimum, maximum: maximum)
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
    func padding(_ edges: Edge.Set = .all, _ length: Int? = nil) -> some View {
        PaddingView(
            content: self,
            insets: EdgeInsets(edges: edges, length: max(length ?? 1, 0))
        )
    }

    /// Adds equal terminal-cell padding to all edges of this view.
    func padding(_ length: Int) -> some View {
        padding(.all, length)
    }

    /// Adds terminal-cell padding using explicit edge insets.
    func padding(_ insets: EdgeInsets) -> some View {
        PaddingView(content: self, insets: insets)
    }

    /// Positions this view within an invisible terminal-cell frame.
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
    func fixedSize() -> some View {
        fixedSize(horizontal: true, vertical: true)
    }

    /// Fixes this view at its ideal terminal-cell size in selected dimensions.
    func fixedSize(horizontal: Bool, vertical: Bool) -> some View {
        FixedSizeView(content: self, horizontal: horizontal, vertical: vertical)
    }
}
