import Testing

@testable import SwiftTUI

@Suite("Proposed View Size")
struct ProposedViewSizeTests {

    @Test
    func `standard proposals contain their documented terminal-cell dimensions`() {
        #expect(ProposedViewSize.zero == ProposedViewSize(columns: 0, rows: 0))
        #expect(ProposedViewSize.unspecified == ProposedViewSize(columns: nil, rows: nil))
        #expect(ProposedViewSize.max == ProposedViewSize(columns: Int.max, rows: Int.max))
    }

    @Test
    func `explicit and Size initializers preserve negative dimensions`() {
        let explicit = ProposedViewSize(columns: -3, rows: -2)
        let converted = ProposedViewSize(Size(columns: -5, rows: -4))

        #expect(explicit.columns == -3)
        #expect(explicit.rows == -2)
        #expect(converted.columns == -5)
        #expect(converted.rows == -4)
        #expect(RenderProposal(columns: -7, rows: -6).columns == -7)
        #expect(RenderProposal(columns: -7, rows: -6).rows == -6)
    }

    @Test
    func `replacing unspecified dimensions uses the default terminal-cell size`() {
        let proposal = ProposedViewSize(columns: 4, rows: nil)

        #expect(
            proposal.replacingUnspecifiedDimensions()
                == Size(columns: 4, rows: 10)
        )
    }

    @Test
    func `replacing unspecified dimensions preserves specified values`() {
        let proposal = ProposedViewSize(columns: nil, rows: -2)

        #expect(
            proposal.replacingUnspecifiedDimensions(
                by: Size(columns: 8, rows: 6)
            ) == Size(columns: 8, rows: -2)
        )
    }

    @Test
    func `a maximum proposal measures fixed constrained and flexible subviews without rendering maximum buffers`() {
        let probe = SubviewMeasurementProbe()
        let view = SubviewMeasurementLayout(proposal: .max, probe: probe) {
            Text("ABC")
            Text("A")
                .frame(maxWidth: 7, maxHeight: 4)
            Spacer()
            Divider()
            HStack {
                Text("A")
                Spacer()
            }
            Grid {
                GridRow {
                    Text("A")
                    Spacer()
                }
            }
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.sizes == [
            Size(columns: 3, rows: 1),
            Size(columns: 7, rows: 4),
            Size(columns: Int.max, rows: Int.max),
            Size(columns: Int.max, rows: 1),
            Size(columns: Int.max, rows: 1),
            Size(columns: Int.max, rows: Int.max),
        ])
    }

    @Test
    func `a negative proposal produces a nonnegative measured block`() {
        let probe = SubviewMeasurementProbe()
        let view = SubviewMeasurementLayout(
            proposal: ProposedViewSize(columns: -3, rows: -2),
            probe: probe
        ) {
            Text("ABC")
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.sizes == [Size(columns: 0, rows: 0)])
    }
}

private nonisolated final class SubviewMeasurementProbe: @unchecked Sendable {

    var sizes: [Size] = []
}

private struct SubviewMeasurementLayout: Layout {

    let proposal: ProposedViewSize

    let probe: SubviewMeasurementProbe

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        probe.sizes = subviews.map { $0.sizeThatFits(self.proposal) }
        return Size(columns: 1, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
    }
}
