import Foundation
import SwiftTUIRuns

nonisolated struct EditableTextSingleLineLayout {

    let content: String

    let runLayout: RunLayout

    init(_ content: String) {
        self.content = content
        self.runLayout = RunGroup(content).layout()
    }

    var columns: Int {
        runLayout.totalColumns
    }

    func column(atCharacterOffset offset: Int) -> Int {
        columns(in: 0..<offset)
    }

    func columns(in range: Range<Int>) -> Int {
        let lowerBound = min(max(range.lowerBound, 0), content.count)
        let upperBound = min(max(range.upperBound, lowerBound), content.count)
        return runLayout.columns(
            in: RunIndex(characterOffset: lowerBound)
                ..< RunIndex(characterOffset: upperBound)
        )
    }

    func offset(nearestColumn column: Int) -> Int {
        let targetColumn = max(column, 0)
        var precedingColumns = 0
        for (row, line) in runLayout.lines.enumerated() {
            let lineEndColumn = precedingColumns + line.columns
            if targetColumn < lineEndColumn {
                return runLayout.index(
                    at: Point(column: targetColumn - precedingColumns, row: row)
                ).characterOffset
            }
            precedingColumns = lineEndColumn
        }
        return content.count
    }
}

enum EditableTextSingleLineRenderer {

    static func renderedBlock<Label: View>(
        text: Binding<String>,
        selection: Binding<TextSelection?>?,
        prompt: Text?,
        label: Label,
        displayMode: EditableTextDisplayMode,
        proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let fieldState = runtime?.editableTextSingleLineState(
            at: path,
            initialText: text.wrappedValue
        )
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        let updatesInteractiveState = !LayoutMeasurementContext.isMeasuring
            && runtime?.isSuppressingInteractiveRenderRegistrations != true
        if updatesInteractiveState {
            let bindingText = text.wrappedValue
            let textChanged = fieldState?.text != bindingText
            fieldState?.synchronize(with: bindingText)
            fieldState?.synchronizeSelection(
                with: selection,
                textChanged: textChanged
            )
            fieldState?.clamp()
        }
        if EnvironmentRenderContext.current.focusPath == nil {
            runtime?.registerFocusable(true, at: interactionPath)
        }
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: interactionPath,
                matches: {
                    EditableTextSingleLineInput.matches($0)
                },
                action: {
                    handle(
                        $0,
                        text: text,
                        selection: selection,
                        state: fieldState
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
                    guard let fieldState else {
                        return false
                    }

                    return fieldState.selectionContains(
                        column: point.column,
                        layoutText: displayMode.layoutText(for: fieldState.text)
                    )
                },
                began: { point in
                    guard let fieldState else {
                        return
                    }

                    fieldState.beginSelection(
                        toColumn: point.column,
                        layoutText: displayMode.layoutText(for: fieldState.text)
                    )
                    fieldState.publishSelection(to: selection)
                },
                changed: { point in
                    guard let fieldState else {
                        return
                    }

                    fieldState.extendSelection(
                        toColumn: point.column,
                        layoutText: displayMode.layoutText(for: fieldState.text)
                    )
                    fieldState.publishSelection(to: selection)
                }
            ),
            at: interactionPath
        )

