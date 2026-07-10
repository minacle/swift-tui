import Foundation
import Terminal

/// A control that displays editable multi-line text in the terminal.
///
/// `TextEditor` binds its editable string to a source of truth, renders text
/// across terminal rows, scrolls to keep the caret visible, and shows a caret
/// while focused.
public nonisolated struct TextEditor: View, TextEditorRenderable, LayoutTraitRenderable {

    /// The body type for this primitive view.
    public typealias Body = Never

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: [.horizontal, .vertical])
    }

    /// Creates a text editor.
    ///
    /// - Parameter text: A binding to the editable string.
    public init(text: Binding<String>) {
        self.text = text
        self.selection = nil
    }

    /// Creates a text editor with bindings to its text and current selection.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string.
    ///   - selection: A binding to the current selection.
    public init(
        text: Binding<String>,
        selection: Binding<TextSelection?>
    ) {
        self.text = text
        self.selection = selection
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
            let bindingText = text.wrappedValue
            let textChanged = editorState?.text != bindingText
            editorState?.synchronize(with: bindingText)
            editorState?.synchronizeSelection(
                with: selection,
                textChanged: textChanged
            )
            editorState?.clamp()
            editorState?.updateLayoutWidth(proposal?.columns)
        }
        runtime?.registerFocusable(true, at: path)
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: path,
                matches: TextEditorInput.matches,
                action: {
                    handle(
                        $0,
                        text: text,
                        selection: selection,
                        state: editorState
                    )
                }
            ),
            at: path
        )
        runtime?.registerPointerDownPositionHandler(
            PointerDownPositionHandler(
                actionPath: path,
                requiresFocus: true,
                began: { point in
                    guard let editorState else {
                        return
                    }

                    let layout = TextEditorLayout(
                        text: editorState.text,
                        maxWidth: editorState.layoutWidth
                    )
                    editorState.beginSelection(to: point, layout: layout)
                    editorState.publishSelection(to: selection)
                },
                changed: { point in
                    guard let editorState else {
                        return
                    }

                    let layout = TextEditorLayout(
                        text: editorState.text,
                        maxWidth: editorState.layoutWidth
                    )
                    editorState.extendSelection(to: point, layout: layout)
                    editorState.publishSelection(to: selection)
                }
            ),
            at: path
        )

        let currentText = editorState?.text ?? text.wrappedValue
        let layout = TextEditorLayout(text: currentText, maxWidth: proposal?.columns)
        let caret = renderedCaret(state: editorState, layout: layout, runtime: runtime, path: path)
        if updatesInteractiveState {
            editorState?.publishSelectionOnFocus(
                runtime?.isFocused(at: path) == true,
                to: selection
            )
            editorState?.updateScrollPoint(
                for: caret,
                viewportWidth: proposal?.columns,
                viewportHeight: proposal?.rows,
                contentWidth: layout.width,
                contentHeight: layout.height
            )
        }

        let environment = EnvironmentRenderContext.current
        let visibleCaret = editorState?.selectedRange == nil ? caret : nil
        let content = RenderedBlock(
            runs: layout.lines.enumerated().flatMap { row, line in
                TextSelectionRenderer.runs(
                    text: line.text,
                    row: row,
                    baseOffset: line.lowerOffset,
                    style: environment.textStyle,
                    selection: editorState?.selectedRange,
                    tint: environment.tint,
                    foregroundStyle: environment.textSelectionForegroundStyle
                )
            },
            width: layout.width,
            height: layout.height,
            paddedRows: Set(0..<layout.height),
            caret: visibleCaret
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

    private func renderedCaret(
        state: TextEditorState?,
        layout: TextEditorLayout,
        runtime: StateRuntime?,
        path: [Int]
    ) -> RenderedCaret? {
        guard runtime?.isFocused(at: path) == true, let state else {
            return nil
        }

        return layout.caret(at: state.offset)
    }

    private func handle(
        _ keyPress: KeyPress,
        text: Binding<String>,
        selection: Binding<TextSelection?>?,
        state: TextEditorState?
    ) -> KeyPress.Result {
        guard let state else {
            return .ignored
        }

        let layout = TextEditorLayout(text: state.text, maxWidth: state.layoutWidth)
        let selecting = keyPress.modifiers.contains(.shift)
        let navigationBehavior =
            EnvironmentRenderContext.current.textSelectionNavigationBehavior
        switch keyPress.key {
        case .leftArrow:
            state.moveLeft(
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            state.publishSelection(to: selection)
            return .handled
        case .rightArrow:
            state.moveRight(
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            state.publishSelection(to: selection)
            return .handled
        case .upArrow:
            state.moveVertically(
                by: -1,
                layout: layout,
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            state.publishSelection(to: selection)
            return .handled
        case .downArrow:
            state.moveVertically(
                by: 1,
                layout: layout,
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            state.publishSelection(to: selection)
            return .handled
        case .home:
            state.moveToLineStart(
                layout: layout,
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            state.publishSelection(to: selection)
            return .handled
        case .end:
            state.moveToLineEnd(
                layout: layout,
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            state.publishSelection(to: selection)
            return .handled
        case .delete:
            state.deleteBackward(update: text)
            state.publishSelection(to: selection)
            return .handled
        case .deleteForward:
            state.deleteForward(update: text)
            state.publishSelection(to: selection)
            return .handled
        case .return:
            state.insert("\n", update: text)
            state.publishSelection(to: selection)
            return .handled
        default:
            guard TextEditorInput.isTextInsertion(keyPress) else {
                return .ignored
            }

            state.insert(keyPress.characters, update: text)
            state.publishSelection(to: selection)
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

    private let selection: TextSelectionState

    var offset: Int {
        selection.offset
    }

    var selectedRange: Range<Int>? {
        selection.range
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
        self.invalidate = invalidate
        self.selection = TextSelectionState(offset: initialText.count, invalidate: invalidate)
    }

    func synchronize(with bindingText: String) {
        guard bindingText != lastObservedBindingText else {
            return
        }

        text = bindingText
        lastObservedBindingText = bindingText
        selection.clamp(upperBound: text.count, clearsSelection: true)
    }

    func clamp() {
        selection.clamp(upperBound: text.count)
    }

    func synchronizeSelection(
        with binding: Binding<TextSelection?>?,
        textChanged: Bool
    ) {
        selection.synchronize(with: binding, in: text, force: textChanged)
    }

    func publishSelection(to binding: Binding<TextSelection?>?) {
        selection.publish(to: binding, in: text)
    }

    func publishSelectionOnFocus(
        _ isFocused: Bool,
        to binding: Binding<TextSelection?>?
    ) {
        selection.publishOnFocus(isFocused, to: binding, in: text)
    }

    func updateLayoutWidth(_ width: Int?) {
        layoutWidth = width
    }

    func moveLeft(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        if !selecting, let selectedRange {
            move(to: selectedRange.lowerBound, preservesPreferredColumn: false, selecting: false)
            return
        }

        prepareForSelectionNavigation(
            toward: .backward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        move(to: offset - 1, preservesPreferredColumn: false, selecting: selecting)
    }

    func moveRight(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        if !selecting, let selectedRange {
            move(to: selectedRange.upperBound, preservesPreferredColumn: false, selecting: false)
            return
        }

        prepareForSelectionNavigation(
            toward: .forward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        move(to: offset + 1, preservesPreferredColumn: false, selecting: selecting)
    }

    func moveVertically(
        by delta: Int,
        layout: TextEditorLayout,
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        prepareForSelectionNavigation(
            toward: delta < 0 ? .backward : .forward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        let current = layout.lineAndColumn(at: offset)
        let column = preferredColumn ?? current.column
        preferredColumn = column
        let lineIndex = min(max(current.lineIndex + delta, 0), layout.lines.count - 1)
        move(
            to: layout.offset(onLine: lineIndex, nearestColumn: column),
            preservesPreferredColumn: true,
            selecting: selecting
        )
    }

    func moveToLineStart(
        layout: TextEditorLayout,
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        prepareForSelectionNavigation(
            toward: .backward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        let current = layout.lineAndColumn(at: offset)
        move(
            to: layout.lines[current.lineIndex].lowerOffset,
            preservesPreferredColumn: false,
            selecting: selecting
        )
    }

    func moveToLineEnd(
        layout: TextEditorLayout,
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        prepareForSelectionNavigation(
            toward: .forward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        let current = layout.lineAndColumn(at: offset)
        move(
            to: layout.lines[current.lineIndex].upperOffset,
            preservesPreferredColumn: false,
            selecting: selecting
        )
    }

    func beginSelection(to point: Point, layout: TextEditorLayout) {
        selection.begin(
            at: offset(to: point, layout: layout),
            upperBound: text.count
        )
        preferredColumn = nil
    }

    func extendSelection(to point: Point, layout: TextEditorLayout) {
        selection.extendFromPointer(
            to: offset(to: point, layout: layout),
            upperBound: text.count
        )
        preferredColumn = nil
    }

    private func offset(to point: Point, layout: TextEditorLayout) -> Int {
        let lineIndex = min(max(scrollPoint.y + point.row, 0), layout.lines.count - 1)
        let column = max(scrollPoint.x + point.column, 0)
        return layout.offset(onLine: lineIndex, nearestColumn: column)
    }

    func insert(_ newText: String, update binding: Binding<String>) {
        let replacementRange = selectedRange ?? offset..<offset
        text.replaceCharacters(in: replacementRange, with: newText)
        commit(update: binding)
        selection.collapse(
            to: replacementRange.lowerBound + newText.count,
            upperBound: text.count
        )
        preferredColumn = nil
    }

    func deleteBackward(update binding: Binding<String>) {
        if let selectedRange {
            delete(selectedRange, update: binding)
            return
        }
        guard offset > 0 else {
            return
        }

        delete((offset - 1)..<offset, update: binding)
    }

    func deleteForward(update binding: Binding<String>) {
        if let selectedRange {
            delete(selectedRange, update: binding)
            return
        }
        guard offset < text.count else {
            return
        }

        delete(offset..<(offset + 1), update: binding)
    }

    private func delete(_ range: Range<Int>, update binding: Binding<String>) {
        text.replaceCharacters(in: range, with: "")
        commit(update: binding)
        selection.collapse(to: range.lowerBound, upperBound: text.count)
        preferredColumn = nil
    }

    private func commit(update binding: Binding<String>) {
        binding.wrappedValue = text
        lastObservedBindingText = binding.wrappedValue
    }

    private func prepareForSelectionNavigation(
        toward direction: TextSelectionNavigationDirection,
        selecting: Bool,
        behavior: TextSelectionNavigationBehavior
    ) {
        guard selecting else {
            return
        }

        selection.prepareForSelectionNavigation(
            toward: direction,
            behavior: behavior,
            upperBound: text.count
        )
    }

    func updateScrollPoint(
        for caret: RenderedCaret?,
        viewportWidth: Int?,
        viewportHeight: Int?,
        contentWidth: Int,
        contentHeight: Int
    ) {
        guard let caret else {
            return
        }

        var x = scrollPoint.x
        var y = scrollPoint.y
        if let viewportWidth, viewportWidth > 0 {
            if caret.column < x {
                x = caret.column
            }
            else if caret.column >= x + viewportWidth {
                x = caret.column - viewportWidth + 1
            }
            x = min(max(x, 0), max(contentWidth - viewportWidth, 0))
        }
        else {
            x = 0
        }

        if let viewportHeight, viewportHeight > 0 {
            if caret.row < y {
                y = caret.row
            }
            else if caret.row >= y + viewportHeight {
                y = caret.row - viewportHeight + 1
            }
            y = min(max(y, 0), max(contentHeight - viewportHeight, 0))
        }
        else {
            y = 0
        }

        scrollPoint = ScrollPoint(x: x, y: y)
    }

    private func move(
        to newOffset: Int,
        preservesPreferredColumn: Bool,
        selecting: Bool
    ) {
        selection.move(to: newOffset, upperBound: text.count, selecting: selecting)
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

    func caret(at offset: Int) -> RenderedCaret {
        let current = lineAndColumn(at: offset)
        return RenderedCaret(row: current.lineIndex, column: current.column)
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
