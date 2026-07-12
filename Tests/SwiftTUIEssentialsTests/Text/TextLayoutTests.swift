import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Text Layout and Wrapping")
struct TextLayoutTests {

    private let emojiZWJSequences = [
        "👩‍❤️‍💋‍👨",
        "👨‍👩‍👧‍👦",
    ]

    @Test
    func `a proposed width wraps text at word boundaries`() {
        let block = ViewResolver.block(
            from: Text("Lorem ipsum dolor"),
            in: RenderProposal(columns: 8)
        )

        #expect(block?.lines == ["Lorem", "ipsum", "dolor"])
    }

    @Test
    func `width constraints and explicit newlines form separate visual lines`() {
        let block = ViewResolver.block(
            from: Text("Alpha beta\ngamma"),
            in: RenderProposal(columns: 7)
        )

        #expect(block?.lines == ["Alpha", "beta ", "gamma"])
    }

    @Test
    func `words wider than the proposal split at character boundaries`() {
        let block = ViewResolver.block(
            from: Text("ABCDEFGHIJ"),
            in: RenderProposal(columns: 3)
        )

        #expect(block?.lines == ["ABC", "DEF", "GHI", "J  "])
    }

    @Test
    func `trailing spaces survive when they overflow onto a new visual line`() {
        let line = "Lorem ipsum dolor sit amet."
        let block = ViewResolver.block(
            from: Text(line + "  "),
            in: RenderProposal(columns: 28)
        )

        #expect(block?.lines == [
            line + " ",
            String(repeating: " ", count: 28),
        ])
    }

    @Test
    func `overflowing spaces remain before the next wrapped character`() {
        let line = "Lorem ipsum dolor sit amet."
        let block = ViewResolver.block(
            from: Text(line + "  a"),
            in: RenderProposal(columns: 28)
        )

        #expect(block?.lines == [
            line + " ",
            " a" + String(repeating: " ", count: 26),
        ])
    }

    @Test
    func `lineLimit truncates the final visible line with an ellipsis`() {
        let block = ViewResolver.block(
            from: Text("Lorem ipsum dolor").lineLimit(2),
            in: RenderProposal(columns: 8)
        )

        #expect(block?.lines == ["Lorem   ", "ipsum..."])
    }

    @Test
    func `head, middle, and tail truncation retain their respective text segments`() {
        let text = "Alpha beta gamma"
        let proposal = RenderProposal(columns: 8)

        let tail = ViewResolver.block(
            from: Text(text).lineLimit(1).truncationMode(.tail),
            in: proposal
        )
        let head = ViewResolver.block(
            from: Text(text).lineLimit(1).truncationMode(.head),
            in: proposal
        )
        let middle = ViewResolver.block(
            from: Text(text).lineLimit(1).truncationMode(.middle),
            in: proposal
        )

        #expect(tail?.lines == ["Alpha..."])
        #expect(head?.lines == ["...gamma"])
        #expect(middle?.lines == ["Alp...ma"])
    }

#if canImport(Darwin)
    @Test
    func `head truncation preserves styling on the retained attributed suffix`() {
        var attributed = AttributedString("Alpha beta gamma")
        attributed[attributed.range(of: "gamma")!].inlinePresentationIntent = .stronglyEmphasized

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed).lineLimit(1).truncationMode(.head),
            in: RenderProposal(columns: 8)
        )

        #expect(block?.runs == [
            RenderedRun(text: "..."),
            RenderedRun(text: "gamma", column: 3, style: TextStyle(isBold: true)),
        ])
    }
