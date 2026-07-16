import Foundation
import SwiftTUIRuns

private struct TextSourceLine {

    var text: String

    var sourceOffsets: [Int?]

    var lowerOffset: Int

    var upperOffset: Int

    static func mappedLines(for text: Text, maxWidth: Int?) -> [TextSourceLine] {
        text.runGroup.layout(fittingColumns: maxWidth).lines.map { line in
            let lowerOffset = line.sourceRange.lowerBound.characterOffset
            let upperOffset = line.sourceRange.upperBound.characterOffset
            return TextSourceLine(
                text: line.runs.map(\.content).joined(),
                sourceOffsets: Array(lowerOffset..<upperOffset).map(Optional.some),
                lowerOffset: lowerOffset,
                upperOffset: upperOffset
            )
        }
    }

    func truncated(
        maxWidth: Int?,
        mode: Text.TruncationMode,
        endingWith endingLine: TextSourceLine
    ) -> TextSourceLine {
        guard let maxWidth else {
            return unboundedTruncation(mode: mode, endingWith: endingLine)
        }
        guard maxWidth > 0 else {
            return TextSourceLine(text: "", sourceOffsets: [], lowerOffset: lowerOffset, upperOffset: lowerOffset)
        }
        guard maxWidth >= 3 else {
            return TextSourceLine(
                text: String(repeating: ".", count: maxWidth),
                sourceOffsets: Array(repeating: nil, count: maxWidth),
                lowerOffset: lowerOffset,
                upperOffset: lowerOffset
            )
        }

        let contentWidth = maxWidth - 3
        switch mode {
        case .head:
            let suffix = Self.suffix(
                of: endingLine.text,
                fittingColumns: contentWidth
            )
            let suffixCount = suffix.count
            return TextSourceLine(
                text: "..." + suffix,
                sourceOffsets: Array(repeating: nil, count: 3)
                    + endingLine.sourceOffsets.suffix(suffixCount),
                lowerOffset: endingLine.upperOffset - suffixCount,
                upperOffset: endingLine.upperOffset
            )
        case .middle:
            let preferredPrefixWidth = (contentWidth + 1) / 2
            var prefix = Self.prefix(
                of: text,
                fittingColumns: preferredPrefixWidth
            )
            var suffix = Self.suffix(
                of: endingLine.text,
                fittingColumns: contentWidth
                    - RunGroup(prefix).measure().maximumContentColumns
            )
            prefix = Self.prefix(
                of: text,
                fittingColumns: contentWidth
                    - RunGroup(suffix).measure().maximumContentColumns
            )
            suffix = Self.suffix(
                of: endingLine.text,
                fittingColumns: contentWidth
                    - RunGroup(prefix).measure().maximumContentColumns
            )
            let prefixCount = prefix.count
            let suffixCount = suffix.count
            return TextSourceLine(
                text: prefix + "..." + suffix,
                sourceOffsets: Array(sourceOffsets.prefix(prefixCount))
                    + Array(repeating: nil, count: 3)
                    + endingLine.sourceOffsets.suffix(suffixCount),
                lowerOffset: lowerOffset,
                upperOffset: endingLine.upperOffset
            )
        case .tail:
            let prefix = Self.prefix(of: text, fittingColumns: contentWidth)
            let prefixCount = prefix.count
            return TextSourceLine(
                text: prefix + "...",
                sourceOffsets: Array(sourceOffsets.prefix(prefixCount))
                    + Array(repeating: nil, count: 3),
                lowerOffset: lowerOffset,
                upperOffset: lowerOffset + prefixCount
            )
        }
    }

    private static func prefix(of text: String, fittingColumns columns: Int) -> String {
        guard let line = RunGroup(text).layout().lines.first else {
            return ""
        }
        let range = line.prefixRange(fittingColumns: columns)
        let count = range.upperBound.characterOffset
            - line.sourceRange.lowerBound.characterOffset
        return String(text.prefix(count))
    }

