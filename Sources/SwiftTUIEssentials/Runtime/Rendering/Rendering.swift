import Foundation

nonisolated struct TerminalViewportSize: Equatable, Sendable {

    var columns: Int

    var rows: Int

    init(columns: Int, rows: Int) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
    }
}

nonisolated struct TextFrame: Equatable, Sendable {

    var text: String

    var row: Int

    var column: Int
}

nonisolated struct RenderedRun: Equatable, Sendable {

    var text: String

    var row: Int

    var column: Int

    var style: TextStyle

    var link: URL?

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
    }

    var width: Int {
        TerminalText.columnWidth(text)
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

        for character in self.text {
            let characterText = String(character)
            let characterWidth = TerminalText.columnWidth(characterText)
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
        let minimumWidth = lines.map(TerminalText.columnWidth).max() ?? 0
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
        for run in runs.sorted(by: { lhs, rhs in
            if lhs.row == rhs.row {
                return lhs.column < rhs.column
            }
            return lhs.row < rhs.row
        }) {
            guard lines.indices.contains(run.row) else {
                continue
            }

            let currentWidth = TerminalText.columnWidth(lines[run.row])
            if currentWidth < run.column {
                lines[run.row] += String(repeating: " ", count: run.column - currentWidth)
            }
            lines[run.row] += run.text
        }

        return lines.enumerated().map { row, line in
            if !line.isEmpty || paddedRows.contains(row) {
                return TerminalText.lineProjection(line, paddedToWidth: width)
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
        for character in run.text {
            let text = String(character)
            let width = TerminalText.columnWidth(text)
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

private extension [RenderedRun] {

    nonisolated func mergedAdjacentRuns() -> [RenderedRun] {
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

nonisolated struct RenderProposal: Equatable, Sendable {

    var columns: Int?

    var rows: Int?

    init(columns: Int? = nil, rows: Int? = nil) {
        self.columns = columns
        self.rows = rows
    }

    init(_ viewport: TerminalViewportSize) {
        self.init(columns: viewport.columns, rows: viewport.rows)
    }
}

nonisolated enum RenderedElement: Equatable, Sendable {

    case block(RenderedBlock)

    case spacer(minLength: Int)
}

nonisolated struct LayoutTraits: Sendable {

    var flexibleAxes: Axis.Set = []

    var fillsStackMinorAxis = false

    var maximumColumns: Int? = nil

    var maximumRows: Int? = nil

    var priority: Double = 0

    var zIndex: Double = 0

    var gridCellColumns = 1

    var gridCellAnchor: UnitPoint?

    var gridCellUnsizedAxes: Axis.Set = []

    var gridColumnAlignment: HorizontalAlignment?

    private var layoutValues = LayoutValueStorage()

    private var containerValueStorage = ContainerValueStorage()

    init(
        flexibleAxes: Axis.Set = [],
        fillsStackMinorAxis: Bool = false,
        priority: Double = 0,
        zIndex: Double = 0
    ) {
        self.flexibleAxes = flexibleAxes
        self.fillsStackMinorAxis = fillsStackMinorAxis
        self.priority = priority
        self.zIndex = zIndex
    }

    func removingFlexibleAxes(_ axes: Axis.Set) -> LayoutTraits {
        var traits = self
        traits.flexibleAxes.subtract(axes)
        return traits
    }

    func settingMaximumSize(columns: Int?, rows: Int?) -> LayoutTraits {
        var traits = self
        if let columns {
            traits.maximumColumns = traits.maximumColumns.map { min($0, columns) } ?? columns
        }
        if let rows {
            traits.maximumRows = traits.maximumRows.map { min($0, rows) } ?? rows
        }
        return traits
    }

    func settingPriority(_ value: Double) -> LayoutTraits {
        var traits = self
        traits.priority = value
        return traits
    }

    func settingZIndex(_ value: Double) -> LayoutTraits {
        var traits = self
        traits.zIndex = value
        return traits
    }

    func settingGridCellColumns(_ count: Int) -> LayoutTraits {
        var traits = self
        traits.gridCellColumns = max(count, 1)
        return traits
    }

    func settingGridCellAnchor(_ anchor: UnitPoint) -> LayoutTraits {
        var traits = self
        traits.gridCellAnchor = anchor
        return traits
    }

    func settingGridCellUnsizedAxes(_ axes: Axis.Set) -> LayoutTraits {
        var traits = self
        traits.gridCellUnsizedAxes = axes
        return traits
    }

    func settingGridColumnAlignment(_ alignment: HorizontalAlignment) -> LayoutTraits {
        var traits = self
        traits.gridColumnAlignment = alignment
        return traits
    }

    func settingLayoutValue<K: LayoutValueKey>(
        key: K.Type,
        value: K.Value
    ) -> LayoutTraits {
        var traits = self
        traits.layoutValues.set(value, for: key)
        return traits
    }

    func layoutValue<K: LayoutValueKey>(for key: K.Type) -> K.Value {
        layoutValues.value(for: key)
    }

    var containerValues: ContainerValues {
        ContainerValues(storage: containerValueStorage)
    }

    func settingContainerValue<Value>(
        _ keyPath: WritableKeyPath<ContainerValues, Value>,
        value: Value
    ) -> LayoutTraits {
        var traits = self
        var values = traits.containerValues
        values[keyPath: keyPath] = value
        traits.containerValueStorage = values.storage
        return traits
    }

    func settingTag<Value: Hashable>(
        _ tag: Value,
        includeOptional: Bool
    ) -> LayoutTraits {
        var traits = self
        traits.containerValueStorage.setTag(
            tag,
            includeOptional: includeOptional
        )
        return traits
    }
}

private nonisolated struct LayoutValueStorage: @unchecked Sendable {

    private var values: [ObjectIdentifier: Any] = [:]

    func value<K: LayoutValueKey>(for key: K.Type) -> K.Value {
        values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue
    }

    mutating func set<K: LayoutValueKey>(_ value: K.Value, for key: K.Type) {
        values[ObjectIdentifier(key)] = value
    }
}

nonisolated struct ContainerValueStorage: @unchecked Sendable {

    private var values: [ObjectIdentifier: StoredContainerValue] = [:]

    private var tags: [ObjectIdentifier: StoredContainerValue] = [:]

    func value<Key: ContainerValueKey>(for key: Key.Type) -> Key.Value {
        guard let stored = values[ObjectIdentifier(key)],
              let value = stored.value as? Key.Value else {
            return Key.defaultValue
        }
        return value
    }

    mutating func set<Key: ContainerValueKey>(
        _ value: Key.Value,
        for key: Key.Type
    ) {
        values[ObjectIdentifier(key)] = StoredContainerValue(value)
    }

    func tag<Value: Hashable>(for type: Value.Type) -> Value? {
        guard let stored = tags[ObjectIdentifier(type)] else {
            return nil
        }
        return stored.value as? Value
    }

    func hasTag<Value: Hashable>(_ tag: Value) -> Bool {
        self.tag(for: Value.self).map { $0 == tag } ?? false
    }

    mutating func setTag<Value: Hashable>(
        _ tag: Value,
        includeOptional: Bool
    ) {
        setTag(tag, for: Value.self)
        if includeOptional {
            let optionalTag: Value? = tag
            setTag(optionalTag, for: Optional<Value>.self)
        }
    }

    private mutating func setTag<Value: Hashable>(
        _ tag: Value,
        for type: Value.Type
    ) {
        tags[ObjectIdentifier(type)] = StoredContainerValue(tag)
    }
}

private nonisolated struct StoredContainerValue {

    let value: Any

    init<Value>(_ value: Value) {
        self.value = value
    }
}

protocol LayoutTraitRenderable {

    var layoutTraits: LayoutTraits { get }
}

nonisolated struct StackChild {

    var traits: LayoutTraits

    var isSpacer: Bool = false

    var isEmptyView: Bool = false

    var suppressesVerticalFlexInParentStack: Bool = false

    var render: (RenderProposal?, Bool) -> RenderedElement?
}

enum LayoutMeasurementContext {

    @TaskLocal
    private static var taskIsMeasuring = false

    static var isMeasuring: Bool {
        taskIsMeasuring
    }

    static func withMeasurement<Value>(_ operation: () -> Value) -> Value {
        $taskIsMeasuring.withValue(true) {
            return operation()
        }
    }
}

enum StackAxisContext {

    @TaskLocal
    static var axis: Axis?

    static func withAxis<Value>(
        _ axis: Axis?,
        operation: () -> Value
    ) -> Value {
        $axis.withValue(axis, operation: operation)
    }
}

nonisolated enum ExplicitAlignmentQueryContext {

    @TaskLocal
    static var keys: Set<AlignmentKey> = []

    static func withKeys<Value>(
        _ additionalKeys: Set<AlignmentKey>,
        operation: () -> Value
    ) -> Value {
        $keys.withValue(keys.union(additionalKeys), operation: operation)
    }
}

protocol FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement]

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild]
}

extension FlattenableViewContent {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        StackRenderer.vertical(
            renderedElements(in: proposal, path: path, runtime: runtime).map { element in
                StackChild(
                    traits: LayoutTraits(),
                    isSpacer: element.isSpacer,
                    suppressesVerticalFlexInParentStack: false,
                    render: { _, _ in element }
                )
            },
            alignment: .leading,
            spacing: 0,
            proposal: proposal
        )
    }
}

extension AnyView: FlattenableViewContent, GridContentRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        storage.layoutTraits
    }

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        storage.renderedElements(in: proposal, path: path, runtime: runtime)
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        storage.stackChildren(in: proposal, path: path, runtime: runtime)
    }

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        storage.gridItems(in: proposal, path: path, runtime: runtime)
    }
}

