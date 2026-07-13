import Foundation
import SwiftTUIRuns
import Terminal

extension EditableText {

    func renderedMultilineBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let alignment = EnvironmentRenderContext.current.multilineTextAlignment
        let editorState = runtime?.editableTextMultilineState(
            at: path,
            initialText: text.wrappedValue
        )
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
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
        if EnvironmentRenderContext.current.focusPath == nil {
            runtime?.registerFocusable(true, at: interactionPath)
        }
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: interactionPath,
                matches: EditableTextMultilineInput.matches,
                action: {
                    handle(
                        $0,
                        text: text,
                        selection: selection,
                        state: editorState,
                        displayedText: displayedText(for: editorState?.text ?? text.wrappedValue)
                    )
                }
            ),
            at: interactionPath
        )
        runtime?.registerPointerDownPositionHandler(
            PointerDownPositionHandler(
                actionPath: interactionPath,
                requiresFocus: true,
                shouldDeferBegin: { point in
                    guard let editorState else {
                        return false
                    }

                    let layout = EditableTextMultilineLayout(
                        text: displayedText(for: editorState.text),
                        maxWidth: editorState.layoutWidth,
                        alignment: alignment
                    )
                    return editorState.selectionContains(point, layout: layout)
                },
                began: { point in
                    guard let editorState else {
                        return
                    }

                    let layout = EditableTextMultilineLayout(
                        text: displayedText(for: editorState.text),
                        maxWidth: editorState.layoutWidth,
                        alignment: alignment
                    )
                    editorState.beginSelection(to: point, layout: layout)
                    editorState.publishSelection(to: selection)
                },
                changed: { point in
                    guard let editorState else {
                        return
                    }

                    let layout = EditableTextMultilineLayout(
                        text: displayedText(for: editorState.text),
                        maxWidth: editorState.layoutWidth,
                        alignment: alignment
                    )
                    editorState.extendSelection(to: point, layout: layout)
                    editorState.publishSelection(to: selection)
                }
            ),
            at: interactionPath
        )

        let currentText = displayedText(for: editorState?.text ?? text.wrappedValue)
        let layout = EditableTextMultilineLayout(
            text: currentText,
            maxWidth: proposal?.columns,
            alignment: alignment
        )
        let caret = renderedCaret(
            state: editorState,
            layout: layout,
            runtime: runtime,
            path: interactionPath
        )
        if updatesInteractiveState {
            editorState?.publishSelectionOnFocus(
                runtime?.isFocused(at: interactionPath) == true,
                to: selection
            )
            editorState?.updateScrollPoint(
                for: caret,
                viewportWidth: proposal?.columns,
                viewportHeight: proposal?.rows,
                contentWidth: layout.renderedWidth,
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
                .map {
                    $0.offsetBy(x: layout.horizontalOffset(onLine: row), y: 0)
                }
            },
            width: layout.renderedWidth,
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
        block.focusRegions.append(
            RenderedFocusRegion(
                path: interactionPath,
                frame: block.bounds,
                positionFrame: block.bounds
            )
        )
        return block
    }

    private func renderedCaret(
        state: EditableTextMultilineState?,
        layout: EditableTextMultilineLayout,
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
        state: EditableTextMultilineState?,
        displayedText: String
    ) -> InputEventResult {
        guard let state else {
            return .ignored
        }

        let layout = EditableTextMultilineLayout(
            text: displayedText,
            maxWidth: state.layoutWidth,
            alignment: EnvironmentRenderContext.current.multilineTextAlignment
        )
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
            guard EditableTextMultilineInput.isTextInsertion(keyPress) else {
                return .ignored
            }

            state.insert(keyPress.characters, update: text)
            state.publishSelection(to: selection)
            return .handled
        }
    }
}

final class EditableTextMultilineState {

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
        layout: EditableTextMultilineLayout,
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
        layout: EditableTextMultilineLayout,
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
        layout: EditableTextMultilineLayout,
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

    func beginSelection(to point: Point, layout: EditableTextMultilineLayout) {
        selection.begin(
            at: offset(to: point, layout: layout),
            upperBound: text.count
        )
        preferredColumn = nil
    }

    func selectionContains(_ point: Point, layout: EditableTextMultilineLayout) -> Bool {
        selectedRange?.contains(offset(to: point, layout: layout)) == true
    }

