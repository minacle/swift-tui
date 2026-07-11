import Testing
@testable import SwiftTUIRuns

@Suite("Run Wrapping")
struct RunWrappingTests {

    @Test
    func `emoji CJK combining marks and zero-width spaces wrap by terminal grapheme width`() {
        #expect(lines(of: "A👨‍👩‍👧‍👦BC", columns: 3) == ["A👨‍👩‍👧‍👦", "BC"])
        #expect(lines(of: "한국어문장", columns: 4) == ["한국", "어문", "장"])
        #expect(lines(of: "e\u{0301}e", columns: 1) == ["e\u{0301}", "e"])
        #expect(lines(of: "ab\u{200B}cd", columns: 2) == ["ab\u{200B}", "cd"])
    }

    @Test
    func `a no-break space suppresses wrapping inside its adjacent text`() {
        #expect(lines(of: "A\u{00A0}B C", columns: 3) == ["A\u{00A0}B", "C"])
    }

    @Test
    func `CRLF NEL and trailing newlines preserve mandatory rows`() {
        #expect(lines(of: "A\r\nB\u{0085}C\n", columns: nil) == ["A", "B", "C", ""])
    }

    @Test
    func `legal punctuation opportunities keep punctuation with preceding words`() {
        #expect(lines(of: "Hello, world. Next", columns: 7) == ["Hello,", "world.", "Next"])
        #expect(lines(of: "Wait! What? Yes.", columns: 6) == ["Wait!", "What?", "Yes."])
        #expect(lines(of: "Key: value; next", columns: 7) == ["Key:", "value;", "next"])
    }

    @Test
    func `emergency wrapping avoids leading punctuation when space permits`() {
        #expect(lines(of: "Hello, world. Next", columns: 5) == ["Hell", "o,", "worl", "d.", "Next"])
        #expect(lines(of: "(AB) [CD] {EF}", columns: 3) == ["(A", "B)", "[C", "D]", "{E", "F}"])
    }

    @Test
    func `overflowing trailing spaces and following text retain source order`() {
        let line = "Lorem ipsum dolor sit amet."

        #expect(lines(of: line + "  ", columns: 28) == [line + " ", " "])
        #expect(lines(of: line + "  a", columns: 28) == [line + " ", " a"])
    }

    @Test
    func `a fitting width narrower than the first wide grapheme yields an empty row`() {
        #expect(lines(of: "한A", columns: 1) == [""])
    }

    private func lines(of content: String, columns: Int?) -> [String] {
        RunGroup(content).layout(fittingColumns: columns).lines.map {
            $0.runs.map(\.content).joined()
        }
    }
}