extension OptionalViewContent: LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        content.map(ViewResolver.layoutTraits) ?? LayoutTraits()
    }
}

extension ConditionalViewContent: LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        switch storage {
        case .trueContent(let content):
            return ViewResolver.layoutTraits(from: content)
        case .falseContent(let content):
            return ViewResolver.layoutTraits(from: content)
        }
    }
}

extension LimitedAvailabilityViewContent: LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }
}

extension GridRow: FlattenableViewContent, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.stackLayoutTraits(
            from: content,
            propagatedAxes: [.horizontal, .vertical],
            spacerAxis: nil
        )
    }

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension Group: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension OptionalViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        guard let content else {
            return []
        }

        return ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        guard let content else {
            return []
        }

        return ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ConditionalViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.elements(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.elements(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.stackChildren(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.stackChildren(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }
}

extension LimitedAvailabilityViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ForEach: FlattenableViewContent where Content: View {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let renderedElements = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(
                at: path,
                id: elementID
            ) ?? offset
            let childPath = path + [childIndex]
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.elements(
                from: child,
                in: proposal,
                path: childPath,
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return renderedElements
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let children = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(
                at: path,
                id: elementID
            ) ?? offset
            let childPath = path + [childIndex]
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.stackChildren(
                from: child,
                in: proposal,
                path: childPath,
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return children
    }

    private func contentElement(
        _ element: Data.Element,
        runtime: StateRuntime?
    ) -> Content {
        guard let runtime, let contextPath else {
            return content(element)
        }

        return runtime.withView(at: contextPath, mode: .render) {
            content(element)
        }
    }
}

extension Group: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        ViewResolver.gridItems(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension OptionalViewContent: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        guard let content else {
            return []
        }
        return ViewResolver.gridItems(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ConditionalViewContent: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.gridItems(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.gridItems(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }
}

extension LimitedAvailabilityViewContent: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        ViewResolver.gridItems(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ForEach: GridContentRenderable where Content: View {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let items = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(at: path, id: elementID) ?? offset
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.gridItems(
                from: child,
                in: proposal,
                path: path + [childIndex],
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return items
    }
}

private struct TextSourceLine {

    var text: String

    var sourceOffsets: [Int?]

    var lowerOffset: Int

    var upperOffset: Int

    static func mappedLines(for text: String, maxWidth: Int?) -> [TextSourceLine] {
        let displayLines = TextLineWrapper.wrappedLines(for: text, maxWidth: maxWidth)
        var lines: [TextSourceLine] = []
        var searchStart = text.startIndex
        for displayLine in displayLines {
            let range: Range<String.Index>
            if displayLine.isEmpty {
                range = searchStart..<searchStart
            }
            else if let found = text.range(of: displayLine, range: searchStart..<text.endIndex) {
                range = found
            }
            else {
                range = searchStart..<searchStart
            }

            let lowerOffset = text.distance(from: text.startIndex, to: range.lowerBound)
            let upperOffset = text.distance(from: text.startIndex, to: range.upperBound)
            lines.append(
                TextSourceLine(
                    text: displayLine,
                    sourceOffsets: Array(lowerOffset..<upperOffset).map(Optional.some),
                    lowerOffset: lowerOffset,
                    upperOffset: upperOffset
                )
            )
            searchStart = range.upperBound
            if searchStart < text.endIndex, text[searchStart] == "\n" {
                searchStart = text.index(after: searchStart)
            }
        }
        return lines
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
            let suffix = TerminalText.suffix(endingLine.text, maxWidth: contentWidth)
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
            var prefix = TerminalText.prefix(text, maxWidth: preferredPrefixWidth)
            var suffix = TerminalText.suffix(
                endingLine.text,
                maxWidth: contentWidth - TerminalText.columnWidth(prefix)
            )
            prefix = TerminalText.prefix(
                text,
                maxWidth: contentWidth - TerminalText.columnWidth(suffix)
            )
            suffix = TerminalText.suffix(
                endingLine.text,
                maxWidth: contentWidth - TerminalText.columnWidth(prefix)
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
            let prefix = TerminalText.prefix(text, maxWidth: contentWidth)
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

enum TextLayoutRenderer {

    static func block(
        for text: Text,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock {
        let lineLimit = EnvironmentRenderContext.current.textLineLimit
        var lines = TextSourceLine.mappedLines(for: text.content, maxWidth: proposal?.columns)
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
        let naturalWidth = lines.map { TerminalText.columnWidth($0.text) }.max() ?? 0
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
            block.hitRegions.append(RenderedHitRegion(path: path, frame: block.bounds))
            runtime?.registerPointerDownPositionHandler(
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
            block.hitRegions.append(
                RenderedHitRegion(
                    path: linkPath,
                    frame: RenderedRect(
                        x: run.column,
                        y: run.row,
                        width: run.width,
                        height: 1
                    )
                )
            )
            runtime?.registerLinkHandler(
                LinkHandler(
                    actionPath: linkPath,
                    action: {
                        EnvironmentRenderContext.current.openURL.result(for: url).accepted
                    }
                ),
                at: linkPath
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
        for (character, sourceOffset) in zip(line.source.text, line.source.sourceOffsets) {
            let width = TerminalText.columnWidth(String(character))
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

        var alignment: AttributedTextAlignment?
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
            var rowAlignment: AttributedTextAlignment?

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

            for (character, sourceOffset) in zip(line.text, line.sourceOffsets) {
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
                column += TerminalText.columnWidth(characterText)
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
        text.runs.flatMap { run -> [StyledCharacter] in
            var style = baseStyle.merged(with: run.style)
            if run.link != nil, style.foregroundStyle == nil, let tint {
                style.foregroundStyle = tint
            }

            return run.text.map {
                StyledCharacter(
                    character: $0,
                    style: style,
                    link: run.link,
                    alignment: run.alignment
                )
            }
        }
    }

    private static func horizontalOffset(
        for line: String,
        alignment: AttributedTextAlignment?,
        defaultAlignment: TextAlignment,
        width: Int?
    ) -> Int {
        guard let width else {
            return 0
        }

        let padding = max(width - TerminalText.columnWidth(line), 0)
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

enum TextLineWrapper {

    static func wrappedLines(for text: String, maxWidth: Int?) -> [String] {
        let paragraphs = UnicodeLineBreak.lineSegments(in: text).map(String.init)
        guard let maxWidth else {
            return paragraphs
        }
        guard maxWidth > 0 else {
            return []
        }

        let lines = paragraphs.flatMap { paragraph in
            wrappedParagraph(paragraph, maxWidth: maxWidth)
        }
        return lines.isEmpty ? [""] : lines
    }

    private static func wrappedParagraph(_ paragraph: String, maxWidth: Int) -> [String] {
        guard !paragraph.isEmpty else {
            return [""]
        }

        var lines: [String] = []
        var start = paragraph.startIndex
        let opportunities = UnicodeLineBreak.opportunities(in: paragraph)
        var opportunityIndex = opportunities.startIndex

        while start < paragraph.endIndex {
            while opportunityIndex < opportunities.endIndex,
                  opportunities[opportunityIndex].index <= start
            {
                opportunityIndex = opportunities.index(after: opportunityIndex)
            }

            if TerminalText.columnWidth(String(paragraph[start..<paragraph.endIndex])) <= maxWidth {
                lines.append(String(paragraph[start..<paragraph.endIndex]))
                break
            }

            var bestBreak: UnicodeLineBreak.Opportunity?
            var scanIndex = opportunityIndex
            while scanIndex < opportunities.endIndex {
                let opportunity = opportunities[scanIndex]
                let width = TerminalText.columnWidth(String(paragraph[start..<opportunity.index]))
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
                    lines.append(String(paragraph[start..<fallbackEnd]))
                    start = fallbackEnd
                }
                else {
                    lines.append(String(paragraph[start..<lineEnd]))
                    start = skippingLeadingWhitespace(in: paragraph, from: bestBreak.index)
                    opportunityIndex = scanIndex
                }
            }
            else {
                lines.append(String(paragraph[start..<fallbackEnd]))
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

    static func truncatedLine(_ line: String, maxWidth: Int?) -> String {
        guard let maxWidth else {
            return line + "..."
        }
        guard maxWidth > 0 else {
            return ""
        }
        guard maxWidth >= 3 else {
            return String(repeating: ".", count: maxWidth)
        }

        return TerminalText.prefix(line, maxWidth: maxWidth - 3) + "..."
    }
}

enum ViewResolver {

    private enum BlockResolution {

        case unresolved

        case resolved(RenderedBlock?)
    }

    static func text<Content: View>(from view: Content) -> String? {
        block(from: view)?.text
    }

    static func block<Content: View>(from view: Content) -> RenderedBlock? {
        block(from: view, in: nil)
    }

    static func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> RenderedBlock? {
        block(
            from: view,
            in: rootProposal(for: view, proposal: proposal),
            path: [],
            runtime: nil
        )
    }

    static func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        switch directlyResolvedBlock(from: view, in: proposal, path: path, runtime: runtime) {
        case .resolved(let block):
            return block
        case .unresolved:
            break
        }

        if let geometryReader = view as? any GeometryReaderRenderable {
            return geometryReader.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let layout = view as? any LayoutRenderable {
            return layout.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let viewThatFits = view as? any ViewThatFitsRenderable {
            return viewThatFits.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let navigation = view as? any NavigationRenderable {
            return navigation.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any LayoutModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any ScrollPositionModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any EnvironmentModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any LifecycleModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any ChangeModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any HiddenModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any TerminationModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any OpenURLModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any FocusModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any InputModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        let body = body(from: view, path: path, runtime: runtime)
        return block(from: body, in: proposal, path: path + [0], runtime: runtime)
    }

    static func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> RenderedElement? {
        element(from: view, in: proposal, path: [], runtime: nil)
    }

    static func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        switch directlyResolvedBlock(from: view, in: proposal, path: path, runtime: runtime) {
        case .resolved(let block):
            if let spacer = view as? Spacer {
                return .spacer(minLength: spacer.minLength ?? 0)
            }
            return block.map { .block($0) }
        case .unresolved:
            break
        }

        if let geometryReader = view as? any GeometryReaderRenderable {
            return geometryReader.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let layout = view as? any LayoutRenderable {
            return layout.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let viewThatFits = view as? any ViewThatFitsRenderable {
            return viewThatFits.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let navigation = view as? any NavigationRenderable {
            return navigation.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any LayoutModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any ScrollPositionModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any EnvironmentModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any LifecycleModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any ChangeModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any HiddenModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any TerminationModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any OpenURLModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any FocusModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any InputModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        let body = body(from: view, path: path, runtime: runtime)
        return element(from: body, in: proposal, path: path + [0], runtime: runtime)
    }

    private static func directlyResolvedBlock<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> BlockResolution {
        if let text = view as? Text {
            return .resolved(
                TextLayoutRenderer.block(
                    for: text,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            )
        }

        if view is EmptyView {
            return .resolved(nil)
        }

        if let spacer = view as? Spacer {
            return .resolved(block(for: spacer, in: proposal))
        }

        if let scroll = view as? any ScrollRenderable {
            return .resolved(scroll.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let editableText = view as? any EditableTextRenderable {
            return .resolved(
                editableText.renderedBlock(in: proposal, path: path, runtime: runtime)
            )
        }

        if let divider = view as? any DividerRenderable {
            return .resolved(
                DividerRenderer.renderedBlock(
                    drawingSet: divider.dividerDrawingSet,
                    proposal: proposal
                )
            )
        }

        if let fillShape = view as? any FillShapeRenderable {
            return .resolved(fillShape.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let shape = view as? any ShapeRenderable {
            return .resolved(ShapeRenderer.defaultBlock(shape: shape, proposal: proposal))
        }

        if let box = view as? any BoxRenderable {
            return .resolved(box.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let group = view as? ViewGroup {
            return .resolved(
                StackRenderer.vertical(
                    group.elements.enumerated().flatMap { index, element in
                        element.stackChildren(
                            in: proposal,
                            path: path + [index],
                            runtime: runtime
                        )
                    },
                    alignment: .leading,
                    spacing: 0,
                    proposal: proposal
                )
            )
        }

        if let content = view as? any FlattenableViewContent {
            return .resolved(content.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let stack = view as? any StackRenderable {
            return .resolved(stack.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        return .unresolved
    }

    private static func block(
        for spacer: Spacer,
        in proposal: RenderProposal?
    ) -> RenderedBlock? {
        let minLength = spacer.minLength ?? 0
        let width = max(proposal?.columns ?? minLength, minLength)
        let height = max(proposal?.rows ?? minLength, minLength)
        guard width > 0 || height > 0 else {
            return nil
        }

        let renderedHeight = max(height, 1)
        return RenderedBlock(
            runs: [],
            width: width,
            height: renderedHeight,
            paddedRows: Set(0..<renderedHeight)
        )
    }
}

enum TextRenderer {

    static func frame(
        for text: String,
        in viewport: TerminalViewportSize
    ) -> TextFrame {
        frame(for: RenderedBlock(lines: [text]), in: viewport)
    }

    static func frame(
        for block: RenderedBlock,
        in viewport: TerminalViewportSize
    ) -> TextFrame {
        let row = max(((viewport.rows - block.height) / 2) + 1, 1)
        let column = max(((viewport.columns - block.width) / 2) + 1, 1)
        let text = block.text
        return TextFrame(text: text, row: row, column: column)
    }

    static func screen(
        for text: String,
        in viewport: TerminalViewportSize
    ) -> String {
        screen(for: RenderedBlock(lines: [text]), in: viewport)
    }

    static func screen(
        for block: RenderedBlock,
        in viewport: TerminalViewportSize
    ) -> String {
        let frame = frame(for: block, in: viewport)
        let visibleBounds = RenderedRect(
            width: viewport.columns - frame.column + 1,
            height: viewport.rows - frame.row + 1
        )
        return TerminalControl.clearScreenSequence
            + block.runs.flatMap { run -> [RenderedRun] in
                run.clipped(to: visibleBounds)
            }.sorted { lhs, rhs in
                if lhs.row == rhs.row {
                    return lhs.column < rhs.column
                }
                return lhs.row < rhs.row
            }.map { run in
                TerminalControl.caretPositionSequence(
                    row: frame.row + run.row,
                    column: frame.column + run.column
                ) + styledText(for: run)
            }.joined()
            + caretSequence(for: block, in: frame, viewport: viewport)
    }

    static func redraw(
        from previousBlock: RenderedBlock?,
        previousViewport: TerminalViewportSize?,
        to block: RenderedBlock,
        in viewport: TerminalViewportSize
    ) -> String {
        guard let previousBlock,
              previousViewport == viewport else {
            return screen(for: block, in: viewport)
        }

        return diff(from: previousBlock, to: block, in: viewport)
    }

    static func diff(
        from previousBlock: RenderedBlock,
        to block: RenderedBlock,
        in viewport: TerminalViewportSize
    ) -> String {
        let previousScreen = RenderedScreenProjection(block: previousBlock, in: viewport)
        let screen = RenderedScreenProjection(block: block, in: viewport)
        let changedCells = changedCells(from: previousScreen.cells, to: screen.cells)
        let frame = frame(for: block, in: viewport)

        return changedRuns(in: screen.cells, changedCells: changedCells).map { run in
            TerminalControl.caretPositionSequence(
                row: run.row + 1,
                column: run.column + 1
            ) + styledText(for: run)
        }.joined()
            + caretSequence(for: block, in: frame, viewport: viewport)
    }

    private static func changedCells(
        from previousCells: [[RenderedScreenCell]],
        to cells: [[RenderedScreenCell]]
    ) -> [[Bool]] {
        let changedCells = cells.enumerated().map { row, rowCells in
            rowCells.indices.map { column in
                previousCells[row][column] != rowCells[column]
            }
        }
        var expandedCells = changedCells

        for row in changedCells.indices {
            for column in changedCells[row].indices where changedCells[row][column] {
                markAffectedCells(containing: column, in: row, cells: previousCells, changedCells: &expandedCells)
                markAffectedCells(containing: column, in: row, cells: cells, changedCells: &expandedCells)
            }
        }

        return expandedCells
    }

    private static func markAffectedCells(
        containing column: Int,
        in row: Int,
        cells: [[RenderedScreenCell]],
        changedCells: inout [[Bool]]
    ) {
        let cell = cells[row][column]
        let leadingColumn = cell.leadingColumn ?? column
        let width = max(cells[row][leadingColumn].width, 1)
        for affectedColumn in leadingColumn..<min(leadingColumn + width, cells[row].count) {
            changedCells[row][affectedColumn] = true
        }
    }

    private static func changedRuns(
        in cells: [[RenderedScreenCell]],
        changedCells: [[Bool]]
    ) -> [RenderedRun] {
        var runs: [RenderedRun] = []
        for row in changedCells.indices {
            var column = 0
            while column < changedCells[row].count {
                guard changedCells[row][column] else {
                    column += 1
                    continue
                }

                let lowerBound = column
                while column < changedCells[row].count, changedCells[row][column] {
                    column += 1
                }

                runs.append(contentsOf: renderedRuns(
                    in: cells[row],
                    row: row,
                    columns: lowerBound..<column
                ))
            }
        }
        return runs
    }

    private static func renderedRuns(
        in cells: [RenderedScreenCell],
        row: Int,
        columns: Range<Int>
    ) -> [RenderedRun] {
        var runs: [RenderedRun] = []
        var column = columns.lowerBound
        while column < columns.upperBound {
            let cell = cells[column]
            let text = cell.isContinuation ? " " : cell.text
            let width = cell.isContinuation ? 1 : max(cell.width, 1)
            append(
                RenderedRun(
                    text: text,
                    row: row,
                    column: column,
                    style: cell.style,
                    link: cell.link
                ),
                to: &runs
            )
            column += width
        }

        return runs
    }

    private static func append(_ run: RenderedRun, to runs: inout [RenderedRun]) {
        guard let last = runs.last,
              last.row == run.row,
              last.column + last.width == run.column,
              last.style == run.style,
              last.link == run.link else {
            runs.append(run)
            return
        }

        runs[runs.count - 1] = RenderedRun(
            text: last.text + run.text,
            row: last.row,
            column: last.column,
            style: last.style,
            link: last.link
        )
    }

    private static func styledText(for run: RenderedRun) -> String {
        guard !run.style.isPlain else {
            return run.text
        }

        return TerminalControl.sgrSequence(for: run.style)
            + run.text
            + TerminalControl.resetSGRSequence(for: run.style)
    }

    private static func caretSequence(
        for block: RenderedBlock,
        in frame: TextFrame,
        viewport: TerminalViewportSize
    ) -> String {
        guard let caret = block.caret else {
            return TerminalControl.hideCaretSequence
        }

        let row = min(max(frame.row + caret.row, 1), viewport.rows)
        let column = min(max(frame.column + caret.column, 1), viewport.columns)
        return TerminalControl.showCaretSequence
            + TerminalControl.caretPositionSequence(row: row, column: column)
    }
}

private struct RenderedScreenCell: Equatable {

    var text: String

    var width: Int

    var style: TextStyle

    var link: URL?

    var leadingColumn: Int?

    static let empty = RenderedScreenCell(
        text: " ",
        width: 1,
        style: .plain,
        link: nil,
        leadingColumn: nil
    )

    var isContinuation: Bool {
        leadingColumn != nil
    }
}

private struct RenderedScreenProjection {

    var cells: [[RenderedScreenCell]]

    init(block: RenderedBlock, in viewport: TerminalViewportSize) {
        cells = Array(
            repeating: Array(repeating: .empty, count: viewport.columns),
            count: viewport.rows
        )

        let frame = TextRenderer.frame(for: block, in: viewport)
        let visibleBounds = RenderedRect(
            width: viewport.columns - frame.column + 1,
            height: viewport.rows - frame.row + 1
        )
        let runs = block.runs.flatMap { run -> [RenderedRun] in
            run.clipped(to: visibleBounds)
        }.sorted { lhs, rhs in
            if lhs.row == rhs.row {
                return lhs.column < rhs.column
            }
            return lhs.row < rhs.row
        }

        for run in runs {
            write(run, in: frame)
        }
    }

    private mutating func write(_ run: RenderedRun, in frame: TextFrame) {
        let row = frame.row + run.row - 1
        guard cells.indices.contains(row) else {
            return
        }

        var column = frame.column + run.column - 1
        if writeSingleWidthRunIfPossible(run, row: row, column: column) {
            return
        }

        for character in run.text {
            let text = String(character)
            let width = TerminalText.columnWidth(text)
            defer {
                column += width
            }

            guard width > 0,
                  column >= 0,
                  column + width <= cells[row].count else {
                continue
            }

            clearCells(row: row, columns: column..<(column + width))
            cells[row][column] = RenderedScreenCell(
                text: text,
                width: width,
                style: run.style,
                link: run.link,
                leadingColumn: nil
            )
            if width > 1 {
                for continuationColumn in (column + 1)..<(column + width) {
                    cells[row][continuationColumn] = RenderedScreenCell(
                        text: "",
                        width: 0,
                        style: run.style,
                        link: run.link,
                        leadingColumn: column
                    )
                }
            }
        }
    }

    private mutating func writeSingleWidthRunIfPossible(
        _ run: RenderedRun,
        row: Int,
        column: Int
    ) -> Bool {
        guard column >= 0,
              run.text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value <= 0x7E }) else {
            return false
        }

        let width = run.text.unicodeScalars.count
        guard width > 0,
              column + width <= cells[row].count,
              cells[row][column..<(column + width)].allSatisfy({ $0 == .empty }) else {
            return false
        }

        for (offset, scalar) in run.text.unicodeScalars.enumerated() {
            cells[row][column + offset] = RenderedScreenCell(
                text: String(scalar),
                width: 1,
                style: run.style,
                link: run.link,
                leadingColumn: nil
            )
        }
        return true
    }

    private mutating func clearCells(row: Int, columns: Range<Int>) {
        let affectedColumns = Set(columns.flatMap { column in
            self.affectedColumns(containing: column, row: row)
        })

        for column in affectedColumns where cells[row].indices.contains(column) {
            cells[row][column] = .empty
        }
    }

    private func affectedColumns(containing column: Int, row: Int) -> [Int] {
        let cell = cells[row][column]
        let leadingColumn = cell.leadingColumn ?? column
        let width = max(cells[row][leadingColumn].width, 1)
        return Array(leadingColumn..<min(leadingColumn + width, cells[row].count))
    }
}

protocol StackRenderable {

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock?

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

protocol VerticalStackFlexSuppressing {}

extension StackRenderable {

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock? {
        renderedBlock(in: proposal, path: [], runtime: nil)
    }
}

extension HStack: LayoutTraitRenderable, StackRenderable, VerticalStackFlexSuppressing {

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(.horizontal) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: .horizontal
            )
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutContainer(
            layout: HStackLayout(alignment: alignment, spacing: spacing),
            content: content
        ).renderedBlock(in: proposal, path: path, runtime: runtime)
    }
}

extension VStack: LayoutTraitRenderable, StackRenderable {

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(.vertical) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: .vertical
            )
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutContainer(
            layout: VStackLayout(alignment: alignment, spacing: spacing),
            content: content
        ).renderedBlock(in: proposal, path: path, runtime: runtime)
    }
}

extension ZStack: LayoutTraitRenderable, StackRenderable {

    var layoutTraits: LayoutTraits {
        StackAxisContext.withAxis(nil) {
            ViewResolver.stackLayoutTraits(
                from: content,
                propagatedAxes: [.horizontal, .vertical],
                spacerAxis: nil
            )
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutContainer(
            layout: ZStackLayout(alignment: alignment),
            content: content
        ).renderedBlock(in: proposal, path: path, runtime: runtime)
    }
}

extension ViewResolver {

    static func blocks<Content: View>(from view: Content) -> [RenderedBlock] {
        if let group = view as? ViewGroup {
            return group.elements.flatMap {
                $0.renderedElements(in: nil, path: [], runtime: nil).compactMap(\.block)
            }
        }

        return block(from: view).map { [$0] } ?? []
    }

    static func elements<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> [RenderedElement] {
        elements(from: view, in: proposal, path: [], runtime: nil)
    }

    static func elements<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.renderedElements(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any FlattenableViewContent {
            return content.renderedElements(in: proposal, path: path, runtime: runtime)
        }

        return element(
            from: view,
            in: proposal,
            path: path,
            runtime: runtime
        ).map { [$0] } ?? []
    }

    static func gridItems<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.gridItems(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any GridContentRenderable {
            return content.gridItems(in: proposal, path: path, runtime: runtime)
        }

        if view is EmptyView {
            return []
        }

        if Content.Body.self != Never.self {
            return gridItems(
                from: body(from: view, path: path, runtime: runtime),
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        }

        return stackChildren(
            from: view,
            in: proposal,
            path: path,
            runtime: runtime
        ).map(GridItem.fullWidth)
    }

    static func stackChildren<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.stackChildren(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any FlattenableViewContent {
            return content.stackChildren(in: proposal, path: path, runtime: runtime)
        }

        let traits = layoutTraits(from: view)
        return [
            StackChild(
                traits: traits,
                isSpacer: view is Spacer,
                isEmptyView: view is EmptyView,
                suppressesVerticalFlexInParentStack: view is any VerticalStackFlexSuppressing,
                render: { childProposal, suppressRegistrations in
                    let render = {
                        element(
                            from: view,
                            in: childProposal,
                            path: path,
                            runtime: runtime
                        )
                    }

                    if suppressRegistrations {
                        return LayoutMeasurementContext.withMeasurement {
                            runtime?.withoutRenderRegistrations(render) ?? render()
                        }
                    }

                    return render()
                }
            ),
        ]
    }

    static func layoutTraits<Content: View>(from view: Content) -> LayoutTraits {
        if let traits = view as? any LayoutTraitRenderable {
            return traits.layoutTraits
        }

        guard Content.Body.self != Never.self else {
            return LayoutTraits()
        }

        return layoutTraits(from: body(from: view, path: [], runtime: nil))
    }

    static func stackLayoutTraits<Content: View>(
        from content: Content,
        propagatedAxes: Axis.Set,
        spacerAxis: Axis?
    ) -> LayoutTraits {
        let flexibleAxes = stackChildren(
            from: content,
            in: nil,
            path: [],
            runtime: nil
        )
        .reduce(into: Axis.Set()) { axes, child in
            axes.formUnion(child.traits.flexibleAxes.intersection(propagatedAxes))
            guard child.isSpacer, let spacerAxis else {
                return
            }

            switch spacerAxis {
            case .horizontal:
                axes.formUnion(.horizontal)
            case .vertical:
                axes.formUnion(.vertical)
            }
        }

        return LayoutTraits(flexibleAxes: flexibleAxes)
    }

    private static func body<Content: View>(
        from view: Content,
        path: [Int],
        runtime: StateRuntime?
    ) -> Content.Body {
        guard let runtime else {
            materializeDynamicEnvironmentProperties(in: view)
            return view.body
        }

        return runtime.withView(at: path, mode: .render) {
            runtime.materializeDynamicProperties(in: view)
            return view.body
        }
    }

    static func rootProposal<Content: View>(
        for view: Content,
        proposal: RenderProposal?
    ) -> RenderProposal? {
        guard let traits = view as? any LayoutTraitRenderable else {
            return proposal
        }

        let axes = traits.layoutTraits.flexibleAxes
        guard !axes.isEmpty else {
            return proposal
        }

        return RenderProposal(
            columns: axes.contains(.horizontal) ? proposal?.columns : nil,
            rows: axes.contains(.vertical) ? proposal?.rows : nil
        )
    }
}

enum ZStackRenderer {

    static func block(
        _ children: [StackChild],
        alignment: Alignment,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        ExplicitAlignmentQueryContext.withKeys([
            alignment.horizontal.key,
            alignment.vertical.key,
        ]) {
            unqueriedBlock(children, alignment: alignment, proposal: proposal)
        }
    }

    private static func unqueriedBlock(
        _ children: [StackChild],
        alignment: Alignment,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let measuredChildren = children.enumerated().compactMap { index, child -> MeasuredChild? in
            guard let element = child.render(proposal, true),
                  let block = renderedBlock(from: element, proposal: proposal),
                  block.width > 0 || block.height > 0 else {
                return nil
            }

            return MeasuredChild(index: index, child: child, block: block)
        }
        guard !measuredChildren.isEmpty else {
            return nil
        }

        let measuredBlocks = measuredChildren.map(\.block)
        let horizontalLine = naturalHorizontalLine(
            for: measuredBlocks,
            alignment: alignment.horizontal
        )
        let verticalLine = naturalVerticalLine(
            for: measuredBlocks,
            alignment: alignment.vertical
        )
        let width = proposal?.columns ?? naturalWidth(
            for: measuredBlocks,
            alignment: alignment.horizontal,
            line: horizontalLine
        )
        let height = proposal?.rows ?? naturalHeight(
            for: measuredBlocks,
            alignment: alignment.vertical,
            line: verticalLine
        )
        let bounds = RenderedRect(width: width, height: height)
        let blocks = measuredChildren
            .sorted {
                if $0.child.traits.zIndex == $1.child.traits.zIndex {
                    return $0.index < $1.index
                }

                return $0.child.traits.zIndex < $1.child.traits.zIndex
            }
            .compactMap { measuredChild -> RenderedBlock? in
                guard let element = measuredChild.child.render(proposal, false),
                      let block = renderedBlock(from: element, proposal: proposal) else {
                    return nil
                }

                let x = proposal?.columns == nil
                    ? horizontalLine.map { $0 - block.viewDimensions[alignment.horizontal] }
                    : nil
                let y = proposal?.rows == nil
                    ? verticalLine.map { $0 - block.viewDimensions[alignment.vertical] }
                    : nil
                return block.offsetBy(
                    x: x ?? horizontalOffset(
                        for: block,
                        containerWidth: width,
                        alignment: alignment.horizontal
                    ),
                    y: y ?? verticalOffset(
                        for: block,
                        containerHeight: height,
                        alignment: alignment.vertical
                    ),
                    clippedTo: bounds
                )
            }

        return RenderedBlock.composited(
            blocks,
            width: width,
            height: height,
            paddedRows: proposedPaddedRows(proposal: proposal, height: height)
        )
    }

    private struct MeasuredChild {

        var index: Int

        var child: StackChild

        var block: RenderedBlock
    }

    private static func renderedBlock(
        from element: RenderedElement,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        switch element {
        case .block(let block):
            return block
        case .spacer(let minLength):
            let width = max(proposal?.columns ?? minLength, minLength)
            let height = max(proposal?.rows ?? minLength, minLength)
            guard width > 0 || height > 0 else {
                return nil
            }

            let renderedHeight = max(height, 1)
            return RenderedBlock(
                runs: [],
                width: width,
                height: renderedHeight,
                paddedRows: Set(0..<renderedHeight)
            )
        }
    }

    private static func proposedPaddedRows(
        proposal: RenderProposal?,
        height: Int
    ) -> Set<Int> {
        proposal?.rows == nil ? [] : Set(0..<height)
    }

    private static func naturalHorizontalLine(
        for blocks: [RenderedBlock],
        alignment: HorizontalAlignment
    ) -> Int? {
        let usesGuides = alignment != .leading
            && alignment != .center
            && alignment != .trailing
            || blocks.contains { $0.viewDimensions[explicit: alignment] != nil }
        guard usesGuides else {
            return nil
        }
        return blocks.map { $0.viewDimensions[alignment] }.max()
    }

    private static func naturalVerticalLine(
        for blocks: [RenderedBlock],
        alignment: VerticalAlignment
    ) -> Int? {
        let usesGuides = alignment != .top
            && alignment != .center
            && alignment != .bottom
            || blocks.contains { $0.viewDimensions[explicit: alignment] != nil }
        guard usesGuides else {
            return nil
        }
        return blocks.map { $0.viewDimensions[alignment] }.max()
    }

    private static func naturalWidth(
        for blocks: [RenderedBlock],
        alignment: HorizontalAlignment,
        line: Int?
    ) -> Int {
        guard let line else {
            return blocks.map(\.width).max() ?? 0
        }
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.width
        }.max() ?? 0
    }

    private static func naturalHeight(
        for blocks: [RenderedBlock],
        alignment: VerticalAlignment,
        line: Int?
    ) -> Int {
        guard let line else {
            return blocks.map(\.height).max() ?? 0
        }
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.height
        }.max() ?? 0
    }

    private static func horizontalOffset(
        for block: RenderedBlock,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = containerWidth - block.width
        if alignment == .leading, block.viewDimensions[explicit: alignment] == nil {
            return 0
        }
        if alignment == .center, block.viewDimensions[explicit: alignment] == nil {
            return padding / 2
        }
        if alignment == .trailing, block.viewDimensions[explicit: alignment] == nil {
            return padding
        }
        let container = ViewDimensions(columns: containerWidth, rows: block.height)
        return container[alignment] - block.viewDimensions[alignment]
    }

    private static func verticalOffset(
        for block: RenderedBlock,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = containerHeight - block.height
        if alignment == .top, block.viewDimensions[explicit: alignment] == nil {
            return 0
        }
        if alignment == .center, block.viewDimensions[explicit: alignment] == nil {
            return padding / 2
        }
        if alignment == .bottom, block.viewDimensions[explicit: alignment] == nil {
            return padding
        }
        let container = ViewDimensions(columns: block.width, rows: containerHeight)
        return container[alignment] - block.viewDimensions[alignment]
    }
}

private extension RenderedElement {

    var block: RenderedBlock? {
        guard case .block(let block) = self else {
            return nil
        }

        return block
    }
}

enum StackRenderer {

    static func horizontal(
        _ children: [StackChild],
        alignment: VerticalAlignment,
        spacing: Int?,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        ExplicitAlignmentQueryContext.withKeys([alignment.key]) {
            unqueriedHorizontal(
                children,
                alignment: alignment,
                spacing: spacing,
                proposal: proposal
            )
        }
    }

    private static func unqueriedHorizontal(
        _ children: [StackChild],
        alignment: VerticalAlignment,
        spacing: Int?,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let layout = horizontalLayout(from: children, spacing: spacing, proposal: proposal)
        guard !layout.items.isEmpty else {
            return nil
        }

        let height = horizontalHeight(for: layout.items, alignment: alignment)
        let items = layout.items.map {
            $0.fillingMinorAxis(height)
        }
        let width = layout.width
        let bounds = RenderedRect(width: width, height: height)
        let runs = items.flatMap { item -> [RenderedRun] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.runs.flatMap {
                $0.offsetBy(x: item.x, y: y)
                    .clipped(to: bounds)
            }
        }
        var paddedRows = Set<Int>()
        for item in items {
            switch item.content {
            case .block(let block):
                let y = verticalOffset(
                    for: block,
                    in: items,
                    containerHeight: height,
                    alignment: alignment
                )
                paddedRows.formUnion(block.paddedRows.map { $0 + y })
            case .spacer:
                paddedRows.formUnion(0..<height)
            }
        }

        return RenderedBlock(
            runs: runs,
            width: width,
            height: height,
            paddedRows: paddedRows,
            caret: horizontalCaret(from: items, height: height, alignment: alignment),
            hitRegions: horizontalHitRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            scrollRegions: horizontalScrollRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            focusRegions: horizontalFocusRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            identifiedRegions: horizontalIdentifiedRegions(
                from: items,
                height: height,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            coordinateSpaceRegions: horizontalCoordinateSpaceRegions(
                from: items,
                height: height,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            explicitAlignments: horizontalExplicitAlignments(
                from: items,
                height: height,
                alignment: alignment
            ),
            spacing: horizontalSpacing(from: items)
        )
    }

    static func vertical(
        _ children: [StackChild],
        alignment: HorizontalAlignment,
        spacing: Int?,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        ExplicitAlignmentQueryContext.withKeys([alignment.key]) {
            unqueriedVertical(
                children,
                alignment: alignment,
                spacing: spacing,
                proposal: proposal
            )
        }
    }

    private static func unqueriedVertical(
        _ children: [StackChild],
        alignment: HorizontalAlignment,
        spacing: Int?,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let layout = verticalLayout(from: children, spacing: spacing, proposal: proposal)
        guard !layout.items.isEmpty else {
            return nil
        }

        let width = verticalWidth(for: layout.items, alignment: alignment)
        let items = layout.items.map {
            $0.fillingMinorAxis(width)
        }
        let height = layout.height
        let bounds = RenderedRect(width: width, height: height)
        let runs = items.flatMap { item -> [RenderedRun] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.runs.flatMap {
                $0.offsetBy(x: x, y: item.y)
                    .clipped(to: bounds)
            }
        }
        var paddedRows = Set<Int>()
        for item in items {
            switch item.content {
            case .block(let block):
                paddedRows.formUnion(block.paddedRows.map { $0 + item.y })
            case .spacer:
                paddedRows.formUnion(item.y..<(item.y + item.height))
            }
        }

        return RenderedBlock(
            runs: runs,
            width: width,
            height: height,
            paddedRows: paddedRows,
            caret: verticalCaret(from: items, width: width, alignment: alignment),
            hitRegions: verticalHitRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            scrollRegions: verticalScrollRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            focusRegions: verticalFocusRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            identifiedRegions: verticalIdentifiedRegions(
                from: items,
                width: width,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            coordinateSpaceRegions: verticalCoordinateSpaceRegions(
                from: items,
                width: width,
                alignment: alignment
            )
                .compactMap { $0.clipped(to: bounds) },
            explicitAlignments: verticalExplicitAlignments(
                from: items,
                width: width,
                alignment: alignment
            ),
            spacing: verticalSpacing(from: items)
        )
    }

    private static func horizontalHeight(
        for items: [HorizontalItem],
        alignment: VerticalAlignment
    ) -> Int {
        let blocks = items.compactMap(\.block)
        guard !blocks.isEmpty else {
            return 1
        }
        let hasExplicitValue = blocks.contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .top && alignment != .center && alignment != .bottom) else {
            return blocks.map(\.height).max() ?? 1
        }
        let line = blocks.map { $0.viewDimensions[alignment] }.max() ?? 0
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.height
        }.max() ?? 1
    }

    private static func verticalWidth(
        for items: [VerticalItem],
        alignment: HorizontalAlignment
    ) -> Int {
        let blocks = items.compactMap(\.block)
        guard !blocks.isEmpty else {
            return 0
        }
        let hasExplicitValue = blocks.contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .leading && alignment != .center && alignment != .trailing) else {
            return blocks.map(\.width).max() ?? 0
        }
        let line = blocks.map { $0.viewDimensions[alignment] }.max() ?? 0
        return blocks.map {
            line - $0.viewDimensions[alignment] + $0.width
        }.max() ?? 0
    }

    private static func horizontalExplicitAlignments(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [AlignmentKey: Int] {
        let blocks = items.compactMap { item -> RenderedBlock? in
            guard var block = item.block else {
                return nil
            }
            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            block.explicitAlignments = block.offsetExplicitAlignments(x: item.x, y: y)
            return block
        }
        return RenderedBlock.combinedExplicitAlignments(from: blocks)
    }

    private static func verticalExplicitAlignments(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [AlignmentKey: Int] {
        let blocks = items.compactMap { item -> RenderedBlock? in
            guard var block = item.block else {
                return nil
            }
            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            block.explicitAlignments = block.offsetExplicitAlignments(x: x, y: item.y)
            return block
        }
        return RenderedBlock.combinedExplicitAlignments(from: blocks)
    }

    private struct HorizontalLayout {

        var items: [HorizontalItem]

        var width: Int
    }

    private struct VerticalLayout {

        var items: [VerticalItem]

        var height: Int
    }

    private struct HorizontalItem {

        var content: RenderedElement

        var x: Int

        var width: Int

        var traits: LayoutTraits

        var render: (RenderProposal?, Bool) -> RenderedElement?

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }

        func fillingMinorAxis(_ height: Int) -> HorizontalItem {
            guard traits.fillsStackMinorAxis,
                  traits.flexibleAxes.contains(.vertical),
                  let content = render(
                      RenderProposal(columns: width, rows: height),
                      false
                  ) else {
                return self
            }

            var item = self
            item.content = content
            return item
        }
    }

    private struct VerticalItem {

        var content: RenderedElement

        var y: Int

        var height: Int

        var traits: LayoutTraits

        var render: (RenderProposal?, Bool) -> RenderedElement?

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }

        func fillingMinorAxis(_ width: Int) -> VerticalItem {
            guard traits.fillsStackMinorAxis,
                  traits.flexibleAxes.contains(.horizontal),
                  let content = render(
                      RenderProposal(columns: width, rows: height),
                      false
                  ) else {
                return self
            }

            var item = self
            item.content = content
            return item
        }
    }

    struct MeasuredChild {

        var content: RenderedElement

        var traits: LayoutTraits

        var suppressesVerticalFlexInParentStack: Bool

        var render: (RenderProposal?, Bool) -> RenderedElement?
    }

    private static func horizontalLayout(
        from children: [StackChild],
        spacing: Int?,
        proposal: RenderProposal?
    ) -> HorizontalLayout {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .horizontal,
            childProposal: horizontalChildProposal
        )
        let gaps = spacingGaps(between: children, spacing: spacing, axis: .horizontal)
        let usesContentFlex = children.contains { $0.isHorizontallyContentFlexible }
        let flexibleCount = children.filter {
            $0.isHorizontallyFlexible(usingContentFlex: usesContentFlex)
        }.count
        let spacingWidth = gaps.reduce(0, +)
        let minimums = children.compactMap {
            $0.horizontalMinimum(usingContentFlex: usesContentFlex)
        }
        let idealWidth = children.reduce(0) { width, child in
            width + child.content.horizontalLength
        } + spacingWidth
        let targetWidth: Int
        let fixedWidth = fixedHorizontalWidth(
            from: children,
            usingContentFlex: usesContentFlex
        )
        if flexibleCount > 0, let columns = proposal?.columns {
            targetWidth = max(columns, minimums.reduce(0, +) + spacingWidth)
        }
        else {
            targetWidth = idealWidth
        }

        let flexibleLengths = flexibleLengths(
            count: flexibleCount,
            minimums: minimums,
            extra: max(
                targetWidth - minimums.reduce(0, +) - fixedWidth - spacingWidth,
                0
            )
        )
        var flexibleIndex = 0
        var x = 0
        let items: [HorizontalItem] = children.enumerated().compactMap {
            index, child -> HorizontalItem? in
            let element: RenderedElement
            let itemWidth: Int
            switch child.content {
            case .block(let block):
                if child.isHorizontallyFlexible(usingContentFlex: usesContentFlex) {
                    let width = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                    element = child.render(
                        horizontalChildProposal(
                            width,
                            traits: child.traits,
                            stackProposal: proposal
                        ),
                        false
                    ) ?? .block(block)
                }
                else {
                    element = child.content
                }
                itemWidth = element.horizontalLength
            case .spacer:
                if child.isHorizontallyFlexible(usingContentFlex: usesContentFlex) {
                    itemWidth = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                }
                else {
                    itemWidth = child.content.horizontalLength
                }
                element = child.content
            }

            guard element.isRenderable else {
                return nil
            }

            let item = HorizontalItem(
                content: element,
                x: x,
                width: itemWidth,
                traits: child.traits,
                render: child.render
            )
            x += item.width + (gaps.indices.contains(index) ? gaps[index] : 0)
            return item
        }

        return HorizontalLayout(
            items: items,
            width: flexibleCount > 0 && proposal?.columns != nil
                ? targetWidth
                : items.map { $0.x + $0.width }.max() ?? 0
        )
    }

    private static func verticalLayout(
        from children: [StackChild],
        spacing: Int?,
        proposal: RenderProposal?
    ) -> VerticalLayout {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .vertical,
            childProposal: verticalChildProposal
        )
        let gaps = spacingGaps(between: children, spacing: spacing, axis: .vertical)
        let usesContentFlex = children.contains { $0.isVerticallyContentFlexible }
        let flexibleCount = children.filter {
            $0.isVerticallyFlexible(usingContentFlex: usesContentFlex)
        }.count
        let spacingHeight = gaps.reduce(0, +)
        let minimums = children.compactMap {
            $0.verticalMinimum(usingContentFlex: usesContentFlex)
        }
        let idealHeight = children.reduce(0) { height, child in
            height + child.content.verticalLength
        } + spacingHeight
        let targetHeight: Int
        let fixedHeight = fixedVerticalHeight(
            from: children,
            usingContentFlex: usesContentFlex
        )
        if flexibleCount > 0, let rows = proposal?.rows {
            targetHeight = max(rows, minimums.reduce(0, +) + spacingHeight)
        }
        else {
            targetHeight = idealHeight
        }

        let flexibleLengths = flexibleLengths(
            count: flexibleCount,
            minimums: minimums,
            extra: max(
                targetHeight - minimums.reduce(0, +) - fixedHeight - spacingHeight,
                0
            )
        )
        var flexibleIndex = 0
        var y = 0
        let items: [VerticalItem] = children.enumerated().compactMap {
            index, child -> VerticalItem? in
            let element: RenderedElement
            let itemHeight: Int
            switch child.content {
            case .block(let block):
                if child.isVerticallyFlexible(usingContentFlex: usesContentFlex) {
                    let height = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                    element = child.render(
                        verticalChildProposal(
                            height,
                            traits: child.traits,
                            stackProposal: proposal
                        ),
                        false
                    ) ?? .block(block)
                }
                else {
                    element = child.content
                }
                itemHeight = element.verticalLength
            case .spacer:
                if child.isVerticallyFlexible(usingContentFlex: usesContentFlex) {
                    itemHeight = flexibleLengths[flexibleIndex]
                    flexibleIndex += 1
                }
                else {
                    itemHeight = child.content.verticalLength
                }
                element = child.content
            }

            guard element.isRenderable else {
                return nil
            }

            let item = VerticalItem(
                content: element,
                y: y,
                height: itemHeight,
                traits: child.traits,
                render: child.render
            )
            y += item.height + (gaps.indices.contains(index) ? gaps[index] : 0)
            return item
        }

        return VerticalLayout(
            items: items,
            height: flexibleCount > 0 && proposal?.rows != nil
                ? targetHeight
                : items.map { $0.y + $0.height }.max() ?? 0
        )
    }

    private static func measuredChildren(
        from children: [StackChild],
        proposal: RenderProposal?,
        stackAxis: Axis,
        childProposal: (Int?, LayoutTraits, RenderProposal?) -> RenderProposal
    ) -> [MeasuredChild] {
        children.compactMap { child in
            let flexibleOnStackAxis: Bool
            switch stackAxis {
            case .horizontal:
                flexibleOnStackAxis = child.traits.flexibleAxes.contains(.horizontal)
            case .vertical:
                flexibleOnStackAxis = !child.suppressesVerticalFlexInParentStack
                    && child.traits.flexibleAxes.contains(.vertical)
            }

            guard let content = child.render(
                childProposal(nil, child.traits, proposal),
                flexibleOnStackAxis
            ), content.isRenderable || flexibleOnStackAxis else {
                return nil
            }

            return MeasuredChild(
                content: content,
                traits: child.traits,
                suppressesVerticalFlexInParentStack: child.suppressesVerticalFlexInParentStack,
                render: child.render
            )
        }
    }

    private static func horizontalChildProposal(
        _ width: Int?,
        traits: LayoutTraits,
        stackProposal: RenderProposal?
    ) -> RenderProposal {
        RenderProposal(
            columns: width,
            rows: traits.flexibleAxes.contains(.vertical)
                || !traits.flexibleAxes.contains(.horizontal) ? stackProposal?.rows : nil
        )
    }

    private static func verticalChildProposal(
        _ height: Int?,
        traits: LayoutTraits,
        stackProposal: RenderProposal?
    ) -> RenderProposal {
        RenderProposal(
            columns: traits.flexibleAxes.contains(.horizontal)
                || !traits.flexibleAxes.contains(.vertical) ? stackProposal?.columns : nil,
            rows: height
        )
    }

    private static func fixedHorizontalWidth(
        from children: [MeasuredChild],
        usingContentFlex: Bool
    ) -> Int {
        children.reduce(0) { width, child in
            switch child.content {
            case .block:
                if child.isHorizontallyFlexible(usingContentFlex: usingContentFlex) {
                    return width
                }
                return width + child.content.horizontalLength
            case .spacer:
                if child.isHorizontallyFlexible(usingContentFlex: usingContentFlex) {
                    return width
                }
                return width + child.content.horizontalLength
            }
        }
    }

    private static func fixedVerticalHeight(
        from children: [MeasuredChild],
        usingContentFlex: Bool
    ) -> Int {
        children.reduce(0) { height, child in
            switch child.content {
            case .block:
                if child.isVerticallyFlexible(usingContentFlex: usingContentFlex) {
                    return height
                }
                return height + child.content.verticalLength
            case .spacer:
                if child.isVerticallyFlexible(usingContentFlex: usingContentFlex) {
                    return height
                }
                return height + child.content.verticalLength
            }
        }
    }

    private static func horizontalCaret(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> RenderedCaret? {
        for item in items {
            guard let block = item.block, let caret = block.caret else {
                continue
            }

            return RenderedCaret(
                row: verticalOffset(
                    for: block,
                    in: items,
                    containerHeight: height,
                    alignment: alignment
                ) + caret.row,
                column: item.x + caret.column
            )
        }

        return nil
    }

    private static func horizontalHitRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedHitRegion] {
        items.flatMap { item -> [RenderedHitRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.hitRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalScrollRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedScrollRegion] {
        items.flatMap { item -> [RenderedScrollRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.scrollRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalFocusRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedFocusRegion] {
        items.flatMap { item -> [RenderedFocusRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.focusRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalIdentifiedRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedIdentifiedRegion] {
        items.flatMap { item -> [RenderedIdentifiedRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.identifiedRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func horizontalCoordinateSpaceRegions(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> [RenderedCoordinateSpaceRegion] {
        items.flatMap { item -> [RenderedCoordinateSpaceRegion] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                for: block,
                in: items,
                containerHeight: height,
                alignment: alignment
            )
            return block.coordinateSpaceRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func verticalCaret(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> RenderedCaret? {
        for item in items {
            guard let block = item.block, let caret = block.caret else {
                continue
            }

            return RenderedCaret(
                row: item.y + caret.row,
                column: horizontalOffset(
                    for: block,
                    in: items,
                    containerWidth: width,
                    alignment: alignment
                ) + caret.column
            )
        }

        return nil
    }

    private static func verticalHitRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedHitRegion] {
        items.flatMap { item -> [RenderedHitRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.hitRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalScrollRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedScrollRegion] {
        items.flatMap { item -> [RenderedScrollRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.scrollRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalFocusRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedFocusRegion] {
        items.flatMap { item -> [RenderedFocusRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.focusRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalIdentifiedRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedIdentifiedRegion] {
        items.flatMap { item -> [RenderedIdentifiedRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.identifiedRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func verticalCoordinateSpaceRegions(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> [RenderedCoordinateSpaceRegion] {
        items.flatMap { item -> [RenderedCoordinateSpaceRegion] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                for: block,
                in: items,
                containerWidth: width,
                alignment: alignment
            )
            return block.coordinateSpaceRegions.map {
                $0.offsetBy(x: x, y: item.y)
            }
        }
    }

    private static func flexibleLengths(
        count: Int,
        minimums: [Int],
        extra: Int
    ) -> [Int] {
        guard count > 0 else {
            return []
        }

        let shared = extra / count
        let remainder = extra % count
        return minimums.enumerated().map { index, minimum in
            minimum + shared + (index < remainder ? 1 : 0)
        }
    }

    private static func spacingGaps(
        between children: [MeasuredChild],
        spacing: Int?,
        axis: Axis
    ) -> [Int] {
        guard children.count > 1 else {
            return []
        }
        if let spacing {
            return Array(repeating: max(spacing, 0), count: children.count - 1)
        }
        return zip(children, children.dropFirst()).map {
            $0.content.spacing.distance(to: $1.content.spacing, along: axis)
        }
    }

    private static func horizontalSpacing(
        from items: [HorizontalItem]
    ) -> ViewSpacing {
        items.enumerated().reduce(ViewSpacing()) { result, element in
            let (index, item) = element
            var edges: Edge.Set = .vertical
            if index == items.startIndex {
                edges.formUnion(.leading)
            }
            if index == items.index(before: items.endIndex) {
                edges.formUnion(.trailing)
            }
            return result.union(item.content.spacing, edges: edges)
        }
    }

    private static func verticalSpacing(
        from items: [VerticalItem]
    ) -> ViewSpacing {
        items.enumerated().reduce(ViewSpacing()) { result, element in
            let (index, item) = element
            var edges: Edge.Set = .horizontal
            if index == items.startIndex {
                edges.formUnion(.top)
            }
            if index == items.index(before: items.endIndex) {
                edges.formUnion(.bottom)
            }
            return result.union(item.content.spacing, edges: edges)
        }
    }

    private static func horizontalOffset(
        for block: RenderedBlock,
        in items: [VerticalItem],
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let hasExplicitValue = items.compactMap(\.block).contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .leading && alignment != .center && alignment != .trailing) else {
            return horizontalOffset(
                contentWidth: block.width,
                containerWidth: containerWidth,
                alignment: alignment
            )
        }
        let line = items.compactMap(\.block).map {
            $0.viewDimensions[alignment]
        }.max() ?? 0
        return line - block.viewDimensions[alignment]
    }

    private static func verticalOffset(
        for block: RenderedBlock,
        in items: [HorizontalItem],
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let hasExplicitValue = items.compactMap(\.block).contains {
            $0.viewDimensions[explicit: alignment] != nil
        }
        guard hasExplicitValue
            || (alignment != .top && alignment != .center && alignment != .bottom) else {
            return verticalOffset(
                contentHeight: block.height,
                containerHeight: containerHeight,
                alignment: alignment
            )
        }
        let line = items.compactMap(\.block).map {
            $0.viewDimensions[alignment]
        }.max() ?? 0
        return line - block.viewDimensions[alignment]
    }

    private static func horizontalOffset(
        contentWidth: Int,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = max(containerWidth - contentWidth, 0)
        if alignment == .leading {
            return 0
        }
        if alignment == .center {
            return padding / 2
        }
        if alignment == .trailing {
            return padding
        }
        let content = ViewDimensions(columns: contentWidth, rows: 0)
        let container = ViewDimensions(columns: containerWidth, rows: 0)
        return container[alignment] - content[alignment]
    }

    private static func verticalOffset(
        contentHeight: Int,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = max(containerHeight - contentHeight, 0)
        if alignment == .top {
            return 0
        }
        if alignment == .center {
            return padding / 2
        }
        if alignment == .bottom {
            return padding
        }
        let content = ViewDimensions(columns: 0, rows: contentHeight)
        let container = ViewDimensions(columns: 0, rows: containerHeight)
        return container[alignment] - content[alignment]
    }
}

private extension StackRenderer.MeasuredChild {

    var isHorizontallyContentFlexible: Bool {
        guard case .block = content else {
            return false
        }

        return traits.flexibleAxes.contains(.horizontal)
    }

    var isVerticallyContentFlexible: Bool {
        guard !suppressesVerticalFlexInParentStack else {
            return false
        }

        guard case .block = content else {
            return false
        }

        return traits.flexibleAxes.contains(.vertical)
    }

    func isHorizontallyFlexible(usingContentFlex: Bool) -> Bool {
        switch content {
        case .block:
            return traits.flexibleAxes.contains(.horizontal)
        case .spacer:
            return !usingContentFlex
        }
    }

    func isVerticallyFlexible(usingContentFlex: Bool) -> Bool {
        guard !suppressesVerticalFlexInParentStack else {
            return false
        }

        switch content {
        case .block:
            return traits.flexibleAxes.contains(.vertical)
        case .spacer:
            return !usingContentFlex
        }
    }

    func horizontalMinimum(usingContentFlex: Bool) -> Int? {
        isHorizontallyFlexible(usingContentFlex: usingContentFlex)
            ? content.spacerMinimum ?? 0
            : nil
    }

    func verticalMinimum(usingContentFlex: Bool) -> Int? {
        isVerticallyFlexible(usingContentFlex: usingContentFlex)
            ? content.spacerMinimum ?? 0
            : nil
    }

}

private extension RenderedElement {

    var spacing: ViewSpacing {
        switch self {
        case .block(let block):
            return block.spacing
        case .spacer:
            return ViewSpacing()
        }
    }

    var isSpacer: Bool {
        guard case .spacer = self else {
            return false
        }

        return true
    }

    var horizontalLength: Int {
        switch self {
        case .block(let block):
            return block.width
        case .spacer(let minLength):
            return minLength
        }
    }

    var isRenderable: Bool {
        switch self {
        case .block(let block):
            return block.width > 0 || block.height > 0
        case .spacer:
            return true
        }
    }

    var spacerMinimum: Int? {
        guard case .spacer(let minLength) = self else {
            return nil
        }

        return minLength
    }

    var verticalLength: Int {
        switch self {
        case .block(let block):
            return block.height
        case .spacer(let minLength):
            return minLength
        }
    }
}
