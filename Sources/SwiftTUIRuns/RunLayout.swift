public import Terminal

/// A character insertion position in a run group's concatenated content.
///
/// Offsets count Swift `Character` values rather than Unicode scalars, UTF-8
/// bytes, or UTF-16 code units.
public struct RunIndex: Comparable, Hashable, Sendable {

    /// The zero-based character offset in the logical string.
    public let characterOffset: Int

    /// Creates an index from a nonnegative character offset.
    ///
    /// - Parameter characterOffset: The number of `Character` values before
    ///   this insertion position.
    /// - Precondition: `characterOffset` is nonnegative.
    public init(characterOffset: Int) {
        precondition(characterOffset >= 0, "A run index cannot have a negative offset.")
        self.characterOffset = characterOffset
    }

    /// Compares indices by their character offsets.
    public static func < (lhs: RunIndex, rhs: RunIndex) -> Bool {
        lhs.characterOffset < rhs.characterOffset
    }
}

/// Intrinsic terminal-cell measurements for a run group.
public struct RunMetrics: Equatable, Sendable {

    /// The narrowest width supported by emergency grapheme wrapping.
    public let minimumContentColumns: Int

    /// The widest mandatory-newline-delimited line without soft wrapping.
    public let maximumContentColumns: Int

    /// The number of lines created by mandatory newlines without soft wrapping.
    public let unwrappedRows: Int

    init(
        minimumContentColumns: Int,
        maximumContentColumns: Int,
        unwrappedRows: Int
    ) {
        self.minimumContentColumns = minimumContentColumns
        self.maximumContentColumns = maximumContentColumns
        self.unwrappedRows = unwrappedRows
    }
}

/// A run group's concrete placement in terminal rows and columns.
///
/// Layout preserves empty lines and source ranges but does not add padding,
/// alignment, truncation, selection styling, or an editable trailing caret
/// line. Those policies belong to the consumer.
public struct RunLayout: Equatable, Sendable {

    /// One visual line in a run layout.
    public struct Line: Equatable, Sendable {

        /// The number of terminal columns occupied by visible content.
        public let columns: Int

        /// The attributed run fragments placed on this line.
        public let runs: [Run]

        /// The logical character range represented by the line.
        public let sourceRange: Range<RunIndex>

        let content: String

        init(
            columns: Int,
            runs: [Run],
            sourceRange: Range<RunIndex>,
            content: String
        ) {
            self.columns = columns
            self.runs = runs
            self.sourceRange = sourceRange
            self.content = content
        }

        /// Returns the terminal columns occupied by a source subrange on this line.
        ///
        /// The requested range is clamped to ``sourceRange``. Content outside
        /// the intersection contributes no columns, and extended grapheme
        /// clusters are measured as indivisible terminal characters.
        ///
        /// - Parameter sourceRange: A range in the run group's logical
        ///   `Character` offsets.
        /// - Returns: The number of occupied terminal columns in the intersection.
        /// - Complexity: O(n), where n is the number of intersecting characters.
        public func columns(in sourceRange: Range<RunIndex>) -> Int {
            let lowerOffset = max(
                sourceRange.lowerBound.characterOffset,
                self.sourceRange.lowerBound.characterOffset
            )
            let upperOffset = min(
                sourceRange.upperBound.characterOffset,
                self.sourceRange.upperBound.characterOffset
            )
            guard lowerOffset < upperOffset else {
                return 0
            }

            let lineOffset = self.sourceRange.lowerBound.characterOffset
            return TerminalText.columnWidth(
                content.sliceCharacters(
                    lowerBound: lowerOffset - lineOffset,
                    upperBound: upperOffset - lineOffset
                )
            )
        }

