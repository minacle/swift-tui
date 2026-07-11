import Testing
@testable import SwiftTUI

@Suite("Layout Properties and Explicit Alignment")
struct LayoutPropertiesAndExplicitAlignmentTests {

    @Test
    func `LayoutProperties defaults to an unknown stack orientation`() {
        let properties = LayoutProperties()

        #expect(properties.stackOrientation == nil)
        #expect(UnknownSpacerProbeLayout.layoutProperties.stackOrientation == nil)
    }

    @Test
    func `custom layout stack orientations select the Divider line axis`() {
        let horizontal = ViewResolver.block(
            from: HorizontalDividerLayout() {
                Divider()
            }
        )
        let vertical = ViewResolver.block(
            from: VerticalDividerLayout() {
                Divider()
            }
        )

        #expect(horizontal?.lines == ["│  ", "│  ", "│  "])
        #expect(vertical?.lines == ["───", "   ", "   "])
    }

    @Test
    func `custom layout stack orientations limit Spacer maximum flexibility to the major axis`() {
        let horizontalProbe = SpacerDimensionsProbe()
        let verticalProbe = SpacerDimensionsProbe()
        let unknownProbe = SpacerDimensionsProbe()

        _ = ViewResolver.block(
            from: HorizontalSpacerProbeLayout(probe: horizontalProbe) {
                Spacer()
            }
        )
        _ = ViewResolver.block(
            from: VerticalSpacerProbeLayout(probe: verticalProbe) {
                Spacer()
            }
        )
        _ = ViewResolver.block(
            from: UnknownSpacerProbeLayout(probe: unknownProbe) {
                Spacer()
            }
        )

        #expect(horizontalProbe.dimensions == Size(columns: Int.max, rows: 0))
        #expect(verticalProbe.dimensions == Size(columns: 0, rows: Int.max))
        #expect(unknownProbe.dimensions == Size(columns: Int.max, rows: Int.max))
    }

    @Test
    func `a custom layout reports an arbitrary horizontal guide to its parent VStack`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .layoutMarker) {
                HorizontalExplicitAlignmentLayout() {
                    Text("A")
                }
                Text("B")
                    .alignmentGuide(HorizontalAlignment.layoutMarker) { _ in 0 }
            }
        )

        #expect(block?.lines == ["A  ", "  B"])
    }

    @Test
    func `a custom layout reports a built-in leading guide to its parent VStack`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .leading) {
                HorizontalExplicitAlignmentLayout() {
                    Text("A")
                }
                Text("B")
            }
        )

        #expect(block?.lines == ["A  ", "  B"])
    }

    @Test
    func `a custom layout reports an arbitrary vertical guide to its parent HStack`() {
        let block = ViewResolver.block(
            from: HStack(alignment: .layoutMarker) {
                VerticalExplicitAlignmentLayout() {
                    Text("A")
                }
                Text("B")
                    .alignmentGuide(VerticalAlignment.layoutMarker) { _ in 0 }
            }
        )

        #expect(block?.lines == ["A ", "  ", " B"])
    }

    @Test
    func `the default custom layout alignment merges placed subview guides`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .layoutMarker) {
                OffsetGuideLayout() {
                    Text("A")
                        .alignmentGuide(HorizontalAlignment.layoutMarker) { _ in 0 }
                }
                Text("B")
                    .alignmentGuide(HorizontalAlignment.layoutMarker) { _ in 0 }
            }
        )

        #expect(block?.lines == [" A ", " B "])
    }

    @Test
    func `dimensions lazily requests a nested custom layout guide`() {
        let probe = ExplicitAlignmentProbe()
        let view = ExplicitAlignmentProbeLayout(probe: probe) {
            HorizontalExplicitAlignmentLayout() {
                Text("A")
            }
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.value == 2)
    }

    @Test
    func `explicit alignment receives the layout bounds proposal subviews and cache`() {
        let probe = ExplicitAlignmentContextProbe()
        let view = VStack(alignment: .layoutMarker) {
            ExplicitAlignmentContextLayout(probe: probe) {
                Text("A")
            }
        }

        _ = ViewResolver.block(from: view)

        #expect(
            probe.bounds == Rect(
                origin: .zero,
                size: Size(columns: 3, rows: 1)
            )
        )
        #expect(probe.proposal == .unspecified)
        #expect(probe.subviewCount == 1)
        #expect(probe.cacheValue == 2)
    }
}

