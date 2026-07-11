import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

func renderUntilStable<Content: View>(
    _ runtime: StateRuntime,
    view: Content,
    in proposal: RenderProposal? = nil,
    maximumPasses: Int = 8
) -> Int {
    for pass in 1...maximumPasses {
        _ = runtime.block(from: view, in: proposal)
        if !runtime.consumeInvalidation() {
            return pass
        }
    }

    return maximumPasses + 1
}

func selectionCharacterOffsets(
    _ selection: TextSelection?,
    in text: String
) -> Range<Int>? {
    guard let selection else {
        return nil
    }

    let range: Range<String.Index>
    switch selection.indices {
    case .selection(let selection):
        range = selection
    }

    guard
        let lowerBound = String.Index(range.lowerBound, within: text),
        let upperBound = String.Index(range.upperBound, within: text)
    else {
        return nil
    }

    let lowerOffset = text.distance(from: text.startIndex, to: lowerBound)
    let upperOffset = text.distance(from: text.startIndex, to: upperBound)
    return lowerOffset..<upperOffset
}

func textFieldOverflowInput() -> String {
    "https://example.com/" + String(repeating: "abcdefghijklmnopqrstuvwxyz0123456789", count: 8)
}

func typeText(_ text: String, into runtime: StateRuntime) {
    for character in text {
        #expect(
            runtime.dispatch(
                KeyPress(
                    key: KeyEquivalent(character),
                    characters: String(character)
                )
            ) == .handled
        )
    }
}