        /// Returns the longest source prefix that fits within a column budget.
        ///
        /// The result never splits an extended grapheme cluster. A nonpositive
        /// budget returns an empty range at the line's start, while a budget at
        /// least as wide as the line returns the complete ``sourceRange``.
        ///
        /// - Parameter columns: The maximum number of terminal columns.
        /// - Returns: A contiguous source range beginning at the line's start.
        /// - Complexity: O(n), where n is the number of examined characters.
        public func prefixRange(fittingColumns columns: Int) -> Range<RunIndex> {
            guard columns > 0 else {
                return sourceRange.lowerBound..<sourceRange.lowerBound
            }
            guard columns < self.columns else {
                return sourceRange
            }

            var usedColumns = 0
            var characterCount = 0
            for character in content {
                let characterColumns = TerminalText.columnWidth(String(character))
                guard usedColumns + characterColumns <= columns else {
                    break
                }
                usedColumns += characterColumns
                characterCount += 1
            }
            let upperBound = RunIndex(
                characterOffset: sourceRange.lowerBound.characterOffset + characterCount
            )
            return sourceRange.lowerBound..<upperBound
        }

        /// Returns the longest source suffix that fits within a column budget.
        ///
        /// The result never splits an extended grapheme cluster. A nonpositive
        /// budget returns an empty range at the line's end, while a budget at
        /// least as wide as the line returns the complete ``sourceRange``.
        ///
        /// - Parameter columns: The maximum number of terminal columns.
        /// - Returns: A contiguous source range ending at the line's end.
        /// - Complexity: O(n), where n is the number of examined characters.
        public func suffixRange(fittingColumns columns: Int) -> Range<RunIndex> {
            guard columns > 0 else {
                return sourceRange.upperBound..<sourceRange.upperBound
            }
            guard columns < self.columns else {
                return sourceRange
            }

            var usedColumns = 0
            var characterCount = 0
            for character in content.reversed() {
                let characterColumns = TerminalText.columnWidth(String(character))
                guard usedColumns + characterColumns <= columns else {
                    break
                }
                usedColumns += characterColumns
                characterCount += 1
            }
            let lowerBound = RunIndex(
                characterOffset: sourceRange.upperBound.characterOffset - characterCount
            )
            return lowerBound..<sourceRange.upperBound
        }

        /// Reports whether a column is an exact extended-grapheme boundary.
        ///
        /// Column zero and the line's ending column are boundaries, including
        /// for an empty line. Negative columns and columns beyond ``columns``
        /// return `false`.
        ///
        /// - Parameter column: A zero-based terminal column relative to this line.
        /// - Returns: `true` when the column does not divide a displayed grapheme.
        /// - Complexity: O(n), where n is the number of examined characters.
        public func isCharacterBoundary(atColumn column: Int) -> Bool {
            guard column >= 0, column <= columns else {
                return false
            }

            var currentColumn = 0
            for character in content {
                let nextColumn = currentColumn + TerminalText.columnWidth(String(character))
                if column == currentColumn || column == nextColumn {
                    return true
                }
                if column < nextColumn {
                    return false
                }
                currentColumn = nextColumn
            }
            return column == currentColumn
        }
    }

    /// A same-attribute fragment placed within one visual line.
    public struct Run: Equatable, Sendable {

        /// The visible unsanitized string fragment.
        public let content: String

        /// The fragment's zero-based starting terminal column in its line.
        public let column: Int

        /// Attributes after resolving enclosing run-group overrides.
        public let attributes: RunAttributes

        /// The fragment's exact character range in the logical input string.
        public let sourceRange: Range<RunIndex>

        init(
            content: String,
            column: Int,
            attributes: RunAttributes,
            sourceRange: Range<RunIndex>
        ) {
            self.content = content
            self.column = column
            self.attributes = attributes
            self.sourceRange = sourceRange
        }
    }

    /// The actual terminal-cell extent occupied by the layout.
    public let size: Size

    /// Visual lines in top-to-bottom row order.
    public let lines: [Line]

    private let characterCount: Int

    init(size: Size, lines: [Line], characterCount: Int) {
        self.size = size
        self.lines = lines
        self.characterCount = characterCount
    }

