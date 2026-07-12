import Foundation
import SwiftTUIRuns

nonisolated struct TerminalViewportSize: Equatable, Sendable {

    var columns: Int

    var rows: Int

    init(columns: Int, rows: Int) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
    }
}

/// The terminal position assigned to the root rendered content.
///
/// Rows and columns use the terminal's one-based coordinate system. The text
/// snapshot is retained for renderer diagnostics and equality checks; input
/// dispatch uses the origin to translate terminal coordinates into the root
/// block's local coordinate space.
nonisolated struct RenderedTerminalFrame: Equatable, Sendable {

    var text: String

    var row: Int

    var column: Int
}

/// A styled text run positioned in zero-based terminal-cell coordinates.
nonisolated struct RenderedRun: Equatable, Sendable {

    var text: String

    var row: Int

    var column: Int

    var style: TextStyle

    var link: URL?

    private let terminalColumns: Int

    init(
        text: String,
        row: Int = 0,
        column: Int = 0,
        style: TextStyle = .plain,
        link: URL? = nil
    ) {
        self.text = text
        self.row = row
        self.column = column
        self.style = style
        self.link = link
        self.terminalColumns = RunGroup(text).measure().maximumContentColumns
    }

    var width: Int {
        terminalColumns
    }

    var isEmpty: Bool {
        text.isEmpty
    }

    func offsetBy(x: Int, y: Int) -> RenderedRun {
        RenderedRun(
            text: text,
            row: row + y,
            column: column + x,
            style: style,
            link: link
        )
    }

    func clipped(to bounds: RenderedRect) -> [RenderedRun] {
        guard !bounds.isEmpty,
              row >= bounds.y,
              row < bounds.y + bounds.height else {
            return []
        }

        return clippedHorizontally(
            fromColumn: bounds.x,
            width: bounds.width
        ).map {
            RenderedRun(
                text: $0.text,
                row: row - bounds.y,
                column: $0.column - bounds.x,
                style: $0.style,
                link: $0.link
            )
        }
    }

    func clippedHorizontally(fromColumn lowerBound: Int, width: Int) -> [RenderedRun] {
        guard width > 0 else {
            return []
        }

        let lowerBound = max(lowerBound, 0)
        let upperBound = lowerBound + width
        var runs: [RenderedRun] = []
        var text = ""
        var textStartColumn: Int?
        var column = column
        let layout = RunGroup(self.text).layout()

        func flush() {
            guard !text.isEmpty, let startColumn = textStartColumn else {
                return
            }

            runs.append(
                RenderedRun(
                    text: text,
                    row: row,
                    column: startColumn,
                    style: style,
                    link: link
                )
            )
            text = ""
            textStartColumn = nil
        }

        for (offset, character) in self.text.enumerated() {
            let characterWidth = layout.columns(
                in: RunIndex(characterOffset: offset)
                    ..< RunIndex(characterOffset: offset + 1)
            )
            let nextColumn = column + characterWidth

            if column >= lowerBound, nextColumn <= upperBound {
                if textStartColumn == nil {
                    textStartColumn = column
                }
                text.append(character)
            }
            else {
                flush()
            }

            column = nextColumn
        }

        flush()
        return runs
    }
}

/// A rendered text insertion caret within a block.
///
/// This value describes an insertion point produced by editable text. It is
/// distinct from the terminal cursor that ANSI control sequences move, show,
/// or hide while presenting a frame.
nonisolated struct RenderedCaret: Equatable, Sendable {

    var row: Int

    var column: Int

    init(row: Int = 0, column: Int = 0) {
        self.row = max(row, 0)
        self.column = max(column, 0)
    }
}

nonisolated struct RenderedRect: Equatable, Sendable {

    var x: Int

    var y: Int

    var width: Int

    var height: Int

    init(x: Int = 0, y: Int = 0, width: Int = 0, height: Int = 0) {
        self.x = x
        self.y = y
        self.width = max(width, 0)
        self.height = max(height, 0)
    }

    var area: Int {
        width * height
    }

    var isEmpty: Bool {
        width == 0 || height == 0
    }

    func contains(column: Int, row: Int) -> Bool {
        !isEmpty
            && column >= x
            && column < x + width
            && row >= y
            && row < y + height
    }

    func offsetBy(x deltaX: Int, y deltaY: Int) -> RenderedRect {
        RenderedRect(
            x: x + deltaX,
            y: y + deltaY,
            width: width,
            height: height
        )
    }

    func clipped(to bounds: RenderedRect) -> RenderedRect? {
        let minX = max(x, bounds.x)
        let minY = max(y, bounds.y)
        let maxX = min(x + width, bounds.x + bounds.width)
        let maxY = min(y + height, bounds.y + bounds.height)
        let rect = RenderedRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        return rect.isEmpty ? nil : rect
    }
}

