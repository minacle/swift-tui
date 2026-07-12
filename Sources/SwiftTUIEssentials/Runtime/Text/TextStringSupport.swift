import SwiftTUIRuns

/// Supplies aggregate source-range queries used by SwiftTUI render adapters.
///
/// Each line remains the authority for terminal-cell measurement; this
/// extension only combines line results for unwrapped consumer content.
nonisolated extension RunLayout {

    var totalColumns: Int {
        lines.reduce(0) { $0 + $1.columns }
    }

    func columns(in sourceRange: Range<RunIndex>) -> Int {
        lines.reduce(0) { $0 + $1.columns(in: sourceRange) }
    }
}

extension String {

    nonisolated func sliceCharacters(lowerBound: Int, upperBound: Int) -> String {
        let lowerOffset = max(min(lowerBound, count), 0)
        let upperOffset = max(min(max(upperBound, lowerOffset), count), 0)
        let lowerIndex = index(startIndex, offsetBy: lowerOffset)
        let upperIndex = index(startIndex, offsetBy: upperOffset)
        return String(self[lowerIndex..<upperIndex])
    }

    mutating func insert(_ insertedText: String, atCharacterOffset offset: Int) {
        insert(contentsOf: insertedText, at: indexAtCharacterOffset(offset))
    }

    mutating func removeCharacter(atOffset offset: Int) {
        remove(at: indexAtCharacterOffset(offset))
    }

    mutating func replaceCharacters(in range: Range<Int>, with replacement: String) {
        let lowerBound = indexAtCharacterOffset(range.lowerBound)
        let upperBound = indexAtCharacterOffset(range.upperBound)
        replaceSubrange(lowerBound..<upperBound, with: replacement)
    }

    private func indexAtCharacterOffset(_ offset: Int) -> Index {
        index(startIndex, offsetBy: min(max(offset, 0), count))
    }
}

extension KeyPress {

    var isTextInsertion: Bool {
        guard key.isTextInputPrintableCharacter else {
            return false
        }

        guard !characters.isEmpty,
              modifiers.intersection([.control, .option, .command]).isEmpty else {
            return false
        }

        return characters.unicodeScalars.allSatisfy {
            $0.properties.generalCategory != .control
        }
    }
}

extension KeyEquivalent {

    fileprivate var isTextInputPrintableCharacter: Bool {
        switch self {
        case .upArrow, .downArrow, .leftArrow, .rightArrow,
                .clear, .delete, .deleteForward, .end, .escape,
                .home, .pageDown, .pageUp, .return, .tab:
            return false
        default:
            return true
        }
    }
}