    /// Returns the nearest visual insertion point for a logical run index.
    ///
    /// Out-of-range offsets clamp to the logical content. When two wrapped
    /// lines share an insertion offset, this method chooses the later line so
    /// an end insertion point can advance past a filled terminal row.
    ///
    /// - Parameter index: A logical character insertion position.
    /// - Returns: The zero-based terminal column and row of the insertion point.
    public func point(at index: RunIndex) -> Point {
        guard !lines.isEmpty else {
            return Point()
        }

        let offset = min(index.characterOffset, characterCount)
        let row = lines.lastIndex {
            offset >= $0.sourceRange.lowerBound.characterOffset
                && offset <= $0.sourceRange.upperBound.characterOffset
        } ?? max(lines.count - 1, 0)
        let line = lines[row]
        let localOffset = min(
            max(offset - line.sourceRange.lowerBound.characterOffset, 0),
            line.content.count
        )
        return Point(
            column: TerminalText.columnWidth(
                line.content,
                upToCharacterOffset: localOffset
            ),
            row: row
        )
    }

    /// Returns the nearest logical insertion index for a visual point.
    ///
    /// Rows and columns outside the layout clamp to the nearest line and
    /// character boundary. A column inside a wide grapheme resolves to the
    /// insertion position before that grapheme.
    ///
    /// - Parameter point: A zero-based terminal point relative to this layout.
    /// - Returns: The nearest logical character insertion position.
    public func index(at point: Point) -> RunIndex {
        guard !lines.isEmpty else {
            return RunIndex(characterOffset: 0)
        }

        let line = lines[min(max(point.row, 0), lines.count - 1)]
        let targetColumn = max(point.column, 0)
        var column = 0
        var offset = line.sourceRange.lowerBound.characterOffset
        for character in line.content {
            let width = TerminalText.columnWidth(String(character))
            guard column + width <= targetColumn else {
                break
            }
            column += width
            offset += 1
        }
        return RunIndex(
            characterOffset: min(offset, line.sourceRange.upperBound.characterOffset)
        )
    }
}

/// Measures and lays out recursive run groups.
public extension RunGroup {

    /// Measures the group's intrinsic terminal-cell requirements.
    ///
    /// - Returns: Metrics computed with SwiftTUIRuns' fixed Unicode width and
    ///   emergency-wrapping policy.
    /// - Complexity: O(n), where n is the number of characters.
    func measure() -> RunMetrics {
        let content = flattenedRuns().map(\.content).joined()
        var minimumContentColumns = 0
        var totalColumns = 0
        for character in content {
            let columns = TerminalText.columnWidth(String(character))
            minimumContentColumns = max(minimumContentColumns, columns)
            totalColumns += columns
        }
        if !UnicodeLineBreak.containsMandatoryBreak(in: content) {
            return RunMetrics(
                minimumContentColumns: minimumContentColumns,
                maximumContentColumns: totalColumns,
                unwrappedRows: 1
            )
        }
        let lines = RunLineWrapper.wrappedLines(for: content, maxWidth: nil)
        return RunMetrics(
            minimumContentColumns: minimumContentColumns,
            maximumContentColumns: lines.map {
                TerminalText.columnWidth($0.content)
            }.max() ?? 0,
            unwrappedRows: lines.count
        )
    }

    /// Lays out the group's content within an optional maximum width.
    ///
    /// Layout uses Unicode 17 line-break data, terminal widths for emoji and
    /// CJK graphemes, punctuation-aware opportunities, and emergency wrapping
    /// at extended-grapheme boundaries. These policies are fixed in this API;
    /// run and group boundaries do not add opportunities.
    ///
    /// - Parameter columns: The maximum terminal-column width, or `nil` to
    ///   disable soft wrapping. Nonpositive widths produce an empty layout.
    /// - Returns: Visual lines and placed run fragments with source mapping.
    /// - Complexity: O(n + b), where n is the number of characters and b is
    ///   the number of examined Unicode line-break opportunities.
    func layout(fittingColumns columns: Int? = nil) -> RunLayout {
        let flattened = flattenedContent()
        let wrappedLines = RunLineWrapper.wrappedLines(
            for: flattened.content,
            maxWidth: columns
        )
        let lines = wrappedLines.map { line in
            layoutLine(line, attributes: flattened.attributes)
        }
        return RunLayout(
            size: Size(
                columns: lines.map(\.columns).max() ?? 0,
                rows: lines.count
            ),
            lines: lines,
            characterCount: flattened.content.count
        )
    }

