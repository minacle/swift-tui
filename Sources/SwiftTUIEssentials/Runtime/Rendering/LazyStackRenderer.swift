/// A structural role used while flattening lazy stack content.
enum LazyStackDescriptorRole: Hashable {

    case item

    case section

    case sectionHeader

    case sectionFooter
}

/// A stable cache identity for one lazily materialized stack child.
struct LazyStackDescriptorIdentity: Hashable {

    var path: [Int]

    var value: AnyHashable?

    var role: LazyStackDescriptorRole
}

/// A child that can be measured only when its estimated frame approaches a viewport.
struct LazyStackDescriptor {

    var identity: AnyHashable

    var scrollID: AnyHashable?

    var sectionID: AnyHashable?

    var role: LazyStackDescriptorRole

    var expand: (() -> [LazyStackDescriptor])?

    var render: (RenderProposal?, Bool) -> RenderedElement?
}

/// Exposes structural children without materializing every child view body.
protocol LazyViewContent {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor]
}

/// Renders a primitive lazy stack for a bounded same-axis scroll viewport.
protocol LazyScrollRenderable {

    var lazyAxis: Axis { get }

    func lazyRenderedBlock(
        in proposal: RenderProposal,
        viewportSize: Size,
        position: ScrollPosition,
        path: [Int],
        runtime: StateRuntime?,
        suppressRegistrations: Bool
    ) -> RenderedBlock?
}

/// Measurements retained for stable lazy children while their stack remains active.
final class LazyStackGeometryCache {

    struct Measurement {

        var mainLength: Int

        var crossLength: Int

        var spacing: ViewSpacing
    }

    var measurements: [AnyHashable: Measurement] = [:]

    func retain(_ identities: Set<AnyHashable>) {
        measurements = measurements.filter {
            identities.contains($0.key)
        }
    }
}

extension LazyHStack: LayoutTraitRenderable, LazyScrollRenderable, StackRenderable,
    VerticalStackFlexSuppressing
{

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(.horizontal) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: .horizontal
            )
        }
    }

    var lazyAxis: Axis {
        .horizontal
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

    func lazyRenderedBlock(
        in proposal: RenderProposal,
        viewportSize: Size,
        position: ScrollPosition,
        path: [Int],
        runtime: StateRuntime?,
        suppressRegistrations: Bool
    ) -> RenderedBlock? {
        LazyStackRenderer.horizontal(
            ViewResolver.lazyStackDescriptors(
                from: content,
                path: path + [0],
                runtime: runtime,
                sectionID: nil
            ),
            alignment: alignment,
            spacing: spacing,
            pinnedViews: pinnedViews,
            proposal: proposal,
            viewportSize: viewportSize,
            position: position,
            path: path,
            runtime: runtime,
            suppressRegistrations: suppressRegistrations
        )
    }
}

extension LazyVStack: LayoutTraitRenderable, LazyScrollRenderable, StackRenderable {

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(.vertical) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: .vertical
            )
        }
    }

    var lazyAxis: Axis {
        .vertical
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

    func lazyRenderedBlock(
        in proposal: RenderProposal,
        viewportSize: Size,
        position: ScrollPosition,
        path: [Int],
        runtime: StateRuntime?,
        suppressRegistrations: Bool
    ) -> RenderedBlock? {
        LazyStackRenderer.vertical(
            ViewResolver.lazyStackDescriptors(
                from: content,
                path: path + [0],
                runtime: runtime,
                sectionID: nil
            ),
            alignment: alignment,
            spacing: spacing,
            pinnedViews: pinnedViews,
            proposal: proposal,
            viewportSize: viewportSize,
            position: position,
            path: path,
            runtime: runtime,
            suppressRegistrations: suppressRegistrations
        )
    }
}

/// Measures and composites only the lazy stack children needed by a viewport.
enum LazyStackRenderer {

    private struct Frame {

        var start: Int

        var length: Int

        var crossLength: Int

        var end: Int {
            start + length
        }
    }