    private static func suffix(of text: String, fittingColumns columns: Int) -> String {
        guard let line = RunGroup(text).layout().lines.first else {
            return ""
        }
        let range = line.suffixRange(fittingColumns: columns)
        let count = line.sourceRange.upperBound.characterOffset
            - range.lowerBound.characterOffset
        return String(text.suffix(count))
    }

    private func unboundedTruncation(
        mode: Text.TruncationMode,
        endingWith endingLine: TextSourceLine
    ) -> TextSourceLine {
        switch mode {
        case .head:
            return TextSourceLine(
                text: "..." + endingLine.text,
                sourceOffsets: Array(repeating: nil, count: 3) + endingLine.sourceOffsets,
                lowerOffset: endingLine.lowerOffset,
                upperOffset: endingLine.upperOffset
            )
        case .middle:
            return TextSourceLine(
                text: text + "..." + endingLine.text,
                sourceOffsets: sourceOffsets
                    + Array(repeating: nil, count: 3)
                    + endingLine.sourceOffsets,
                lowerOffset: lowerOffset,
                upperOffset: endingLine.upperOffset
            )
        case .tail:
            return TextSourceLine(
                text: text + "...",
                sourceOffsets: sourceOffsets + Array(repeating: nil, count: 3),
                lowerOffset: lowerOffset,
                upperOffset: upperOffset
            )
        }
    }
}

/// Resolves a ``Text`` value into wrapped, styled terminal-cell runs.
enum TextLayoutRenderer {

    static func block(
        for text: Text,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock {
        let lineLimit = EnvironmentRenderContext.current.textLineLimit
        var lines = TextSourceLine.mappedLines(for: text, maxWidth: proposal?.columns)
        let isTruncated = lineLimit.number.map { lines.count > $0 } ?? false
        let endingLine = lines.last

        if let number = lineLimit.number {
            lines = Array(lines.prefix(number))
            if isTruncated, !lines.isEmpty, let endingLine {
                lines[lines.count - 1] = lines[lines.count - 1].truncated(
                    maxWidth: proposal?.columns,
                    mode: EnvironmentRenderContext.current.truncationMode,
                    endingWith: endingLine
                )
            }
            if lineLimit.reservesSpace, lines.count < number {
                let offset = lines.last?.upperOffset ?? text.content.count
                lines.append(
                    contentsOf: Array(
                        repeating: TextSourceLine(
                            text: "",
                            sourceOffsets: [],
                            lowerOffset: offset,
                            upperOffset: offset
                        ),
                        count: number - lines.count
                    )
                )
            }
        }

        let environment = EnvironmentRenderContext.current
        let allowsSelection = environment.isTextSelectionEnabled && environment.isEnabled
        let selectionState = allowsSelection
            ? runtime?.textSelectionState(at: path)
            : nil
        selectionState?.clamp(upperBound: text.content.count)
        let naturalWidth = lines.map {
            RunGroup($0.text).measure().maximumContentColumns
        }.max() ?? 0
        let alignmentWidth = if text.hasAttributedAlignment {
            proposal?.columns
        }
        else {
            naturalWidth
        }
        let layout = TextRunLayoutMapper.renderedRuns(
            for: lines,
            text: text,
            baseStyle: environment.textStyle,
            tint: environment.tint,
            selection: selectionState?.range,
            selectionForegroundStyle: environment.textSelectionForegroundStyle,
            defaultAlignment: environment.multilineTextAlignment,
            alignmentWidth: alignmentWidth
        )
        let width = if text.hasAttributedAlignment, let columns = proposal?.columns {
            columns
        }
        else {
            naturalWidth
        }
        var block = RenderedBlock(
            runs: layout.runs,
            width: width,
            height: lines.count,
            paddedRows: Set(
                lines.enumerated().compactMap { row, line in
                    line.text.isEmpty && !layout.runs.isEmpty ? row : nil
                }
            )
        )
        if allowsSelection, !block.bounds.isEmpty {
            let attachmentIDs = runtime?.registerPointerDownPositionHandler(
                PointerDownPositionHandler(
                    actionPath: path,
                    requiresFocus: false,
                    shouldDeferBegin: { point in
                        selectionState?.range?.contains(layout.offset(at: point)) == true
                    },
                    began: { point in
                        runtime?.beginTextSelection(
                            at: path,
                            offset: layout.offset(at: point),
                            upperBound: text.content.count
                        )
                    },
                    changed: { point in
                        selectionState?.extendFromPointer(
                            to: layout.offset(at: point),
                            upperBound: text.content.count
                        )
                    }
                ),
                at: path
            ) ?? []
            block.hitRegions.append(
                RenderedHitRegion(
                    path: path,
                    frame: block.bounds,
                    recognitionAttachmentIDs: attachmentIDs
                )
            )
        }
        registerLinks(in: runtime, path: path, runs: layout.runs, block: &block)
        return block
    }

    private static func registerLinks(
        in runtime: StateRuntime?,
        path: [Int],
        runs: [RenderedRun],
        block: inout RenderedBlock
    ) {
        var linkIndex = 0
        for run in runs {
            guard let url = run.link else {
                continue
            }

            let linkPath = path + [linkIndex]
            linkIndex += 1
            let attachmentID = runtime?.registerLinkHandler(
                LinkHandler(
                    actionPath: linkPath,
                    action: {
                        EnvironmentRenderContext.current.openURL.result(for: url).accepted
                    }
                ),
                at: linkPath
            )
            block.hitRegions.append(
                RenderedHitRegion(
                    path: linkPath,
                    frame: RenderedRect(
                        x: run.column,
                        y: run.row,
                        width: run.width,
                        height: 1
                    ),
                    recognitionAttachmentIDs: attachmentID.map { [$0] } ?? []
                )
            )
        }
    }
}

private struct TextRunLayoutResult {

