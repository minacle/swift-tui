struct WrappedRunLine: Equatable, Sendable {

    let content: String

    let lowerOffset: Int

    let upperOffset: Int
}

enum RunLineWrapper {

    static func wrappedLines(
        for text: String,
        maxWidth: Int?
    ) -> [WrappedRunLine] {
        if maxWidth == nil, !UnicodeLineBreak.containsMandatoryBreak(in: text) {
            return [
                WrappedRunLine(
                    content: text,
                    lowerOffset: 0,
                    upperOffset: text.count
                )
            ]
        }
        let paragraphs = UnicodeLineBreak.lineSegments(in: text)
        guard let maxWidth else {
            return paragraphs.map { paragraph in
                WrappedRunLine(
                    content: String(paragraph),
                    lowerOffset: text.distance(
                        from: text.startIndex,
                        to: paragraph.startIndex
                    ),
                    upperOffset: text.distance(
                        from: text.startIndex,
                        to: paragraph.endIndex
                    )
                )
            }
        }
        guard maxWidth > 0 else {
            return []
        }

        return paragraphs.flatMap { paragraph in
            let baseOffset = text.distance(
                from: text.startIndex,
                to: paragraph.startIndex
            )
            return wrappedParagraph(String(paragraph), maxWidth: maxWidth).map { line in
                WrappedRunLine(
                    content: String(line.content),
                    lowerOffset: baseOffset + line.lowerOffset,
                    upperOffset: baseOffset + line.upperOffset
                )
            }
        }
    }

    private struct ParagraphLine {

        let content: Substring

        let lowerOffset: Int

        let upperOffset: Int
    }

    private static func wrappedParagraph(
        _ paragraph: String,
        maxWidth: Int
    ) -> [ParagraphLine] {
        guard !paragraph.isEmpty else {
            return [
                ParagraphLine(
                    content: paragraph[...],
                    lowerOffset: 0,
                    upperOffset: 0
                )
            ]
        }

        var lines: [ParagraphLine] = []
        var start = paragraph.startIndex
        let opportunities = UnicodeLineBreak.opportunities(in: paragraph)
        var opportunityIndex = opportunities.startIndex

        func appendLine(endingAt end: String.Index) {
            lines.append(
                ParagraphLine(
                    content: paragraph[start..<end],
                    lowerOffset: paragraph.distance(from: paragraph.startIndex, to: start),
                    upperOffset: paragraph.distance(from: paragraph.startIndex, to: end)
                )
            )
        }

        while start < paragraph.endIndex {
            while opportunityIndex < opportunities.endIndex,
                  opportunities[opportunityIndex].index <= start
            {
                opportunityIndex = opportunities.index(after: opportunityIndex)
            }

            if TerminalText.columnWidth(String(paragraph[start..<paragraph.endIndex])) <= maxWidth {
                appendLine(endingAt: paragraph.endIndex)
                break
            }

            var bestBreak: UnicodeLineBreak.Opportunity?
            var scanIndex = opportunityIndex
            while scanIndex < opportunities.endIndex {
                let opportunity = opportunities[scanIndex]
                let width = TerminalText.columnWidth(
                    String(paragraph[start..<opportunity.index])
                )
                guard width <= maxWidth else {
                    break
                }

                bestBreak = opportunity
                scanIndex = opportunities.index(after: scanIndex)
            }

            let fallbackEnd = fittingCharacterBoundary(
                in: paragraph,
                from: start,
                maxWidth: maxWidth
            )
            if let bestBreak {
                let lineEnd = trimmingTrailingWhitespace(
                    in: paragraph,
                    lowerBound: start,
                    upperBound: bestBreak.index
                )
                if shouldPreserveFittingBreakSpaces(
                    in: paragraph,
                    lowerBound: start,
                    fallbackEnd: fallbackEnd
                ) {
                    appendLine(endingAt: fallbackEnd)
                    start = fallbackEnd
                }
                else {
                    appendLine(endingAt: lineEnd)
                    start = skippingLeadingWhitespace(in: paragraph, from: bestBreak.index)
                    opportunityIndex = scanIndex
                }
            }
            else {
                appendLine(endingAt: fallbackEnd)
                if fallbackEnd > start {
                    start = skippingLeadingWhitespace(in: paragraph, from: fallbackEnd)
                }
                else {
                    if TerminalText.columnWidth(String(paragraph[start])) > maxWidth {
                        break
                    }
                    start = paragraph.index(after: start)
                }
            }
        }
        return lines
    }

    private static func fittingCharacterBoundary(
        in text: String,
        from start: String.Index,
        maxWidth: Int
    ) -> String.Index {
        var index = start
        var width = 0
        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            let characterWidth = TerminalText.columnWidth(String(text[index]))
            guard width + characterWidth <= maxWidth else {
                break
            }
            width += characterWidth
            index = nextIndex
        }
        if index < text.endIndex,
           index > start,
           UnicodeLineBreak.preventsBreakBefore(text[index])
        {
            let previousIndex = text.index(before: index)
            if TerminalText.columnWidth(String(text[start..<previousIndex])) >= 2 {
                index = previousIndex
            }
        }
        return index
    }

    private static func shouldPreserveFittingBreakSpaces(
        in text: String,
        lowerBound: String.Index,
        fallbackEnd: String.Index
    ) -> Bool {
        guard fallbackEnd > lowerBound else {
            return false
        }
        if containsOnlyBreakSpaces(in: text, from: fallbackEnd) {
            return true
        }

        let previousIndex = text.index(before: fallbackEnd)
        return UnicodeLineBreak.isBreakSpace(text[previousIndex])
            && fallbackEnd < text.endIndex
            && UnicodeLineBreak.isBreakSpace(text[fallbackEnd])
    }

    private static func containsOnlyBreakSpaces(
        in text: String,
        from start: String.Index
    ) -> Bool {
        var index = start
        while index < text.endIndex {
            guard UnicodeLineBreak.isBreakSpace(text[index]) else {
                return false
            }
            index = text.index(after: index)
        }
        return true
    }

    private static func trimmingTrailingWhitespace(
        in text: String,
        lowerBound: String.Index,
        upperBound: String.Index
    ) -> String.Index {
        var index = upperBound
        while index > lowerBound {
            let previous = text.index(before: index)
            guard UnicodeLineBreak.isBreakSpace(text[previous]) else {
                break
            }
            index = previous
        }
        return index
    }

    private static func skippingLeadingWhitespace(
        in text: String,
        from start: String.Index
    ) -> String.Index {
        var index = start
        while index < text.endIndex, UnicodeLineBreak.isBreakSpace(text[index]) {
            index = text.index(after: index)
        }
        return index
    }
}
