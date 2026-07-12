import Testing
@testable import SwiftTUIEssentials

@Suite("Rendering Pipeline Stages")
struct RenderingPipelineStageTests {

    @Test
    func `an unspecified RenderProposal preserves intrinsic axes while a viewport proposal specifies both axes`() {
        let intrinsic = RenderProposal(columns: 8)
        let viewport = RenderProposal(TerminalViewportSize(columns: 80, rows: 24))

        #expect(intrinsic.columns == 8)
        #expect(intrinsic.rows == nil)
        #expect(viewport == RenderProposal(columns: 80, rows: 24))
    }

    @Test
    func `LayoutMeasurementContext marks only nested measurement work`() {
        #expect(!LayoutMeasurementContext.isMeasuring)

        let isMeasuring = LayoutMeasurementContext.withMeasurement {
            LayoutMeasurementContext.isMeasuring
        }

        #expect(isMeasuring)
        #expect(!LayoutMeasurementContext.isMeasuring)
    }

    @Test
    func `ViewResolver evaluates a composite body into a rendered block`() {
        let block = ViewResolver.block(from: PipelineCompositeView())

        #expect(block?.runs == [RenderedRun(text: "resolved")])
        #expect(block?.width == 8)
        #expect(block?.height == 1)
    }

    @Test
    func `TextLayoutRenderer wraps wide and narrow graphemes into positioned runs`() {
        let block = TextLayoutRenderer.block(
            for: Text("한AB"),
            in: RenderProposal(columns: 3),
            path: [],
            runtime: nil
        )

        #expect(block.lines == ["한", "AB"])
        #expect(block.width == 2)
        #expect(block.height == 2)
        #expect(block.runs == [
            RenderedRun(text: "한"),
            RenderedRun(text: "AB", row: 1),
        ])
    }

    @Test
    func `padding translates visible runs the caret and every interaction region together`() {
        let sourceFrame = RenderedRect(width: 1, height: 1)
        let block = RenderedBlock(
            runs: [RenderedRun(text: "A")],
            width: 1,
            height: 1,
            caret: RenderedCaret(column: 1),
            hitRegions: [RenderedHitRegion(path: [0], frame: sourceFrame)],
            scrollRegions: [RenderedScrollRegion(path: [1], frame: sourceFrame)],
            focusRegions: [
                RenderedFocusRegion(
                    path: [2],
                    frame: sourceFrame,
                    positionFrame: sourceFrame
                ),
            ],
            identifiedRegions: [RenderedIdentifiedRegion(id: "item", frame: sourceFrame)],
            coordinateSpaceRegions: [
                RenderedCoordinateSpaceRegion(
                    name: "space",
                    path: [3],
                    frame: sourceFrame
                ),
            ]
        )

        let padded = block.padded(
            by: EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 0)
        )
        let translatedFrame = RenderedRect(x: 2, y: 1, width: 1, height: 1)

        #expect(padded.runs == [RenderedRun(text: "A", row: 1, column: 2)])
        #expect(padded.caret == RenderedCaret(row: 1, column: 3))
        #expect(padded.hitRegions == [RenderedHitRegion(path: [0], frame: translatedFrame)])
        #expect(padded.scrollRegions == [RenderedScrollRegion(path: [1], frame: translatedFrame)])
        #expect(padded.focusRegions == [
            RenderedFocusRegion(
                path: [2],
                frame: translatedFrame,
                positionFrame: translatedFrame
            ),
        ])
        #expect(padded.identifiedRegions == [
            RenderedIdentifiedRegion(id: "item", frame: translatedFrame),
        ])
        #expect(padded.coordinateSpaceRegions == [
            RenderedCoordinateSpaceRegion(
                name: "space",
                path: [3],
                frame: translatedFrame
            ),
        ])
    }

    @Test
    func `StackRenderer places child blocks along the requested axis with spacing`() {
        let children = ["A", "B"].map { text in
            StackChild(traits: LayoutTraits()) { _, _ in
                .block(RenderedBlock(lines: [text]))
            }
        }

        let block = StackRenderer.horizontal(
            children,
            alignment: .center,
            spacing: 2
        )

        #expect(block?.runs == [
            RenderedRun(text: "A"),
            RenderedRun(text: "B", column: 3),
        ])
        #expect(block?.width == 4)
        #expect(block?.height == 1)
    }

    @Test
    func `TerminalScreenRenderer selects full and differential output from frame history`() {
        let viewport = TerminalViewportSize(columns: 3, rows: 1)
        let previous = RenderedBlock(lines: ["ABC"])
        let current = RenderedBlock(lines: ["AXC"])

        let initialOutput = TerminalScreenRenderer.redraw(
            from: nil,
            previousViewport: nil,
            to: previous,
            in: viewport
        )
        let updateOutput = TerminalScreenRenderer.redraw(
            from: previous,
            previousViewport: viewport,
            to: current,
            in: viewport
        )

        #expect(initialOutput == "\u{001B}[2J\u{001B}[1;1HABC\u{001B}[?25l")
        #expect(updateOutput == "\u{001B}[1;2HX\u{001B}[?25l")
    }
}

private struct PipelineCompositeView: View {

    var body: some View {
        Text("resolved")
    }
}