#endif

    @Test
    func `truncationMode defaults to tail and propagates through the environment`() {
        #expect(EnvironmentValues().truncationMode == .tail)
        #expect(ViewResolver.text(from: TruncationModeEnvironmentMarkerText()) == "tail")
        #expect(
            ViewResolver.text(
                from: TruncationModeEnvironmentMarkerText().truncationMode(.middle)
            ) == "middle"
        )
    }

    @Test
    func `multiline alignment uses the widest natural line as its alignment width`() {
        let text = "A\nBBB"

        let leading = ViewResolver.block(
            from: Text(text).multilineTextAlignment(.leading)
        )
        let center = ViewResolver.block(
            from: Text(text).multilineTextAlignment(.center)
        )
        let trailing = ViewResolver.block(
            from: Text(text).multilineTextAlignment(.trailing)
        )

        #expect(leading?.lines == ["A  ", "BBB"])
        #expect(center?.lines == [" A ", "BBB"])
        #expect(trailing?.lines == ["  A", "BBB"])
    }

    @Test
    func `multiline alignment does not expand a single-line text view to its proposal`() {
        let block = ViewResolver.block(
            from: Text("A").multilineTextAlignment(.center),
            in: RenderProposal(columns: 5)
        )

        #expect(block?.width == 1)
        #expect(block?.lines == ["A"])
    }

    @Test
    func `multilineTextAlignment defaults to leading and propagates through the environment`() {
        #expect(EnvironmentValues().multilineTextAlignment == .leading)
        #expect(ViewResolver.text(from: MultilineTextAlignmentEnvironmentMarkerText()) == "leading")
        #expect(
            ViewResolver.text(
                from: MultilineTextAlignmentEnvironmentMarkerText()
                    .multilineTextAlignment(.trailing)
            ) == "trailing"
        )
    }

    @Test
    func `a space-reserving line limit pads text to the requested number of rows`() {
        let block = ViewResolver.block(from: Text("Hello").lineLimit(3, reservesSpace: true))

        #expect(block?.height == 3)
        #expect(block?.lines == ["Hello", "     ", "     "])
    }

    @Test
    func `lineLimit defaults to nil in direct and property-wrapper environment reads`() {
        #expect(EnvironmentValues().lineLimit == nil)
        #expect(ViewResolver.text(from: LineLimitEnvironmentMarkerText()) == "nil")
    }

    @Test
    func `lineLimit exposes its value to descendant environment reads`() {
        let view = LineLimitEnvironmentMarkerText()
            .lineLimit(2)

        #expect(ViewResolver.text(from: view) == "2")
    }

    @Test
    func `lineLimit clamps zero to one before direct and rendered environment use`() {
        var environment = EnvironmentValues()
        environment.lineLimit = 0

        let block = ViewResolver.block(
            from: Text("Alpha beta").environment(\.lineLimit, Optional(0)),
            in: RenderProposal(columns: 5)
        )

        #expect(environment.lineLimit == 1)
        #expect(block?.lines == ["Al..."])
    }

    @Test
    func `an ancestor lineLimit truncates text inside its descendant view tree`() {
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("Alpha beta gamma")
        }
        .lineLimit(2)

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 6))

        #expect(block?.lines == ["Alpha ", "bet..."])
    }

    @Test
    func `a descendant nil lineLimit removes its ancestor's limit`() {
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("Alpha beta gamma")
                .lineLimit(nil)
        }
        .lineLimit(1)

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 6))

        #expect(block?.lines == ["Alpha", "beta ", "gamma"])
    }

    @Test
    func `wide characters wrap according to their terminal-cell widths`() {
        let block = ViewResolver.block(
            from: Text("한글AB"),
            in: RenderProposal(columns: 4)
        )

        #expect(block?.lines == ["한글", "AB  "])
    }

    @Test
    func `emoji ZWJ sequences remain intact immediately before automatic wrapping`() {
        for emoji in emojiZWJSequences {
            let block = ViewResolver.block(
                from: Text("A\(emoji)BC"),
                in: RenderProposal(columns: 4)
            )

            #expect(block?.lines == ["A\(emoji)", "BC "])
        }
    }

    @Test
    func `emoji ZWJ sequences remain intact at the automatic wrapping boundary`() {
        for emoji in emojiZWJSequences {
            let block = ViewResolver.block(
                from: Text("AB\(emoji)C"),
                in: RenderProposal(columns: 4)
            )

            #expect(block?.lines == ["AB\(emoji)", "C   "])
        }
    }

    @Test
    func `emoji ZWJ sequences move intact past the automatic wrapping boundary`() {
        for emoji in emojiZWJSequences {
            let block = ViewResolver.block(
                from: Text("ABC\(emoji)D"),
                in: RenderProposal(columns: 4)
            )

            #expect(block?.lines == ["ABC", "\(emoji)D"])
        }
    }

    @Test
    func `a proposal narrower than the first wide glyph produces an empty text line`() {
        let block = ViewResolver.block(
            from: Text("한A"),
            in: RenderProposal(columns: 1)
        )

        #expect(block?.lines == [""])
    }

    @Test
    func `a frame narrower than a wide glyph renders a blank clipped cell`() {
        let block = ViewResolver.block(
            from: Text("한A").frame(width: 1, height: 1)
        )

        #expect(block?.lines == [" "])
    }

    @Test
    func `CJK text wraps at Unicode break opportunities without spaces`() {
        let block = ViewResolver.block(
            from: Text("한국어문장"),
            in: RenderProposal(columns: 4)
        )

        #expect(block?.lines == ["한국", "어문", "장  "])
    }

    @Test
    func `a no-break space keeps adjacent characters on the same visual line`() {
        let block = ViewResolver.block(
            from: Text("A\u{00A0}B C"),
            in: RenderProposal(columns: 3)
        )

        #expect(block?.lines == ["A\u{00A0}B", "C  "])
    }

    @Test
    func `a zero-width space creates a wrapping boundary without occupying a column`() {
        let block = ViewResolver.block(
            from: Text("ab\u{200B}cd"),
            in: RenderProposal(columns: 2)
        )

        #expect(block?.lines == ["ab\u{200B}", "cd"])
    }

    @Test
    func `a combining sequence stays together on one visual line`() {
        let block = ViewResolver.block(
            from: Text("e\u{0301}e"),
            in: RenderProposal(columns: 1)
        )

        #expect(block?.lines == ["e\u{0301}", "e"])
    }

    @Test
    func `CRLF and NEL characters create mandatory visual line breaks`() {
        let block = ViewResolver.block(from: Text("A\r\nB\u{0085}C"))

        #expect(block?.lines == ["A", "B", "C"])
    }

    @Test
    func `a slash provides a wrapping boundary after itself`() {
        let block = ViewResolver.block(
            from: Text("aa/bb"),
            in: RenderProposal(columns: 3)
        )

        #expect(block?.lines == ["aa/", "bb "])
    }

    @Test
    func `commas and periods stay with preceding words at legal wrap widths`() {
        let block = ViewResolver.block(
            from: Text("Hello, world. Next"),
            in: RenderProposal(columns: 7)
        )

        #expect(block?.lines == ["Hello,", "world.", "Next  "])
    }

    @Test
    func `emergency wrapping keeps commas and periods with the preceding character`() {
        let block = ViewResolver.block(
            from: Text("Hello, world. Next"),
            in: RenderProposal(columns: 5)
        )

        #expect(block?.lines == ["Hell", "o,  ", "worl", "d.  ", "Next"])
    }

    @Test
    func `exclamation and question marks stay with preceding words at legal wrap widths`() {
        let block = ViewResolver.block(
            from: Text("Wait! What? Yes."),
            in: RenderProposal(columns: 6)
        )

        #expect(block?.lines == ["Wait!", "What?", "Yes. "])
    }

    @Test
    func `emergency wrapping keeps exclamation and question marks with the preceding character`() {
        let block = ViewResolver.block(
            from: Text("Wait! What? Yes."),
            in: RenderProposal(columns: 4)
        )

        #expect(block?.lines == ["Wai ", "t!  ", "Wha ", "t?  ", "Yes."])
    }

    @Test
    func `two-column emergency wrapping may place exclamation and question marks on separate visual lines`() {
        let block = ViewResolver.block(
            from: Text("Wait! What? Yes."),
            in: RenderProposal(columns: 2)
        )

        #expect(block?.lines == ["Wa", "it", "! ", "Wh", "at", "? ", "Ye", "s."])
    }

    @Test
    func `colons and semicolons stay with preceding words at legal wrap widths`() {
        let block = ViewResolver.block(
            from: Text("Key: value; next"),
            in: RenderProposal(columns: 7)
        )

        #expect(block?.lines == ["Key:  ", "value;", "next  "])
    }

    @Test
    func `emergency wrapping keeps colons and semicolons with the preceding character`() {
        let block = ViewResolver.block(
            from: Text("Key: value; next"),
            in: RenderProposal(columns: 5)
        )

        #expect(block?.lines == ["Key:", "valu", "e;  ", "next"])
    }

    @Test
    func `emergency wrapping does not separate Japanese closing punctuation`() {
        let block = ViewResolver.block(
            from: Text("こんにちは。\n元気です。"),
            in: RenderProposal(columns: 10)
        )

        #expect(block?.lines == ["こんにち  ", "は。      ", "元気です。"])
    }

    @Test
    func `quoted text stays grouped across Latin and CJK quotation marks`() {
        let doubleQuoted = ViewResolver.block(
            from: Text("\"Hello\" next"),
            in: RenderProposal(columns: 7)
        )
        let singleQuoted = ViewResolver.block(
            from: Text("'Hello' next"),
            in: RenderProposal(columns: 7)
        )
        let cornerQuoted = ViewResolver.block(
            from: Text("「東京」へ行く"),
            in: RenderProposal(columns: 8)
        )

        #expect(doubleQuoted?.lines == ["\"Hello\"", "next   "])
        #expect(singleQuoted?.lines == ["'Hello'", "next   "])
        #expect(cornerQuoted?.lines == ["「東京」", "へ行く  "])
    }

    @Test
    func `emergency wrapping keeps closing quotes with their preceding character`() {
        let block = ViewResolver.block(
            from: Text("\"Hi\" 'Yo'"),
            in: RenderProposal(columns: 3)
        )

        #expect(block?.lines == ["\"H", "i\"", "'Y", "o'"])
    }

    @Test
    func `parenthesized and bracketed text stays grouped at legal wrap widths`() {
        let parentheses = ViewResolver.block(
            from: Text("(AB) CD"),
            in: RenderProposal(columns: 4)
        )
        let brackets = ViewResolver.block(
            from: Text("[AB] CD"),
            in: RenderProposal(columns: 4)
        )
        let braces = ViewResolver.block(
            from: Text("{AB} CD"),
            in: RenderProposal(columns: 4)
        )

        #expect(parentheses?.lines == ["(AB)", "CD  "])
        #expect(brackets?.lines == ["[AB]", "CD  "])
        #expect(braces?.lines == ["{AB}", "CD  "])
    }

    @Test
    func `emergency wrapping keeps closing brackets with their preceding character`() {
        let block = ViewResolver.block(
            from: Text("(AB) [CD] {EF}"),
            in: RenderProposal(columns: 3)
        )

        #expect(block?.lines == ["(A", "B)", "[C", "D]", "{E", "F}"])
    }

    @Test
    func `CJK closing punctuation stays attached to its preceding characters`() {
        let block = ViewResolver.block(
            from: Text("東京、京都。大阪！奈良？"),
            in: RenderProposal(columns: 6)
        )

        #expect(block?.lines == ["東京、", "京都。", "大阪！", "奈良？"])
    }

    @Test
    func `numeric separators and percent signs stay grouped on one visual line`() {
        let block = ViewResolver.block(
            from: Text("ID 1,234.56% OK"),
            in: RenderProposal(columns: 11)
        )

        #expect(block?.lines == ["ID       ", "1,234.56%", "OK       "])
    }

    @Test
    func `hyphens and slashes wrap only at their Unicode-allowed boundaries`() {
        let block = ViewResolver.block(
            from: Text("pre-fix / path/to/file"),
            in: RenderProposal(columns: 8)
        )

        #expect(block?.lines == ["pre-    ", "fix /   ", "path/to/", "file    "])
    }
}