        let currentText = fieldState?.text ?? text.wrappedValue
        let layoutText = displayMode.layoutText(for: currentText)
        let singleLineLayout = EditableTextSingleLineLayout(layoutText)
        let isFocused = runtime?.isFocused(at: interactionPath) == true
        if updatesInteractiveState {
            fieldState?.publishSelectionOnFocus(isFocused, to: selection)
        }
        if updatesInteractiveState, let maxWidth = proposal?.columns {
            fieldState?.updateHorizontalScrollOffset(
                maxWidth: maxWidth,
                layout: singleLineLayout
            )
        }
        let horizontalScrollOffset = proposal?.columns == nil
            ? 0
            : fieldState?.horizontalScrollOffset ?? 0
        let scrollColumn = singleLineLayout.column(
            atCharacterOffset: horizontalScrollOffset
        )
        var labelEnvironment = EnvironmentRenderContext.current
        labelEnvironment.isFocused = isFocused
        let displayText = EnvironmentRenderContext.withValues(labelEnvironment) {
            Self.displayText(
                using: currentText,
                layoutText: layoutText,
                prompt: prompt,
                label: label
            )
        }
        let caret: RenderedCaret? = fieldState?.selectedRange == nil
            ? renderedCaret(
                state: fieldState,
                isFocused: isFocused,
                layout: singleLineLayout
            )
            : nil
        let displayTextWidth = RunGroup(displayText.content).measure().maximumContentColumns
        let reservesTrailingCaretCell = !currentText.isEmpty
        let contentWidth = max(
            reservesTrailingCaretCell ? displayTextWidth + 1 : displayTextWidth,
            1
        )
        let environment = EnvironmentRenderContext.current
        let content = RenderedBlock(
            runs: TextSelectionRenderer.runs(
                text: displayText.content,
                style: textStyle(isPlaceholder: displayText.isPlaceholder),
                selection: displayText.isPlaceholder ? nil : fieldState?.selectedRange,
                tint: environment.tint,
                foregroundStyle: environment.textSelectionForegroundStyle
            ),
            width: contentWidth,
            height: 1,
            caret: caret
        )