    func extendSelection(to point: Point, layout: EditableTextMultilineLayout) {
        selection.extendFromPointer(
            to: offset(to: point, layout: layout),
            upperBound: text.count
        )
        preferredColumn = nil
    }

    private func offset(to point: Point, layout: EditableTextMultilineLayout) -> Int {
        let lineIndex = min(max(scrollPoint.y + point.row, 0), layout.lines.count - 1)
        let column = max(scrollPoint.x + point.column, 0)
        return layout.offset(onLine: lineIndex, nearestRenderedColumn: column)
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

struct EditableTextMultilineLayout {

    let lines: [EditableTextMultilineLine]

    private let runLayout: RunLayout

    let maximumWidth: Int?

    let alignment: TextAlignment

    init(
        text: String,
        maxWidth: Int?,
        alignment: TextAlignment = .leading
    ) {
        let runLayout = RunGroup(text).layout(fittingColumns: maxWidth)
        self.runLayout = runLayout
        self.lines = EditableTextMultilineLayout.lines(
            from: runLayout,
            maxWidth: maxWidth
        )
        self.maximumWidth = maxWidth
        self.alignment = alignment
    }

    var width: Int {
        max(runLayout.size.columns, 1)
    }

    var height: Int {
        max(lines.count, 1)
    }

    var renderedWidth: Int {
        max(width, maximumWidth ?? width)
    }

    func caret(at offset: Int) -> RenderedCaret {
        let current = lineAndColumn(at: offset)
        return RenderedCaret(
            row: current.lineIndex,
            column: horizontalOffset(onLine: current.lineIndex) + current.column
        )
    }

    func lineAndColumn(at offset: Int) -> (lineIndex: Int, column: Int) {
        let offset = max(offset, 0)
        if lines.count > runLayout.lines.count,
           let trailingLine = lines.last,
           offset >= trailingLine.lowerOffset
        {
            return (lines.count - 1, 0)
        }
        let point = runLayout.point(at: RunIndex(characterOffset: offset))
        return (point.row, point.column)
    }

    func offset(onLine lineIndex: Int, nearestColumn column: Int) -> Int {
        if runLayout.lines.indices.contains(lineIndex) {
            return runLayout.index(
                at: Point(column: max(column, 0), row: lineIndex)
            ).characterOffset
        }
        return lines[min(max(lineIndex, 0), lines.count - 1)].lowerOffset
    }

    func offset(onLine lineIndex: Int, nearestRenderedColumn column: Int) -> Int {
        offset(
            onLine: lineIndex,
            nearestColumn: max(column - horizontalOffset(onLine: lineIndex), 0)
        )
    }

    func horizontalOffset(onLine lineIndex: Int) -> Int {
        let clampedLineIndex = min(max(lineIndex, 0), lines.count - 1)
        let lineColumns = runLayout.lines.indices.contains(clampedLineIndex)
            ? runLayout.lines[clampedLineIndex].columns
            : 0
        let padding = max(renderedWidth - lineColumns, 0)
        switch alignment {
        case .leading:
            return 0
        case .center:
            return padding / 2
        case .trailing:
            return padding
        }
    }

    private static func lines(
        from runLayout: RunLayout,
        maxWidth: Int?
    ) -> [EditableTextMultilineLine] {
        var lines = runLayout.lines.map { line in
            EditableTextMultilineLine(
                text: line.runs.map(\.content).joined(),
                lowerOffset: line.sourceRange.lowerBound.characterOffset,
                upperOffset: line.sourceRange.upperBound.characterOffset
            )
        }
        if lines.isEmpty {
            lines = [EditableTextMultilineLine(text: "", lowerOffset: 0, upperOffset: 0)]
        }
        guard let maxWidth,
              maxWidth > 0,
              let lastLine = lines.last,
              !lastLine.text.isEmpty,
              runLayout.lines.last?.columns == maxWidth
        else {
            return lines
        }

        lines.append(
            EditableTextMultilineLine(
                text: "",
                lowerOffset: lastLine.upperOffset,
                upperOffset: lastLine.upperOffset
            )
        )
        return lines
    }
}

struct EditableTextMultilineLine {

    let text: String

    let lowerOffset: Int

    let upperOffset: Int
}

private enum EditableTextMultilineInput {

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