    private struct Snapshot {

        var frames: [Frame]

        var mainLength: Int

        var crossLength: Int

        var sectionRanges: [AnyHashable: Range<Int>]
    }

    static func horizontal(
        _ descriptors: [LazyStackDescriptor],
        alignment: VerticalAlignment,
        spacing: Int?,
        pinnedViews: PinnedScrollableViews,
        proposal: RenderProposal,
        viewportSize: Size,
        position: ScrollPosition,
        path: [Int],
        runtime: StateRuntime?,
        suppressRegistrations: Bool
    ) -> RenderedBlock? {
        block(
            descriptors,
            axis: .horizontal,
            horizontalAlignment: nil,
            verticalAlignment: alignment,
            spacing: spacing,
            pinnedViews: pinnedViews,
            proposal: proposal,
            viewportSize: viewportSize,
            position: position,
            path: path,
            runtime: runtime,
            suppressRegistrations: suppressRegistrations
        )
    }

    static func vertical(
        _ descriptors: [LazyStackDescriptor],
        alignment: HorizontalAlignment,
        spacing: Int?,
        pinnedViews: PinnedScrollableViews,
        proposal: RenderProposal,
        viewportSize: Size,
        position: ScrollPosition,
        path: [Int],
        runtime: StateRuntime?,
        suppressRegistrations: Bool
    ) -> RenderedBlock? {
        block(
            descriptors,
            axis: .vertical,
            horizontalAlignment: alignment,
            verticalAlignment: nil,
            spacing: spacing,
            pinnedViews: pinnedViews,
            proposal: proposal,
            viewportSize: viewportSize,
            position: position,
            path: path,
            runtime: runtime,
            suppressRegistrations: suppressRegistrations
        )
    }