nonisolated struct RenderedHitRegion: Equatable, Sendable {

    var path: [Int]

    var frame: RenderedRect

    func offsetBy(x: Int, y: Int) -> RenderedHitRegion {
        RenderedHitRegion(path: path, frame: frame.offsetBy(x: x, y: y))
    }

    func clipped(to bounds: RenderedRect) -> RenderedHitRegion? {
        frame.clipped(to: bounds).map {
            RenderedHitRegion(path: path, frame: $0)
        }
    }
}

nonisolated struct RenderedScrollRegion: Equatable, Sendable {

    var path: [Int]

    var frame: RenderedRect

    func offsetBy(x: Int, y: Int) -> RenderedScrollRegion {
        RenderedScrollRegion(path: path, frame: frame.offsetBy(x: x, y: y))
    }

    func clipped(to bounds: RenderedRect) -> RenderedScrollRegion? {
        frame.clipped(to: bounds).map {
            RenderedScrollRegion(path: path, frame: $0)
        }
    }
}

nonisolated struct RenderedFocusRegion: Equatable, Sendable {

    var path: [Int]

    var frame: RenderedRect

    var positionFrame: RenderedRect? = nil

    func offsetBy(x: Int, y: Int) -> RenderedFocusRegion {
        RenderedFocusRegion(
            path: path,
            frame: frame.offsetBy(x: x, y: y),
            positionFrame: positionFrame?.offsetBy(x: x, y: y)
        )
    }

    func clipped(to bounds: RenderedRect) -> RenderedFocusRegion? {
        frame.clipped(to: bounds).map {
            RenderedFocusRegion(
                path: path,
                frame: $0,
                positionFrame: positionFrame?.clipped(to: bounds)
            )
        }
    }
}

nonisolated struct RenderedIdentifiedRegion: Equatable, @unchecked Sendable {

    var id: AnyHashable

    var frame: RenderedRect

    func offsetBy(x: Int, y: Int) -> RenderedIdentifiedRegion {
        RenderedIdentifiedRegion(id: id, frame: frame.offsetBy(x: x, y: y))
    }

    func clipped(to bounds: RenderedRect) -> RenderedIdentifiedRegion? {
        frame.clipped(to: bounds).map {
            RenderedIdentifiedRegion(id: id, frame: $0)
        }
    }
}

nonisolated struct RenderedCoordinateSpaceRegion: Equatable, @unchecked Sendable {

    var name: AnyHashable

    var path: [Int]

    var frame: RenderedRect

    func offsetBy(x: Int, y: Int) -> RenderedCoordinateSpaceRegion {
        RenderedCoordinateSpaceRegion(
            name: name,
            path: path,
            frame: frame.offsetBy(x: x, y: y)
        )
    }

    func clipped(to bounds: RenderedRect) -> RenderedCoordinateSpaceRegion? {
        frame.clipped(to: bounds).map {
            RenderedCoordinateSpaceRegion(name: name, path: path, frame: $0)
        }
    }
}

