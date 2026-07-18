/// A stack container that can render its children from a size proposal.
protocol StackRenderable {

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock?

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

protocol VerticalStackFlexSuppressing {}

extension StackRenderable {

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock? {
        renderedBlock(in: proposal, path: [], runtime: nil)
    }
}

extension HStack: LayoutTraitRenderable, StackRenderable, VerticalStackFlexSuppressing {

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(.horizontal) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: .horizontal
            )
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutContainer(
            layout: HStackLayout(alignment: alignment, spacing: spacing),
            content: content
        ).renderedBlock(in: proposal, path: path, runtime: runtime)
    }
}

extension VStack: LayoutTraitRenderable, StackRenderable {

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(.vertical) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: .vertical
            )
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutContainer(
            layout: VStackLayout(alignment: alignment, spacing: spacing),
            content: content
        ).renderedBlock(in: proposal, path: path, runtime: runtime)
    }
}

extension ZStack: LayoutTraitRenderable, StackRenderable {

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(nil) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: nil
            )
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutContainer(
            layout: ZStackLayout(alignment: alignment),
            content: content
        ).renderedBlock(in: proposal, path: path, runtime: runtime)
    }
}


/// Measures, aligns, orders, and composites overlapping stack children.
enum ZStackRenderer {

    static func block(
        _ children: [StackChild],
        alignment: Alignment,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        ExplicitAlignmentQueryContext.withKeys([
            alignment.horizontal.key,
            alignment.vertical.key,
        ]) {
            unqueriedBlock(children, alignment: alignment, proposal: proposal)
        }
    }

    private static func unqueriedBlock(
        _ children: [StackChild],
        alignment: Alignment,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let measuredChildren = children.enumerated().compactMap { index, child -> MeasuredChild? in
            guard let element = child.render(proposal, true),
                  let block = renderedBlock(from: element, proposal: proposal),
                  block.width > 0 || block.height > 0 else {
                return nil
            }

            return MeasuredChild(index: index, child: child, block: block)
        }
        guard !measuredChildren.isEmpty else {
            return nil
        }

        let measuredBlocks = measuredChildren.map(\.block)
        let horizontalLine = naturalHorizontalLine(
            for: measuredBlocks,
            alignment: alignment.horizontal
        )
        let verticalLine = naturalVerticalLine(
            for: measuredBlocks,
            alignment: alignment.vertical
        )
        let width = proposal?.columns ?? naturalWidth(
            for: measuredBlocks,
            alignment: alignment.horizontal,
            line: horizontalLine
        )
        let height = proposal?.rows ?? naturalHeight(
            for: measuredBlocks,
            alignment: alignment.vertical,
            line: verticalLine
        )
        let bounds = RenderedRect(width: width, height: height)
        let blocks = measuredChildren
            .sorted {
                if $0.child.traits.zIndex == $1.child.traits.zIndex {
                    return $0.index < $1.index
                }

                return $0.child.traits.zIndex < $1.child.traits.zIndex
            }
            .compactMap { measuredChild -> RenderedBlock? in
                guard let element = measuredChild.child.render(proposal, false),
                      let block = renderedBlock(from: element, proposal: proposal) else {
                    return nil
                }

                let x = proposal?.columns == nil
                    ? horizontalLine.map { $0 - block.viewDimensions[alignment.horizontal] }
                    : nil
                let y = proposal?.rows == nil
                    ? verticalLine.map { $0 - block.viewDimensions[alignment.vertical] }
                    : nil
                return block.offsetBy(
                    x: x ?? horizontalOffset(
                        for: block,
                        containerWidth: width,
                        alignment: alignment.horizontal
                    ),
                    y: y ?? verticalOffset(
                        for: block,
                        containerHeight: height,
                        alignment: alignment.vertical
                    ),
                    clippedTo: bounds
                )
            }

        return RenderedBlock.composited(
            blocks,
            width: width,
            height: height,
            paddedRows: proposedPaddedRows(proposal: proposal, height: height)
        )
    }