    private static func block(
        _ initialDescriptors: [LazyStackDescriptor],
        axis: Axis,
        horizontalAlignment: HorizontalAlignment?,
        verticalAlignment: VerticalAlignment?,
        spacing: Int?,
        pinnedViews: PinnedScrollableViews,
        proposal: RenderProposal,
        viewportSize: Size,
        position: ScrollPosition,
        path: [Int],
        runtime: StateRuntime?,
        suppressRegistrations: Bool
    ) -> RenderedBlock? {
        guard !initialDescriptors.isEmpty else {
            return nil
        }

        let cache = runtime?.lazyStackGeometryCache(at: path) ?? LazyStackGeometryCache()
        let viewportLength = axis == .horizontal
            ? viewportSize.columns
            : viewportSize.rows
        guard viewportLength > 0 else {
            return nil
        }

        var descriptors = initialDescriptors
        var snapshot = layoutSnapshot(
            descriptors,
            axis: axis,
            spacing: spacing,
            cache: cache
        )
        var offset = resolvedOffset(
            position,
            axis: axis,
            contentLength: snapshot.mainLength,
            viewportLength: viewportLength
        )
        var selected = selectedIndices(
            descriptors,
            snapshot: snapshot,
            offset: offset,
            viewportLength: viewportLength
        )

        while let index = selected.sorted().first(where: { descriptors[$0].expand != nil }) {
            let descriptor = descriptors[index]
            var replacements = descriptor.expand?() ?? []
            if !replacements.isEmpty, replacements[0].scrollID == nil {
                replacements[0].scrollID = descriptor.scrollID
            }
            descriptors.replaceSubrange(index...index, with: replacements)
            guard !descriptors.isEmpty else {
                return nil
            }

            snapshot = layoutSnapshot(
                descriptors,
                axis: axis,
                spacing: spacing,
                cache: cache
            )
            offset = resolvedOffset(
                position,
                axis: axis,
                contentLength: snapshot.mainLength,
                viewportLength: viewportLength
            )
            selected = selectedIndices(
                descriptors,
                snapshot: snapshot,
                offset: offset,
                viewportLength: viewportLength
            )
        }
        cache.retain(Set(descriptors.map(\.identity)))

        var measuredIndices: Set<Int> = []
        while let index = selected.first(where: { !measuredIndices.contains($0) }) {
            measuredIndices.insert(index)
            measure(
                descriptor: descriptors[index],
                axis: axis,
                proposal: childProposal(axis: axis, proposal: proposal),
                cache: cache
            )
            snapshot = layoutSnapshot(
                descriptors,
                axis: axis,
                spacing: spacing,
                cache: cache
            )
            offset = resolvedOffset(
                position,
                axis: axis,
                contentLength: snapshot.mainLength,
                viewportLength: viewportLength
            )
            selected = selectedIndices(
                descriptors,
                snapshot: snapshot,
                offset: offset,
                viewportLength: viewportLength
            )
        }

        var rendered: [(index: Int, block: RenderedBlock)] = []
        for index in selected.sorted() {
            guard let block = renderedBlock(
                from: descriptors[index].render(
                    childProposal(axis: axis, proposal: proposal),
                    suppressRegistrations
                ),
                axis: axis,
                proposal: proposal
            ) else {
                continue
            }

            cache.measurements[descriptors[index].identity] = .init(
                mainLength: mainLength(of: block, axis: axis),
                crossLength: crossLength(of: block, axis: axis),
                spacing: block.spacing
            )
            rendered.append((index, block))
        }

        snapshot = layoutSnapshot(
            descriptors,
            axis: axis,
            spacing: spacing,
            cache: cache
        )
        offset = resolvedOffset(
            position,
            axis: axis,
            contentLength: snapshot.mainLength,
            viewportLength: viewportLength
        )
        let width = axis == .horizontal ? snapshot.mainLength : snapshot.crossLength
        let height = axis == .horizontal ? snapshot.crossLength : snapshot.mainLength
        let bounds = RenderedRect(width: width, height: height)
        var ordinaryBlocks: [RenderedBlock] = []
        var pinnedBlocks: [RenderedBlock] = []
        for item in rendered {
            let descriptor = descriptors[item.index]
            let frame = snapshot.frames[item.index]
            let mainOrigin = pinnedOrigin(
                descriptor: descriptor,
                naturalOrigin: frame.start,
                length: frame.length,
                sectionRanges: snapshot.sectionRanges,
                pinnedViews: pinnedViews,
                offset: offset,
                viewportLength: viewportLength
            )
            let crossOrigin = alignedCrossOrigin(
                block: item.block,
                axis: axis,
                crossLength: snapshot.crossLength,
                horizontalAlignment: horizontalAlignment,
                verticalAlignment: verticalAlignment
            )
            let placed = item.block.offsetBy(
                x: axis == .horizontal ? mainOrigin : crossOrigin,
                y: axis == .horizontal ? crossOrigin : mainOrigin,
                clippedTo: bounds
            )
            if mainOrigin == frame.start {
                ordinaryBlocks.append(placed)
            }
            else {
                pinnedBlocks.append(placed)
            }
        }

        var result = RenderedBlock.composited(
            ordinaryBlocks + pinnedBlocks,
            width: width,
            height: height
        )
        for (index, descriptor) in descriptors.enumerated() {
            guard let scrollID = descriptor.scrollID else {
                continue
            }

            let frame = snapshot.frames[index]
            result.identifiedRegions.append(
                RenderedIdentifiedRegion(
                    id: scrollID,
                    frame: axis == .horizontal
                        ? RenderedRect(
                            x: frame.start,
                            width: frame.length,
                            height: snapshot.crossLength
                        )
                        : RenderedRect(
                            y: frame.start,
                            width: snapshot.crossLength,
                            height: frame.length
                        )
                )
            )
        }
        return result
    }

