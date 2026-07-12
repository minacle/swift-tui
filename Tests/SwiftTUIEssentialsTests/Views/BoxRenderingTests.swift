import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Box Rendering")
struct BoxRenderingTests {

    @Test
    func `a one-cell box renders as a cross`() {
        let block = ViewResolver.block(
            from: Box()
                .frame(width: 1, height: 1)
        )

        #expect(block?.lines == ["┼"])
    }

    @Test
    func `a one-row box renders side tees joined by a horizontal line`() {
        let block = ViewResolver.block(
            from: Box()
                .frame(width: 3, height: 1)
        )

        #expect(block?.lines == ["├─┤"])
    }

    @Test
    func `a one-column box renders top and bottom tees joined vertically`() {
        let block = ViewResolver.block(
            from: Box()
                .frame(width: 1, height: 3)
        )

        #expect(block?.lines == ["┬", "│", "┴"])
    }

    @Test
    func `a box adds a regular border and offsets its content into the interior`() {
        let block = ViewResolver.block(
            from: Box {
                Text("A")
            }
        )

        #expect(block?.width == 3)
        #expect(block?.height == 3)
        #expect(block?.lines == [
            "┌─┐",
            "│A│",
            "└─┘",
        ])
        #expect(block?.runs.contains(RenderedRun(text: "A", row: 1, column: 1)) == true)
    }

    @Test
    func `a RoundedBox adds rounded corners and offsets its content into the interior`() {
        let block = ViewResolver.block(
            from: RoundedBox {
                Text("A")
            }
        )

        #expect(block?.width == 3)
        #expect(block?.height == 3)
        #expect(block?.lines == [
            "╭─╮",
            "│A│",
            "╰─╯",
        ])
        #expect(block?.runs.contains(RenderedRun(text: "A", row: 1, column: 1)) == true)
    }

    @Test
    func `an empty RoundedBox fills its proposed size with a rounded border`() {
        let block = ViewResolver.block(
            from: RoundedBox()
                .frame(width: 4, height: 3)
        )

        #expect(block?.lines == [
            "╭──╮",
            "│  │",
            "╰──╯",
        ])
    }

    @Test
    func `a collapsed RoundedBox uses regular tees and a cross`() {
        let cell = ViewResolver.block(
            from: RoundedBox()
                .frame(width: 1, height: 1)
        )
        let row = ViewResolver.block(
            from: RoundedBox()
                .frame(width: 3, height: 1)
        )
        let column = ViewResolver.block(
            from: RoundedBox()
                .frame(width: 1, height: 3)
        )

        #expect(cell?.lines == ["┼"])
        #expect(row?.lines == ["├─┤"])
        #expect(column?.lines == ["┬", "│", "┴"])
    }

    @Test
    func `a frame-constrained box clips content to its interior`() {
        let block = ViewResolver.block(
            from: Box {
                Text("AB")
            }
            .frame(width: 3, height: 3)
        )

        #expect(block?.lines == [
            "┌─┐",
            "│A│",
            "└─┘",
        ])
    }

    @Test
    func `a two-by-two box leaves no room for content`() {
        let block = ViewResolver.block(
            from: Box {
                Text("A")
            }
            .frame(width: 2, height: 2)
        )

        #expect(block?.lines == [
            "┌┐",
            "└┘",
        ])
    }

    @Test
    func `heavy and double boxes use their respective line-drawing characters`() {
        let heavy = ViewResolver.block(
            from: HeavyBox()
                .frame(width: 3, height: 3)
        )
        let double = ViewResolver.block(
            from: DoubleBox()
                .frame(width: 3, height: 3)
        )

        #expect(heavy?.lines == [
            "┏━┓",
            "┃ ┃",
            "┗━┛",
        ])
        #expect(double?.lines == [
            "╔═╗",
            "║ ║",
            "╚═╝",
        ])
    }

    @Test
    func `box borders preserve only foreground color, background color, and dim styling`() {
        let block = ViewResolver.block(
            from: Box {
                Text("A")
            }
            .foregroundStyle(.red)
            ._backgroundStyle(.blue)
            .bold()
            .dim()
            .italic()
            .underline()
            .strikethrough()
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "┌─┐",
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    backgroundStyle: AnyColor(Color16.blue),
                    isDim: true
                )
            ),
            RenderedRun(
                text: "│",
                row: 1,
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    backgroundStyle: AnyColor(Color16.blue),
                    isDim: true
                )
            ),
            RenderedRun(
                text: "│",
                row: 1,
                column: 2,
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    backgroundStyle: AnyColor(Color16.blue),
                    isDim: true
                )
            ),
            RenderedRun(
                text: "└─┘",
                row: 2,
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    backgroundStyle: AnyColor(Color16.blue),
                    isDim: true
                )
            ),
            RenderedRun(
                text: "A",
                row: 1,
                column: 1,
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    backgroundStyle: AnyColor(Color16.blue),
                    isBold: true,
                    isDim: true,
                    isItalic: true,
                    isUnderline: true,
                    isStrikethrough: true
                )
            ),
        ])
    }

    @Test
    func `box border terminal output emits only foreground, background, and dim SGR styles`() {
        let output = TerminalScreenRenderer.screen(
            for: ViewResolver.block(
                from: Box()
                    .frame(width: 1, height: 1)
                    .foregroundStyle(.red)
                    ._backgroundStyle(.blue)
                    .bold()
                    .dim()
                    .italic()
                    .underline()
                    .strikethrough()
            )!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(
            output == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[2m\u{001B}[31m\u{001B}[44m┼\u{001B}[22m\u{001B}[39m\u{001B}[49m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `a box offsets nested scroll, hit, and focus regions into its interior`() {
        let runtime = StateRuntime()
        let view = Box {
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            .scrollPosition(.constant(ScrollPosition(x: 1)))
            .onTapGesture {}
            .focusable()
        }
        .frame(width: 5, height: 3)

        let block = runtime.block(from: view)

        #expect(block?.lines == [
            "┌───┐",
            "│BCD│",
            "└───┘",
        ])
        #expect(block?.scrollRegions.map(\.frame) == [
            RenderedRect(x: 1, y: 1, width: 3, height: 1),
        ])
        #expect(block?.hitRegions.map(\.frame) == [
            RenderedRect(x: 1, y: 1, width: 3, height: 1),
        ])
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(x: 1, y: 1, width: 3, height: 1),
        ])
    }
}
