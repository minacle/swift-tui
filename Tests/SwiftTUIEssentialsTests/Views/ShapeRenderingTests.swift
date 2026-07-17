import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Shape Rendering")
struct ShapeRenderingTests {

    @Test
    func `a filled rectangle covers its frame with colored full-block cells`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .fill(.red)
                .frame(width: 3, height: 2)
        )

        #expect(block?.width == 3)
        #expect(block?.height == 2)
        #expect(block?.lines == ["███", "███"])
        #expect(block?.runs == [
            RenderedRun(
                text: "███",
                row: 0,
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(
                text: "███",
                row: 1,
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `accentColor shape fills resolve the nearest tint and preserve bounds when tint is cleared`() {
        let tinted = ViewResolver.block(
            from: Rectangle()
                .fill(.accentColor)
                .frame(width: 2, height: 1)
                .tint(.green)
        )
        let cleared = ViewResolver.block(
            from: Rectangle()
                .fill(.accentColor)
                .frame(width: 2, height: 1)
                .tint(Optional<Color16>.none)
        )

        #expect(tinted?.runs == [
            RenderedRun(
                text: "██",
                style: TextStyle(foregroundStyle: AnyColor(Color16.green))
            ),
        ])
        #expect(cleared?.runs.isEmpty == true)
        #expect(cleared?.width == 2)
        #expect(cleared?.height == 1)
        #expect(cleared?.lines == ["  "])
    }

    @Test
    func `a filled rectangle emits a foreground-color SGR sequence around its full-block cells`() {
        let output = TerminalScreenRenderer.screen(
            for: ViewResolver.block(
                from: Rectangle()
                    .fill(.red)
                    .frame(width: 2, height: 1)
            )!,
            in: TerminalViewportSize(columns: 2, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[31m██\u{001B}[39m\u{001B}[?25l")
    }

    @Test
    func `a plain rectangle uses foregroundStyle as its default fill`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .foregroundStyle(.red)
                .frame(width: 2, height: 1)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "██",
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `an empty half-cell edge style leaves the full-block fill unchanged`() {
        let plain = ViewResolver.block(
            from: Rectangle()
                .fill(.red)
                .frame(width: 3, height: 2)
        )
        let styled = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle())
                .fill(.red)
                .frame(width: 3, height: 2)
        )

        #expect(styled == plain)
    }

    @Test
    func `individual half-cell edges render on their selected sides`() {
        let top = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: .top))
                .fill(.red)
                .frame(width: 3, height: 3)
        )
        let bottom = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: .bottom))
                .fill(.red)
                .frame(width: 3, height: 3)
        )
        let leading = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: .leading))
                .fill(.red)
                .frame(width: 3, height: 3)
        )
        let trailing = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: .trailing))
                .fill(.red)
                .frame(width: 3, height: 3)
        )

        #expect(top?.lines == ["▄▄▄", "███", "███"])
        #expect(bottom?.lines == ["███", "███", "▀▀▀"])
        #expect(leading?.lines == ["▐██", "▐██", "▐██"])
        #expect(trailing?.lines == ["██▌", "██▌", "██▌"])
    }

    @Test
    func `combined half-cell edges use quarter-block glyphs at corners`() {
        let all = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: .all))
                .fill(.red)
                .frame(width: 3, height: 3)
        )
        let topLeading = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: [.top, .leading]))
                .fill(.red)
                .frame(width: 3, height: 3)
        )

        #expect(all?.lines == ["▗▄▖", "▐█▌", "▝▀▘"])
        #expect(topLeading?.lines == ["▗▄▄", "▐██", "▐██"])
    }

    @Test
    func `applying an edge style preserves the Rectangle type and replaces the previous edge style`() {
        let rectangle: Rectangle = Rectangle()
            .edge(style: RectangleHalfCellEdgeStyle(edges: .top))
            .edge(style: RectangleHalfCellEdgeStyle(edges: .bottom))
        let block = ViewResolver.block(
            from: rectangle
                .fill(.red)
                .frame(width: 3, height: 2)
        )

        #expect(block?.lines == ["███", "▀▀▀"])
    }

    @Test
    func `half-cell edges respect the rectangle size, offset, and fill color`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: [.top, .leading]))
                .size(width: 3, height: 2)
                .offset(x: 1, y: 1)
                .fill(.blue)
                .frame(width: 5, height: 4, alignment: .topLeading)
        )

        #expect(block?.lines == ["     ", " ▗▄▄ ", " ▐██ ", "     "])
        #expect(block?.runs == [
            RenderedRun(
                text: "▗▄▄",
                row: 1,
                column: 1,
                style: TextStyle(foregroundStyle: AnyColor(Color16.blue))
            ),
            RenderedRun(
                text: "▐██",
                row: 2,
                column: 1,
                style: TextStyle(foregroundStyle: AnyColor(Color16.blue))
            ),
        ])
    }

    @Test
    func `clipping away the original half-cell edges exposes full-block interior cells`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: [.top, .leading]))
                .size(width: 3, height: 3)
                .offset(x: -1, y: -1)
                .fill(.red)
                .frame(width: 2, height: 2, alignment: .topLeading)
        )

        #expect(block?.lines == ["██", "██"])
    }

    @Test
    func `opposing half-cell edges on a single-cell axis leave no filled area`() {
        let horizontal = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: .horizontal))
                .fill(.red)
                .frame(width: 1, height: 2)
        )
        let vertical = ViewResolver.block(
            from: Rectangle()
                .edge(style: RectangleHalfCellEdgeStyle(edges: .vertical))
                .fill(.red)
                .frame(width: 2, height: 1)
        )

        #expect(horizontal?.runs == [])
        #expect(horizontal?.lines == [" ", " "])
        #expect(vertical?.runs == [])
        #expect(vertical?.lines == ["  "])
    }

    @Test
    func `shape size changes the drawn rectangle without changing its layout bounds`() {
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
                text: "██",
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
        ])
        #expect(block?.lines == ["██  ", "    ", "    "])
    }

    @Test
    func `the width-and-height size overload matches the Size overload`() {
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

    @Test
    func `shape offset moves the drawn rectangle within its layout bounds`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .size(width: 2, height: 1)
                .offset(Point(column: 1, row: 1))
                .fill(.blue)
                .frame(width: 4, height: 3, alignment: .topLeading)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "██",
                row: 1,
                column: 1,
                style: TextStyle(foregroundStyle: AnyColor(Color16.blue))
            ),
        ])
    }

    @Test
    func `the x-and-y offset overload matches the Point overload`() {
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

    @Test
    func `a negative shape size draws no fill while preserving its layout frame`() {
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

    @Test
    func `a negative shape offset clips the fill to layout bounds`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .size(width: 3, height: 1)
                .offset(x: -1, y: 0)
                .fill(.red)
                .frame(width: 3, height: 1, alignment: .topLeading)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "██",
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `the last fill in a chain renders above earlier fills`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .fill(.red)
                .fill(.blue)
                .frame(width: 2, height: 1)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "██",
                style: TextStyle(foregroundStyle: AnyColor(Color16.blue))
            ),
        ])
    }

    @Test
    func `a filled rectangle renders behind base content in a background and over it in an overlay`() {
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
        #expect(background?.lines == ["A██", "███"])
        #expect(overlay?.width == 3)
        #expect(overlay?.height == 2)
        #expect(overlay?.runs == [
            RenderedRun(
                text: "███",
                row: 0,
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(
                text: "███",
                row: 1,
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
        ])
    }
}
