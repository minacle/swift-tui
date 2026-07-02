import Foundation

extension UnicodeLineBreakClass {

    static func untailoredClass(for scalar: Unicode.Scalar) -> UnicodeLineBreakClass {
        let value = scalar.value
        var lowerBound = 0
        var upperBound = lineBreakRanges.count

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            let range = lineBreakRanges[middle]
            if value < range.lowerBound {
                upperBound = middle
            }
            else if value > range.upperBound {
                lowerBound = middle + 1
            }
            else {
                return range.lineBreakClass
            }
        }

        return defaultClass(for: value)
    }

    private static let lineBreakRanges: [UnicodeLineBreakRange] = parseLineBreakRanges(lineBreakDataText)

    static var lineBreakDataRangeCount: Int {
        lineBreakRanges.count
    }

    private static func defaultClass(for value: UInt32) -> UnicodeLineBreakClass {
        switch value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x3FFFD,
             0x1F000...0x1FAFF,
             0x1FC00...0x1FFFD:
            return .ideographic
        case 0x20A0...0x20CF:
            return .prefixNumeric
        case 0x1F100...0x1F10A,
             0x1F110...0x1F12F,
             0x1F130...0x1F14F:
            return .alphabetic
        default:
            return .unknown
        }
    }

    private static func parseLineBreakRanges(_ contents: String) -> [UnicodeLineBreakRange] {
        var ranges: [UnicodeLineBreakRange] = []

        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        for (lineNumber, line) in lines.enumerated() {
            let data = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
                .trimmingCharacters(in: .whitespaces)
            guard !data.isEmpty else {
                continue
            }

            let fields = data.split(whereSeparator: \.isWhitespace)
            guard
                fields.count == 3,
                let lowerBound = UInt32(fields[0], radix: 16),
                let upperBound = UInt32(fields[1], radix: 16),
                let lineBreakClass = UnicodeLineBreakClass(lineBreakDataCode: fields[2])
            else {
                preconditionFailure("Invalid embedded UnicodeLineBreakData line \(lineNumber + 1): \(line)")
            }

            ranges.append(
                UnicodeLineBreakRange(
                    lowerBound: lowerBound,
                    upperBound: upperBound,
                    lineBreakClass: lineBreakClass
                )
            )
        }

        return ranges
    }

    private init?(lineBreakDataCode code: Substring) {
        switch code {
        case "AI":
            self = .ambiguous
        case "AK":
            self = .aksara
        case "AL":
            self = .alphabetic
        case "AP":
            self = .aksaraPrebase
        case "AS":
            self = .aksaraStart
        case "B2":
            self = .breakBoth
        case "BA":
            self = .breakAfter
        case "BB":
            self = .breakBefore
        case "BK":
            self = .mandatoryBreak
        case "CB":
            self = .contingentBreak
        case "CJ":
            self = .conditionalJapaneseStarter
        case "CL":
            self = .closePunctuation
        case "CM":
            self = .combiningMark
        case "CP":
            self = .closeParenthesis
        case "CR":
            self = .carriageReturn
        case "EB":
            self = .emojiBase
        case "EM":
            self = .emojiModifier
        case "EX":
            self = .exclamation
        case "GL":
            self = .glue
        case "H2":
            self = .hangulLv
        case "H3":
            self = .hangulLvt
        case "HH":
            self = .unambiguousHyphen
        case "HL":
            self = .hebrewLetter
        case "HY":
            self = .hyphen
        case "ID":
            self = .ideographic
        case "IN":
            self = .inseparable
        case "IS":
            self = .infixNumeric
        case "JL":
            self = .hangulLJamo
        case "JT":
            self = .hangulTJamo
        case "JV":
            self = .hangulVJamo
        case "LF":
            self = .lineFeed
        case "NL":
            self = .nextLine
        case "NS":
            self = .nonstarter
        case "NU":
            self = .numeric
        case "OP":
            self = .openPunctuation
        case "PO":
            self = .postfixNumeric
        case "PR":
            self = .prefixNumeric
        case "QU":
            self = .quotation
        case "RI":
            self = .regionalIndicator
        case "SA":
            self = .complexContext
        case "SG":
            self = .surrogate
        case "SP":
            self = .space
        case "SY":
            self = .breakSymbols
        case "VF":
            self = .viramaFinal
        case "VI":
            self = .virama
        case "WJ":
            self = .wordJoiner
        case "XX":
            self = .unknown
        case "ZW":
            self = .zeroWidthSpace
        case "ZWJ":
            self = .zeroWidthJoiner
        default:
            return nil
        }
    }
}
