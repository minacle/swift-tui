import Testing

@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("TextField Rendering")
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

    @Test
    func `a TextField stays on one row and rejects horizontal wheel input`() {
        let runtime = StateRuntime()
        let view = FocusedNarrowTextField()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)
        #expect(block?.lines == ["ef "])
        #expect(block?.scrollRegions.isEmpty == true)
        _ = runtime.consumeInvalidation()
        #expect(
            runtime.dispatch(
                PointerScroll(
                    delta: Size(columns: -1, rows: 0),
                    location: Point(column: 0, row: 0)
                )
            ) == .ignored
        )
        #expect(runtime.consumeInvalidation() == false)
    }
}

private struct FocusedNarrowTextField: View {

    @FocusState private var isFocused = true

    var body: some View {
        TextField("Name", text: .constant("abcdef"))
            .focused($isFocused)
            .frame(width: 3)
    }
}