    private static func measure(
        descriptor: LazyStackDescriptor,
        axis: Axis,
        proposal: RenderProposal,
        cache: LazyStackGeometryCache
    ) {
        guard let block = renderedBlock(
            from: descriptor.render(proposal, true),
            axis: axis,
            proposal: proposal
        ) else {
            cache.measurements[descriptor.identity] = .init(
                mainLength: 0,
                crossLength: 0,
                spacing: .zero
            )
            return
        }

        cache.measurements[descriptor.identity] = .init(
            mainLength: mainLength(of: block, axis: axis),
            crossLength: crossLength(of: block, axis: axis),
            spacing: block.spacing
        )
    }

    private static func layoutSnapshot(
        _ descriptors: [LazyStackDescriptor],
        axis: Axis,
        spacing: Int?,
        cache: LazyStackGeometryCache
    ) -> Snapshot {
        let measuredLengths = cache.measurements.values.map(\.mainLength).sorted()
        let estimatedLength = measuredLengths.isEmpty
            ? 1
            : measuredLengths[measuredLengths.count / 2]
        let defaultSpacing = ViewSpacing()
        var frames: [Frame] = []
        var position = 0
        var crossLength = 0
        var sectionStarts: [AnyHashable: Int] = [:]
        var sectionEnds: [AnyHashable: Int] = [:]
        for (index, descriptor) in descriptors.enumerated() {
            let measurement = cache.measurements[descriptor.identity]
            let length = measurement?.mainLength ?? estimatedLength
            let cross = measurement?.crossLength ?? 0
            let frame = Frame(start: position, length: length, crossLength: cross)
            frames.append(frame)
            crossLength = max(crossLength, cross)
            if let sectionID = descriptor.sectionID {
                sectionStarts[sectionID] = min(sectionStarts[sectionID] ?? frame.start, frame.start)
                sectionEnds[sectionID] = max(sectionEnds[sectionID] ?? frame.end, frame.end)
            }
            guard index < descriptors.count - 1 else {
                position = frame.end
                continue
            }

            let gap: Int
            if let spacing {
                gap = spacing
            }
            else {
                let current = measurement?.spacing ?? defaultSpacing
                let next = cache.measurements[descriptors[index + 1].identity]?.spacing
                    ?? defaultSpacing
                gap = current.distance(to: next, along: axis)
            }
            position = frame.end + gap
        }
        let ranges = Dictionary(uniqueKeysWithValues: sectionStarts.compactMap { id, start in
            sectionEnds[id].map { (id, start..<$0) }
        })
        return Snapshot(
            frames: frames,
            mainLength: frames.last?.end ?? 0,
            crossLength: crossLength,
            sectionRanges: ranges
        )
    }

    private static func selectedIndices(
        _ descriptors: [LazyStackDescriptor],
        snapshot: Snapshot,
        offset: Int,
        viewportLength: Int
    ) -> Set<Int> {
        let visible = offset..<(offset + viewportLength)
        var result = Set(snapshot.frames.indices.filter { index in
            let frame = snapshot.frames[index]
            return frame.length == 0
                ? visible.contains(frame.start)
                : frame.start < visible.upperBound && frame.end > visible.lowerBound
        })
        if result.isEmpty,
           let nearest = snapshot.frames.indices.min(by: {
               abs(snapshot.frames[$0].start - offset) < abs(snapshot.frames[$1].start - offset)
           }) {
            result.insert(nearest)
        }
        if let first = result.min(), first > 0 {
            result.insert(first - 1)
        }
        if let last = result.max(), last + 1 < descriptors.count {
            result.insert(last + 1)
        }

        let intersectingSections = Set(snapshot.sectionRanges.compactMap { id, range in
            range.lowerBound < visible.upperBound && range.upperBound > visible.lowerBound
                ? id
                : nil
        })
        for (index, descriptor) in descriptors.enumerated()
        where descriptor.sectionID.map(intersectingSections.contains) == true
            && (descriptor.role == .sectionHeader || descriptor.role == .sectionFooter) {
            result.insert(index)
        }
        return result
    }

