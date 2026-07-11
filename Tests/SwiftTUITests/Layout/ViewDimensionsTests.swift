import Testing
@testable import SwiftTUI

@Suite("View Dimensions")
struct ViewDimensionsTests {

    @Test
    func `built-in alignment guides resolve from terminal-cell dimensions`() {
        let dimensions = ViewDimensions(columns: 7, rows: 5)

        #expect(dimensions[.leading] == 0)
        #expect(dimensions[HorizontalAlignment.center] == 3)
        #expect(dimensions[.trailing] == 7)
        #expect(dimensions[.top] == 0)
        #expect(dimensions[VerticalAlignment.center] == 2)
        #expect(dimensions[.bottom] == 5)
    }

    @Test
    func `a custom alignment guide derives its default from the view dimensions`() {
        let dimensions = ViewDimensions(columns: 9, rows: 5)

        #expect(dimensions[HorizontalAlignment.oneThird] == 3)
        #expect(dimensions[VerticalAlignment.oneThird] == 1)
        #expect(dimensions[explicit: HorizontalAlignment.oneThird] == nil)
        #expect(dimensions[explicit: VerticalAlignment.oneThird] == nil)
    }

    @Test
    func `alignment types average explicit values and truncate fractional cells`() {
        #expect(HorizontalAlignment.oneThird.combineExplicit([nil, 1, 3, 9]) == 4)
        #expect(VerticalAlignment.oneThird.combineExplicit([-2, 1]) == 0)
        #expect(HorizontalAlignment.center.combineExplicit([nil, nil]) == nil)
    }

    @Test
    func `dimensions returns nested explicit guides from the measured subview`() {
        let probe = ViewDimensionsProbe()
        let view = DimensionsProbeLayout(probe: probe) {
            Text("ABCD")
                .alignmentGuide(.leading) { $0.columns + 1 }
                .alignmentGuide(HorizontalAlignment.oneThird) { $0[.leading] + 2 }
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.columns == 4)
        #expect(probe.rows == 1)
        #expect(probe.leading == 5)
        #expect(probe.oneThird == 7)
        #expect(probe.explicitLeading == 5)
        #expect(probe.explicitOneThird == 7)
    }

    @Test
    func `an outer alignment guide reads and replaces the inner explicit value`() {
        let probe = ViewDimensionsProbe()
        let view = DimensionsProbeLayout(probe: probe) {
            Text("AB")
                .alignmentGuide(.leading) { _ in 1 }
                .alignmentGuide(.leading) { $0[.leading] + 3 }
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.leading == 4)
        #expect(probe.explicitLeading == 4)
    }

    @Test
    func `padding and framing translate an explicit guide into the outer coordinate space`() {
        let probe = ViewDimensionsProbe()
        let view = DimensionsProbeLayout(probe: probe) {
            Text("A")
                .alignmentGuide(.leading) { _ in 0 }
                .padding(.leading, 2)
                .frame(width: 5, alignment: .trailing)
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.columns == 5)
        #expect(probe.explicitLeading == 4)
    }

    @Test
    func `custom layout placement anchors a subview at its explicit guide`() {
        let view = GuidePlacementLayout() {
            Text("AB")
                .alignmentGuide(HorizontalAlignment.oneThird) { _ in 1 }
        }

        #expect(ViewResolver.block(from: view)?.lines == [" AB  "])
    }

    @Test
    func `dimensions shares sizeThatFits proposal normalization`() {
        let probe = ViewDimensionsProposalProbe()
        let view = ProposalDimensionsLayout(probe: probe) {
            Text("AB")
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.sizes == [
            Size(),
            Size(columns: 2, rows: 1),
            Size(columns: 2, rows: 1),
            Size(columns: 2, rows: 1),
        ])
    }

    @Test
    func `alignmentGuide preserves flexible layout traits`() {
        let view = HStack(spacing: 0) {
            Text("[")
            TextField("Name", text: .constant(""))
                .alignmentGuide(HorizontalAlignment.oneThird) { _ in 0 }
            Text("]")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 8))

        #expect(block?.lines == ["[Name  ]"])
    }
}

private nonisolated enum OneThirdAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        context.columns / 3
    }
}

private extension HorizontalAlignment {
    nonisolated static let oneThird = HorizontalAlignment(OneThirdAlignment.self)
}

private nonisolated enum VerticalOneThirdAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        context.rows / 3
    }
}

private extension VerticalAlignment {
    nonisolated static let oneThird = VerticalAlignment(VerticalOneThirdAlignment.self)
}

private nonisolated final class ViewDimensionsProbe: @unchecked Sendable {
    var columns = 0
    var rows = 0
    var leading = 0
    var oneThird = 0
    var explicitLeading: Int?
    var explicitOneThird: Int?
}

private struct DimensionsProbeLayout: Layout {

    let probe: ViewDimensionsProbe

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        guard let subview = subviews.first else {
            return Size()
        }
        let dimensions = subview.dimensions(in: proposal)
        probe.columns = dimensions.columns
        probe.rows = dimensions.rows
        probe.leading = dimensions[.leading]
        probe.oneThird = dimensions[HorizontalAlignment.oneThird]
        probe.explicitLeading = dimensions[explicit: HorizontalAlignment.leading]
        probe.explicitOneThird = dimensions[explicit: HorizontalAlignment.oneThird]
        return Size(columns: dimensions.columns, rows: dimensions.rows)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(at: bounds.origin, proposal: proposal)
    }
}

private struct GuidePlacementLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 5, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: Point(column: 2, row: 0),
            anchor: Alignment(horizontal: .oneThird, vertical: .top)
        )
    }
}

private nonisolated final class ViewDimensionsProposalProbe: @unchecked Sendable {
    var sizes: [Size] = []
}

private struct ProposalDimensionsLayout: Layout {

    let probe: ViewDimensionsProposalProbe

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        guard let subview = subviews.first else {
            return Size()
        }
        probe.sizes = [
            subview.dimensions(in: .zero),
            subview.dimensions(in: .max),
            subview.dimensions(in: .unspecified),
            subview.dimensions(in: ProposedViewSize(columns: 4, rows: 2)),
        ].map { Size(columns: $0.columns, rows: $0.rows) }
        return subview.sizeThatFits(.unspecified)
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
