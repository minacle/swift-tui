import Testing
@testable import SwiftTUI

@Suite("Shape")
struct ShapeTests {

    @Test func rectangleFillRendersBackgroundCells() {
        let block = ViewResolver.block(
            from: Rectangle()
                .fill(.red)
                .frame(width: 3, height: 2)
        )

        #expect(block?.width == 3)
        #expect(block?.height == 2)
        #expect(block?.lines == ["   ", "   "])
        #expect(block?.runs == [
            RenderedRun(
                text: "   ",
                row: 0,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(
                text: "   ",
                row: 1,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test func rectangleFillEmitsBackgroundSGRSpaces() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(
                from: Rectangle()
                    .fill(.red)
                    .frame(width: 2, height: 1)
            )!,
            in: TerminalViewportSize(columns: 2, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[41m  \u{001B}[49m\u{001B}[?25l")
    }

    @Test func plainRectangleUsesForegroundStyleAsDefaultFill() {
        let block = ViewResolver.block(
            from: Rectangle()
                .foregroundStyle(.red)
                .frame(width: 2, height: 1)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "  ",
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test func shapeSizeChangesDrawnRectWithoutChangingLayoutSize() {
        let block = ViewResolver.block(
            from: Rectangle()
                .size(Size(columns: 2, rows: 1))
                .fill(.red)
                .frame(width: 4, height: 3, alignment: .topLeading)
        )

        #expect(block?.width == 4)
        #expect(block?.height == 3)
        #expect(block?.runs == [
            RenderedRun(
                text: "  ",
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
        #expect(block?.lines == ["    ", "    ", "    "])
    }

    @Test func shapeSizeWidthHeightMatchesTerminalSize() {
        let explicitSize = ViewResolver.block(
            from: Rectangle()
                .size(Size(columns: 2, rows: 1))
                .fill(.red)
                .frame(width: 4, height: 3, alignment: .topLeading)
        )
        let labeledSize = ViewResolver.block(
            from: Rectangle()
                .size(width: 2, height: 1)
                .fill(.red)
                .frame(width: 4, height: 3, alignment: .topLeading)
        )

        #expect(labeledSize == explicitSize)
    }

    @Test func shapeOffsetMovesDrawnRectWithinLayoutBounds() {
        let block = ViewResolver.block(
            from: Rectangle()
                .size(width: 2, height: 1)
                .offset(Point(column: 1, row: 1))
                .fill(.blue)
                .frame(width: 4, height: 3, alignment: .topLeading)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "  ",
                row: 1,
                column: 1,
                style: TextStyle(backgroundStyle: AnyColor(Color16.blue))
            ),
        ])
    }

    @Test func shapeOffsetXYMatchesTerminalPoint() {
        let explicitPoint = ViewResolver.block(
            from: Rectangle()
                .size(width: 2, height: 1)
                .offset(Point(column: 1, row: 1))
                .fill(.blue)
                .frame(width: 4, height: 3, alignment: .topLeading)
        )
        let labeledOffset = ViewResolver.block(
            from: Rectangle()
                .size(width: 2, height: 1)
                .offset(x: 1, y: 1)
                .fill(.blue)
                .frame(width: 4, height: 3, alignment: .topLeading)
        )

        #expect(labeledOffset == explicitPoint)
    }

    @Test func negativeShapeSizeDrawsNoFillButKeepsFrame() {
        let block = ViewResolver.block(
            from: Rectangle()
                .size(Size(columns: -1, rows: 2))
                .fill(.red)
                .frame(width: 3, height: 2, alignment: .topLeading)
        )

        #expect(block?.width == 3)
        #expect(block?.height == 2)
        #expect(block?.runs == [])
        #expect(block?.lines == ["   ", "   "])
    }

    @Test func negativeShapeOffsetClipsFillToBounds() {
        let block = ViewResolver.block(
            from: Rectangle()
                .size(width: 3, height: 1)
                .offset(x: -1, y: 0)
                .fill(.red)
                .frame(width: 3, height: 1, alignment: .topLeading)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "  ",
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test func shapeViewFillChainsDrawLaterFillAboveEarlierFill() {
        let block = ViewResolver.block(
            from: Rectangle()
                .fill(.red)
                .fill(.blue)
                .frame(width: 2, height: 1)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "  ",
                style: TextStyle(backgroundStyle: AnyColor(Color16.blue))
            ),
        ])
    }

    @Test func framedRectangleFillWorksInBackgroundAndOverlay() {
        let background = ViewResolver.block(
            from: Text("A")
                .frame(width: 3, height: 2, alignment: .topLeading)
                .background(alignment: .topLeading) {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: 3, height: 2, alignment: .topLeading)
                }
        )
        let overlay = ViewResolver.block(
            from: Text("A")
                .frame(width: 3, height: 2, alignment: .topLeading)
                .overlay(alignment: .topLeading) {
                    Rectangle()
                        .fill(.red)
                        .frame(width: 3, height: 2, alignment: .topLeading)
                }
        )

        #expect(background?.width == 3)
        #expect(background?.height == 2)
        #expect(background?.lines == ["A  ", "   "])
        #expect(overlay?.width == 3)
        #expect(overlay?.height == 2)
        #expect(overlay?.runs == [
            RenderedRun(
                text: "   ",
                row: 0,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(
                text: "   ",
                row: 1,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }
}
