import Testing
@testable import SwiftTUIRuns

@Suite("Terminal Text Width")
struct TerminalTextWidthTests {

    @Test
    func `emoji ZWJ sequences occupy one two-column grapheme`() {
        #expect(TerminalText.columnWidth("👩‍❤️‍💋‍👨") == 2)
        #expect(TerminalText.columnWidth("👨‍👩‍👧‍👦") == 2)
    }

    @Test
    func `emoji presentation sequences occupy two columns`() {
        for text in ["❤️", "✈️", "1️⃣", "🇰🇷", "👍🏽"] {
            #expect(TerminalText.columnWidth(text) == 2)
        }
    }

    @Test
    func `variation selectors choose narrow text or wide emoji presentation`() {
        #expect(TerminalText.columnWidth("♥︎") == 1)
        #expect(TerminalText.columnWidth("♥️") == 2)
    }

    @Test
    func `mixed text adds terminal widths by grapheme`() {
        #expect(TerminalText.columnWidth("A👨‍👩‍👧‍👦한") == 5)
    }

    @Test
    func `combining zero-width and CJK text preserve their terminal widths`() {
        #expect(TerminalText.columnWidth("e\u{0301}") == 1)
        #expect(TerminalText.columnWidth("\u{200B}") == 0)
        #expect(TerminalText.columnWidth("한글") == 4)
    }
}
