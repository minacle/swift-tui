import Foundation
import Terminal

/// A control that displays editable multi-line text in the terminal.
///
/// `TextEditor` binds its editable string to a source of truth, renders text
/// across terminal rows, scrolls to keep the caret visible, and shows a cursor
/// while focused.
public nonisolated struct TextEditor: View, TextEditorRenderable, LayoutTraitRenderable {

    /// The body type for this primitive view.
    public typealias Body = Never

    let text: Binding<String>

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    /// Creates a text editor.
    ///
    /// - Parameter text: A binding to the editable string.
    public init(text: Binding<String>) {
        self.text = text
    }
}

protocol TextEditorRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

extension TextEditor {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let editorState = runtime?.textEditorState(
            at: path,
            initialText: text.wrappedValue
        )
        let updatesInteractiveState = !LayoutMeasurementContext.isMeasuring
            && runtime?.isSuppressingInteractiveRenderRegistrations != true
        if updatesInteractiveState {
            editorState?.synchronize(with: text.wrappedValue)
            editorState?.clamp()
            editorState?.updateLayoutWidth(proposal?.columns)
        }
        runtime?.registerFocusable(true, at: path)
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: path,
                matches: TextEditorInput.matches,
                action: {
                    handle($0, text: text, state: editorState)
                }
            ),
            at: path
        )
        runtime?.registerPointerDownPositionHandler(
            PointerDownPositionHandler(
                actionPath: path,
                action: { point in
                    guard let editorState else {
                        return
                    }

                    let layout = TextEditorLayout(
                        text: editorState.text,
                        maxWidth: editorState.layoutWidth
                    )
                    editorState.move(to: point, layout: layout)
                }
            ),
            at: path
        )

        let currentText = editorState?.text ?? text.wrappedValue
        let layout = TextEditorLayout(text: currentText, maxWidth: proposal?.columns)
        let cursor = renderedCursor(state: editorState, layout: layout, runtime: runtime, path: path)
        if updatesInteractiveState {
            editorState?.updateScrollPoint(
                for: cursor,
                viewportWidth: proposal?.columns,
                viewportHeight: proposal?.rows,
                contentWidth: layout.width,
                contentHeight: layout.height
            )
        }

        let content = RenderedBlock(
            runs: layout.lines.enumerated().map {
                RenderedRun(
                    text: $0.element.text,
                    row: $0.offset,
                    style: EnvironmentRenderContext.current.textStyle
                )
            },
            width: layout.width,
            height: layout.height,
            paddedRows: Set(0..<layout.height),
            cursor: cursor
        )

        var block = ScrollViewRenderer.render(
            content,
            axes: [.horizontal, .vertical],
            position: ScrollPosition(point: editorState?.scrollPoint ?? ScrollPoint()),
            proposal: RenderProposal(columns: proposal?.columns, rows: proposal?.rows)
        ).block
        block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
        return block
    }

    private func renderedCursor(
        state: TextEditorState?,
        layout: TextEditorLayout,
        runtime: StateRuntime?,
        path: [Int]
    ) -> RenderedCursor? {
        guard runtime?.isFocused(at: path) == true, let state else {
            return nil
        }

        return layout.cursor(at: state.offset)
    }

    private func handle(
        _ keyPress: KeyPress,
        text: Binding<String>,
        state: TextEditorState?
    ) -> KeyPress.Result {
        guard let state else {
            return .ignored
        }

        let layout = TextEditorLayout(text: state.text, maxWidth: state.layoutWidth)
        switch keyPress.key {
        case .leftArrow:
            state.moveLeft()
            return .handled
        case .rightArrow:
            state.moveRight()
            return .handled
        case .upArrow:
            state.moveVertically(by: -1, layout: layout)
            return .handled
        case .downArrow:
            state.moveVertically(by: 1, layout: layout)
            return .handled
        case .home:
            state.moveToLineStart(layout: layout)
            return .handled
        case .end:
            state.moveToLineEnd(layout: layout)
            return .handled
        case .delete:
            state.deleteBackward(update: text)
            return .handled
        case .deleteForward:
            state.deleteForward(update: text)
            return .handled
        case .return:
            state.insert("\n", update: text)
            return .handled
        default:
            guard TextEditorInput.isTextInsertion(keyPress) else {
                return .ignored
            }

            state.insert(keyPress.characters, update: text)
            return .handled
        }
    }
}

