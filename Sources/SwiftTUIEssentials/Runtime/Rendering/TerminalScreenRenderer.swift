import Foundation
import SwiftTUIRuns

/// Projects a root block into a terminal viewport and produces ANSI output.
///
/// The first frame and any viewport-size change produce a full-screen redraw.
/// Stable viewport updates compare projected terminal cells and write only
/// changed runs before updating the terminal cursor used to present a rendered
/// text caret.
enum TerminalScreenRenderer {

    static func frame(
        for text: String,
        in viewport: TerminalViewportSize
    ) -> RenderedTerminalFrame {
        frame(for: RenderedBlock(lines: [text]), in: viewport)
    }

    static func frame(
        for block: RenderedBlock,
        in viewport: TerminalViewportSize
    ) -> RenderedTerminalFrame {
        let row = max(((viewport.rows - block.height) / 2) + 1, 1)
        let column = max(((viewport.columns - block.width) / 2) + 1, 1)
        let text = block.text
        return RenderedTerminalFrame(text: text, row: row, column: column)
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
        in frame: RenderedTerminalFrame,
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

/// A viewport-sized cell projection used to compare complete terminal frames.
///
/// Wide graphemes occupy one leading cell plus continuation cells. Diffing
/// expands changes to every cell occupied by the old and new graphemes so a
/// width transition cannot leave stale terminal content behind.
private struct RenderedScreenProjection {

    var cells: [[RenderedScreenCell]]

    init(block: RenderedBlock, in viewport: TerminalViewportSize) {
        cells = Array(
            repeating: Array(repeating: .empty, count: viewport.columns),
            count: viewport.rows
        )

        let frame = TerminalScreenRenderer.frame(for: block, in: viewport)
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

    private mutating func write(_ run: RenderedRun, in frame: RenderedTerminalFrame) {
        let row = frame.row + run.row - 1
        guard cells.indices.contains(row) else {
            return
        }

        var column = frame.column + run.column - 1
        if writeSingleWidthRunIfPossible(run, row: row, column: column) {
            return
        }

        let layout = RunGroup(run.text).layout()
        for (offset, character) in run.text.enumerated() {
            let text = String(character)
            let width = layout.columns(
                in: RunIndex(characterOffset: offset)
                    ..< RunIndex(characterOffset: offset + 1)
            )
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
