import Foundation

/// A control that displays editable single-line text in the terminal.
///
/// `TextField` binds its editable string to a source of truth, renders one
/// terminal row, scrolls horizontally when the text is wider than the proposed
/// width, and shows a caret while focused.
public nonisolated struct TextField<Label: View>: View, TextFieldRenderable, LayoutTraitRenderable {

    /// The body type for this primitive view.
    public typealias Body = Never

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    let prompt: Text?

    let label: Label

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: .horizontal)
    }

    /// Creates a text field with a custom label view.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string.
    ///   - prompt: Placeholder text shown when `text` is empty.
    ///   - label: A view builder that creates the field label. SwiftTUI uses
    ///     the label's text as fallback placeholder text when `prompt` is `nil`.
    public init(
        text: Binding<String>,
        prompt: Text? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.text = text
        self.selection = nil
        self.prompt = prompt
        self.label = label()
    }
}

public extension TextField where Label == Text {

    /// Creates a text field with a text label generated from a title string.
    ///
    /// - Parameters:
    ///   - title: The field label and fallback placeholder text.
    ///   - text: A binding to the editable string.
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a text field with a text label generated from a title string.
    ///
    /// - Parameters:
    ///   - title: The field label.
    ///   - text: A binding to the editable string.
    ///   - prompt: Placeholder text shown when `text` is empty.
    init(_ title: String, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt) {
            Text(title)
        }
    }

    /// Creates a text field with bindings to its text and current selection.
    ///
    /// - Parameters:
    ///   - title: The field label and fallback placeholder text.
    ///   - text: A binding to the editable string.
    ///   - selection: A binding to the current selection.
    ///   - prompt: Placeholder text shown when `text` is empty.
    init(
        _ title: String,
        text: Binding<String>,
        selection: Binding<TextSelection?>,
        prompt: Text? = nil
    ) {
        self.text = text
        self.selection = selection
        self.prompt = prompt
        self.label = Text(title)
    }
}

/// A control that displays editable single-line secure text in the terminal.
///
/// `SecureField` binds its editable string to a source of truth, renders one
/// terminal row, scrolls horizontally when the masked text is wider than the
/// proposed width, and shows a caret while focused. Non-empty input is masked
/// with bullet characters in rendered output.
public nonisolated struct SecureField<Label: View>: View, TextFieldRenderable, LayoutTraitRenderable {

    /// The body type for this primitive view.
    public typealias Body = Never

    let text: Binding<String>

    let prompt: Text?

    let label: Label

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: .horizontal)
    }

    /// Creates a secure field with a custom label view.
    ///
    /// - Parameters:
    ///   - text: A binding to the editable string.
    ///   - prompt: Placeholder text shown when `text` is empty.
    ///   - label: A view builder that creates the field label. SwiftTUI uses
    ///     the label's text as fallback placeholder text when `prompt` is `nil`.
    public init(
        text: Binding<String>,
        prompt: Text? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.text = text
        self.prompt = prompt
        self.label = label()
    }
}

public extension SecureField where Label == Text {

    /// Creates a secure field with a text label generated from a title string.
    ///
    /// - Parameters:
    ///   - title: The field label and fallback placeholder text.
    ///   - text: A binding to the editable string.
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a secure field with a text label generated from a title string.
    ///
    /// - Parameters:
    ///   - title: The field label.
    ///   - text: A binding to the editable string.
    ///   - prompt: Placeholder text shown when `text` is empty.
    init(_ title: String, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt) {
            Text(title)
        }
    }
}