final class TextEditorState {

    private let invalidate: () -> Void

    private(set) var text: String {
        didSet {
            if text != oldValue {
                invalidate()
            }
        }
    }

    private var lastObservedBindingText: String

    private(set) var offset = 0 {
        didSet {
            if offset != oldValue {
                invalidate()
            }
        }
    }

    private var preferredColumn: Int?

    private(set) var layoutWidth: Int?

    private(set) var scrollPoint = ScrollPoint() {
        didSet {
            if scrollPoint != oldValue {
                invalidate()
            }
        }
    }

    init(initialText: String, invalidate: @escaping () -> Void) {
        self.text = initialText
        self.lastObservedBindingText = initialText
        self.offset = initialText.count
        self.invalidate = invalidate
    }

    func synchronize(with bindingText: String) {
        guard bindingText != lastObservedBindingText else {
            return
        }

        text = bindingText
        lastObservedBindingText = bindingText
        clamp()
    }

    func clamp() {
        move(to: offset, preservesPreferredColumn: false)
    }

    func updateLayoutWidth(_ width: Int?) {
        layoutWidth = width
    }

    func moveLeft() {
        move(to: offset - 1, preservesPreferredColumn: false)
    }

    func moveRight() {
        move(to: offset + 1, preservesPreferredColumn: false)
    }

    func moveVertically(by delta: Int, layout: TextEditorLayout) {
        let current = layout.lineAndColumn(at: offset)
        let column = preferredColumn ?? current.column
        preferredColumn = column
        let lineIndex = min(max(current.lineIndex + delta, 0), layout.lines.count - 1)
        offset = layout.offset(onLine: lineIndex, nearestColumn: column)
    }

    func moveToLineStart(layout: TextEditorLayout) {
        let current = layout.lineAndColumn(at: offset)
        move(to: layout.lines[current.lineIndex].lowerOffset, preservesPreferredColumn: false)
    }

    func moveToLineEnd(layout: TextEditorLayout) {
        let current = layout.lineAndColumn(at: offset)
        move(to: layout.lines[current.lineIndex].upperOffset, preservesPreferredColumn: false)
    }

    func move(to point: Point, layout: TextEditorLayout) {
        let lineIndex = min(max(scrollPoint.y + point.row, 0), layout.lines.count - 1)
        let column = max(scrollPoint.x + point.column, 0)
        move(
            to: layout.offset(onLine: lineIndex, nearestColumn: column),
            preservesPreferredColumn: false
        )
    }

    func insert(_ newText: String, update binding: Binding<String>) {
        text.insert(newText, atCharacterOffset: offset)
        binding.wrappedValue = text
        lastObservedBindingText = binding.wrappedValue
        offset += newText.count
        preferredColumn = nil
    }

    func deleteBackward(update binding: Binding<String>) {
        guard offset > 0 else {
            return
        }

        text.removeCharacter(atOffset: offset - 1)
        binding.wrappedValue = text
        lastObservedBindingText = binding.wrappedValue
        offset -= 1
        preferredColumn = nil
    }

    func deleteForward(update binding: Binding<String>) {
        guard offset < text.count else {
            return
        }

        text.removeCharacter(atOffset: offset)
        binding.wrappedValue = text
        lastObservedBindingText = binding.wrappedValue
        preferredColumn = nil
    }

    func updateScrollPoint(
        for cursor: RenderedCursor?,
        viewportWidth: Int?,
        viewportHeight: Int?,
        contentWidth: Int,
        contentHeight: Int
    ) {
        guard let cursor else {
            return
        }

        var x = scrollPoint.x
        var y = scrollPoint.y
        if let viewportWidth, viewportWidth > 0 {
            if cursor.column < x {
                x = cursor.column
            }
            else if cursor.column >= x + viewportWidth {
                x = cursor.column - viewportWidth + 1
            }
            x = min(max(x, 0), max(contentWidth - viewportWidth, 0))
        }
        else {
            x = 0
        }

        if let viewportHeight, viewportHeight > 0 {
            if cursor.row < y {
                y = cursor.row
            }
            else if cursor.row >= y + viewportHeight {
                y = cursor.row - viewportHeight + 1
            }
            y = min(max(y, 0), max(contentHeight - viewportHeight, 0))
        }
        else {
            y = 0
        }

        scrollPoint = ScrollPoint(x: x, y: y)
    }

