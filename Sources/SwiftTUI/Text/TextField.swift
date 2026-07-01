import Foundation

/// A control that displays editable single-line text in the terminal.
public nonisolated struct TextField<Label: View>: View, TextFieldRenderable, LayoutTraitRenderable {

    public typealias Body = Never

    let text: Binding<String>

    let prompt: Text?

    let label: Label

    var layoutTraits: LayoutTraits {
        LayoutTraits(flexibleAxes: .horizontal)
    }

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
    init(_ title: String, text: Binding<String>) {
        self.init(title, text: text, prompt: nil)
    }

    /// Creates a text field with a text label generated from a title string.
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
        let submitAction = SubmitContext.currentAction
        let fieldState = runtime?.textFieldState(
            at: path,
            initialText: text.wrappedValue
        )
        fieldState?.synchronize(with: text.wrappedValue)
        fieldState?.clamp()
        runtime?.registerFocusable(true, at: path)
        runtime?.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: submitAction?.actionPath ?? path,
                matches: {
                    TextFieldInput.matches($0)
                },
                action: {
                    handle($0, state: fieldState, submitAction: submitAction)
                }
            ),
            at: path
        )

        let text = fieldState?.text ?? text.wrappedValue
        let isFocused = runtime?.isFocused(at: path) == true
        if let maxWidth = proposal?.columns {
            fieldState?.updateHorizontalScrollOffset(maxWidth: maxWidth)
        }
        let horizontalScrollOffset = proposal?.columns == nil
            ? 0
            : fieldState?.horizontalScrollOffset ?? 0
        let scrollColumn = TerminalText.columnWidth(
            text,
            upToCharacterOffset: horizontalScrollOffset
        )
        let displayText = displayText(using: text)
        let content = RenderedBlock(
            runs: [
                RenderedRun(
                    text: displayText,
                    style: EnvironmentRenderContext.current.textStyle
                ),
            ],
            width: max(TerminalText.columnWidth(displayText), 1),
            height: 1,
            cursor: renderedCursor(state: fieldState, isFocused: isFocused)
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

    private func displayText(using text: String) -> String {
        if !text.isEmpty {
            return text
        }
        if let prompt {
            return prompt.content
        }

        return ViewResolver.text(from: label) ?? ""
    }

    private func renderedCursor(
        state: TextFieldState?,
        isFocused: Bool
    ) -> RenderedCursor? {
        guard isFocused, let state else {
            return nil
        }

        return RenderedCursor(
            column: TerminalText.columnWidth(
                state.text,
                upToCharacterOffset: state.offset
            )
        )
    }

    private func handle(
        _ keyPress: KeyPress,
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

    private(set) var horizontalScrollOffset = 0 {
        didSet {
            if horizontalScrollOffset != oldValue {
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

    func updateHorizontalScrollOffset(maxWidth: Int) {
        guard maxWidth > 0 else {
            horizontalScrollOffset = 0
            return
        }

        let visibleTextWidth = offset == text.count && !text.isEmpty
            ? maxWidth - 1
            : maxWidth
        if TerminalText.columnWidth(text) <= visibleTextWidth {
            horizontalScrollOffset = 0
            return
        }

        if offset < horizontalScrollOffset {
            horizontalScrollOffset = offset
            return
        }

        let visibleUpperOffset = offset < text.count ? offset + 1 : offset
        if TerminalText.columnWidth(
            text,
            lowerCharacterOffset: horizontalScrollOffset,
            upperCharacterOffset: visibleUpperOffset
        ) <= visibleTextWidth {
            return
        }

        var newOffset = offset
        while newOffset > 0 {
            let previousOffset = newOffset - 1
            let width = TerminalText.columnWidth(
                text,
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
        guard keyPress.key.isPrintableCharacter else {
            return false
        }

        guard !keyPress.characters.isEmpty,
              keyPress.modifiers.intersection([.control, .option, .command]).isEmpty else {
            return false
        }

        return keyPress.characters.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0)
        }
    }
}

private extension KeyEquivalent {

    var isPrintableCharacter: Bool {
        switch self {
        case .upArrow, .downArrow, .leftArrow, .rightArrow,
                .clear, .delete, .deleteForward, .end, .escape,
                .home, .pageDown, .pageUp, .return, .tab:
            return false
        default:
            return true
        }
    }
}

private extension String {

    mutating func insert(_ insertedText: String, atCharacterOffset offset: Int) {
        insert(
            contentsOf: insertedText,
            at: indexAtCharacterOffset(offset)
        )
    }

    mutating func removeCharacter(atOffset offset: Int) {
        remove(at: indexAtCharacterOffset(offset))
    }

    private func indexAtCharacterOffset(_ offset: Int) -> Index {
        index(startIndex, offsetBy: min(max(offset, 0), count))
    }
}