    private struct MeasuredChild {

        var index: Int

        var child: StackChild

        var block: RenderedBlock
    }

    private static func renderedBlock(
        from element: RenderedElement,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        switch element {
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

    private static func proposedPaddedRows(
        proposal: RenderProposal?,
        height: Int
    ) -> Set<Int> {
        proposal?.rows == nil ? [] : Set(0..<height)
    }

    private static func naturalHorizontalLine(
        for blocks: [RenderedBlock],
        alignment: HorizontalAlignment
    ) -> Int? {
        let usesGuides = alignment != .leading
            && alignment != .center
            && alignment != .trailing
            || blocks.contains { $0.viewDimensions[explicit: alignment] != nil }
        guard usesGuides else {
            return nil
        }
        return blocks.map { $0.viewDimensions[alignment] }.max()
    }

    private static func naturalVerticalLine(
        for blocks: [RenderedBlock],
        alignment: VerticalAlignment
    ) -> Int? {
        let usesGuides = alignment != .top
            && alignment != .center
            && alignment != .bottom
            || blocks.contains { $0.viewDimensions[explicit: alignment] != nil }
        guard usesGuides else {
            return nil
        }
        return blocks.map { $0.viewDimensions[alignment] }.max()
    }

    private static func naturalWidth(
        for blocks: [RenderedBlock],
        alignment: HorizontalAlignment,
        line: Int?
    ) -> Int {
        guard let line else {
            return blocks.map(\.width).max() ?? 0
        }
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.width
        }.max() ?? 0
    }

    private static func naturalHeight(
        for blocks: [RenderedBlock],
        alignment: VerticalAlignment,
        line: Int?
    ) -> Int {
        guard let line else {
            return blocks.map(\.height).max() ?? 0
        }
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.height
        }.max() ?? 0
    }

    private static func horizontalOffset(
        for block: RenderedBlock,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = containerWidth - block.width
        if alignment == .leading, block.viewDimensions[explicit: alignment] == nil {
            return 0
        }
        if alignment == .center, block.viewDimensions[explicit: alignment] == nil {
            return padding / 2
        }
        if alignment == .trailing, block.viewDimensions[explicit: alignment] == nil {
            return padding
        }
        let container = ViewDimensions(columns: containerWidth, rows: block.height)
        return container[alignment] - block.viewDimensions[alignment]
    }

    private static func verticalOffset(
        for block: RenderedBlock,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = containerHeight - block.height
        if alignment == .top, block.viewDimensions[explicit: alignment] == nil {
            return 0
        }
        if alignment == .center, block.viewDimensions[explicit: alignment] == nil {
            return padding / 2
        }
        if alignment == .bottom, block.viewDimensions[explicit: alignment] == nil {
            return padding
        }
        let container = ViewDimensions(columns: block.width, rows: containerHeight)
        return container[alignment] - block.viewDimensions[alignment]
    }
}

/// Measures and places children along a horizontal or vertical stack axis.
enum StackRenderer {

    static func horizontal(
        _ children: [StackChild],
        alignment: VerticalAlignment,
        spacing: Int?,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        ExplicitAlignmentQueryContext.withKeys([alignment.key]) {
            unqueriedHorizontal(
                children,
                alignment: alignment,
                spacing: spacing,
                proposal: proposal
            )
        }
    }

