import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("Secure Text Entry")
struct SecureTextEntryTests {

    @Test
    func `a secure field masks its bound value and reserves a trailing caret cell`() {
        let secureField = SecureField("Password", text: .constant("secret"))

        #expect(ViewResolver.text(from: secureField) == "•••••• ")
    }

    @Test
    func `inherited text styles are applied to a secure field's masked value`() {
        let secureField = SecureField("Password", text: .constant("secret"))
            .foregroundStyle(.brightGreen)
            .bold()
            .dim()
            .italic()
            .underline()
            .strikethrough()

        #expect(ViewResolver.block(from: secureField)?.runs == [
            RenderedRun(
                text: "••••••",
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.brightGreen),
                    isBold: true,
                    isDim: true,
                    isItalic: true,
                    isUnderline: true,
                    isStrikethrough: true
                )
            ),
        ])
    }

    @Test
    func `an empty secure field prefers its prompt over its title`() {
        let secureField = SecureField(
            "Password",
            text: .constant(""),
            prompt: Text("Required")
        )

        #expect(ViewResolver.text(from: secureField) == "Required")
    }

    @Test
    func `an empty secure field falls back to its title when no prompt is provided`() {
        let secureField = SecureField("Password", text: .constant(""))

        #expect(ViewResolver.text(from: secureField) == "Password")
    }

    @Test
    func `a secure field's fallback title is dimmed when its value is empty`() {
        let secureField = SecureField("Password", text: .constant(""))

        #expect(ViewResolver.block(from: secureField)?.runs == [
            RenderedRun(
                text: "Password",
                style: TextStyle(isDim: true)
            ),
        ])
    }

    @Test
    func `typing and deletion update a focused secure field without revealing its value`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<String>()
        let view = SecureFieldEditingView(textProbe: probe)

        #expect(runtime.block(from: view)?.text == "Password")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Password")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 0))

        #expect(runtime.dispatch(KeyPress(key: "s", characters: "s")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "e", characters: "e")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(probe.binding?.wrappedValue == "sec")
        #expect(runtime.block(from: view)?.text == "••• ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 3))

        #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "r", characters: "r")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(probe.binding?.wrappedValue == "sec")
        #expect(runtime.block(from: view)?.text == "••• ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 2))
    }

    @Test
    func `clicking masked text positions the secure field's caret for insertion`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<String>()
        let view = SecureFieldEditingView(textProbe: probe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        for character in "secret" {
            #expect(
                runtime.dispatch(
                    KeyPress(key: KeyEquivalent(character), characters: String(character))
                ) == .handled
            )
        }
        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .down)
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        #expect(probe.binding?.wrappedValue == "seXcret")
        #expect(runtime.block(from: view)?.text == "••••••• ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 3))
    }

    @Test
    func `dragging across masked text selects the underlying range for replacement`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<String>()
        let view = SecureFieldEditingView(textProbe: probe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        for character in "secret" {
            #expect(
                runtime.dispatch(
                    KeyPress(key: KeyEquivalent(character), characters: String(character))
                ) == .handled
            )
        }
        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 3, row: 0), modifiers: [])
            ) == .handled
        )
        #expect(runtime.block(from: view)?.runs == [
            RenderedRun(
                text: "•••",
                style: TextStyle(backgroundStyle: AnyColor(Color16.blue))
            ),
            RenderedRun(text: "•••", column: 3),
        ])
        #expect(runtime.block(from: view)?.caret == nil)
        #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
        #expect(runtime.consumeInvalidation())

        #expect(probe.binding?.wrappedValue == "Xret")
        #expect(runtime.block(from: view)?.text == "•••• ")
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `secure field caret placement and scrolling use mask widths instead of source glyph widths`() {
        let runtime = StateRuntime()
        let view = SecureFieldInitialTextView(text: "한ABC")
            .frame(width: 3)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["•• "])
        #expect(block?.caret == RenderedCaret(column: 2))

        #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["•••"])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 0))
    }

    @Test
    func `Return submits the secure field's current value without inserting a newline`() {
        let runtime = StateRuntime()
        let view = SecureFieldSubmitView()

        #expect(runtime.block(from: view)?.lines == ["Password", "  none  "])
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "s", characters: "s")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["• ", "s "])
        #expect(runtime.block(from: view)?.caret == RenderedCaret(column: 1))
    }

    @Test
    func `a flexible secure field claims the remaining HStack width ahead of a spacer`() {
        let stack = HStack(spacing: 0) {
            SecureField("Password", text: .constant(""))
            Spacer()
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 20))

        #expect(block?.width == 20)
        #expect(block?.lines == ["Password            "])
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(x: 0, y: 0, width: 20, height: 1),
        ])
    }
}
