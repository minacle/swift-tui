import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Terminal Screen Rendering")
struct TerminalScreenRenderingTests {

    @Test
    func `TextRenderer centers a text frame in the terminal viewport`() {
        let frame = TextRenderer.frame(
            for: "Hello",
            in: TerminalViewportSize(columns: 400, rows: 240)
        )

        #expect(frame == TextFrame(text: "Hello", row: 120, column: 198))
    }

    @Test
    func `a full-screen render clears the terminal, positions centered text, and hides the caret`() {
        let output = TextRenderer.screen(
            for: "Hello",
            in: TerminalViewportSize(columns: 10, rows: 5)
        )

        #expect(output == "\u{001B}[2J\u{001B}[3;3HHello\u{001B}[?25l")
    }

    @Test
    func `a full-screen render centers each line of a multiline block`() {
        let output = TextRenderer.screen(
            for: RenderedBlock(lines: ["A", "B"]),
            in: TerminalViewportSize(columns: 10, rows: 5)
        )

        #expect(output == "\u{001B}[2J\u{001B}[2;5HA\u{001B}[3;5HB\u{001B}[?25l")
    }

    @Test
    func `a full-screen render moves directly between separated runs without writing layout spaces`() {
        let block = ViewResolver.block(
            from: HStack(spacing: 3) {
                Text("A")
                Text("B")
            }
        )!
        let output = TextRenderer.screen(
            for: block,
            in: TerminalViewportSize(columns: 10, rows: 5)
        )

        #expect(output == "\u{001B}[2J\u{001B}[3;3HA\u{001B}[3;7HB\u{001B}[?25l")
        #expect(!output.contains(" "))
    }