    private static func unqueriedHorizontal(
        _ children: [StackChild],
        alignment: VerticalAlignment,
        spacing: Int?,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let layout = horizontalLayout(from: children, spacing: spacing, proposal: proposal)
        guard !layout.items.isEmpty else {
            return nil
        }

        let height = horizontalHeight(for: layout.items, alignment: alignment)
        let items = layout.items.map {
            $0.fillingMinorAxis(height)
        }
        let width = layout.width
        let bounds = RenderedRect(width: width, height: height)
        let runs = items.flatMap { item -> [RenderedRun] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.runs.flatMap {
                $0.offsetBy(x: item.x, y: y)
                    .clipped(to: bounds)
            }
        }
        var paddedRows = Set<Int>()
        for item in items {
            switch item.content {
            case .block(let block):
                let y = verticalOffset(
                    for: block,
                    in: items,
                    containerHeight: height,
                    alignment: alignment
                )
                paddedRows.formUnion(block.paddedRows.map { $0 + y })
            case .spacer:
                paddedRows.formUnion(0..<height)
            }
        }

        return RenderedBlock(
            runs: runs,
            width: width,
            height: height,
            paddedRows: paddedRows,
            caret: horizontalCaret(from: items, height: height, alignment: alignment),
            hitRegions: horizontalHitRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            scrollRegions: horizontalScrollRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            focusRegions: horizontalFocusRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            identifiedRegions: horizontalIdentifiedRegions(
                from: items,
                height: height,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            coordinateSpaceRegions: horizontalCoordinateSpaceRegions(
                from: items,
                height: height,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            explicitAlignments: horizontalExplicitAlignments(
                from: items,
                height: height,
                alignment: alignment
            ),
            spacing: horizontalSpacing(from: items)
        )
    }

    static func vertical(
        _ children: [StackChild],
        alignment: HorizontalAlignment,
        spacing: Int?,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        ExplicitAlignmentQueryContext.withKeys([alignment.key]) {
            unqueriedVertical(
                children,
                alignment: alignment,
                spacing: spacing,
                proposal: proposal
            )
        }
    }

    private static func unqueriedVertical(
        _ children: [StackChild],
        alignment: HorizontalAlignment,
        spacing: Int?,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let layout = verticalLayout(from: children, spacing: spacing, proposal: proposal)
        guard !layout.items.isEmpty else {
            return nil
        }

        let width = verticalWidth(for: layout.items, alignment: alignment)
        let items = layout.items.map {
            $0.fillingMinorAxis(width)
        }
        let height = layout.height
        let bounds = RenderedRect(width: width, height: height)
        let runs = items.flatMap { item -> [RenderedRun] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.runs.flatMap {
                $0.offsetBy(x: x, y: item.y)
                    .clipped(to: bounds)
            }
        }
        var paddedRows = Set<Int>()
        for item in items {
            switch item.content {
            case .block(let block):
                paddedRows.formUnion(block.paddedRows.map { $0 + item.y })
            case .spacer:
                paddedRows.formUnion(item.y..<(item.y + item.height))
            }
        }

        return RenderedBlock(
            runs: runs,
            width: width,
            height: height,
            paddedRows: paddedRows,
            caret: verticalCaret(from: items, width: width, alignment: alignment),
            hitRegions: verticalHitRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            scrollRegions: verticalScrollRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            focusRegions: verticalFocusRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            identifiedRegions: verticalIdentifiedRegions(
                from: items,
                width: width,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            coordinateSpaceRegions: verticalCoordinateSpaceRegions(
                from: items,
                width: width,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            explicitAlignments: verticalExplicitAlignments(
                from: items,
                width: width,
                alignment: alignment
            ),
            spacing: verticalSpacing(from: items)
        )
    }

    private static func horizontalHeight(
        for items: [HorizontalItem],
        alignment: VerticalAlignment
    ) -> Int {
        let blocks = items.compactMap(\.block)
        guard !blocks.isEmpty else {
            return 1
        }
        let hasExplicitValue = blocks.contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .top && alignment != .center && alignment != .bottom) else {
            return blocks.map(\.height).max() ?? 1
        }
        let line = blocks.map { $0.viewDimensions[alignment] }.max() ?? 0
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.height
        }.max() ?? 1
    }

    private static func verticalWidth(
        for items: [VerticalItem],
        alignment: HorizontalAlignment
    ) -> Int {
        let blocks = items.compactMap(\.block)
        guard !blocks.isEmpty else {
            return 0
        }
        let hasExplicitValue = blocks.contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .leading && alignment != .center && alignment != .trailing) else {
            return blocks.map(\.width).max() ?? 0
        }
        let line = blocks.map { $0.viewDimensions[alignment] }.max() ?? 0
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.width
        }.max() ?? 0
    }

