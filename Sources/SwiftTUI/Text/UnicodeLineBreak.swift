struct UnicodeLineBreakRange: Sendable {

    let lowerBound: UInt32

    let upperBound: UInt32

    let lineBreakClass: UnicodeLineBreakClass
}

enum UnicodeLineBreakClass: Sendable {

    case ambiguous
    case aksara
    case aksaraPrebase
    case aksaraStart
    case alphabetic
    case breakAfter
    case breakBefore
    case breakBoth
    case breakSymbols
    case carriageReturn
    case closeParenthesis
    case closePunctuation
    case combiningMark
    case complexContext
    case conditionalJapaneseStarter
    case contingentBreak
    case emojiBase
    case emojiModifier
    case exclamation
    case glue
    case hangulLJamo
    case hangulLv
    case hangulLvt
    case hangulTJamo
    case hangulVJamo
    case hebrewLetter
    case hyphen
    case ideographic
    case infixNumeric
    case inseparable
    case lineFeed
    case mandatoryBreak
    case nextLine
    case nonstarter
    case numeric
    case openPunctuation
    case postfixNumeric
    case prefixNumeric
    case quotation
    case regionalIndicator
    case space
    case surrogate
    case unambiguousHyphen
    case unknown
    case virama
    case viramaFinal
    case wordJoiner
    case zeroWidthJoiner
    case zeroWidthSpace

    static func resolvedClass(for scalar: Unicode.Scalar) -> UnicodeLineBreakClass {
        switch untailoredClass(for: scalar) {
        case .ambiguous, .complexContext, .surrogate, .unknown:
            return .alphabetic
        case .conditionalJapaneseStarter:
            return .nonstarter
        default:
            return untailoredClass(for: scalar)
        }
    }
}

enum UnicodeLineBreak {

    struct Opportunity: Sendable {

        enum Kind: Sendable {

            case allowed
            case mandatory
        }

        let index: String.Index

        let kind: Kind
    }

    private struct Token {

        let character: Character

        let index: String.Index

        let nextIndex: String.Index

        let lineBreakClass: UnicodeLineBreakClass
    }

    static func opportunities(in text: String) -> [Opportunity] {
        let tokens = tokens(in: text)
        guard !tokens.isEmpty else {
            return []
        }

        var opportunities: [Opportunity] = []
        for boundary in 1..<tokens.count {
            let left = tokens[boundary - 1]
            let right = tokens[boundary]

            if isHardBreak(left.lineBreakClass) {
                opportunities.append(
                    Opportunity(index: left.nextIndex, kind: .mandatory)
                )
                continue
            }

            if left.lineBreakClass == .carriageReturn,
               right.lineBreakClass == .lineFeed
            {
                continue
            }

            if isBreakAllowed(before: boundary, in: tokens) {
                opportunities.append(
                    Opportunity(index: right.index, kind: .allowed)
                )
            }
        }

        if isHardBreak(tokens[tokens.count - 1].lineBreakClass) {
            opportunities.append(
                Opportunity(index: tokens[tokens.count - 1].nextIndex, kind: .mandatory)
            )
        }

        return opportunities
    }

    static func lineSegments(in text: String) -> [Substring] {
        guard !text.isEmpty else {
            return [text[...]]
        }

        var segments: [Substring] = []
        var segmentStart = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)
            let currentClass = lineBreakClass(for: character)