        var block = ScrollViewRenderer.render(
            content,
            axes: .horizontal,
            position: ScrollPosition(x: scrollColumn),
            proposal: RenderProposal(columns: proposal?.columns, rows: 1)
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

    private static func displayText<Label: View>(
        using text: String,
        layoutText: String,
        prompt: Text?,
        label: Label
    ) -> DisplayText {
        if !text.isEmpty {
            return DisplayText(content: layoutText, isPlaceholder: false)
        }
        if let prompt {
            return DisplayText(content: prompt.content, isPlaceholder: true)
        }

        return DisplayText(
            content: ViewResolver.text(from: label) ?? "",
            isPlaceholder: true
        )
    }

    private static func textStyle(isPlaceholder: Bool) -> TextStyle {
        var style = EnvironmentRenderContext.current.textStyle
        if isPlaceholder {
            style.isDim = true
        }
        return style
    }

    private static func renderedCaret(
        state: EditableTextSingleLineState?,
        isFocused: Bool,
        layout: EditableTextSingleLineLayout
    ) -> RenderedCaret? {
        guard isFocused, let state else {
            return nil
        }

        return RenderedCaret(
            column: layout.column(atCharacterOffset: state.offset)
        )
    }

    private static func handle(
        _ keyPress: KeyPress,
        text: Binding<String>,
        selection: Binding<TextSelection?>?,
        state: EditableTextSingleLineState?
    ) -> InputEventResult {
        guard let state else {
            return .ignored
        }

        let navigationBehavior =
            EnvironmentRenderContext.current.textSelectionNavigationBehavior
        let selecting = keyPress.modifiers.contains(.shift)
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
        case .home:
            state.moveToStart(
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            state.publishSelection(to: selection)
            return .handled
        case .end:
            state.moveToEnd(
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
            return .ignored
        default:
            guard EditableTextSingleLineInput.isTextInsertion(keyPress) else {
                return .ignored
            }

            state.insert(keyPress.characters, update: text)
            state.publishSelection(to: selection)
            return .handled
        }
    }
}

private struct DisplayText {

    let content: String

    let isPlaceholder: Bool
}

enum EditableTextDisplayMode {

    case plain

    case masked(Character)

    func layoutText(for text: String) -> String {
        switch self {
        case .plain:
            return text
        case .masked(let character):
            return String(repeating: String(character), count: text.count)
        }
    }
}

final class EditableTextSingleLineState {

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

    private(set) var horizontalScrollOffset = 0

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
        horizontalScrollOffset = min(horizontalScrollOffset, offset)
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

    func moveLeft(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        if !selecting, let selectedRange {
            selection.collapse(to: selectedRange.lowerBound, upperBound: text.count)
            return
        }

        if selecting {
            selection.prepareForSelectionNavigation(
                toward: .backward,
                behavior: navigationBehavior,
                upperBound: text.count
            )
        }
        selection.move(to: offset - 1, upperBound: text.count, selecting: selecting)
    }

    func moveRight(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        if !selecting, let selectedRange {
            selection.collapse(to: selectedRange.upperBound, upperBound: text.count)
            return
        }

        if selecting {
            selection.prepareForSelectionNavigation(
                toward: .forward,
                behavior: navigationBehavior,
                upperBound: text.count
            )
        }
        selection.move(to: offset + 1, upperBound: text.count, selecting: selecting)
    }

    func moveToStart(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        if selecting {
            selection.prepareForSelectionNavigation(
                toward: .backward,
                behavior: navigationBehavior,
                upperBound: text.count
            )
        }
        selection.move(to: 0, upperBound: text.count, selecting: selecting)
    }

    func moveToEnd(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) {
        if selecting {
            selection.prepareForSelectionNavigation(
                toward: .forward,
                behavior: navigationBehavior,
                upperBound: text.count
            )
        }
        selection.move(to: text.count, upperBound: text.count, selecting: selecting)
    }

    func beginSelection(toColumn column: Int, layoutText: String) {
        selection.begin(
            at: offset(toColumn: column, layoutText: layoutText),
            upperBound: text.count
        )
    }

    func selectionContains(column: Int, layoutText: String) -> Bool {
        selectedRange?.contains(
            offset(toColumn: column, layoutText: layoutText)
        ) == true
    }

    func extendSelection(toColumn column: Int, layoutText: String) {
        selection.extendFromPointer(
            to: offset(toColumn: column, layoutText: layoutText),
            upperBound: text.count
        )
    }

    private func offset(toColumn column: Int, layoutText: String) -> Int {
        let layout = EditableTextSingleLineLayout(layoutText)
        let scrollColumn = layout.column(atCharacterOffset: horizontalScrollOffset)
        return layout.offset(nearestColumn: scrollColumn + column)
    }

    func updateHorizontalScrollOffset(
        maxWidth: Int,
        layout: EditableTextSingleLineLayout
    ) {
        guard maxWidth > 0 else {
            horizontalScrollOffset = 0
            return
        }

        let textWidth = layout.columns
        // Exact-fit text may still need to scroll to expose its trailing caret cell.
        if textWidth < maxWidth {
            horizontalScrollOffset = 0
            return
        }

        let visibleTextWidth = offset == text.count && !text.isEmpty
            ? maxWidth - 1
            : maxWidth
        if offset < horizontalScrollOffset {
            horizontalScrollOffset = offset
            return
        }

        let visibleUpperOffset = offset < text.count ? offset + 1 : offset
        if layout.columns(
            in: horizontalScrollOffset..<visibleUpperOffset
        ) <= visibleTextWidth {
            return
        }

        var newOffset = offset
        while newOffset > 0 {
            let previousOffset = newOffset - 1
            let width = layout.columns(
                in: previousOffset..<visibleUpperOffset
            )
            guard width <= visibleTextWidth else {
                break
            }

            newOffset = previousOffset
        }

        horizontalScrollOffset = newOffset
    }

    func insert(_ newText: String, update binding: Binding<String>) {
        let replacementRange = selectedRange ?? offset..<offset
        text.replaceCharacters(in: replacementRange, with: newText)
        commit(update: binding)
        selection.collapse(
            to: replacementRange.lowerBound + newText.count,
            upperBound: text.count
        )
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
    }

    private func commit(update binding: Binding<String>) {
        binding.wrappedValue = text
        lastObservedBindingText = binding.wrappedValue
    }

    private static func offset(in text: String, nearestColumn column: Int) -> Int {
        EditableTextSingleLineLayout(text).offset(nearestColumn: column)
    }
}

private enum EditableTextSingleLineInput {

    static func matches(_ keyPress: KeyPress) -> Bool {
        guard keyPress.phase.contains(.down) || keyPress.phase.contains(.repeat) else {
            return false
        }

        return keyPress.key == .delete
            || keyPress.key == .deleteForward
            || keyPress.key == .end
            || keyPress.key == .home
            || keyPress.key == .leftArrow
            || keyPress.key == .return
            || keyPress.key == .rightArrow
            || isTextInsertion(keyPress)
    }

    static func isTextInsertion(_ keyPress: KeyPress) -> Bool {
        keyPress.isTextInsertion
    }
}