    private static func horizontalExplicitAlignments(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [AlignmentKey: Int] {
        let blocks = items.compactMap { item -> RenderedBlock? in
            guard var block = item.block else {
                return nil
            }
            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            block.explicitAlignments = block.offsetExplicitAlignments(x: item.x, y: y)
            return block
        }
        return RenderedBlock.combinedExplicitAlignments(from: blocks)
    }

    private static func verticalExplicitAlignments(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [AlignmentKey: Int] {
        let blocks = items.compactMap { item -> RenderedBlock? in
            guard var block = item.block else {
                return nil
            }
            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            block.explicitAlignments = block.offsetExplicitAlignments(x: x, y: item.y)
            return block
        }
        return RenderedBlock.combinedExplicitAlignments(from: blocks)
    }

    private struct HorizontalLayout {

        var items: [HorizontalItem]

        var width: Int
    }

    private struct VerticalLayout {

        var items: [VerticalItem]

        var height: Int
    }

    private struct HorizontalItem {

        var content: RenderedElement

        var x: Int

        var width: Int

        var traits: LayoutTraits

        var render: (RenderProposal?, Bool) -> RenderedElement?

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }

        func fillingMinorAxis(_ height: Int) -> HorizontalItem {
            guard traits.fillsStackMinorAxis,
                  traits.flexibleAxes.contains(.vertical),
                  let content = render(
                      RenderProposal(columns: width, rows: height),
                      false
                  ) else {
                return self
            }

            var item = self
            item.content = content
            return item
        }
    }

    private struct VerticalItem {

        var content: RenderedElement

        var y: Int

        var height: Int

        var traits: LayoutTraits

        var render: (RenderProposal?, Bool) -> RenderedElement?

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }

        func fillingMinorAxis(_ width: Int) -> VerticalItem {
            guard traits.fillsStackMinorAxis,
                  traits.flexibleAxes.contains(.horizontal),
                  let content = render(
                      RenderProposal(columns: width, rows: height),
                      false
                  ) else {
                return self
            }

            var item = self
            item.content = content
            return item
        }
    }

    struct MeasuredChild {

        var content: RenderedElement

        var traits: LayoutTraits

        var suppressesVerticalFlexInParentStack: Bool

        var render: (RenderProposal?, Bool) -> RenderedElement?
    }

    private static func horizontalLayout(
        from children: [StackChild],
        spacing: Int?,
        proposal: RenderProposal?
    ) -> HorizontalLayout {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .horizontal,
            childProposal: horizontalChildProposal
        )
        let gaps = spacingGaps(between: children, spacing: spacing, axis: .horizontal)
        let usesContentFlex = children.contains { $0.isHorizontallyContentFlexible }
        let flexibleCount = children.filter {
            $0.isHorizontallyFlexible(usingContentFlex: usesContentFlex)
        }.count
        let spacingWidth = gaps.reduce(0, +)
        let minimums = children.compactMap {
            $0.horizontalMinimum(usingContentFlex: usesContentFlex)
        }
        let idealWidth = children.reduce(0) { width, child in
            width + child.content.horizontalLength
        } + spacingWidth
        let targetWidth: Int
        let fixedWidth = fixedHorizontalWidth(
            from: children,
            usingContentFlex: usesContentFlex
        )
        if flexibleCount > 0, let columns = proposal?.columns {
            targetWidth = max(columns, minimums.reduce(0, +) + spacingWidth)
        }
        else {
            targetWidth = idealWidth
        }

