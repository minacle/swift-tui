enum TerminalText {

    static func columnWidth(_ text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { width, scalar in
            width += columnWidth(of: scalar)
        }
    }

    static func columnWidth(
        _ text: String,
        upToCharacterOffset offset: Int
    ) -> Int {
        columnWidth(text.sliceCharacters(lowerBound: 0, upperBound: offset))
    }

    static func columnWidth(
        _ text: String,
        lowerCharacterOffset: Int,
        upperCharacterOffset: Int
    ) -> Int {
        columnWidth(
            text.sliceCharacters(
                lowerBound: lowerCharacterOffset,
                upperBound: upperCharacterOffset
            )
        )
    }

    static func lineProjection(_ text: String, paddedToWidth width: Int) -> String {
        text + String(repeating: " ", count: max(width - columnWidth(text), 0))
    }

    static func prefix(_ text: String, maxWidth: Int) -> String {
        guard maxWidth > 0 else {
            return ""
        }

        var result = ""
        var usedWidth = 0
        for character in text {
            let width = columnWidth(String(character))
            guard usedWidth + width <= maxWidth else {
                break
            }

            result.append(character)
            usedWidth += width
        }

        return result
    }

    static func isCharacterBoundary(_ text: String, atColumn column: Int) -> Bool {
        guard column > 0 else {
            return true
        }

        var currentColumn = 0
        for character in text {
            let nextColumn = currentColumn + columnWidth(String(character))
            if column == currentColumn || column == nextColumn {
                return true
            }
            if column < nextColumn {
                return false
            }

            currentColumn = nextColumn
        }

        return true
    }

    private static func columnWidth(of scalar: Unicode.Scalar) -> Int {
        let value = scalar.value
        if value == 0 || value < 32 || (0x7F..<0xA0).contains(value) {
            return 0
        }
        if isZeroWidthScalar(value) {
            return 0
        }
        if isCombiningScalar(value) {
            return 0
        }
        if isWideScalar(value) {
            return 2
        }
        return 1
    }

    private static func isZeroWidthScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x00AD,
             0x200B...0x200D,
             0x2060,
             0xFE00...0xFE0F,
             0xE0100...0xE01EF:
            return true
        default:
            return false
        }
    }

    private static func isCombiningScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x0300...0x036F,
             0x1AB0...0x1AFF,
             0x1DC0...0x1DFF,
             0x20D0...0x20FF,
             0xFE20...0xFE2F:
            return true
        default:
            return false
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
            return true
        default:
            return false
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