    struct Line {

        var source: TextSourceLine

        var column: Int
    }

    var runs: [RenderedRun]

    var lines: [Line]

    func offset(at point: Point) -> Int {
        guard !lines.isEmpty else {
            return 0
        }

        let line = lines[min(max(point.row, 0), lines.count - 1)]
        let targetColumn = max(point.column - line.column, 0)
        var column = 0
        var offset = line.source.lowerOffset
        let displayLayout = RunGroup(line.source.text).layout()
        for (localOffset, pair) in zip(
            line.source.text,
            line.source.sourceOffsets
        ).enumerated() {
            let sourceOffset = pair.1
            let width = displayLayout.columns(
                in: RunIndex(characterOffset: localOffset)
                    ..< RunIndex(characterOffset: localOffset + 1)
            )
            guard column + width <= targetColumn else {
                return sourceOffset ?? offset
            }

            column += width
            if let sourceOffset {
                offset = sourceOffset + 1
            }
        }
        return min(offset, line.source.upperOffset)
    }
}

private enum TextRunLayoutMapper {

    private struct StyledCharacter {

        var character: Character

        var style: TextStyle

        var link: URL?

        var alignment: TextAttributedAlignment?
    }

    static func renderedRuns(
        for lines: [TextSourceLine],
        text: Text,
        baseStyle: TextStyle,
        tint: AnyColor?,
        selection: Range<Int>?,
        selectionForegroundStyle: AnyShapeStyle?,
        defaultAlignment: TextAlignment = .leading,
        alignmentWidth: Int? = nil
    ) -> TextRunLayoutResult {
        let characters = styledCharacters(for: text, baseStyle: baseStyle, tint: tint)
        var renderedRuns: [RenderedRun] = []
        var renderedLines: [TextRunLayoutResult.Line] = []

        for (row, line) in lines.enumerated() {
            var column = 0
            var pendingText = ""
            var pendingColumn = 0
            var pendingStyle: TextStyle?
            var pendingLink: URL?
            var rowRuns: [RenderedRun] = []
            var rowAlignment: TextAttributedAlignment?
            let lineLayout = RunGroup(line.text).layout()

            func flush() {
                guard !pendingText.isEmpty, let style = pendingStyle else {
                    return
                }

                rowRuns.append(
                    RenderedRun(
                        text: pendingText,
                        row: row,
                        column: pendingColumn,
                        style: style,
                        link: pendingLink
                    )
                )
                pendingText = ""
                pendingStyle = nil
                pendingLink = nil
            }

            for (localOffset, pair) in zip(
                line.text,
                line.sourceOffsets
            ).enumerated() {
                let character = pair.0
                let sourceOffset = pair.1
                let styledCharacter = sourceOffset.flatMap {
                    characters.indices.contains($0) ? characters[$0] : nil
                }
                var style = styledCharacter?.style ?? baseStyle
                let link = styledCharacter?.link
                if let sourceOffset, selection?.contains(sourceOffset) == true {
                    if let tint {
                        style.backgroundStyle = tint
                    }
                    if let selectionForegroundStyle {
                        style.foregroundStyle = selectionForegroundStyle._swiftTUIAnyColor
                    }
                }
                if rowAlignment == nil {
                    rowAlignment = styledCharacter?.alignment
                }
                if pendingStyle != style || pendingLink != link {
                    flush()
                    pendingColumn = column
                    pendingStyle = style
                    pendingLink = link
                }

                let characterText = String(character)
                pendingText += characterText
                column += lineLayout.columns(
                    in: RunIndex(characterOffset: localOffset)
                        ..< RunIndex(characterOffset: localOffset + 1)
                )
            }

            flush()
            let offset = horizontalOffset(
                for: line.text,
                alignment: rowAlignment,
                defaultAlignment: defaultAlignment,
                width: alignmentWidth
            )
            renderedRuns.append(contentsOf: rowRuns.map { $0.offsetBy(x: offset, y: 0) })
            renderedLines.append(TextRunLayoutResult.Line(source: line, column: offset))
        }

        return TextRunLayoutResult(runs: renderedRuns, lines: renderedLines)
    }

