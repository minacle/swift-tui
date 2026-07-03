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

    init(
        text: String,
        row: Int = 0,
        column: Int = 0,
        style: TextStyle = .plain
    ) {
        self.text = text
        self.row = row
        self.column = column
        self.style = style
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
            style: style
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
                style: $0.style
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
                    style: style
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

nonisolated struct RenderedCursor: Equatable, Sendable {

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

    func offsetBy(x: Int, y: Int) -> RenderedFocusRegion {
        RenderedFocusRegion(path: path, frame: frame.offsetBy(x: x, y: y))
    }

    func clipped(to bounds: RenderedRect) -> RenderedFocusRegion? {
        frame.clipped(to: bounds).map {
            RenderedFocusRegion(path: path, frame: $0)
        }
    }
}

nonisolated struct RenderedBlock: Equatable, Sendable {

    var runs: [RenderedRun]

    private var minimumWidth: Int

    private var minimumHeight: Int

    // Used only when projecting coordinate-based runs back to legacy lines.
    var paddedRows: Set<Int>

    var cursor: RenderedCursor?

    var hitRegions: [RenderedHitRegion]

    var scrollRegions: [RenderedScrollRegion]

    var focusRegions: [RenderedFocusRegion]

    init(
        lines: [String],
        style: TextStyle = .plain,
        cursor: RenderedCursor? = nil,
        hitRegions: [RenderedHitRegion] = [],
        scrollRegions: [RenderedScrollRegion] = [],
        focusRegions: [RenderedFocusRegion] = []
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
        self.cursor = cursor
        self.hitRegions = hitRegions
        self.scrollRegions = scrollRegions
        self.focusRegions = focusRegions
    }

    init(
        runs: [RenderedRun],
        width: Int? = nil,
        height: Int? = nil,
        paddedRows: Set<Int> = [],
        cursor: RenderedCursor? = nil,
        hitRegions: [RenderedHitRegion] = [],
        scrollRegions: [RenderedScrollRegion] = [],
        focusRegions: [RenderedFocusRegion] = []
    ) {
        self.runs = runs.filter { !$0.isEmpty }
        self.minimumWidth = max(width ?? 0, 0)
        self.minimumHeight = max(height ?? 0, 0)
        self.paddedRows = paddedRows
        self.cursor = cursor
        self.hitRegions = hitRegions
        self.scrollRegions = scrollRegions
        self.focusRegions = focusRegions
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
            cursor: framedCursor(x: x, y: y, width: targetWidth, height: targetHeight),
            hitRegions: framedHitRegions(x: x, y: y, width: targetWidth, height: targetHeight),
            scrollRegions: framedScrollRegions(x: x, y: y, width: targetWidth, height: targetHeight),
            focusRegions: framedFocusRegions(x: x, y: y, width: targetWidth, height: targetHeight)
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
            cursor: cursor.map {
                RenderedCursor(row: $0.row + insets.top, column: $0.column + insets.leading)
            },
            hitRegions: hitRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            scrollRegions: scrollRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            },
            focusRegions: focusRegions.map {
                $0.offsetBy(x: insets.leading, y: insets.top)
            }
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
            cursor: offsetCursor(x: x, y: y, bounds: bounds),
            hitRegions: hitRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            scrollRegions: scrollRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            },
            focusRegions: focusRegions.compactMap {
                $0.offsetBy(x: x, y: y).clipped(to: bounds)
            }
        )
    }

    private func framedCursor(
        x: Int,
        y: Int,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> RenderedCursor? {
        guard let cursor else {
            return nil
        }

        let row = cursor.row + y
        let column = cursor.column + x
        guard row >= 0,
              row < targetHeight,
              column >= 0,
              column <= targetWidth else {
            return nil
        }

        return RenderedCursor(row: row, column: min(column, targetWidth - 1))
    }

    private func offsetCursor(x: Int, y: Int, bounds: RenderedRect) -> RenderedCursor? {
        guard let cursor else {
            return nil
        }

        let row = cursor.row + y
        let column = cursor.column + x
        guard row >= bounds.y,
              row < bounds.y + bounds.height,
              column >= bounds.x,
              column <= bounds.x + bounds.width else {
            return nil
        }

        return RenderedCursor(
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

    private func horizontalOffset(
        contentWidth: Int,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = containerWidth - contentWidth
        switch alignment {
        case .leading:
            return 0
        case .center:
            return padding / 2
        case .trailing:
            return padding
        }
    }

    private func verticalOffset(
        contentHeight: Int,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = containerHeight - contentHeight
        switch alignment {
        case .top:
            return 0
        case .center:
            return padding / 2
        case .bottom:
            return padding
        }
    }
}

nonisolated struct RenderProposal: Equatable, Sendable {

    var columns: Int?

    var rows: Int?

    init(columns: Int? = nil, rows: Int? = nil) {
        self.columns = columns.map { max($0, 0) }
        self.rows = rows.map { max($0, 0) }
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

    var priority: Double = 0

    func removingFlexibleAxes(_ axes: Axis.Set) -> LayoutTraits {
        var traits = self
        traits.flexibleAxes.subtract(axes)
        return traits
    }
}

protocol LayoutTraitRenderable {

    var layoutTraits: LayoutTraits { get }
}

nonisolated struct StackChild {

    var traits: LayoutTraits

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
                    render: { _, _ in element }
                )
            },
            alignment: .leading,
            spacing: 0,
            proposal: proposal
        )
    }
}

