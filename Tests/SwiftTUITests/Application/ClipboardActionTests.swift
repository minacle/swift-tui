import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Clipboard Actions")
struct ClipboardActionTests {

    @Test
    func `copy actions accept strings and selection substrings while paste actions return text`() {
        var copied: [String] = []
        let copy = CopyAction {
            copied.append($0)
        }
        copy("literal")

        let text = "A👨‍👩‍👧‍👦한"
        let lowerBound = text.index(after: text.startIndex)
        let upperBound = text.index(after: lowerBound)
        let selection = TextSelection(range: lowerBound..<upperBound)
        guard case .selection(let range) = selection.indices else {
            Issue.record("Expected a single text selection")
            return
        }
        copy(text[range])

        let paste = PasteAction {
            "붙여넣기"
        }

        #expect(copied == ["literal", "👨‍👩‍👧‍👦"])
        #expect(paste() == "붙여넣기")
    }

    @Test
    func `default clipboard actions discard copied text and return no pasted text`() {
        let environment = EnvironmentValues()

        environment.copy("discarded")

        #expect(environment.paste() == nil)
    }

    @Test
    func `clipboard actions captured from an environment snapshot remain callable`() {
        var copied: [String] = []
        let probe = ClipboardActionProbe()
        let view = CapturedClipboardActionsView(probe: probe)
            .environment(\.copy, CopyAction {
                copied.append($0)
            })
            .environment(\.paste, PasteAction {
                "snapshot"
            })

        _ = ViewResolver.text(from: view)
        probe.copy?("selected")

        #expect(copied == ["selected"])
        #expect(probe.paste?() == "snapshot")
    }
}
