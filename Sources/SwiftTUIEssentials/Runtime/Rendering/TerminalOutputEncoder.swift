/// Encodes rendered runs as terminal text without owning screen presentation.
///
/// One-shot output materializes positioned gaps and reserved trailing cells as
/// literal spaces. Full-screen and differential rendering reuse the same SGR
/// wrapping so style bytes remain consistent across presentation paths.
enum TerminalOutputEncoder {

    static func ansiText(for block: RenderedBlock) -> String {
        guard block.height > 0 else {
            return ""
        }

        let runs = block.runs.sorted { lhs, rhs in
            if lhs.row == rhs.row {
                return lhs.column < rhs.column
            }
            return lhs.row < rhs.row
        }

        return (0..<block.height).map { row in
            ansiLine(
                for: runs.filter { $0.row == row },
                width: block.width,
                padsTrailingCells: block.paddedRows.contains(row)
            )
        }.joined(separator: "\n")
    }

    static func styledText(for run: RenderedRun) -> String {
        guard !run.style.isPlain else {
            return run.text
        }

        return TerminalControl.sgrSequence(for: run.style)
            + run.text
            + TerminalControl.resetSGRSequence(for: run.style)
    }

    private static func ansiLine(
        for runs: [RenderedRun],
        width: Int,
        padsTrailingCells: Bool
    ) -> String {
        var output = ""
        var currentColumn = 0

        for run in runs {
            if currentColumn < run.column {
                output += String(repeating: " ", count: run.column - currentColumn)
                currentColumn = run.column
            }

            if !run.text.isEmpty {
                output += styledText(for: run)
            }
            currentColumn += run.width
        }

        if !output.isEmpty || padsTrailingCells {
            output += String(repeating: " ", count: max(width - currentColumn, 0))
        }
        return output
    }
}
