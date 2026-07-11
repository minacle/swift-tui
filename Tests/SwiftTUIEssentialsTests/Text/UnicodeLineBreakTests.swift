import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Unicode Line Breaking")
struct UnicodeLineBreakTests {

    @Test
    func `a zero-width space creates an allowed line-break opportunity`() {
        #expect(lineBreakOffsets(in: "ab\u{200B}cd") == [3])
        #expect(lineBreakKinds(in: "ab\u{200B}cd") == ["allowed"])
    }

    @Test
    func `a word joiner suppresses breaks inside the joined text`() {
        #expect(lineBreakOffsets(in: "A\u{2060}B C") == [4])
    }

    @Test
    func `spaces after common punctuation expose allowed line-break positions`() {
        #expect(lineBreakOffsets(in: "Hello, world. Next") == [7, 14])
        #expect(lineBreakOffsets(in: "Wait! What? Yes.") == [6, 12])
        #expect(lineBreakOffsets(in: "Key: value; next") == [5, 12])
    }

    @Test
    func `closing quotes and brackets stay attached to the preceding token`() {
        #expect(lineBreakOffsets(in: "\"Hello\" next") == [8])
        #expect(lineBreakOffsets(in: "'Hello' next") == [8])
        #expect(lineBreakOffsets(in: "(AB) CD") == [5])
        #expect(lineBreakOffsets(in: "[AB] CD") == [5])
        #expect(lineBreakOffsets(in: "{AB} CD") == [5])
    }

    @Test
    func `numeric separators and percent signs stay inside one number`() {
        #expect(lineBreakOffsets(in: "A 1,234.56% B") == [2, 12])
    }

    @Test
    func `hyphens and slashes expose their allowed line-break positions`() {
        #expect(lineBreakOffsets(in: "pre-fix / path/to/file") == [4, 10, 15, 18])
    }

    @Test
    func `a newline creates a mandatory line-break opportunity`() {
        #expect(lineBreakOffsets(in: "A\nB") == [2])
        #expect(lineBreakKinds(in: "A\nB") == ["mandatory"])
    }
}

private func lineBreakOffsets(in text: String) -> [Int] {
    UnicodeLineBreak.opportunities(in: text).map {
        text.distance(from: text.startIndex, to: $0.index)
    }
}

private func lineBreakKinds(in text: String) -> [String] {
    UnicodeLineBreak.opportunities(in: text).map {
        switch $0.kind {
        case .allowed:
            "allowed"
        case .mandatory:
            "mandatory"
        }
    }
}
