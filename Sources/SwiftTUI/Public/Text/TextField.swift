import Foundation

/// A control that displays editable single-line text in the terminal.
///
/// `TextField` binds its editable string to a source of truth, renders one
/// terminal row, scrolls horizontally when the text is wider than the proposed
/// width, and shows a cursor while focused.
public nonisolated struct TextField<Label: View>: View, TextFieldRenderable, LayoutTraitRenderable {

    /// The body type for this primitive view.
    public typealias Body = Never

    let text: Binding<String>

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
}

/// A control that displays editable single-line secure text in the terminal.
///
/// `SecureField` binds its editable string to a source of truth, renders one
/// terminal row, scrolls horizontally when the masked text is wider than the
/// proposed width, and shows a cursor while focused. Non-empty input is masked
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
            fieldState?.synchronize(with: text.wrappedValue)
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
                action: { point in
                    guard let fieldState else {
                        return
                    }

                    fieldState.move(
                        toColumn: point.column,
                        layoutText: displayMode.layoutText(for: fieldState.text)
                    )
                }
            ),
            at: path
        )

        let currentText = fieldState?.text ?? text.wrappedValue
        let layoutText = displayMode.layoutText(for: currentText)
        let isFocused = runtime?.isFocused(at: path) == true
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
        let cursor = renderedCursor(
            state: fieldState,
            isFocused: isFocused,
            layoutText: layoutText
        )
        let displayTextWidth = TerminalText.columnWidth(displayText.content)
        let reservesTrailingCaretCell = !currentText.isEmpty
        let contentWidth = max(
            reservesTrailingCaretCell ? displayTextWidth + 1 : displayTextWidth,
            1
        )
        let content = RenderedBlock(
            runs: [
                RenderedRun(
                    text: displayText.content,
                    style: textStyle(isPlaceholder: displayText.isPlaceholder)
                ),
            ],
            width: contentWidth,
            height: 1,
            cursor: cursor
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

    private static func renderedCursor(
        state: TextFieldState?,
        isFocused: Bool,
        layoutText: String
    ) -> RenderedCursor? {
        guard isFocused, let state else {
            return nil
        }

        return RenderedCursor(
            column: TerminalText.columnWidth(
                layoutText,
                upToCharacterOffset: state.offset
            )
        )
    }

    private static func handle(
        _ keyPress: KeyPress,
        text: Binding<String>,
        state: TextFieldState?,
        submitAction: SubmitAction?
    ) -> KeyPress.Result {
        guard let state else {
            return .ignored
        }

        switch keyPress.key {
        case .leftArrow:
            state.moveLeft()
            return .handled
        case .rightArrow:
            state.moveRight()
            return .handled
        case .home:
            state.move(to: 0)
            return .handled
        case .end:
            state.move(to: state.text.count)
            return .handled
        case .delete:
            state.deleteBackward(update: text)
            return .handled
        case .deleteForward:
            state.deleteForward(update: text)
            return .handled
        case .return:
            submitAction?.action()
            return .handled
        default:
            guard TextFieldInput.isTextInsertion(keyPress) else {
                return .ignored
            }

            state.insert(keyPress.characters, update: text)
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

    private(set) var offset = 0 {
        didSet {
            if offset != oldValue {
                invalidate()
            }
        }
    }

    private(set) var horizontalScrollOffset = 0

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
    }

    func clamp() {
        move(to: offset)
        horizontalScrollOffset = min(horizontalScrollOffset, offset)
    }

    func moveLeft() {
        offset = max(offset - 1, 0)
    }

    func moveRight() {
        move(to: offset + 1)
    }

    func move(to offset: Int) {
        self.offset = min(max(offset, 0), text.count)
    }

    func move(toColumn column: Int, layoutText: String) {
        let scrollColumn = TerminalText.columnWidth(
            layoutText,
            upToCharacterOffset: horizontalScrollOffset
        )
        move(to: Self.offset(in: layoutText, nearestColumn: scrollColumn + column))
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
        text.insert(newText, atCharacterOffset: offset)
        binding.wrappedValue = text
        lastObservedBindingText = binding.wrappedValue
        offset += newText.count
    }

    func deleteBackward(update binding: Binding<String>) {
        guard offset > 0 else {
            return
        }

        text.removeCharacter(atOffset: offset - 1)
        binding.wrappedValue = text
        lastObservedBindingText = binding.wrappedValue
        offset -= 1
    }

    func deleteForward(update binding: Binding<String>) {
        guard offset < text.count else {
            return
        }

        text.removeCharacter(atOffset: offset)
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