    private func move(to newOffset: Int, preservesPreferredColumn: Bool) {
        offset = min(max(newOffset, 0), text.count)
        if !preservesPreferredColumn {
            preferredColumn = nil
        }
    }
}

struct TextEditorLayout {

    let lines: [TextEditorLine]

    init(text: String, maxWidth: Int?) {
        let displayLines = TextLineWrapper.wrappedLines(for: text, maxWidth: maxWidth)
        self.lines = TextEditorLayout.lines(
            from: displayLines,
            in: text,
            maxWidth: maxWidth
        )
    }

    var width: Int {
        max(lines.map { TerminalText.columnWidth($0.text) }.max() ?? 0, 1)
    }

    var height: Int {
        max(lines.count, 1)
    }

    func cursor(at offset: Int) -> RenderedCursor {
        let current = lineAndColumn(at: offset)
        return RenderedCursor(row: current.lineIndex, column: current.column)
    }

    func lineAndColumn(at offset: Int) -> (lineIndex: Int, column: Int) {
        let offset = max(offset, 0)
        let lineIndex = lines.lastIndex {
            offset >= $0.lowerOffset && offset <= $0.upperOffset
        } ?? max(lines.count - 1, 0)
        let line = lines[lineIndex]
        return (
            lineIndex,
            TerminalText.columnWidth(
                line.text.sliceCharacters(
                    lowerBound: 0,
                    upperBound: offset - line.lowerOffset
                )
            )
        )
    }

    func offset(onLine lineIndex: Int, nearestColumn column: Int) -> Int {
        let line = lines[min(max(lineIndex, 0), lines.count - 1)]
        var currentColumn = 0
        var offset = line.lowerOffset
        for character in line.text {
            let characterWidth = TerminalText.columnWidth(String(character))
            guard currentColumn + characterWidth <= column else {
                break
            }

            currentColumn += characterWidth
            offset += 1
        }
        return min(offset, line.upperOffset)
    }

    private static func mappedLines(
        from displayLines: [String],
        in text: String
    ) -> [TextEditorLine] {
        guard !displayLines.isEmpty else {
            return [TextEditorLine(text: "", lowerOffset: 0, upperOffset: 0)]
        }

        var lines: [TextEditorLine] = []
        var searchStart = text.startIndex
        for displayLine in displayLines {
            let range: Range<String.Index>
            if displayLine.isEmpty {
                range = searchStart..<searchStart
            }
            else if let found = text.range(
                of: displayLine,
                range: searchStart..<text.endIndex
            ) {
                range = found
            }
            else {
                range = searchStart..<searchStart
            }

            let lowerOffset = text.distance(from: text.startIndex, to: range.lowerBound)
            let upperOffset = text.distance(from: text.startIndex, to: range.upperBound)
            lines.append(
                TextEditorLine(
                    text: displayLine,
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

    private static func lines(
        from displayLines: [String],
        in text: String,
        maxWidth: Int?
    ) -> [TextEditorLine] {
        var lines = mappedLines(from: displayLines, in: text)
        guard let maxWidth,
              maxWidth > 0,
              let lastLine = lines.last,
              !lastLine.text.isEmpty,
              TerminalText.columnWidth(lastLine.text) == maxWidth
        else {
            return lines
        }

        lines.append(
            TextEditorLine(
                text: "",
                lowerOffset: lastLine.upperOffset,
                upperOffset: lastLine.upperOffset
            )
        )
        return lines
    }
}

struct TextEditorLine {

    let text: String

    let lowerOffset: Int

    let upperOffset: Int
}

private enum TextEditorInput {

    static func matches(_ keyPress: KeyPress) -> Bool {
        guard keyPress.phase.contains(.down) || keyPress.phase.contains(.repeat) else {
            return false
        }

        return keyPress.key == .delete
            || keyPress.key == .deleteForward
            || keyPress.key == .downArrow
            || keyPress.key == .end
            || keyPress.key == .home
            || keyPress.key == .leftArrow
            || keyPress.key == .return
            || keyPress.key == .rightArrow
            || keyPress.key == .upArrow
            || isTextInsertion(keyPress)
    }

    static func isTextInsertion(_ keyPress: KeyPress) -> Bool {
        keyPress.isTextInsertion
    }
}