extension AnyView: FlattenableViewContent, LayoutTraitRenderable {

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

enum TextLayoutRenderer {

    static func block(for text: Text, in proposal: RenderProposal?) -> RenderedBlock {
        let lineLimit = TextLineLimitContext.current
        var lines = wrappedLines(for: text.content, maxWidth: proposal?.columns)
        let isTruncated = lineLimit.number.map { lines.count > $0 } ?? false

        if let number = lineLimit.number {
            lines = Array(lines.prefix(number))
            if isTruncated, !lines.isEmpty {
                lines[lines.count - 1] = truncatedLine(
                    lines[lines.count - 1],
                    maxWidth: proposal?.columns
                )
            }
            if lineLimit.reservesSpace, lines.count < number {
                lines.append(contentsOf: Array(repeating: "", count: number - lines.count))
            }
        }

        return RenderedBlock(
            lines: lines,
            style: EnvironmentRenderContext.current.textStyle
        )
    }

    private static func wrappedLines(for text: String, maxWidth: Int?) -> [String] {
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

            if let bestBreak {
                let lineEnd = trimmingTrailingWhitespace(
                    in: paragraph,
                    lowerBound: start,
                    upperBound: bestBreak.index
                )
                lines.append(String(paragraph[start..<lineEnd]))
                start = skippingLeadingWhitespace(in: paragraph, from: bestBreak.index)
                opportunityIndex = scanIndex
            }
            else {
                let fallbackEnd = fittingCharacterBoundary(
                    in: paragraph,
                    from: start,
                    maxWidth: maxWidth
                )
                lines.append(String(paragraph[start..<fallbackEnd]))
                if fallbackEnd > start {
                    start = skippingLeadingWhitespace(in: paragraph, from: fallbackEnd)
                }
                else {
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
        return index
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

    private static func truncatedLine(_ line: String, maxWidth: Int?) -> String {
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
        if let text = view as? Text {
            return TextLayoutRenderer.block(for: text, in: proposal)
        }

        if view is EmptyView {
            return nil
        }

        if let spacer = view as? Spacer {
            return block(for: spacer, in: proposal)
        }

        if let scroll = view as? any ScrollRenderable {
            return scroll.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let textField = view as? any TextFieldRenderable {
            return textField.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let geometryReader = view as? any GeometryReaderRenderable {
            return geometryReader.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let layout = view as? any LayoutRenderable {
            return layout.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let navigation = view as? any NavigationRenderable {
            return navigation.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let group = view as? ViewGroup {
            return StackRenderer.vertical(
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
        }

        if let content = view as? any FlattenableViewContent {
            return content.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let stack = view as? any StackRenderable {
            return stack.renderedBlock(in: proposal, path: path, runtime: runtime)
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

        if let modifier = view as? any TerminationModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any FocusModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any InputModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any SubmitModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        let body = runtime?.withView(at: path, mode: .render) {
            runtime?.materializeDynamicProperties(in: view)
            return view.body
        } ?? view.body
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
        if let text = view as? Text {
            return .block(TextLayoutRenderer.block(for: text, in: proposal))
        }

        if view is EmptyView {
            return nil
        }

        if let spacer = view as? Spacer {
            return .spacer(minLength: spacer.minLength ?? 0)
        }

        if let scroll = view as? any ScrollRenderable {
            return scroll.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
        }

        if let textField = view as? any TextFieldRenderable {
            return textField.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
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

        if let navigation = view as? any NavigationRenderable {
            return navigation.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let group = view as? ViewGroup {
            return block(
                from: group,
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
        }

        if let content = view as? any FlattenableViewContent {
            return content.renderedBlock(in: proposal, path: path, runtime: runtime).map { .block($0) }
        }

        if let stack = view as? any StackRenderable {
            return stack.renderedBlock(
                in: proposal,
                path: path,
                runtime: runtime
            ).map { .block($0) }
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

        if let modifier = view as? any TerminationModifierRenderable {
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

        if let modifier = view as? any SubmitModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        let body = runtime?.withView(at: path, mode: .render) {
            runtime?.materializeDynamicProperties(in: view)
            return view.body
        } ?? view.body
        return element(from: body, in: proposal, path: path + [0], runtime: runtime)
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
                TerminalControl.cursorPositionSequence(
                    row: frame.row + run.row,
                    column: frame.column + run.column
                ) + styledText(for: run)
            }.joined()
            + cursorSequence(for: block, in: frame, viewport: viewport)
    }

    private static func styledText(for run: RenderedRun) -> String {
        guard !run.style.isPlain else {
            return run.text
        }

        return TerminalControl.sgrSequence(for: run.style)
            + run.text
            + TerminalControl.resetSGRSequence(for: run.style)
    }

    private static func cursorSequence(
        for block: RenderedBlock,
        in frame: TextFrame,
        viewport: TerminalViewportSize
    ) -> String {
        guard let cursor = block.cursor else {
            return TerminalControl.hideCursorSequence
        }

        let row = min(max(frame.row + cursor.row, 1), viewport.rows)
        let column = min(max(frame.column + cursor.column, 1), viewport.columns)
        return TerminalControl.showCursorSequence
            + TerminalControl.cursorPositionSequence(row: row, column: column)
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

extension StackRenderable {

    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock? {
        renderedBlock(in: proposal, path: [], runtime: nil)
    }
}

extension HStack: StackRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        StackRenderer.horizontal(
            ViewResolver.stackChildren(
                from: content,
                in: RenderProposal(rows: proposal?.rows),
                path: path + [0],
                runtime: runtime
            ),
            alignment: alignment,
            spacing: spacing,
            proposal: proposal
        )
    }
}

extension VStack: StackRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        StackRenderer.vertical(
            ViewResolver.stackChildren(
                from: content,
                in: RenderProposal(columns: proposal?.columns),
                path: path + [0],
                runtime: runtime
            ),
            alignment: alignment,
            spacing: spacing,
            proposal: proposal
        )
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

        return layoutTraits(from: view.body)
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
        spacing: Int,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        let layout = horizontalLayout(from: children, spacing: spacing, proposal: proposal)
        let items = layout.items
        guard !items.isEmpty else {
            return nil
        }

        let height = items.compactMap(\.block?.height).max() ?? 1
        let width = layout.width
        let bounds = RenderedRect(width: width, height: height)
        let runs = items.flatMap { item -> [RenderedRun] in
            guard let block = item.block else {
                return []
            }

            let y = verticalOffset(
                contentHeight: block.height,
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
                    contentHeight: block.height,
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
            cursor: horizontalCursor(from: items, height: height, alignment: alignment),
            hitRegions: horizontalHitRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            scrollRegions: horizontalScrollRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            focusRegions: horizontalFocusRegions(from: items, height: height, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) }
        )
    }

    static func vertical(
        _ children: [StackChild],
        alignment: HorizontalAlignment,
        spacing: Int,
        proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        let layout = verticalLayout(from: children, spacing: spacing, proposal: proposal)
        let items = layout.items
        guard !items.isEmpty else {
            return nil
        }

        let width = items.compactMap(\.block?.width).max() ?? 0
        let height = layout.height
        let bounds = RenderedRect(width: width, height: height)
        let runs = items.flatMap { item -> [RenderedRun] in
            guard let block = item.block else {
                return []
            }

            let x = horizontalOffset(
                contentWidth: block.width,
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
            cursor: verticalCursor(from: items, width: width, alignment: alignment),
            hitRegions: verticalHitRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            scrollRegions: verticalScrollRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) },
            focusRegions: verticalFocusRegions(from: items, width: width, alignment: alignment)
                .compactMap { $0.clipped(to: bounds) }
        )
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

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }
    }

    private struct VerticalItem {

        var content: RenderedElement

        var y: Int

        var height: Int

        var block: RenderedBlock? {
            guard case .block(let block) = content else {
                return nil
            }

            return block
        }
    }

    struct MeasuredChild {

        var content: RenderedElement

        var traits: LayoutTraits

        var render: (RenderProposal?, Bool) -> RenderedElement?
    }

    private static func horizontalLayout(
        from children: [StackChild],
        spacing: Int,
        proposal: RenderProposal?
    ) -> HorizontalLayout {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .horizontal,
            childProposal: horizontalChildProposal
        )
        let usesContentFlex = children.contains { $0.isHorizontallyContentFlexible }
        let flexibleCount = children.filter {
            $0.isHorizontallyFlexible(usingContentFlex: usesContentFlex)
        }.count
        let spacingWidth = spacingWidth(for: children.count, spacing: spacing)
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
        let items: [HorizontalItem] = children.compactMap { child -> HorizontalItem? in
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

            let item = HorizontalItem(content: element, x: x, width: itemWidth)
            x += item.width + max(spacing, 0)
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
        spacing: Int,
        proposal: RenderProposal?
    ) -> VerticalLayout {
        let children = measuredChildren(
            from: children,
            proposal: proposal,
            stackAxis: .vertical,
            childProposal: verticalChildProposal
        )
        let usesContentFlex = children.contains { $0.isVerticallyContentFlexible }
        let flexibleCount = children.filter {
            $0.isVerticallyFlexible(usingContentFlex: usesContentFlex)
        }.count
        let spacingHeight = spacingWidth(for: children.count, spacing: spacing)
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
        let items: [VerticalItem] = children.compactMap { child -> VerticalItem? in
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

            let item = VerticalItem(content: element, y: y, height: itemHeight)
            y += item.height + max(spacing, 0)
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
                flexibleOnStackAxis = child.traits.flexibleAxes.contains(.vertical)
            }

            guard let content = child.render(
                childProposal(nil, child.traits, proposal),
                flexibleOnStackAxis
            ), content.isRenderable else {
                return nil
            }

            return MeasuredChild(
                content: content,
                traits: child.traits,
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

    private static func horizontalCursor(
        from items: [HorizontalItem],
        height: Int,
        alignment: VerticalAlignment
    ) -> RenderedCursor? {
        for item in items {
            guard let block = item.block, let cursor = block.cursor else {
                continue
            }

            return RenderedCursor(
                row: verticalOffset(
                    contentHeight: block.height,
                    containerHeight: height,
                    alignment: alignment
                ) + cursor.row,
                column: item.x + cursor.column
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
                contentHeight: block.height,
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
                contentHeight: block.height,
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
                contentHeight: block.height,
                containerHeight: height,
                alignment: alignment
            )
            return block.focusRegions.map {
                $0.offsetBy(x: item.x, y: y)
            }
        }
    }

    private static func verticalCursor(
        from items: [VerticalItem],
        width: Int,
        alignment: HorizontalAlignment
    ) -> RenderedCursor? {
        for item in items {
            guard let block = item.block, let cursor = block.cursor else {
                continue
            }

            return RenderedCursor(
                row: item.y + cursor.row,
                column: horizontalOffset(
                    contentWidth: block.width,
                    containerWidth: width,
                    alignment: alignment
                ) + cursor.column
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
                contentWidth: block.width,
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
                contentWidth: block.width,
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
                contentWidth: block.width,
                containerWidth: width,
                alignment: alignment
            )
            return block.focusRegions.map {
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

    private static func spacingWidth(for count: Int, spacing: Int) -> Int {
        max(count - 1, 0) * max(spacing, 0)
    }

    private static func horizontalOffset(
        contentWidth: Int,
        containerWidth: Int,
        alignment: HorizontalAlignment
    ) -> Int {
        let padding = max(containerWidth - contentWidth, 0)
        switch alignment {
        case .leading:
            return 0
        case .center:
            return padding / 2
        case .trailing:
            return padding
        }
    }

    private static func verticalOffset(
        contentHeight: Int,
        containerHeight: Int,
        alignment: VerticalAlignment
    ) -> Int {
        let padding = max(containerHeight - contentHeight, 0)
        switch alignment {
        case .top:
            return 0
        case .center:
            return padding / 2
        case .bottom:
            return padding
        }
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