        let flexibleLengths = flexibleLengths(
            count: flexibleCount,
            minimums: minimums,
            extra: max(
                targetWidth - minimums.reduce(0, +) - fixedWidth - spacingWidth,
                0
            )
        )
        var flexibleIndex = 0
        var x = 0
        let items: [HorizontalItem] = children.enumerated().compactMap {
            index, child -> HorizontalItem? in
            let element: RenderedElement
            let itemWidth: Int
            switch child.content {
            case .block(let block):
                if child.isHorizontallyFlexible(usingContentFlex: usesContentFlex) {
                    let width = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                    element = child.render(
                        horizontalChildProposal(
                            width,
                            traits: child.traits,
                            stackProposal: proposal
                        ),
                        false
                    ) ?? .block(block)
                }
                else {
                    element = child.content
                }
                itemWidth = element.horizontalLength
            case .spacer:
                if child.isHorizontallyFlexible(usingContentFlex: usesContentFlex) {
                    itemWidth = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                }
                else {
                    itemWidth = child.content.horizontalLength
                }
                element = child.content
            }

            guard element.isRenderable else {
                return nil
            }

            let item = HorizontalItem(
                content: element,
                x: x,
                width: itemWidth,
                traits: child.traits,
                render: child.render
            )
            x += item.width + (gaps.indices.contains(index) ? gaps[index] : 0)
            return item
        }

