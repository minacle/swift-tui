import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Text Field Rendering")
struct TextFieldRenderingTests {

    @Test
    func `an unfocused nonempty text field reserves a trailing caret cell without rendering a caret`() {
        let textField = TextField("Name", text: .constant("mayu"))
        let block = ViewResolver.block(from: textField)

        #expect(block?.text == "mayu ")
        #expect(block?.width == 5)
        #expect(block?.caret == nil)
    }

    @Test
    func `a text field applies inherited text styles to its visible value`() {
        let textField = TextField("Name", text: .constant("mayu"))
            .foregroundStyle(.brightGreen)
            .bold()
            .dim()
            .italic()
            .underline()
            .strikethrough()

        #expect(ViewResolver.block(from: textField)?.runs == [
            RenderedRun(
                text: "mayu",
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
    func `an empty text field prefers its prompt over its title`() {
        let textField = TextField(
            "Name",
            text: .constant(""),
            prompt: Text("Required")
        )

        #expect(ViewResolver.text(from: textField) == "Required")
    }

    @Test
    func `a text field prompt inherits text styles and adds dimming`() {
        let textField = TextField(
            "Name",
            text: .constant(""),
            prompt: Text("Required")
        )
        .foregroundStyle(.brightGreen)
        .bold()

        #expect(ViewResolver.block(from: textField)?.runs == [
            RenderedRun(
                text: "Required",
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.brightGreen),
                    isBold: true,
                    isDim: true
                )
            ),
        ])
    }

    @Test
    func `an empty text field falls back to its title when no prompt is provided`() {
        let textField = TextField("Name", text: .constant(""))

        #expect(ViewResolver.text(from: textField) == "Name")
    }

    @Test
    func `a text field's fallback title is dimmed when its value is empty`() {
        let textField = TextField("Name", text: .constant(""))

        #expect(ViewResolver.block(from: textField)?.runs == [
            RenderedRun(
                text: "Name",
                style: TextStyle(isDim: true)
            ),
        ])
    }

    @Test
    func `a text field renders its bound value with a trailing caret cell`() {
        var value = "mayu"
        let textField = TextField(
            "Name",
            text: Binding(
                get: {
                    value
                },
                set: { newValue in
                    value = newValue
                }
            )
        )

        #expect(ViewResolver.text(from: textField) == "mayu ")
    }
}