    private static func resolvedOffset(
        _ position: ScrollPosition,
        axis: Axis,
        contentLength: Int,
        viewportLength: Int
    ) -> Int {
        let maximum = max(contentLength - viewportLength, 0)
        let requested: Int
        if let point = position.point {
            requested = axis == .horizontal ? point.x : point.y
        }
        else {
            requested = switch (axis, position.edge) {
            case (.horizontal, .trailing), (.vertical, .bottom):
                maximum
            default:
                0
            }
        }
        return min(max(requested, 0), maximum)
    }

    private static func pinnedOrigin(
        descriptor: LazyStackDescriptor,
        naturalOrigin: Int,
        length: Int,
        sectionRanges: [AnyHashable: Range<Int>],
        pinnedViews: PinnedScrollableViews,
        offset: Int,
        viewportLength: Int
    ) -> Int {
        guard let sectionID = descriptor.sectionID,
              let section = sectionRanges[sectionID] else {
            return naturalOrigin
        }

        switch descriptor.role {
        case .sectionHeader where pinnedViews.contains(.sectionHeaders):
            return min(max(naturalOrigin, offset), max(section.upperBound - length, section.lowerBound))
        case .sectionFooter where pinnedViews.contains(.sectionFooters):
            return max(
                min(naturalOrigin, offset + viewportLength - length),
                section.lowerBound
            )
        default:
            return naturalOrigin
        }
    }

    private static func childProposal(
        axis: Axis,
        proposal: RenderProposal
    ) -> RenderProposal {
        switch axis {
        case .horizontal:
            RenderProposal(columns: nil, rows: proposal.rows)
        case .vertical:
            RenderProposal(columns: proposal.columns, rows: nil)
        }
    }

    private static func renderedBlock(
        from element: RenderedElement?,
        axis: Axis,
        proposal: RenderProposal
    ) -> RenderedBlock? {
        switch element {
        case .block(let block):
            return block
        case .spacer(let minLength):
            let width = axis == .horizontal ? minLength : max(proposal.columns ?? 0, 0)
            let height = axis == .vertical ? minLength : max(proposal.rows ?? 1, 1)
            guard width > 0 || height > 0 else {
                return nil
            }
            return RenderedBlock(
                runs: [],
                width: width,
                height: height,
                paddedRows: Set(0..<height)
            )
        case nil:
            return nil
        }
    }

    private static func mainLength(of block: RenderedBlock, axis: Axis) -> Int {
        axis == .horizontal ? block.width : block.height
    }

    private static func crossLength(of block: RenderedBlock, axis: Axis) -> Int {
        axis == .horizontal ? block.height : block.width
    }

    private static func alignedCrossOrigin(
        block: RenderedBlock,
        axis: Axis,
        crossLength: Int,
        horizontalAlignment: HorizontalAlignment?,
        verticalAlignment: VerticalAlignment?
    ) -> Int {
        switch axis {
        case .horizontal:
            let alignment = verticalAlignment ?? .center
            let padding = crossLength - block.height
            if alignment == .top {
                return 0
            }
            if alignment == .center {
                return padding / 2
            }
            if alignment == .bottom {
                return padding
            }
            let container = ViewDimensions(columns: block.width, rows: crossLength)
            return container[alignment] - block.viewDimensions[alignment]
        case .vertical:
            let alignment = horizontalAlignment ?? .center
            let padding = crossLength - block.width
            if alignment == .leading {
                return 0
            }
            if alignment == .center {
                return padding / 2
            }
            if alignment == .trailing {
                return padding
            }
            let container = ViewDimensions(columns: crossLength, rows: block.height)
            return container[alignment] - block.viewDimensions[alignment]
        }
    }
}

extension StackChild {

    func identified(by id: AnyHashable) -> StackChild {
        var child = self
        let render = child.render
        child.render = { proposal, suppressRegistrations in
            let element = render(proposal, suppressRegistrations)
            guard case .block(var block) = element else {
                return element
            }

            block.identifiedRegions.append(
                RenderedIdentifiedRegion(id: id, frame: block.bounds)
            )
            return .block(block)
        }
        return child
    }
}