    private static func styledCharacters(
        for text: Text,
        baseStyle: TextStyle,
        tint: AnyColor?
    ) -> [StyledCharacter] {
        var resolvedAttributes = Array<RunAttributes?>(
            repeating: nil,
            count: text.content.count
        )
        for line in text.runGroup.layout().lines {
            for run in line.runs {
                for offset in run.sourceRange.lowerBound.characterOffset
                    ..< run.sourceRange.upperBound.characterOffset
                {
                    resolvedAttributes[offset] = run.attributes
                }
            }
        }
        var offset = 0
        return text.content.map { character in
            defer { offset += 1 }
            let annotation = text.annotations.first {
                $0.range.contains(RunIndex(characterOffset: offset))
            }
            var style = baseStyle.merging(resolvedAttributes[offset] ?? RunAttributes())
            if annotation?.link != nil, style.foregroundStyle == nil, let tint {
                style.foregroundStyle = tint
            }

            return StyledCharacter(
                character: character,
                style: style,
                link: annotation?.link,
                alignment: annotation?.alignment
            )
        }
    }

    private static func horizontalOffset(
        for line: String,
        alignment: TextAttributedAlignment?,
        defaultAlignment: TextAlignment,
        width: Int?
    ) -> Int {
        guard let width else {
            return 0
        }

        let padding = max(
            width - RunGroup(line).measure().maximumContentColumns,
            0
        )
        if let alignment {
            switch alignment {
            case .left:
                return 0
            case .center:
                return padding / 2
            case .right:
                return padding
            }
        }
        switch defaultAlignment {
        case .leading:
            return 0
        case .center:
            return padding / 2
        case .trailing:
            return padding
        }
    }

}
