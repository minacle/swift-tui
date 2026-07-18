import Foundation
import SwiftTUIRuns
import Terminal

extension EditableText {

    func renderedEditableTextBlock(
        in proposal: RenderProposal?,
        placeholder: String?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let alignment = EnvironmentRenderContext.current.multilineTextAlignment
        let bindingText = text.wrappedValue
        let editorState = runtime?.editableTextState(
            at: path,
            initialText: bindingText
        )
        let focusPath = EnvironmentRenderContext.current.focusPath ?? path
        let updatesInteractiveState = !LayoutMeasurementContext.isMeasuring
            && runtime?.isSuppressingInteractiveRenderRegistrations != true
        if updatesInteractiveState {
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
            runtime?.registerFocusable(true, at: focusPath)
        }
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: focusPath,
                matches: {
                    EditableTextInput.matches($0, policy: inputPolicy)
                },
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
            at: path
        )
        let pointerAttachmentIDs = runtime?.registerPointerDownPositionHandler(
            PointerDownPositionHandler(
                actionPath: focusPath,
                requiresFocus: true,
                shouldDeferBegin: { point in
                    guard let editorState else {
                        return false
                    }

                    let layout = EditableTextLayout(
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

                    let layout = EditableTextLayout(
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

                    let layout = EditableTextLayout(
                        text: displayedText(for: editorState.text),
                        maxWidth: editorState.layoutWidth,
                        alignment: alignment
                    )
                    editorState.extendSelection(to: point, layout: layout)
                    editorState.publishSelection(to: selection)
                }
            ),
            at: path,
            requiringFocusAt: focusPath
        ) ?? []

        let editableText = editorState.map {
            updatesInteractiveState
                ? $0.text
                : $0.textForMeasurement(bindingText: bindingText)
        } ?? bindingText
        let displayedEditableText = displayedText(for: editableText)
        let displaysPlaceholder = editableText.isEmpty && placeholder != nil
        let renderedText = displaysPlaceholder ? placeholder ?? "" : displayedEditableText
        let renderedLayout = EditableTextLayout(
            text: renderedText,
            maxWidth: proposal?.columns,
            alignment: alignment
        )
        let editingLayout = EditableTextLayout(
            text: displayedEditableText,
            maxWidth: proposal?.columns,
            alignment: alignment
        )
        let caret = renderedCaret(
            state: editorState,
            layout: editingLayout,
            runtime: runtime,
            path: focusPath
        )
        if updatesInteractiveState {
            editorState?.publishSelectionOnFocus(
                runtime?.isFocused(at: focusPath) == true,
                to: selection
            )
        }

        let environment = EnvironmentRenderContext.current
        let visibleCaret = editorState?.selectedRange == nil ? caret : nil
        let textInputEndpoint = editingLayout.caret(
            at: editorState?.offset ?? editableText.count
        )
        var placeholderStyle = environment.textStyle
        placeholderStyle.isDim = true
        let intrinsicCaret = editingLayout.caret(at: editableText.count)
        let contentWidth = max(
            renderedLayout.renderedWidth,
            editingLayout.renderedWidth,
            proposal?.columns == nil ? intrinsicCaret.column + 1 : 0
        )
        var block = RenderedBlock(
            runs: renderedLayout.lines.enumerated().flatMap { row, line in
                TextSelectionRenderer.runs(
                    text: line.text,
                    row: row,
                    baseOffset: line.lowerOffset,
                    style: displaysPlaceholder ? placeholderStyle : environment.textStyle,
                    selection: displaysPlaceholder ? nil : editorState?.selectedRange,
                    tint: environment.tint,
                    foregroundStyle: environment.textSelectionForegroundStyle
                )
                .map {
                    $0.offsetBy(
                        x: renderedLayout.horizontalOffset(onLine: row),
                        y: 0
                    )
                }
            },
            width: contentWidth,
            height: max(renderedLayout.height, editingLayout.height),
            paddedRows: Set(0..<max(renderedLayout.height, editingLayout.height)),
            caret: visibleCaret,
            textInputAnchor: RenderedTextInputAnchor(
                focusPath: focusPath,
                generation: editorState?.textInputGeneration ?? 0,
                isFocused: runtime?.isFocused(at: focusPath) == true,
                row: textInputEndpoint.row,
                column: textInputEndpoint.column
            )
        )
        if !pointerAttachmentIDs.isEmpty {
            block.hitRegions.append(
                RenderedHitRegion(
                    path: path,
                    frame: block.bounds,
                    positionFrame: block.bounds,
                    recognitionAttachmentIDs: pointerAttachmentIDs
                )
            )
        }
        block.focusRegions.append(
            RenderedFocusRegion(
                path: focusPath,
                frame: block.bounds,
                positionFrame: block.bounds
            )
        )
        return block
    }

    private func renderedCaret(
        state: EditableTextState?,
        layout: EditableTextLayout,
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
        state: EditableTextState?,
        displayedText: String
    ) -> InputEventResult {
        guard let state else {
            return .ignored
        }

        let layout = EditableTextLayout(
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
            let moved = state.moveVertically(
                by: -1,
                layout: layout,
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            if moved {
                state.publishSelection(to: selection)
            }
            return moved ? .handled : .ignored
        case .downArrow:
            let moved = state.moveVertically(
                by: 1,
                layout: layout,
                selecting: selecting,
                navigationBehavior: navigationBehavior
            )
            if moved {
                state.publishSelection(to: selection)
            }
            return moved ? .handled : .ignored
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
            guard EditableTextInput.isTextInsertion(keyPress) else {
                return .ignored
            }

            state.insert(keyPress.characters, update: text)
            state.publishSelection(to: selection)
            return .handled
        }
    }
}

final class EditableTextState {

    private struct AnchorSnapshot: Equatable {

        let text: String

        let offset: Int

        let selectedRange: Range<Int>?
    }

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

    /// Changes only when editing or selection movement changes the input anchor.
    private(set) var textInputGeneration: UInt64 = 0

    init(initialText: String, invalidate: @escaping () -> Void) {
        self.text = initialText
        self.lastObservedBindingText = initialText
        self.invalidate = invalidate
        self.selection = TextSelectionState(offset: initialText.count, invalidate: invalidate)
    }

    @discardableResult
    func synchronize(with bindingText: String) -> Bool {
        guard bindingText != lastObservedBindingText else {
            return false
        }

        let snapshot = anchorSnapshot
        text = bindingText
        lastObservedBindingText = bindingText
        selection.clamp(upperBound: text.count, clearsSelection: true)
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func clamp() -> Bool {
        let snapshot = anchorSnapshot
        selection.clamp(upperBound: text.count)
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func synchronizeSelection(
        with binding: Binding<TextSelection?>?,
        textChanged: Bool
    ) -> Bool {
        let snapshot = anchorSnapshot
        selection.synchronize(with: binding, in: text, force: textChanged)
        return completeAnchorMutation(from: snapshot)
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

    /// Returns text for a side-effect-free measurement render.
    ///
    /// A newly observed binding value must determine natural layout before the
    /// subsequent interactive render synchronizes state. When the binding still
    /// equals the last committed value, retained internal text wins so a binding
    /// that rejected an edit does not make measurement roll that edit back.
    func textForMeasurement(bindingText: String) -> String {
        bindingText == lastObservedBindingText ? text : bindingText
    }

    @discardableResult
    func moveLeft(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) -> Bool {
        let snapshot = anchorSnapshot
        if !selecting, let selectedRange {
            moveSelection(
                to: selectedRange.lowerBound,
                preservesPreferredColumn: false,
                selecting: false
            )
            return completeAnchorMutation(from: snapshot)
        }

        prepareForSelectionNavigation(
            toward: .backward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        moveSelection(
            to: offset - 1,
            preservesPreferredColumn: false,
            selecting: selecting
        )
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func moveRight(
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) -> Bool {
        let snapshot = anchorSnapshot
        if !selecting, let selectedRange {
            moveSelection(
                to: selectedRange.upperBound,
                preservesPreferredColumn: false,
                selecting: false
            )
            return completeAnchorMutation(from: snapshot)
        }

        prepareForSelectionNavigation(
            toward: .forward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        moveSelection(
            to: offset + 1,
            preservesPreferredColumn: false,
            selecting: selecting
        )
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func moveVertically(
        by delta: Int,
        layout: EditableTextLayout,
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) -> Bool {
        let snapshot = anchorSnapshot
        prepareForSelectionNavigation(
            toward: delta < 0 ? .backward : .forward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        let current = layout.lineAndColumn(at: offset)
        let column = preferredColumn ?? current.column
        preferredColumn = column
        let lineIndex = min(max(current.lineIndex + delta, 0), layout.lines.count - 1)
        moveSelection(
            to: layout.offset(onLine: lineIndex, nearestColumn: column),
            preservesPreferredColumn: true,
            selecting: selecting
        )
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func moveToLineStart(
        layout: EditableTextLayout,
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) -> Bool {
        let snapshot = anchorSnapshot
        prepareForSelectionNavigation(
            toward: .backward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        let current = layout.lineAndColumn(at: offset)
        moveSelection(
            to: layout.lines[current.lineIndex].lowerOffset,
            preservesPreferredColumn: false,
            selecting: selecting
        )
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func moveToLineEnd(
        layout: EditableTextLayout,
        selecting: Bool = false,
        navigationBehavior: TextSelectionNavigationBehavior = .dragEndpoint
    ) -> Bool {
        let snapshot = anchorSnapshot
        prepareForSelectionNavigation(
            toward: .forward,
            selecting: selecting,
            behavior: navigationBehavior
        )
        let current = layout.lineAndColumn(at: offset)
        moveSelection(
            to: layout.lines[current.lineIndex].upperOffset,
            preservesPreferredColumn: false,
            selecting: selecting
        )
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func beginSelection(to point: Point, layout: EditableTextLayout) -> Bool {
        let snapshot = anchorSnapshot
        selection.begin(
            at: offset(to: point, layout: layout),
            upperBound: text.count
        )
        preferredColumn = nil
        return completeAnchorMutation(from: snapshot)
    }

    func selectionContains(_ point: Point, layout: EditableTextLayout) -> Bool {
        selectedRange?.contains(offset(to: point, layout: layout)) == true
    }

    @discardableResult
    func extendSelection(to point: Point, layout: EditableTextLayout) -> Bool {
        let snapshot = anchorSnapshot
        selection.extendFromPointer(
            to: offset(to: point, layout: layout),
            upperBound: text.count
        )
        preferredColumn = nil
        return completeAnchorMutation(from: snapshot)
    }

    private func offset(to point: Point, layout: EditableTextLayout) -> Int {
        let lineIndex = min(max(point.row, 0), layout.lines.count - 1)
        let column = max(point.column, 0)
        return layout.offset(onLine: lineIndex, nearestRenderedColumn: column)
    }

    @discardableResult
    func insert(_ newText: String, update binding: Binding<String>) -> Bool {
        let snapshot = anchorSnapshot
        let replacementRange = selectedRange ?? offset..<offset
        text.replaceCharacters(in: replacementRange, with: newText)
        commit(update: binding)
        selection.collapse(
            to: replacementRange.lowerBound + newText.count,
            upperBound: text.count
        )
        preferredColumn = nil
        return completeAnchorMutation(from: snapshot)
    }

    @discardableResult
    func deleteBackward(update binding: Binding<String>) -> Bool {
        if let selectedRange {
            return delete(selectedRange, update: binding)
        }
        guard offset > 0 else {
            return false
        }

        return delete((offset - 1)..<offset, update: binding)
    }

    @discardableResult
    func deleteForward(update binding: Binding<String>) -> Bool {
        if let selectedRange {
            return delete(selectedRange, update: binding)
        }
        guard offset < text.count else {
            return false
        }

        return delete(offset..<(offset + 1), update: binding)
    }

    private func delete(_ range: Range<Int>, update binding: Binding<String>) -> Bool {
        let snapshot = anchorSnapshot
        text.replaceCharacters(in: range, with: "")
        commit(update: binding)
        selection.collapse(to: range.lowerBound, upperBound: text.count)
        preferredColumn = nil
        return completeAnchorMutation(from: snapshot)
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

    private var anchorSnapshot: AnchorSnapshot {
        AnchorSnapshot(
            text: text,
            offset: offset,
            selectedRange: selectedRange
        )
    }

    private func completeAnchorMutation(from snapshot: AnchorSnapshot) -> Bool {
        guard snapshot != anchorSnapshot else {
            return false
        }

        textInputGeneration &+= 1
        return true
    }

    private func moveSelection(
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

struct EditableTextLayout {

    let lines: [EditableTextLine]

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
        self.lines = EditableTextLayout.lines(
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
    ) -> [EditableTextLine] {
        var lines = runLayout.lines.map { line in
            EditableTextLine(
                text: line.runs.map(\.content).joined(),
                lowerOffset: line.sourceRange.lowerBound.characterOffset,
                upperOffset: line.sourceRange.upperBound.characterOffset
            )
        }
        if lines.isEmpty {
            lines = [EditableTextLine(text: "", lowerOffset: 0, upperOffset: 0)]
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
            EditableTextLine(
                text: "",
                lowerOffset: lastLine.upperOffset,
                upperOffset: lastLine.upperOffset
            )
        )
        return lines
    }
}

struct EditableTextLine {

    let text: String

    let lowerOffset: Int

    let upperOffset: Int
}

private enum EditableTextInput {

    static func matches(
        _ keyPress: KeyPress,
        policy: EditableText.InputPolicy
    ) -> Bool {
        guard keyPress.phase.contains(.down) || keyPress.phase.contains(.repeat) else {
            return false
        }

        return keyPress.key == .delete
            || keyPress.key == .deleteForward
            || (keyPress.key == .downArrow && policy.allowsVerticalNavigation)
            || keyPress.key == .end
            || keyPress.key == .home
            || keyPress.key == .leftArrow
            || (keyPress.key == .return && policy.allowsNewlineInsertion)
            || keyPress.key == .rightArrow
            || (keyPress.key == .upArrow && policy.allowsVerticalNavigation)
            || isTextInsertion(keyPress)
    }

    static func isTextInsertion(_ keyPress: KeyPress) -> Bool {
        keyPress.isTextInsertion
    }
}
