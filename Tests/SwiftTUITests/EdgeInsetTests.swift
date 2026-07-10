import Testing
@testable import SwiftTUI

@Test func edgeInsetPlacesContentAtEveryEdge() {
    let proposal = RenderProposal(columns: 5, rows: 3)
    let top = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.top) { Text("T") },
        in: proposal
    )
    let bottom = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.bottom) { Text("B") },
        in: proposal
    )
    let leading = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.leading) { Text("L") },
        in: proposal
    )
    let trailing = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.trailing) { Text("R") },
        in: proposal
    )

    #expect(top?.lines == ["  T  ", "CCCCC", "CCCCC"])
    #expect(bottom?.lines == ["CCCCC", "CCCCC", "  B  "])
    #expect(leading?.lines == [" CCCC", "LCCCC", " CCCC"])
    #expect(trailing?.lines == ["CCCC ", "CCCCR", "CCCC "])
}

@Test func edgeInsetAppliesSpacingAndClampsNegativeSpacing() {
    let positive = ViewResolver.block(
        from: Text("C")
            .edgeInset(.top, spacing: 2) { Text("T") }
    )
    let negative = ViewResolver.block(
        from: Text("C")
            .edgeInset(.top, spacing: -2) { Text("T") }
    )

    #expect(positive?.lines == ["T", "", "", "C"])
    #expect(negative?.lines == ["T", "C"])
}

@Test func emptyConditionalEdgeInsetDoesNotAddSpacing() {
    let includesInset = false
    let block = ViewResolver.block(
        from: Text("C")
            .edgeInset(.top, spacing: 2) {
                if includesInset {
                    Text("T")
                }
            }
    )

    #expect(block?.lines == ["C"])
}

@Test func sameEdgeInsetsAccumulateWithLastModifierOutermost() {
    let block = ViewResolver.block(
        from: Text("C")
            .edgeInset(.top) { Text("A") }
            .edgeInset(.top) { Text("B") }
    )

    #expect(block?.lines == ["B", "A", "C"])
}

@Test func perpendicularEdgeInsetOrderControlsCornerOwnership() {
    let leadingOutside = ViewResolver.block(
        from: Text("C")
            .edgeInset(.top) { Text("T") }
            .edgeInset(.leading) { Text("L") }
    )
    let topOutside = ViewResolver.block(
        from: Text("C")
            .edgeInset(.leading) { Text("L") }
            .edgeInset(.top) { Text("T") }
    )

    #expect(leadingOutside?.lines == ["LT", " C"])
    #expect(topOutside?.lines == ["T ", "LC"])
}

@Test func edgeInsetPreservesContentLayoutFlexibility() {
    let proposal = RenderProposal(columns: 5, rows: 4)
    let fixed = ViewResolver.block(
        from: Text("C")
            .edgeInset(.bottom) { Text("B") },
        in: proposal
    )
    let flexible = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.bottom) { Text("B") },
        in: proposal
    )

    #expect(fixed?.lines == ["C", "B"])
    #expect(flexible?.lines == ["CCCCC", "CCCCC", "CCCCC", "  B  "])
}

@Test func edgeInsetUsesNaturalThicknessAndPreservesCrossAxisFlexibility() {
    let block = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.top) {
                FlexibleProbe("I", naturalWidth: 2, naturalHeight: 1)
            },
        in: RenderProposal(columns: 5, rows: 4)
    )

    #expect(block?.lines == ["IIIII", "CCCCC", "CCCCC", "CCCCC"])
}

@Test func edgeInsetTreatsBuilderContentAsOneInsetRegion() {
    let block = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.top) {
                Text("T")
                FlexibleProbe("I")
            },
        in: RenderProposal(columns: 5, rows: 4)
    )

    #expect(block?.lines == ["T    ", "IIIII", "CCCCC", "CCCCC"])
}

@Test func edgeInsetPreservesGroupedContentFlexibility() {
    let block = ViewResolver.block(
        from: Group {
            FlexibleProbe("C")
        }
        .edgeInset(.bottom) { Text("B") },
        in: RenderProposal(columns: 5, rows: 3)
    )

    #expect(block?.lines == ["CCCCC", "CCCCC", "  B  "])
}

@Test func edgeInsetOffsetsCaretAndInteractionRegions() {
    let block = ViewResolver.block(
        from: FlexibleProbe("C")
            .edgeInset(.bottom, spacing: 1) {
                MetadataProbe()
            },
        in: RenderProposal(columns: 4, rows: 5)
    )
    let expectedFrame = RenderedRect(x: 1, y: 4, width: 1, height: 1)

    #expect(block?.caret == RenderedCaret(row: 4, column: 1))
    #expect(block?.hitRegions.map(\.frame) == [expectedFrame])
    #expect(block?.scrollRegions.map(\.frame) == [expectedFrame])
    #expect(block?.focusRegions.map(\.frame) == [expectedFrame])
    #expect(block?.identifiedRegions.map(\.frame) == [expectedFrame])
    #expect(block?.coordinateSpaceRegions.map(\.frame) == [expectedFrame])
}

private struct FlexibleProbe: View, LayoutModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let character: Character

    let naturalWidth: Int

    let naturalHeight: Int

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    init(_ character: Character, naturalWidth: Int = 1, naturalHeight: Int = 1) {
        self.character = character
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let width = proposal?.columns ?? naturalWidth
        let height = proposal?.rows ?? naturalHeight
        return RenderedBlock(
            lines: Array(
                repeating: String(repeating: character, count: width),
                count: height
            )
        )
    }
}

private struct MetadataProbe: View, LayoutModifierRenderable {

    typealias Body = Never

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let frame = RenderedRect(width: 1, height: 1)
        return RenderedBlock(
            runs: [RenderedRun(text: "I")],
            width: 1,
            height: 1,
            caret: RenderedCaret(row: 0, column: 0),
            hitRegions: [RenderedHitRegion(path: [0], frame: frame)],
            scrollRegions: [RenderedScrollRegion(path: [0], frame: frame)],
            focusRegions: [RenderedFocusRegion(path: [0], frame: frame)],
            identifiedRegions: [RenderedIdentifiedRegion(id: "probe", frame: frame)],
            coordinateSpaceRegions: [
                RenderedCoordinateSpaceRegion(name: "probe", path: [0], frame: frame),
            ]
        )
    }
}
