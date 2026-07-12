import Testing

@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("TextField Placeholder Resolution")
struct TextFieldRenderingTests {

    @Test
    func `an empty TextField prefers its prompt over its title`() {
        let textField = TextField(
            "Name",
            text: .constant(""),
            prompt: Text("Required")
        )

        #expect(ViewResolver.text(from: textField) == "Required")
    }

    @Test
    func `an empty TextField uses its title when no prompt is provided`() {
        let textField = TextField("Name", text: .constant(""))

        #expect(ViewResolver.text(from: textField) == "Name")
    }
}