    private func flattenedRuns() -> [(content: String, attributes: RunAttributes)] {
        flattenedRuns(inheriting: RunAttributes())
    }

    private struct FlattenedContent {
        var content: String
        var attributes: [RunAttributes]
    }

    private func flattenedContent() -> FlattenedContent {
        let runs = flattenedRuns()
        let content = runs.map(\.content).joined()
        var attributeRanges: [(upperUTF8Offset: Int, attributes: RunAttributes)] = []
        var upperUTF8Offset = 0
        for run in runs where !run.content.isEmpty {
            upperUTF8Offset += run.content.utf8.count
            attributeRanges.append((upperUTF8Offset, run.attributes))
        }
        var rangeIndex = 0
        var characterUTF8Offset = 0
        let attributes = content.map { character in
            while rangeIndex < attributeRanges.count - 1,
                  characterUTF8Offset >= attributeRanges[rangeIndex].upperUTF8Offset
            {
                rangeIndex += 1
            }
            defer { characterUTF8Offset += String(character).utf8.count }
            return attributeRanges.indices.contains(rangeIndex)
                ? attributeRanges[rangeIndex].attributes
                : RunAttributes()
        }
        return FlattenedContent(
            content: content,
            attributes: attributes
        )
    }

    private func flattenedRuns(
        inheriting inherited: RunAttributes
    ) -> [(content: String, attributes: RunAttributes)] {
        let resolved = attributes.overriding(inherited)
        return children.flatMap { child in
            switch child {
            case .run(let run):
                [(run.content, run.attributes.overriding(resolved))]
            case .group(let group):
                group.flattenedRuns(inheriting: resolved)
            }
        }
    }

    private func layoutLine(
        _ line: WrappedRunLine,
        attributes: [RunAttributes]
    ) -> RunLayout.Line {
        var runs: [RunLayout.Run] = []
        var pendingContent = ""
        var pendingAttributes: RunAttributes?
        var pendingColumn = 0
        var pendingOffset = line.lowerOffset
        var column = 0

        func flush(upperOffset: Int) {
            guard !pendingContent.isEmpty, let pendingAttributes else {
                return
            }
            runs.append(
                RunLayout.Run(
                    content: pendingContent,
                    column: pendingColumn,
                    attributes: pendingAttributes,
                    sourceRange: (
                        RunIndex(characterOffset: pendingOffset)
                            ..< RunIndex(characterOffset: upperOffset)
                    )
                )
            )
            pendingContent = ""
        }

        for (localOffset, character) in line.content.enumerated() {
            let sourceOffset = line.lowerOffset + localOffset
            let characterAttributes = attributes.indices.contains(sourceOffset)
                ? attributes[sourceOffset]
                : RunAttributes()
            if pendingAttributes != characterAttributes {
                flush(upperOffset: sourceOffset)
                pendingColumn = column
                pendingOffset = sourceOffset
                pendingAttributes = characterAttributes
            }
            pendingContent.append(character)
            column += TerminalText.columnWidth(String(character))
        }
        flush(upperOffset: line.upperOffset)

        return RunLayout.Line(
            columns: column,
            runs: runs,
            sourceRange: (
                RunIndex(characterOffset: line.lowerOffset)
                    ..< RunIndex(characterOffset: line.upperOffset)
            ),
            content: line.content
        )
    }
}