/// A terminal-cell rendering result with its interaction metadata.
///
/// Runs and regions share the block's zero-based coordinate space. Operations
/// that frame, pad, offset, clip, or composite a block must transform its caret
/// and every interaction region together with its visible runs so input and
/// rendering continue to describe the same view hierarchy.
nonisolated struct RenderedBlock: Equatable, Sendable {

    var runs: [RenderedRun]

    private var minimumWidth: Int

    private var minimumHeight: Int

    // Used only when projecting coordinate-based runs back to legacy lines.
    var paddedRows: Set<Int>

    var caret: RenderedCaret?

    var hitRegions: [RenderedHitRegion]

    var scrollRegions: [RenderedScrollRegion]

    var focusRegions: [RenderedFocusRegion]

    var identifiedRegions: [RenderedIdentifiedRegion]

    var coordinateSpaceRegions: [RenderedCoordinateSpaceRegion]

    var explicitAlignments: [AlignmentKey: Int]

    var spacing: ViewSpacing

    init(
        lines: [String],
        style: TextStyle = .plain,
        caret: RenderedCaret? = nil,
        hitRegions: [RenderedHitRegion] = [],
        scrollRegions: [RenderedScrollRegion] = [],
        focusRegions: [RenderedFocusRegion] = [],
        identifiedRegions: [RenderedIdentifiedRegion] = [],
        coordinateSpaceRegions: [RenderedCoordinateSpaceRegion] = [],
        explicitAlignments: [AlignmentKey: Int] = [:],
        spacing: ViewSpacing = ViewSpacing()
    ) {
        let minimumWidth = lines.map {
            RunGroup($0).measure().maximumContentColumns
        }.max() ?? 0
        self.runs = lines.enumerated().compactMap { row, line in
            line.isEmpty ? nil : RenderedRun(text: line, row: row, style: style)
        }
        self.minimumWidth = minimumWidth
        self.minimumHeight = lines.count
        self.paddedRows = Set(
            lines.enumerated().compactMap { row, line in
                line.isEmpty && minimumWidth > 0 ? row : nil
            }
        )
        self.caret = caret
        self.hitRegions = hitRegions
        self.scrollRegions = scrollRegions
        self.focusRegions = focusRegions
        self.identifiedRegions = identifiedRegions
        self.coordinateSpaceRegions = coordinateSpaceRegions
        self.explicitAlignments = explicitAlignments
        self.spacing = spacing
    }

    init(
        runs: [RenderedRun],
        width: Int? = nil,
        height: Int? = nil,
        paddedRows: Set<Int> = [],
        caret: RenderedCaret? = nil,
        hitRegions: [RenderedHitRegion] = [],
        scrollRegions: [RenderedScrollRegion] = [],
        focusRegions: [RenderedFocusRegion] = [],
        identifiedRegions: [RenderedIdentifiedRegion] = [],
        coordinateSpaceRegions: [RenderedCoordinateSpaceRegion] = [],
        explicitAlignments: [AlignmentKey: Int] = [:],
        spacing: ViewSpacing = ViewSpacing()
    ) {
        self.runs = runs.filter { !$0.isEmpty }
        self.minimumWidth = max(width ?? 0, 0)
        self.minimumHeight = max(height ?? 0, 0)
        self.paddedRows = paddedRows
        self.caret = caret
        self.hitRegions = hitRegions
        self.scrollRegions = scrollRegions
        self.focusRegions = focusRegions
        self.identifiedRegions = identifiedRegions
        self.coordinateSpaceRegions = coordinateSpaceRegions
        self.explicitAlignments = explicitAlignments
        self.spacing = spacing
    }

    static func == (lhs: RenderedBlock, rhs: RenderedBlock) -> Bool {
        lhs.runs == rhs.runs
            && lhs.minimumWidth == rhs.minimumWidth
            && lhs.minimumHeight == rhs.minimumHeight
            && lhs.paddedRows == rhs.paddedRows
            && lhs.caret == rhs.caret
            && lhs.hitRegions == rhs.hitRegions
            && lhs.scrollRegions == rhs.scrollRegions
            && lhs.focusRegions == rhs.focusRegions
            && lhs.identifiedRegions == rhs.identifiedRegions
            && lhs.coordinateSpaceRegions == rhs.coordinateSpaceRegions
            && lhs.explicitAlignments == rhs.explicitAlignments
            && lhs.spacing.isEqual(to: rhs.spacing)
    }

    var lines: [String] {
        guard height > 0 else {
            return []
        }

        var lines = Array(repeating: "", count: height)
        var lineColumns = Array(repeating: 0, count: height)
        for run in runs.sorted(by: { lhs, rhs in
            if lhs.row == rhs.row {
                return lhs.column < rhs.column
            }
            return lhs.row < rhs.row
        }) {
            guard lines.indices.contains(run.row) else {
                continue
            }

            let currentWidth = lineColumns[run.row]
            if currentWidth < run.column {
                lines[run.row] += String(repeating: " ", count: run.column - currentWidth)
                lineColumns[run.row] = run.column
            }
            lines[run.row] += run.text
            lineColumns[run.row] += run.width
        }

        return lines.enumerated().map { row, line in
            if !line.isEmpty || paddedRows.contains(row) {
                return line + String(
                    repeating: " ",
                    count: max(width - lineColumns[row], 0)
                )
            }
            return line
        }
    }

    var text: String {
        lines.joined(separator: "\n")
    }

    var width: Int {
        max(
            minimumWidth,
            runs.map { $0.column + $0.width }.max() ?? 0
        )
    }

    var height: Int {
        max(
            minimumHeight,
            runs.map { $0.row + 1 }.max() ?? 0
        )
    }

    var bounds: RenderedRect {
        RenderedRect(width: width, height: height)
    }

    var viewDimensions: ViewDimensions {
        ViewDimensions(
            columns: width,
            rows: height,
            explicitAlignments: explicitAlignments
        )
    }

    func settingExplicitAlignment(
        _ guide: HorizontalAlignment,
        computeValue: @Sendable (ViewDimensions) -> Int
    ) -> RenderedBlock {
        settingExplicitAlignment(guide.key, computeValue: computeValue)
    }

    func settingExplicitAlignment(
        _ guide: VerticalAlignment,
        computeValue: @Sendable (ViewDimensions) -> Int
    ) -> RenderedBlock {
        settingExplicitAlignment(guide.key, computeValue: computeValue)
    }

    private func settingExplicitAlignment(
        _ key: AlignmentKey,
        computeValue: @Sendable (ViewDimensions) -> Int
    ) -> RenderedBlock {
        var block = self
        block.explicitAlignments[key] = computeValue(viewDimensions)
        return block
    }

    func framed(width targetWidth: Int, height targetHeight: Int, alignment: Alignment) -> RenderedBlock {
        let targetWidth = max(targetWidth, 0)
        let targetHeight = max(targetHeight, 0)
        guard targetWidth > 0, targetHeight > 0 else {
            return RenderedBlock(lines: [])
        }

        let x = horizontalOffset(
            contentWidth: width,
            containerWidth: targetWidth,
            alignment: alignment.horizontal
        )
        let y = verticalOffset(
            contentHeight: height,
            containerHeight: targetHeight,
            alignment: alignment.vertical
        )

        return RenderedBlock(
            runs: runs.flatMap {
                $0.offsetBy(x: x, y: y).clipped(
                    to: RenderedRect(width: targetWidth, height: targetHeight)
                )
            },
            width: targetWidth,
            height: targetHeight,
            paddedRows: Set(0..<targetHeight),
            caret: framedCaret(x: x, y: y, width: targetWidth, height: targetHeight),
            hitRegions: framedHitRegions(x: x, y: y, width: targetWidth, height: targetHeight),
            scrollRegions: framedScrollRegions(x: x, y: y, width: targetWidth, height: targetHeight),
            focusRegions: framedFocusRegions(x: x, y: y, width: targetWidth, height: targetHeight),
            identifiedRegions: framedIdentifiedRegions(
                x: x,
                y: y,
                width: targetWidth,
                height: targetHeight
            ),
            coordinateSpaceRegions: framedCoordinateSpaceRegions(
                x: x,
                y: y,
                width: targetWidth,
                height: targetHeight
            ),
            explicitAlignments: offsetExplicitAlignments(x: x, y: y),
            spacing: spacing
        )
    }

    func padded(by insets: EdgeInsets) -> RenderedBlock {
        let contentWidth = width
        let targetWidth = contentWidth + insets.horizontal

        return RenderedBlock(
            runs: runs.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            width: targetWidth,
            height: height + insets.vertical,
            paddedRows: Set(0..<(height + insets.vertical)),
            caret: caret.map {
                RenderedCaret(row: $0.row + insets.top, column: $0.column + insets.leading)
            },
            hitRegions: hitRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            scrollRegions: scrollRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            focusRegions: focusRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            identifiedRegions: identifiedRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            coordinateSpaceRegions: coordinateSpaceRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            explicitAlignments: offsetExplicitAlignments(
                x: insets.leading,
                y: insets.top
            ),
            spacing: spacing
        )
    }

    func offsetBy(x: Int, y: Int, clippedTo bounds: RenderedRect) -> RenderedBlock {
        RenderedBlock(
            runs: runs.flatMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            width: bounds.width,
            height: bounds.height,
            paddedRows: Set(
                paddedRows.map { $0 + y }.filter {
                    $0 >= 0 && $0 < bounds.height
                }
            ),
            caret: offsetCaret(x: x, y: y, bounds: bounds),
            hitRegions: hitRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            scrollRegions: scrollRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            focusRegions: focusRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            identifiedRegions: identifiedRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            coordinateSpaceRegions: coordinateSpaceRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            explicitAlignments: offsetExplicitAlignments(x: x, y: y),
            spacing: spacing
        )
    }

    func aligned(in bounds: RenderedRect, alignment: Alignment) -> RenderedBlock {
        offsetBy(
            x: horizontalOffset(
                contentWidth: width,
                containerWidth: bounds.width,
                alignment: alignment.horizontal
            ),
            y: verticalOffset(
                contentHeight: height,
                containerHeight: bounds.height,
                alignment: alignment.vertical
            ),
            clippedTo: bounds
        )
    }

    static func composited(
        _ blocks: [RenderedBlock],
        width: Int,
        height: Int,
        paddedRows: Set<Int> = []
    ) -> RenderedBlock {
        let width = max(width, 0)
        let height = max(height, 0)
        let bounds = RenderedRect(width: width, height: height)
        let visiblePaddedRows = Set(
            paddedRows.union(blocks.flatMap(\.paddedRows)).filter {
                $0 >= 0 && $0 < height
            }
        )

        return RenderedBlock(
            runs: CompositedCell.runs(from: blocks, clippedTo: bounds),
            width: width,
            height: height,
            paddedRows: visiblePaddedRows,
            caret: blocks.reversed().compactMap(\.caret).first,
            hitRegions: blocks.reversed().flatMap(\.hitRegions),
            scrollRegions: blocks.reversed().flatMap(\.scrollRegions),
            focusRegions: blocks.reversed().flatMap(\.focusRegions),
            identifiedRegions: blocks.reversed().flatMap(\.identifiedRegions),
            coordinateSpaceRegions: blocks.reversed().flatMap(\.coordinateSpaceRegions),
            explicitAlignments: combinedExplicitAlignments(from: blocks),
            spacing: blocks.reduce(ViewSpacing()) {
                $0.union($1.spacing)
            }
        )
    }

    static func combinedExplicitAlignments(
        from blocks: [RenderedBlock]
    ) -> [AlignmentKey: Int] {
        let keys = Set(blocks.flatMap { $0.explicitAlignments.keys })
        return Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            let values = blocks.compactMap { $0.explicitAlignments[key] }
            guard !values.isEmpty else {
                return nil
            }
            return (key, values.reduce(0, +) / values.count)
        })
    }

    func offsetExplicitAlignments(x: Int, y: Int) -> [AlignmentKey: Int] {
        Dictionary(uniqueKeysWithValues: explicitAlignments.map { key, value in
            (key, value + (key.axis == .horizontal ? x : y))
        })
    }

    private func framedCaret(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> RenderedCaret? {
        guard let caret else {
            return nil
        }

        let row = caret.row + y
        let column = caret.column + x
        guard row >= 0,
              row < targetHeight,
              column >= 0,
              column <= targetWidth else {
            return nil
        }

        return RenderedCaret(row: row, column: min(column, targetWidth - 1))
    }

    private func offsetCaret(x: Int, y: Int, bounds: RenderedRect) -> RenderedCaret? {
        guard let caret else {
            return nil
        }

        let row = caret.row + y
        let column = caret.column + x
        guard row >= bounds.y,
              row < bounds.y + bounds.height,
              column >= bounds.x,
              column <= bounds.x + bounds.width else {
            return nil
        }

        return RenderedCaret(
            row: row - bounds.y,
            column: min(column - bounds.x, bounds.width - 1)
        )
    }

    private func framedHitRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedHitRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return hitRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func framedScrollRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedScrollRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return scrollRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func framedFocusRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedFocusRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return focusRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func framedIdentifiedRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedIdentifiedRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return identifiedRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func framedCoordinateSpaceRegions(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [RenderedCoordinateSpaceRegion] {
        let bounds = RenderedRect(width: targetWidth, height: targetHeight)
        return coordinateSpaceRegions.compactMap {
            $0.offsetBy(x: x, y: y).clipped(to: bounds)
        }
    }

    private func horizontalOffset(
        contentWidth: Int,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = containerWidth - contentWidth
        if viewDimensions[explicit: alignment] != nil {
            let container = ViewDimensions(columns: containerWidth, rows: height)
            return container[alignment] - viewDimensions[alignment]
        }
        if alignment == .leading {
            return 0
        }
        if alignment == .center {
            return padding / 2
        }
        if alignment == .trailing {
            return padding
        }
        let container = ViewDimensions(columns: containerWidth, rows: height)
        return container[alignment] - viewDimensions[alignment]
    }

    private func verticalOffset(
        contentHeight: Int,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = containerHeight - contentHeight
        if viewDimensions[explicit: alignment] != nil {
            let container = ViewDimensions(columns: width, rows: containerHeight)
            return container[alignment] - viewDimensions[alignment]
        }
        if alignment == .top {
            return 0
        }
        if alignment == .center {
            return padding / 2
        }
        if alignment == .bottom {
            return padding
        }
        let container = ViewDimensions(columns: width, rows: containerHeight)
        return container[alignment] - viewDimensions[alignment]
    }
}

private nonisolated struct CompositedCell: Equatable {

    var text: String

    var row: Int

    var column: Int

    var width: Int

    var style: TextStyle

    var link: URL?

    static func runs(
        from blocks: [RenderedBlock],
        clippedTo bounds: RenderedRect
    ) -> [RenderedRun] {
        guard !bounds.isEmpty else {
            return []
        }

        var rows: [Int: [Int: CompositedCell]] = [:]
        for block in blocks {
            for run in block.runs.flatMap({ $0.clipped(to: bounds) }) {
                write(run, to: &rows)
            }
        }

        return rows
            .flatMap { row, cellsByColumn in
                uniqueCells(in: cellsByColumn).map {
                    RenderedRun(
                        text: $0.text,
                        row: row,
                        column: $0.column,
                        style: $0.style,
                        link: $0.link
                    )
                }
            }
            .sorted {
                if $0.row == $1.row {
                    return $0.column < $1.column
                }

                return $0.row < $1.row
            }
            .mergedAdjacentRuns()
    }

    private static func write(
        _ run: RenderedRun,
        to rows: inout [Int: [Int: CompositedCell]]
    ) {
        var column = run.column
        let layout = RunGroup(run.text).layout()
        for (offset, character) in run.text.enumerated() {
            let text = String(character)
            let width = layout.columns(
                in: RunIndex(characterOffset: offset)
                    ..< RunIndex(characterOffset: offset + 1)
            )
            guard width > 0 else {
                continue
            }

            write(
                CompositedCell(
                    text: text,
                    row: run.row,
                    column: column,
                    width: width,
                    style: run.style,
                    link: run.link
                ),
                to: &rows
            )
            column += width
        }
    }

    private static func write(
        _ cell: CompositedCell,
        to rows: inout [Int: [Int: CompositedCell]]
    ) {
        var cellsByColumn = rows[cell.row] ?? [:]
        let columns = cell.column..<(cell.column + cell.width)
        var overlappedCells: [CompositedCell] = []

        for column in columns {
            if let overlappedCell = cellsByColumn[column],
               !overlappedCells.contains(overlappedCell) {
                overlappedCells.append(overlappedCell)
            }
        }

        let cell = cell.inheritingBackground(from: overlappedCells)

        for overlappedCell in overlappedCells {
            for column in overlappedCell.column..<(overlappedCell.column + overlappedCell.width) {
                cellsByColumn[column] = nil
            }
        }

        for column in columns {
            cellsByColumn[column] = cell
        }
        rows[cell.row] = cellsByColumn
    }

    private func inheritingBackground(from cells: [CompositedCell]) -> CompositedCell {
        guard style.backgroundStyle == nil,
              let backgroundStyle = cells.lazy.compactMap(\.style.backgroundStyle).first else {
            return self
        }

        var cell = self
        cell.style.backgroundStyle = backgroundStyle
        return cell
    }

    private static func uniqueCells(
        in cellsByColumn: [Int: CompositedCell]
    ) -> [CompositedCell] {
        var cells: [CompositedCell] = []
        for cell in cellsByColumn.values.sorted(by: { $0.column < $1.column }) {
            if !cells.contains(cell) {
                cells.append(cell)
            }
        }
        return cells
    }
}

extension [RenderedRun] {

    fileprivate nonisolated func mergedAdjacentRuns() -> [RenderedRun] {
        var runs: [RenderedRun] = []
        for run in self {
            guard let last = runs.last,
                  last.row == run.row,
                  last.column + last.width == run.column,
                  last.style == run.style,
                  last.link == run.link else {
                runs.append(run)
                continue
            }

            runs[runs.count - 1] = RenderedRun(
                text: last.text + run.text,
                row: last.row,
                column: last.column,
                style: last.style,
                link: last.link
            )
        }
        return runs
    }
}