        return HorizontalLayout(
            items: items,
            width: flexibleCount > 0 && proposal?.columns != nil
                ? targetWidth
                : items.map { $0.x + $0.width }.max() ?? 0
        )
    }

    private static func verticalLayout(
        from children: [StackChild],
        spacing: Int?,
        proposal: RenderProposal?
    ) -> VerticalLayout {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .vertical,
            childProposal: verticalChildProposal
        )
        let gaps = spacingGaps(between: children, spacing: spacing, axis: .vertical)
        let usesContentFlex = children.contains { $0.isVerticallyContentFlexible }
        let flexibleCount = children.filter {
            $0.isVerticallyFlexible(usingContentFlex: usesContentFlex)
        }.count
        let spacingHeight = gaps.reduce(0, +)
        let minimums = children.compactMap {
            $0.verticalMinimum(usingContentFlex: usesContentFlex)
        }
        let idealHeight = children.reduce(0) { height, child in
            height + child.content.verticalLength
        } + spacingHeight
        let targetHeight: Int
        let fixedHeight = fixedVerticalHeight(
            from: children,
            usingContentFlex: usesContentFlex
        )
        if flexibleCount > 0, let rows = proposal?.rows {
            targetHeight = max(rows, minimums.reduce(0, +) + spacingHeight)
        }
        else {
            targetHeight = idealHeight
        }

        let flexibleLengths = flexibleLengths(
            count: flexibleCount,
            minimums: minimums,
            extra: max(
                targetHeight - minimums.reduce(0, +) - fixedHeight - spacingHeight,
                0
            )
        )
        var flexibleIndex = 0
        var y = 0
        let items: [VerticalItem] = children.enumerated().compactMap {
            index, child -> VerticalItem? in
            let element: RenderedElement
            let itemHeight: Int
            switch child.content {
            case .block(let block):
                if child.isVerticallyFlexible(usingContentFlex: usesContentFlex) {
                    let height = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                    element = child.render(
                        verticalChildProposal(
                            height,
                            traits: child.traits,
                            stackProposal: proposal
                        ),
                        false
                    ) ?? .block(block)
                }
                else {
                    element = child.content
                }
                itemHeight = element.verticalLength
            case .spacer:
                if child.isVerticallyFlexible(usingContentFlex: usesContentFlex) {
                    itemHeight = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                }
                else {
                    itemHeight = child.content.verticalLength
                }
                element = child.content
            }

            guard element.isRenderable else {
                return nil
            }

            let item = VerticalItem(
                content: element,
                y: y,
                height: itemHeight,
                traits: child.traits,
                render: child.render
            )
            y += item.height + (gaps.indices.contains(index) ? gaps[index] : 0)
            return item
        }

        return VerticalLayout(
            items: items,
            height: flexibleCount > 0 && proposal?.rows != nil
                ? targetHeight
                : items.map { $0.y + $0.height }.max() ?? 0
        )
    }

    private static func measuredChildren(
        from children: [StackChild],
        proposal: RenderProposal?,
        stackAxis: Axis,
        childProposal: (Int?, LayoutTraits, RenderProposal?) -> RenderProposal
    ) -> [MeasuredChild] {
        children.compactMap { child in
            let flexibleOnStackAxis: Bool
            switch stackAxis {
            case .horizontal:
                flexibleOnStackAxis = child.traits.flexibleAxes.contains(.horizontal)
            case .vertical:
                flexibleOnStackAxis = !child.suppressesVerticalFlexInParentStack
                    && child.traits.flexibleAxes.contains(.vertical)
            }

            let axisSet: Axis.Set = stackAxis == .horizontal ? .horizontal : .vertical
            let finiteMeasurementLength: Int?
            if flexibleOnStackAxis,
               child.traits.preferredFiniteMeasurementAxes.contains(axisSet) {
                finiteMeasurementLength = stackAxis == .horizontal
                    ? proposal?.columns
                    : proposal?.rows
            }
            else {
                finiteMeasurementLength = nil
            }

            guard let content = child.render(
                childProposal(finiteMeasurementLength, child.traits, proposal),
                flexibleOnStackAxis
            ), content.isRenderable || flexibleOnStackAxis else {
                return nil
            }

            return MeasuredChild(
                content: content,
                traits: child.traits,
                suppressesVerticalFlexInParentStack: child.suppressesVerticalFlexInParentStack,
                render: child.render
            )
        }
    }

    private static func horizontalChildProposal(
        _ width: Int?,
        traits: LayoutTraits,
        stackProposal: RenderProposal?
    ) -> RenderProposal {
        RenderProposal(
            columns: width,
            rows: traits.flexibleAxes.contains(.vertical)
                || !traits.flexibleAxes.contains(.horizontal) ? stackProposal?.rows : nil
        )
    }

    private static func verticalChildProposal(
        _ height: Int?,
        traits: LayoutTraits,
        stackProposal: RenderProposal?
    ) -> RenderProposal {
        RenderProposal(
            columns: traits.flexibleAxes.contains(.horizontal)
                || !traits.flexibleAxes.contains(.vertical) ? stackProposal?.columns : nil,
            rows: height
        )
    }

    private static func fixedHorizontalWidth(
        from children: [MeasuredChild],
        usingContentFlex: Bool
    ) -> Int {
        children.reduce(0) { width, child in
            switch child.content {
            case .block:
                if child.isHorizontallyFlexible(usingContentFlex: usingContentFlex) {
                    return width
                }
                return width + child.content.horizontalLength
            case .spacer:
                if child.isHorizontallyFlexible(usingContentFlex: usingContentFlex) {
                    return width
                }
                return width + child.content.horizontalLength
            }
        }
    }

    private static func fixedVerticalHeight(
        from children: [MeasuredChild],
        usingContentFlex: Bool
    ) -> Int {
        children.reduce(0) { height, child in
            switch child.content {
            case .block:
                if child.isVerticallyFlexible(usingContentFlex: usingContentFlex) {
                    return height
                }
                return height + child.content.verticalLength
            case .spacer:
                if child.isVerticallyFlexible(usingContentFlex: usingContentFlex) {
                    return height
                }
                return height + child.content.verticalLength
            }
        }
    }

    private static func horizontalCaret(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> RenderedCaret? {
        for item in items {
            guard let block = item.block, let caret = block.caret else {
                continue
            }

            return RenderedCaret(
                row: verticalOffset(
                    for: block,
                    in: items,
                    containerHeight: height,
                    alignment: alignment
                ) + caret.row,
                column: item.x + caret.column
            )
        }

        return nil
    }

    private static func horizontalHitRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedHitRegion] {
        items.flatMap { item -> [RenderedHitRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.hitRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalScrollRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedScrollRegion] {
        items.flatMap { item -> [RenderedScrollRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.scrollRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalFocusRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedFocusRegion] {
        items.flatMap { item -> [RenderedFocusRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.focusRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalIdentifiedRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedIdentifiedRegion] {
        items.flatMap { item -> [RenderedIdentifiedRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.identifiedRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalCoordinateSpaceRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedCoordinateSpaceRegion] {
        items.flatMap { item -> [RenderedCoordinateSpaceRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.coordinateSpaceRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func verticalCaret(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> RenderedCaret? {
        for item in items {
            guard let block = item.block, let caret = block.caret else {
                continue
            }

            return RenderedCaret(
                row: item.y + caret.row,
                column: horizontalOffset(
                    for: block,
                    in: items,
                    containerWidth: width,
                    alignment: alignment
                ) + caret.column
            )
        }

        return nil
    }

    private static func verticalHitRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedHitRegion] {
        items.flatMap { item -> [RenderedHitRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.hitRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalScrollRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedScrollRegion] {
        items.flatMap { item -> [RenderedScrollRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.scrollRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalFocusRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedFocusRegion] {
        items.flatMap { item -> [RenderedFocusRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.focusRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalIdentifiedRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedIdentifiedRegion] {
        items.flatMap { item -> [RenderedIdentifiedRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.identifiedRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalCoordinateSpaceRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedCoordinateSpaceRegion] {
        items.flatMap { item -> [RenderedCoordinateSpaceRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.coordinateSpaceRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func flexibleLengths(
        count: Int,
        minimums: [Int],
        extra: Int
    ) -> [Int] {
        guard count > 0 else {
            return []
        }

        let shared = extra / count
        let remainder = extra % count
        return minimums.enumerated().map { index, minimum in
            minimum + shared + (index < remainder ? 1 : 0)
        }
    }

    private static func spacingGaps(
        between children: [MeasuredChild],
        spacing: Int?,
        axis: Axis
    ) -> [Int] {
        guard children.count > 1 else {
            return []
        }
        if let spacing {
            return Array(repeating: max(spacing, 0), count: children.count - 1)
        }
        return zip(children, children.dropFirst()).map {
            $0.content.spacing.distance(to: $1.content.spacing, along: axis)
        }
    }

    private static func horizontalSpacing(
        from items: [HorizontalItem]
    ) -> ViewSpacing {
        items.enumerated().reduce(ViewSpacing()) { result, element in
            let (index, item) = element
            var edges: Edge.Set = .vertical
            if index == items.startIndex {
                edges.formUnion(.leading)
            }
            if index == items.index(before: items.endIndex) {
                edges.formUnion(.trailing)
            }
            return result.union(item.content.spacing, edges: edges)
        }
    }

    private static func verticalSpacing(
        from items: [VerticalItem]
    ) -> ViewSpacing {
        items.enumerated().reduce(ViewSpacing()) { result, element in
            let (index, item) = element
            var edges: Edge.Set = .horizontal
            if index == items.startIndex {
                edges.formUnion(.top)
            }
            if index == items.index(before: items.endIndex) {
                edges.formUnion(.bottom)
            }
            return result.union(item.content.spacing, edges: edges)
        }
    }

    private static func horizontalOffset(
        for block: RenderedBlock,
        in items: [VerticalItem],
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let hasExplicitValue = items.compactMap(\.block).contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .leading && alignment != .center && alignment != .trailing) else {
            return horizontalOffset(
                contentWidth: block.width,
                containerWidth: containerWidth,
                alignment: alignment
            )
        }
        let line = items.compactMap(\.block).map {
            $0.viewDimensions[alignment]
        }.max() ?? 0
        return line - block.viewDimensions[alignment]
    }

    private static func verticalOffset(
        for block: RenderedBlock,
        in items: [HorizontalItem],
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let hasExplicitValue = items.compactMap(\.block).contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .top && alignment != .center && alignment != .bottom) else {
            return verticalOffset(
                contentHeight: block.height,
                containerHeight: containerHeight,
                alignment: alignment
            )
        }
        let line = items.compactMap(\.block).map {
            $0.viewDimensions[alignment]
        }.max() ?? 0
        return line - block.viewDimensions[alignment]
    }

    private static func horizontalOffset(
        contentWidth: Int,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = max(containerWidth - contentWidth, 0)
        if alignment == .leading {
            return 0
        }
        if alignment == .center {
            return padding / 2
        }
        if alignment == .trailing {
            return padding
        }
        let content = ViewDimensions(columns: contentWidth, rows: 0)
        let container = ViewDimensions(columns: containerWidth, rows: 0)
        return container[alignment] - content[alignment]
    }

    private static func verticalOffset(
        contentHeight: Int,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = max(containerHeight - contentHeight, 0)
        if alignment == .top {
            return 0
        }
        if alignment == .center {
            return padding / 2
        }
        if alignment == .bottom {
            return padding
        }
        let content = ViewDimensions(columns: 0, rows: contentHeight)
        let container = ViewDimensions(columns: 0, rows: containerHeight)
        return container[alignment] - content[alignment]
    }
}

extension StackRenderer.MeasuredChild {

    fileprivate var isHorizontallyContentFlexible: Bool {
        guard case .block = content else {
            return false
        }

        return traits.flexibleAxes.contains(.horizontal)
    }

    fileprivate var isVerticallyContentFlexible: Bool {
        guard !suppressesVerticalFlexInParentStack else {
            return false
        }

        guard case .block = content else {
            return false
        }

        return traits.flexibleAxes.contains(.vertical)
    }

    fileprivate func isHorizontallyFlexible(usingContentFlex: Bool) -> Bool {
        switch content {
        case .block:
            return traits.flexibleAxes.contains(.horizontal)
        case .spacer:
            return !usingContentFlex
        }
    }

    fileprivate func isVerticallyFlexible(usingContentFlex: Bool) -> Bool {
        guard !suppressesVerticalFlexInParentStack else {
            return false
        }

        switch content {
        case .block:
            return traits.flexibleAxes.contains(.vertical)
        case .spacer:
            return !usingContentFlex
        }
    }

    fileprivate func horizontalMinimum(usingContentFlex: Bool) -> Int? {
        isHorizontallyFlexible(usingContentFlex: usingContentFlex)
            ? content.spacerMinimum ?? 0
            : nil
    }

    fileprivate func verticalMinimum(usingContentFlex: Bool) -> Int? {
        isVerticallyFlexible(usingContentFlex: usingContentFlex)
            ? content.spacerMinimum ?? 0
            : nil
    }

}

extension RenderedElement {

    fileprivate var spacing: ViewSpacing {
        switch self {
        case .block(let block):
            return block.spacing
        case .spacer:
            return ViewSpacing()
        }
    }

    fileprivate var isSpacer: Bool {
        guard case .spacer = self else {
            return false
        }

        return true
    }

    fileprivate var horizontalLength: Int {
        switch self {
        case .block(let block):
            return block.width
        case .spacer(let minLength):
            return minLength
        }
    }

    fileprivate var isRenderable: Bool {
        switch self {
        case .block(let block):
            return block.width > 0 || block.height > 0
        case .spacer:
            return true
        }
    }

    fileprivate var spacerMinimum: Int? {
        guard case .spacer(let minLength) = self else {
            return nil
        }

        return minLength
    }

    fileprivate var verticalLength: Int {
        switch self {
        case .block(let block):
            return block.height
        case .spacer(let minLength):
            return minLength
        }
    }
}
