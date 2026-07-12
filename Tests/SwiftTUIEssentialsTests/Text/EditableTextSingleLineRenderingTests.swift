import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

@Suite("EditableText Single-Line Rendering")
struct EditableTextSingleLineRenderingTests {

    @Test
    func `an unfocused nonempty single-line EditableText reserves a trailing caret cell without rendering a caret`() {
        let textField = SingleLineEditableText("Name", text: .constant("mayu"))
        let block = ViewResolver.block(from: textField)

        #expect(block?.text == "mayu ")
        #expect(block?.width == 5)
        #expect(block?.caret == nil)
    }

    @Test
    func `a single-line EditableText applies inherited text styles to its visible value`() {
        let textField = SingleLineEditableText("Name", text: .constant("mayu"))
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
    func `a single-line EditableText placeholder inherits text styles and adds dimming`() {
        let editableText = EditableText(text: .constant(""))
            .placeholder {
                Text("Required")
            }
            .foregroundStyle(.brightGreen)
            .bold()

        #expect(ViewResolver.block(from: editableText)?.runs == [
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
    func `a single-line EditableText placeholder is dimmed when its value is empty`() {
        let editableText = EditableText(text: .constant(""))
            .placeholder {
                Text("Name")
            }

        #expect(ViewResolver.block(from: editableText)?.runs == [
            RenderedRun(
                text: "Name",
                style: TextStyle(isDim: true)
            ),
        ])
    }

    @Test
    func `a single-line EditableText renders its bound value with a trailing caret cell`() {
        var value = "mayu"
        let textField = SingleLineEditableText(
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