            if isHardBreak(currentClass) {
                segments.append(text[segmentStart..<index])

                if currentClass == .carriageReturn,
                   nextIndex < text.endIndex,
                   lineBreakClass(for: text[nextIndex]) == .lineFeed
                {
                    let afterLineFeed = text.index(after: nextIndex)
                    segmentStart = afterLineFeed
                    index = afterLineFeed
                }
                else {
                    segmentStart = nextIndex
                    index = nextIndex
                }
            }
            else {
                index = nextIndex
            }
        }

        segments.append(text[segmentStart..<text.endIndex])
        return segments
    }

    static func isBreakSpace(_ character: Character) -> Bool {
        lineBreakClass(for: character) == .space
    }

    private static func tokens(in text: String) -> [Token] {
        var tokens: [Token] = []
        var index = text.startIndex
        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            let character = text[index]
            tokens.append(
                Token(
                    character: character,
                    index: index,
                    nextIndex: nextIndex,
                    lineBreakClass: lineBreakClass(for: character)
                )
            )
            index = nextIndex
        }

        return tokens
    }

    private static func lineBreakClass(for character: Character) -> UnicodeLineBreakClass {
        for scalar in String(character).unicodeScalars {
            let lineBreakClass = UnicodeLineBreakClass.resolvedClass(for: scalar)
            if lineBreakClass != .combiningMark && lineBreakClass != .zeroWidthJoiner {
                return lineBreakClass
            }
        }

        return .alphabetic
    }

    private static func isBreakAllowed(
        before boundary: Int,
        in tokens: [Token]
    ) -> Bool {
        let left = tokens[boundary - 1].lineBreakClass
        let right = tokens[boundary].lineBreakClass
        let leftNonSpace = nonSpaceBefore(boundary, in: tokens)?.lineBreakClass

        if boundary == 0 {
            return false
        }

        if isHardBreak(right) {
            return false
        }

        if right == .space || right == .zeroWidthSpace {
            return false
        }

        if left == .zeroWidthJoiner {
            return false
        }

        if
            let zeroWidthSpace = nonSpaceBefore(boundary, in: tokens),
            zeroWidthSpace.lineBreakClass == .zeroWidthSpace
        {
            return true
        }

        if right == .combiningMark || right == .zeroWidthJoiner {
            return false
        }

        if left == .wordJoiner || right == .wordJoiner {
            return false
        }

        if left == .glue {
            return false
        }

        if right == .glue
            && left != .space
            && left != .breakAfter
            && left != .hyphen
            && left != .unambiguousHyphen
        {
            return false
        }

        if right == .closePunctuation
            || right == .closeParenthesis
            || right == .exclamation
            || right == .breakSymbols
        {
            return false
        }

        if leftNonSpace == .openPunctuation {
            return false
        }

        if leftNonSpace == .closePunctuation || leftNonSpace == .closeParenthesis,
           right == .nonstarter
        {
            return false
        }

        if leftNonSpace == .breakBoth, right == .breakBoth {
            return false
        }

        if left == .space {
            return true
        }

        if left == .quotation || right == .quotation {
            return false
        }

        if left == .contingentBreak || right == .contingentBreak {
            return true
        }

        if isWordInitialHyphen(before: boundary, in: tokens) {
            return false
        }

        if right == .breakAfter
            || right == .unambiguousHyphen
            || right == .hyphen
            || right == .nonstarter
            || left == .breakBefore
        {
            return false
        }

        if isHebrewHyphenSequence(before: boundary, in: tokens)
            || (left == .breakSymbols && right == .hebrewLetter)
        {
            return false
        }

        if right == .inseparable {
            return false
        }

        if isAlphabetic(left) && right == .numeric {
            return false
        }
        if left == .numeric && isAlphabetic(right) {
            return false
        }

        if left == .prefixNumeric && isIdeographicEmoji(right) {
            return false
        }
        if isIdeographicEmoji(left) && right == .postfixNumeric {
            return false
        }

        if isNumericPrefixOrPostfix(left) && isAlphabetic(right) {
            return false
        }
        if isAlphabetic(left) && isNumericPrefixOrPostfix(right) {
            return false
        }

        if isNumericSequence(left, right) {
            return false
        }

        if isKoreanSyllableSequence(left, right) {
            return false
        }

        if isKoreanClass(left) && right == .postfixNumeric {
            return false
        }
        if left == .prefixNumeric && isKoreanClass(right) {
            return false
        }

        if isAlphabetic(left) && isAlphabetic(right) {
            return false
        }

        if isBrahmicSequence(before: boundary, in: tokens) {
            return false
        }

        if left == .infixNumeric && isAlphabetic(right) {
            return false
        }

        if isParenthesizedSequence(left, right) {
            return false
        }

        if isRegionalIndicatorPair(before: boundary, in: tokens) {
            return false
        }

        if left == .emojiBase && right == .emojiModifier {
            return false
        }

        return true
    }

    private static func nonSpaceBefore(
        _ boundary: Int,
        in tokens: [Token]
    ) -> Token? {
        var index = boundary - 1
        while index >= 0 {
            let token = tokens[index]
            if token.lineBreakClass != .space {
                return token
            }
            index -= 1
        }

        return nil
    }

    private static func tokenBefore(
        _ index: Int,
        in tokens: [Token]
    ) -> Token? {
        guard index >= 0 && index < tokens.count else {
            return nil
        }
        return tokens[index]
    }

    private static func isHardBreak(_ lineBreakClass: UnicodeLineBreakClass) -> Bool {
        lineBreakClass == .mandatoryBreak
            || lineBreakClass == .carriageReturn
            || lineBreakClass == .lineFeed
            || lineBreakClass == .nextLine
    }

    private static func isAlphabetic(_ lineBreakClass: UnicodeLineBreakClass) -> Bool {
        lineBreakClass == .alphabetic || lineBreakClass == .hebrewLetter
    }

    private static func isIdeographicEmoji(_ lineBreakClass: UnicodeLineBreakClass) -> Bool {
        lineBreakClass == .ideographic
            || lineBreakClass == .emojiBase
            || lineBreakClass == .emojiModifier
    }

    private static func isNumericPrefixOrPostfix(
        _ lineBreakClass: UnicodeLineBreakClass
    ) -> Bool {
        lineBreakClass == .prefixNumeric || lineBreakClass == .postfixNumeric
    }

    private static func isNumericSequence(
        _ left: UnicodeLineBreakClass,
        _ right: UnicodeLineBreakClass
    ) -> Bool {
        if left == .hyphen && right == .numeric {
            return true
        }
        if left == .infixNumeric && right == .numeric {
            return true
        }
        if left == .breakSymbols && right == .numeric {
            return true
        }
        if left == .numeric
            && (right == .numeric
                || right == .infixNumeric
                || right == .breakSymbols
                || right == .closePunctuation
                || right == .closeParenthesis
                || right == .postfixNumeric
                || right == .prefixNumeric)
        {
            return true
        }
        if isNumericPrefixOrPostfix(left)
            && (right == .numeric || right == .openPunctuation)
        {
            return true
        }
        if (left == .closePunctuation || left == .closeParenthesis)
            && isNumericPrefixOrPostfix(right)
        {
            return true
        }
        return false
    }

    private static func isKoreanClass(_ lineBreakClass: UnicodeLineBreakClass) -> Bool {
        lineBreakClass == .hangulLJamo
            || lineBreakClass == .hangulVJamo
            || lineBreakClass == .hangulTJamo
            || lineBreakClass == .hangulLv
            || lineBreakClass == .hangulLvt
    }

    private static func isKoreanSyllableSequence(
        _ left: UnicodeLineBreakClass,
        _ right: UnicodeLineBreakClass
    ) -> Bool {
        switch (left, right) {
        case (.hangulLJamo, .hangulLJamo),
             (.hangulLJamo, .hangulVJamo),
             (.hangulLJamo, .hangulLv),
             (.hangulLJamo, .hangulLvt),
             (.hangulVJamo, .hangulVJamo),
             (.hangulVJamo, .hangulTJamo),
             (.hangulLv, .hangulVJamo),
             (.hangulLv, .hangulTJamo),
             (.hangulTJamo, .hangulTJamo),
             (.hangulLvt, .hangulTJamo):
            return true
        default:
            return false
        }
    }

    private static func isBrahmicSequence(
        before boundary: Int,
        in tokens: [Token]
    ) -> Bool {
        let left = tokens[boundary - 1].lineBreakClass
        let right = tokens[boundary].lineBreakClass
        let previous = tokenBefore(boundary - 2, in: tokens)?.lineBreakClass
        let next = tokenBefore(boundary + 1, in: tokens)?.lineBreakClass

        if left == .aksaraPrebase
            && (right == .aksara || right == .combiningMark || right == .aksaraStart)
        {
            return true
        }
        if (left == .aksara || left == .combiningMark || left == .aksaraStart)
            && (right == .viramaFinal || right == .virama)
        {
            return true
        }
        if (previous == .aksara || previous == .combiningMark || previous == .aksaraStart)
            && left == .virama
            && (right == .aksara || right == .combiningMark)
        {
            return true
        }
        if (left == .aksara || left == .combiningMark || left == .aksaraStart)
            && (right == .aksara || right == .combiningMark || right == .aksaraStart)
            && next == .viramaFinal
        {
            return true
        }
        return false
    }

    private static func isParenthesizedSequence(
        _ left: UnicodeLineBreakClass,
        _ right: UnicodeLineBreakClass
    ) -> Bool {
        if (left == .alphabetic || left == .hebrewLetter || left == .numeric)
            && right == .openPunctuation
        {
            return true
        }
        if left == .closeParenthesis
            && (right == .alphabetic || right == .hebrewLetter || right == .numeric)
        {
            return true
        }
        return false
    }

    private static func isRegionalIndicatorPair(
        before boundary: Int,
        in tokens: [Token]
    ) -> Bool {
        guard tokens[boundary - 1].lineBreakClass == .regionalIndicator,
              tokens[boundary].lineBreakClass == .regionalIndicator else {
            return false
        }

        var count = 0
        var index = boundary - 1
        while index >= 0, tokens[index].lineBreakClass == .regionalIndicator {
            count += 1
            index -= 1
        }
        return count % 2 == 1
    }

    private static func isWordInitialHyphen(
        before boundary: Int,
        in tokens: [Token]
    ) -> Bool {
        let left = tokens[boundary - 1].lineBreakClass
        let right = tokens[boundary].lineBreakClass
        guard (left == .hyphen || left == .unambiguousHyphen)
                && (right == .alphabetic || right == .hebrewLetter) else {
            return false
        }

        guard let previous = tokenBefore(boundary - 2, in: tokens)?.lineBreakClass else {
            return true
        }

        return previous == .mandatoryBreak
            || previous == .carriageReturn
            || previous == .lineFeed
            || previous == .nextLine
            || previous == .space
            || previous == .zeroWidthSpace
            || previous == .contingentBreak
            || previous == .glue
    }

    private static func isHebrewHyphenSequence(
        before boundary: Int,
        in tokens: [Token]
    ) -> Bool {
        let left = tokens[boundary - 1].lineBreakClass
        let right = tokens[boundary].lineBreakClass
        let previous = tokenBefore(boundary - 2, in: tokens)?.lineBreakClass

        return previous == .hebrewLetter
            && (left == .hyphen || left == .unambiguousHyphen)
            && right != .hebrewLetter
    }
}
