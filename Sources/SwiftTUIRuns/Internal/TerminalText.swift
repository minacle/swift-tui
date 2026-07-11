import Foundation

enum TerminalText {

    static func columnWidth(_ text: String) -> Int {
        text.reduce(into: 0) { width, character in
            width += columnWidth(of: character)
        }
    }

    static func columnWidth(
        _ text: String,
        upToCharacterOffset offset: Int
    ) -> Int {
        columnWidth(text.sliceCharacters(lowerBound: 0, upperBound: offset))
    }

    private static func columnWidth(of character: Character) -> Int {
        let scalars = character.unicodeScalars
        let usesTextPresentation = scalars.contains { $0.value == 0xFE0E }
        let usesEmojiPresentation = scalars.contains {
            $0.value == 0xFE0F || $0.properties.isEmojiPresentation
        }
        if !usesTextPresentation && usesEmojiPresentation {
            return 2
        }

        return scalars.reduce(into: 0) { width, scalar in
            width += columnWidth(of: scalar)
        }
    }

    private static func columnWidth(of scalar: Unicode.Scalar) -> Int {
        let value = scalar.value
        if value == 0 || value < 32 || (0x7F..<0xA0).contains(value) {
            return 0
        }
        if isZeroWidthScalar(value) || isCombiningScalar(value) {
            return 0
        }
        return isWideScalar(value) ? 2 : 1
    }

    private static func isZeroWidthScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x00AD,
             0x200B...0x200D,
             0x2060,
             0xFE00...0xFE0F,
             0xE0100...0xE01EF:
            true
        default:
            false
        }
    }

    private static func isCombiningScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x0300...0x036F,
             0x1AB0...0x1AFF,
             0x1DC0...0x1DFF,
             0x20D0...0x20FF,
             0xFE20...0xFE2F:
            true
        default:
            false
        }
    }

    private static func isWideScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x1100...0x115F,
             0x2329...0x232A,
             0x2E80...0xA4CF,
             0xAC00...0xD7A3,
             0xF900...0xFAFF,
             0xFE10...0xFE19,
             0xFE30...0xFE6F,
             0xFF00...0xFF60,
             0xFFE0...0xFFE6,
             0x1F300...0x1FAFF,
             0x20000...0x3FFFD:
            true
        default:
            false
        }
    }
}

extension String {

    func sliceCharacters(lowerBound: Int, upperBound: Int) -> String {
        let lowerOffset = max(min(lowerBound, count), 0)
        let upperOffset = max(min(max(upperBound, lowerOffset), count), 0)
        let lowerIndex = index(startIndex, offsetBy: lowerOffset)
        let upperIndex = index(startIndex, offsetBy: upperOffset)
        return String(self[lowerIndex..<upperIndex])
    }
}