private nonisolated enum LayoutHorizontalMarker: AlignmentID {

    static func defaultValue(in context: ViewDimensions) -> Int {
        0
    }
}

private extension HorizontalAlignment {

    nonisolated static let layoutMarker = HorizontalAlignment(LayoutHorizontalMarker.self)
}

private nonisolated enum LayoutVerticalMarker: AlignmentID {

    static func defaultValue(in context: ViewDimensions) -> Int {
        0
    }
}

private extension VerticalAlignment {

    nonisolated static let layoutMarker = VerticalAlignment(LayoutVerticalMarker.self)
}

private nonisolated protocol FixedThreeCellLayout: Layout where Cache == Void {}

private extension FixedThreeCellLayout {

    nonisolated func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 3, rows: 3)
    }

    nonisolated func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

private struct HorizontalDividerLayout: FixedThreeCellLayout {

    nonisolated static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }
}

private struct VerticalDividerLayout: FixedThreeCellLayout {

    nonisolated static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }
}

private nonisolated final class SpacerDimensionsProbe: @unchecked Sendable {

    var dimensions = Size()
}

private nonisolated protocol SpacerProbeLayout: Layout where Cache == Void {

    nonisolated var probe: SpacerDimensionsProbe { get }
}

private extension SpacerProbeLayout {

    nonisolated func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        probe.dimensions = subviews.first?.sizeThatFits(.max) ?? Size()
        return Size(columns: 1, rows: 1)
    }

    nonisolated func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {}
}

private struct HorizontalSpacerProbeLayout: SpacerProbeLayout {

    let probe: SpacerDimensionsProbe

    nonisolated static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .horizontal
        return properties
    }
}

private struct VerticalSpacerProbeLayout: SpacerProbeLayout {

    let probe: SpacerDimensionsProbe

    nonisolated static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }
}

private struct UnknownSpacerProbeLayout: SpacerProbeLayout {

    let probe: SpacerDimensionsProbe
}

private struct HorizontalExplicitAlignmentLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 3, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(at: bounds.origin)
    }

    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Int? {
        guide == .layoutMarker || guide == .leading
            ? bounds.origin.column + 2
            : nil
    }
}

private struct VerticalExplicitAlignmentLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 1, rows: 3)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(at: bounds.origin)
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Int? {
        guide == .layoutMarker ? bounds.origin.row + 2 : nil
    }
}

private struct OffsetGuideLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 3, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: Point(column: bounds.origin.column + 1, row: bounds.origin.row)
        )
    }
}

private nonisolated final class ExplicitAlignmentProbe: @unchecked Sendable {

    var value: Int?
}

private struct ExplicitAlignmentProbeLayout: Layout {

    let probe: ExplicitAlignmentProbe

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        let dimensions = subviews.first?.dimensions(in: .unspecified)
        probe.value = dimensions?[explicit: HorizontalAlignment.layoutMarker]
        return Size(columns: 3, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(at: bounds.origin)
    }
}

private nonisolated final class ExplicitAlignmentContextProbe: @unchecked Sendable {

    var bounds: Rect?
    var proposal: ProposedViewSize?
    var subviewCount = 0
    var cacheValue = 0
}

private struct ExplicitAlignmentContextLayout: Layout {

    let probe: ExplicitAlignmentContextProbe

    func makeCache(subviews: Subviews) -> Int {
        0
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Int
    ) -> Size {
        cache = 1
        return Size(columns: 3, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Int
    ) {
        cache = 2
        subviews.first?.place(at: bounds.origin)
    }

    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Int
    ) -> Int? {
        guard guide == .layoutMarker else {
            return nil
        }
        probe.bounds = bounds
        probe.proposal = proposal
        probe.subviewCount = subviews.count
        probe.cacheValue = cache
        return bounds.origin.column
    }
}