struct SubmitView<Content: View>: View, SubmitModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let action: SubmitAction

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        SubmitContext.withAction(action) {
            ViewResolver.block(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        SubmitContext.withAction(action) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

struct SubmitAction {

    let actionPath: [Int]?

    let action: () -> Void
}

protocol TextFieldRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

protocol SubmitModifierRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement?
}

public extension View {

    /// Performs an action when the user submits a text field within this view.
    ///
    /// The action runs when a focused `TextField` receives Return. If multiple
    /// `onSubmit` modifiers are nested, the innermost submit action visible to
    /// the text field handles the submission.
    ///
    /// - Parameter action: The action to run on submit.
    /// - Returns: A view that supplies the submit action to descendant text fields.
    func onSubmit(_ action: @escaping () -> Void) -> some View {
        SubmitView(
            content: self,
            action: SubmitAction(
                actionPath: StateContext.currentPath,
                action: action
            )
        )
    }
}

extension TextField {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        TextInputRenderer.renderedBlock(
            text: text,
            selection: selection,
            prompt: prompt,
            label: label,
            displayMode: .plain,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

extension SecureField {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        TextInputRenderer.renderedBlock(
            text: text,
            selection: nil,
            prompt: prompt,
            label: label,
            displayMode: .secure,
            proposal: proposal,
            path: path,
            runtime: runtime
        )
    }
}

private enum TextInputRenderer {

    static func renderedBlock<Label: View>(
        text: Binding<String>,
        selection: Binding<TextSelection?>?,
        prompt: Text?,
        label: Label,
        displayMode: TextFieldDisplayMode,
        proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let submitAction = SubmitContext.currentAction
        let fieldState = runtime?.textFieldState(
            at: path,
            initialText: text.wrappedValue
        )
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
        runtime?.registerFocusable(true, at: path)
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: submitAction?.actionPath ?? path,
                matches: {
                    TextFieldInput.matches($0)
                },
                action: {
                    handle(
                        $0,
                        text: text,
                        selection: selection,
                        state: fieldState,
                        submitAction: submitAction
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
            at: path
        )

        let currentText = fieldState?.text ?? text.wrappedValue
        let layoutText = displayMode.layoutText(for: currentText)
        let isFocused = runtime?.isFocused(at: path) == true
        if updatesInteractiveState {
            fieldState?.publishSelectionOnFocus(isFocused, to: selection)
        }
        if updatesInteractiveState, let maxWidth = proposal?.columns {
            fieldState?.updateHorizontalScrollOffset(
                maxWidth: maxWidth,
                layoutText: layoutText
            )
        }
        let horizontalScrollOffset = proposal?.columns == nil
            ? 0
            : fieldState?.horizontalScrollOffset ?? 0
        let scrollColumn = TerminalText.columnWidth(
            layoutText,
            upToCharacterOffset: horizontalScrollOffset
        )
        let displayText = displayText(
            using: currentText,
            layoutText: layoutText,
            prompt: prompt,
            label: label
        )
        let caret: RenderedCaret? = fieldState?.selectedRange == nil
            ? renderedCaret(
                state: fieldState,
                isFocused: isFocused,
                layoutText: layoutText
            )
            : nil
        let displayTextWidth = TerminalText.columnWidth(displayText.content)
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
        block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
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
        state: TextFieldState?,
        isFocused: Bool,
        layoutText: String
    ) -> RenderedCaret? {
        guard isFocused, let state else {
            return nil
        }

        return RenderedCaret(
            column: TerminalText.columnWidth(
                layoutText,
                upToCharacterOffset: state.offset
            )
        )
    }

    private static func handle(
        _ keyPress: KeyPress,
        text: Binding<String>,
        selection: Binding<TextSelection?>?,
        state: TextFieldState?,
        submitAction: SubmitAction?
    ) -> KeyPress.Result {
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
            submitAction?.action()
            return .handled
        default:
            guard TextFieldInput.isTextInsertion(keyPress) else {
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

private enum TextFieldDisplayMode {

    case plain

    case secure

    func layoutText(for text: String) -> String {
        switch self {
        case .plain:
            return text
        case .secure:
            return String(repeating: "•", count: text.count)
        }
    }
}

final class TextFieldState {

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

    func extendSelection(toColumn column: Int, layoutText: String) {
        selection.extendFromPointer(
            to: offset(toColumn: column, layoutText: layoutText),
            upperBound: text.count
        )
    }

    private func offset(toColumn column: Int, layoutText: String) -> Int {
        let scrollColumn = TerminalText.columnWidth(
            layoutText,
            upToCharacterOffset: horizontalScrollOffset
        )
        return Self.offset(in: layoutText, nearestColumn: scrollColumn + column)
    }

    func updateHorizontalScrollOffset(maxWidth: Int, layoutText: String) {
        guard maxWidth > 0 else {
            horizontalScrollOffset = 0
            return
        }

        let textWidth = TerminalText.columnWidth(layoutText)
        if textWidth <= maxWidth {
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
        if TerminalText.columnWidth(
            layoutText,
            lowerCharacterOffset: horizontalScrollOffset,
            upperCharacterOffset: visibleUpperOffset
        ) <= visibleTextWidth {
            return
        }

        var newOffset = offset
        while newOffset > 0 {
            let previousOffset = newOffset - 1
            let width = TerminalText.columnWidth(
                layoutText,
                lowerCharacterOffset: previousOffset,
                upperCharacterOffset: visibleUpperOffset
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
        var currentColumn = 0
        var offset = 0
        for character in text {
            let characterWidth = TerminalText.columnWidth(String(character))
            guard currentColumn + characterWidth <= column else {
                break
            }

            currentColumn += characterWidth
            offset += 1
        }
        return min(offset, text.count)
    }
}

private enum SubmitContext {

    private struct TaskAction: @unchecked Sendable {

        var action: SubmitAction?
    }

    @TaskLocal
    private static var taskAction = TaskAction(action: nil)

    static var currentAction: SubmitAction? {
        taskAction.action
    }

    static func withAction<Value>(
        _ action: SubmitAction,
        perform operation: () -> Value
    ) -> Value {
        $taskAction.withValue(TaskAction(action: action)) {
            return operation()
        }
    }
}

private enum TextFieldInput {

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