    @Test
    func `a full-screen render preserves literal spaces inside a text run`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A B"))!,
            in: TerminalViewportSize(columns: 7, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;3HA B\u{001B}[?25l")
    }

    @Test
    func `a full-screen render wraps 16-color foreground text in matching SGR sequences`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").foregroundStyle(.red))!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[31mA\u{001B}[39m\u{001B}[?25l")
    }

    @Test
    func `a full-screen render wraps 256-color foreground text in matching SGR sequences`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").foregroundStyle(Color256(rawValue: 196)))!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(
            output
                == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[38;5;196mA\u{001B}[39m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `a full-screen render wraps true-color foreground text in matching SGR sequences`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(
                from: Text("A").foregroundStyle(TrueColor(red: 1, green: 2, blue: 3))
            )!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(
            output
                == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[38;2;1;2;3mA\u{001B}[39m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `a full-screen render wraps 16-color background text in matching SGR sequences`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").background(.red))!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[41mA\u{001B}[49m\u{001B}[?25l")
    }

    @Test
    func `a full-screen render wraps 256-color background text in matching SGR sequences`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").background(Color256(rawValue: 196)))!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(
            output
                == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[48;5;196mA\u{001B}[49m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `a full-screen render wraps true-color background text in matching SGR sequences`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(
                from: Text("A").background(TrueColor(red: 1, green: 2, blue: 3))
            )!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(
            output
                == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[48;2;1;2;3mA\u{001B}[49m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `an explicit default background overrides an inherited background with reset SGR sequences`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(
                from: VStack(alignment: .leading) {
                    Text("A")
                    Text("B")
                        ._backgroundStyle(.default)
                }
                ._backgroundStyle(.red)
            )!,
            in: TerminalViewportSize(columns: 1, rows: 2)
        )

        #expect(
            output
                == "\u{001B}[2J"
                + "\u{001B}[1;1H\u{001B}[41mA\u{001B}[49m"
                + "\u{001B}[2;1H\u{001B}[49mB\u{001B}[49m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `screen output renders bold SGR`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").bold())!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[1mA\u{001B}[22m\u{001B}[?25l")
    }

    @Test
    func `screen output renders dim SGR`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").dim())!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[2mA\u{001B}[22m\u{001B}[?25l")
    }

    @Test
    func `screen output renders italic SGR`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").italic())!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[3mA\u{001B}[23m\u{001B}[?25l")
    }

    @Test
    func `screen output renders underline SGR`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").underline())!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[4mA\u{001B}[24m\u{001B}[?25l")
    }

    @Test
    func `screen output renders strikethrough SGR`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("A").strikethrough())!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[9mA\u{001B}[29m\u{001B}[?25l")
    }

    @Test
    func `combined text styles emit SGR sequences in deterministic enable and reset order`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(
                from: Text("A")
                    .bold()
                    .dim()
                    .italic()
                    .underline()
                    .strikethrough()
                    .foregroundStyle(.brightCyan)
                    .background(.blue)
            )!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(
            output
                == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[1m\u{001B}[2m\u{001B}[3m\u{001B}[4m\u{001B}[9m\u{001B}[96m\u{001B}[44m"
                + "A"
                + "\u{001B}[22m\u{001B}[23m\u{001B}[24m\u{001B}[29m\u{001B}[39m\u{001B}[49m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `explicit default foreground and disabled styles override inherited text styling`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(
                from: VStack(alignment: .leading) {
                    Text("A")
                    Text("B")
                        .foregroundStyle(.default)
                        .bold(false)
                        .dim(false)
                        .italic(false)
                        .underline(false)
                        .strikethrough(false)
                }
                .foregroundStyle(.red)
                .bold()
                .dim()
                .italic()
                .underline()
                .strikethrough()
            )!,
            in: TerminalViewportSize(columns: 1, rows: 2)
        )

        #expect(
            output
                == "\u{001B}[2J"
                + "\u{001B}[1;1H"
                + "\u{001B}[1m\u{001B}[2m\u{001B}[3m\u{001B}[4m\u{001B}[9m\u{001B}[31m"
                + "A"
                + "\u{001B}[22m\u{001B}[23m\u{001B}[24m\u{001B}[29m\u{001B}[39m"
                + "\u{001B}[2;1H\u{001B}[39mB\u{001B}[39m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `a full-screen render shows and positions a rendered caret`() {
        let output = TextRenderer.screen(
            for: RenderedBlock(lines: ["Hello"], caret: RenderedCaret(column: 2)),
            in: TerminalViewportSize(columns: 10, rows: 5)
        )

        #expect(output == "\u{001B}[2J\u{001B}[3;3HHello\u{001B}[?25h\u{001B}[3;5H")
    }

    @Test
    func `a full-screen render clips plain text to the viewport width`() {
        let output = TextRenderer.screen(
            for: RenderedBlock(lines: ["ABCDE"]),
            in: TerminalViewportSize(columns: 3, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1HABC\u{001B}[?25l")
    }

    @Test
    func `a full-screen render clips styled text without losing its SGR wrapping`() {
        let output = TextRenderer.screen(
            for: ViewResolver.block(from: Text("ABCDE").foregroundStyle(.blue).dim())!,
            in: TerminalViewportSize(columns: 3, rows: 1)
        )

        #expect(
            output
                == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[2m\u{001B}[34m"
                + "ABC"
                + "\u{001B}[22m\u{001B}[39m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `caret positioning counts terminal cells occupied by wide text`() {
        let output = TextRenderer.screen(
            for: RenderedBlock(lines: ["한A"], caret: RenderedCaret(column: 3)),
            in: TerminalViewportSize(columns: 10, rows: 5)
        )

        #expect(output == "\u{001B}[2J\u{001B}[3;4H한A\u{001B}[?25h\u{001B}[3;7H")
    }

    @Test
    func `a differential render writes only the changed character`() {
        let output = TextRenderer.diff(
            from: RenderedBlock(lines: ["ABC"]),
            to: RenderedBlock(lines: ["AXC"]),
            in: TerminalViewportSize(columns: 3, rows: 1)
        )

        #expect(output == "\u{001B}[1;2HX\u{001B}[?25l")
    }

    @Test
    func `a differential render overwrites removed trailing text with spaces`() {
        let output = TextRenderer.diff(
            from: RenderedBlock(lines: ["ABCD"]),
            to: RenderedBlock(runs: [RenderedRun(text: "A")], width: 4, height: 1),
            in: TerminalViewportSize(columns: 4, rows: 1)
        )

        #expect(output == "\u{001B}[1;2H   \u{001B}[?25l")
    }

    @Test
    func `a differential render rewrites unchanged text when its style changes`() {
        let output = TextRenderer.diff(
            from: RenderedBlock(lines: ["A"]),
            to: ViewResolver.block(from: Text("A").foregroundStyle(.blue).bold())!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(output == "\u{001B}[1;1H\u{001B}[1m\u{001B}[34mA\u{001B}[22m\u{001B}[39m\u{001B}[?25l")
    }

    @Test
    func `a differential render can update only caret visibility and position`() {
        let output = TextRenderer.diff(
            from: RenderedBlock(lines: ["A"], caret: RenderedCaret(column: 0)),
            to: RenderedBlock(lines: ["A"], caret: RenderedCaret(column: 1)),
            in: TerminalViewportSize(columns: 2, rows: 1)
        )

        #expect(output == "\u{001B}[?25h\u{001B}[1;2H")
    }

    @Test
    func `redraw performs a full-screen render when the viewport changes`() {
        let output = TextRenderer.redraw(
            from: RenderedBlock(lines: ["A"]),
            previousViewport: TerminalViewportSize(columns: 1, rows: 1),
            to: RenderedBlock(lines: ["A"]),
            in: TerminalViewportSize(columns: 2, rows: 1)
        )

        #expect(output == "\u{001B}[2J\u{001B}[1;1HA\u{001B}[?25l")
    }

    @Test
    func `screen output diff clears wide-character continuation when replacing with narrow text`() {
        let output = TextRenderer.diff(
            from: RenderedBlock(lines: ["한"]),
            to: RenderedBlock(lines: ["A"]),
            in: TerminalViewportSize(columns: 2, rows: 1)
        )

        #expect(output == "\u{001B}[1;1HA \u{001B}[?25l")
    }

    @Test
    func `screen output diff clears an emoji ZWJ continuation when replacing with narrow text`() {
        let output = TextRenderer.diff(
            from: RenderedBlock(lines: ["👨‍👩‍👧‍👦"]),
            to: RenderedBlock(lines: ["A"]),
            in: TerminalViewportSize(columns: 2, rows: 1)
        )

        #expect(output == "\u{001B}[1;1HA \u{001B}[?25l")
    }

    @Test
    func `a differential render overwrites both cells when narrow text becomes a wide character`() {
        let output = TextRenderer.diff(
            from: RenderedBlock(lines: ["AB"]),
            to: RenderedBlock(lines: ["한"]),
            in: TerminalViewportSize(columns: 2, rows: 1)
        )

        #expect(output == "\u{001B}[1;1H한\u{001B}[?25l")
    }

    @Test
    func `editing a full-screen background TextEditor produces a minimal diff without clearing the screen`() {
        let runtime = StateRuntime()
        let view = FullScreenBackgroundTextEditorEditingView()
        let proposal = RenderProposal(columns: 6, rows: 2)

        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let previousBlock = runtime.block(from: view, in: proposal)!
        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
        let block = runtime.block(from: view, in: proposal)!

        let output = TextRenderer.diff(
            from: previousBlock,
            to: block,
            in: TerminalViewportSize(columns: 6, rows: 2)
        )

        #expect(!output.contains(TerminalControl.clearScreenSequence))
        #expect(output == "\u{001B}[1;1H\u{001B}[41ma\u{001B}[49m\u{001B}[?25h\u{001B}[1;2H")
    }
}
