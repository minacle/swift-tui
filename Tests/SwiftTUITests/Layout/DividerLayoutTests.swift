import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Divider Layout")
struct DividerLayoutTests {

    @Test
    func `divider variants use their matching horizontal glyphs outside stacks`() {
        let regular = ViewResolver.block(
            from: Divider(),
            in: RenderProposal(columns: 3, rows: 4)
        )
        let heavy = ViewResolver.block(
            from: HeavyDivider(),
            in: RenderProposal(columns: 3, rows: 4)
        )
        let double = ViewResolver.block(
            from: DoubleDivider(),
            in: RenderProposal(columns: 3, rows: 4)
        )

        #expect(regular?.lines == ["───"])
        #expect(heavy?.lines == ["━━━"])
        #expect(double?.lines == ["═══"])
    }

    @Test
    func `an unspecified divider is one horizontal cell and a zero-width divider is empty`() {
        let unspecified = ViewResolver.block(from: Divider())
        let empty = ViewResolver.block(
            from: Divider(),
            in: RenderProposal(columns: 0)
        )

        #expect(unspecified?.width == 1)
        #expect(unspecified?.height == 1)
        #expect(unspecified?.lines == ["─"])
        #expect(empty?.width == 0)
        #expect(empty?.height == 0)
        #expect(empty?.lines == [])
    }

    @Test
    func `divider variants fill a VStack minor axis with horizontal lines`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .leading, spacing: 0) {
                Text("ABCDE")
                Divider()
                HeavyDivider()
                DoubleDivider()
            }
        )

        #expect(block?.lines == [
            "ABCDE",
            "─────",
            "━━━━━",
            "═════",
        ])
    }

    @Test
    func `divider variants fill an HStack minor axis with vertical lines`() {
        let block = ViewResolver.block(
            from: HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Text("A")
                    Text("B")
                    Text("C")
                }
                Divider()
                HeavyDivider()
                DoubleDivider()
                Text("X")
            }
        )

        #expect(block?.lines == [
            "A│┃║X",
            "B│┃║ ",
            "C│┃║ ",
        ])
    }

    @Test
    func `stack proposals extend dividers only along their line axis`() {
        let horizontal = ViewResolver.block(
            from: VStack(spacing: 0) {
                Divider()
            },
            in: RenderProposal(columns: 4, rows: 3)
        )
        let vertical = ViewResolver.block(
            from: HStack(spacing: 0) {
                Divider()
            },
            in: RenderProposal(columns: 4, rows: 3)
        )

        #expect(horizontal?.width == 4)
        #expect(horizontal?.height == 1)
        #expect(horizontal?.lines == ["────"])
        #expect(vertical?.width == 1)
        #expect(vertical?.height == 3)
        #expect(vertical?.lines == ["│", "│", "│"])
    }

    @Test
    func `the nearest HStack or VStack determines a nested divider direction`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Text("A")
                        Text("B")
                    }
                    Divider()
                }
                Divider()
            }
        )

        #expect(block?.lines == [
            "A│",
            "B│",
            "──",
        ])
    }

    @Test
    func `ZStack and custom Layout reset an enclosing HStack divider direction`() {
        let block = ViewResolver.block(
            from: HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Text("A")
                    Text("B")
                }
                ZStack(alignment: .topLeading) {
                    Divider()
                }
                FixedHorizontalDividerLayout() {
                    Divider()
                }
            }
        )

        #expect(block?.lines == [
            "A────",
            "B    ",
        ])
    }

    @Test
    func `foregroundStyle colors a divider run`() {
        let block = ViewResolver.block(
            from: Divider().foregroundStyle(.red),
            in: RenderProposal(columns: 3)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "───",
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `AnyView and padding preserve divider minor-axis expansion`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .leading, spacing: 0) {
                Text("ABCDE")
                AnyView(
                    Divider()
                        .padding(.horizontal, 1)
                )
            }
        )

        #expect(block?.lines == [
            "ABCDE",
            " ─── ",
        ])
    }

    @Test
    func `a fixed divider width prevents VStack minor-axis expansion`() {
        let framed = ViewResolver.block(
            from: VStack(alignment: .leading, spacing: 0) {
                Text("ABCDE")
                Divider().frame(width: 2, alignment: .leading)
            }
        )
        let fixedSize = ViewResolver.block(
            from: VStack(alignment: .leading, spacing: 0) {
                Text("ABCDE")
                Divider().fixedSize(horizontal: true, vertical: false)
            }
        )

        #expect(framed?.lines == ["ABCDE", "──   "])
        #expect(fixedSize?.lines == ["ABCDE", "─    "])
    }
}

private nonisolated struct FixedHorizontalDividerLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> Size {
        Size(columns: 3, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        for subview in subviews {
            subview.place(
                at: .zero,
                proposal: ProposedViewSize(columns: 3, rows: 1)
            )
        }
    }
}
