import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("Disclosure Group")
struct DisclosureGroupTests {

    @Test
    func `all four DisclosureGroup initializers render their labels and bound states`() {
        let localTitle = DisclosureGroup("Title") {
            Text("Hidden")
        }
        let localCustom = DisclosureGroup {
            Text("Hidden")
        } label: {
            Text("Custom")
        }
        let boundTitle = DisclosureGroup("Bound", isExpanded: .constant(true)) {
            Text("Visible")
        }
        let boundCustom = DisclosureGroup(isExpanded: .constant(true)) {
            Text("Shown")
        } label: {
            Text("Label")
        }

        #expect(ViewResolver.block(from: localTitle)?.lines == ["▶ Title "])
        #expect(ViewResolver.block(from: localCustom)?.lines == ["▶ Custom "])
        #expect(ViewResolver.block(from: boundTitle)?.lines == ["▼ Bound ", "Visible "])
        #expect(ViewResolver.block(from: boundCustom)?.lines == ["▼ Label ", "Shown   "])
    }

    @Test
    func `a collapsed DisclosureGroup fills its proposed width with one column between the triangle and title`() {
        let view = DisclosureGroup("Title") {
            Text("Hidden")
        }

        let block = ViewResolver.block(
            from: view,
            in: RenderProposal(columns: 10)
        )

        #expect(block?.width == 10)
        #expect(block?.height == 1)
        #expect(block?.lines == ["▶ Title   "])
    }

    @Test
    func `a multiline label sets the header height and expanded content starts unindented on the next row`() {
        let view = DisclosureGroup(isExpanded: .constant(true)) {
            Text("First\nSecond")
        } label: {
            Text("Primary\nSecondary")
        }

        let block = ViewResolver.block(
            from: view,
            in: RenderProposal(columns: 12)
        )

        #expect(block?.width == 12)
        #expect(block?.height == 4)
        #expect(block?.lines == [
            "▼ Primary   ",
            "  Secondary ",
            "First       ",
            "Second      ",
        ])
    }

    @Test
    func `only the disclosure triangle toggles internally stored expansion`() {
        let runtime = StateRuntime()
        let view = DisclosureGroup("Title") {
            Text("Content")
        }
        let proposal = RenderProposal(columns: 10)

        #expect(runtime.block(from: view, in: proposal)?.lines == ["▶ Title   "])

        dispatchClick(to: runtime, column: 3, row: 1)
        #expect(!runtime.consumeInvalidation())
        dispatchClick(to: runtime, column: 10, row: 1)
        #expect(!runtime.consumeInvalidation())

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view, in: proposal)?.lines == [
            "▼ Title   ",
            "Content   ",
        ])

        dispatchClick(to: runtime, column: 3, row: 1)
        #expect(!runtime.consumeInvalidation())
        dispatchClick(to: runtime, column: 1, row: 2)
        #expect(!runtime.consumeInvalidation())

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view, in: proposal)?.lines == ["▶ Title   "])
    }

    @Test
    func `a bound DisclosureGroup reads external changes and writes triangle toggles`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<Bool>()
        let view = BoundDisclosureGroupView(probe: probe)

        #expect(runtime.block(from: view)?.lines == ["▼ Label ", "Content "])
        #expect(probe.binding?.wrappedValue == true)

        probe.binding?.wrappedValue = false
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["▶ Label "])

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(probe.binding?.wrappedValue == true)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["▼ Label ", "Content "])
    }
}

private struct BoundDisclosureGroupView: View {

    @State private var isExpanded = true

    let probe: BindingProbe<Bool>

    var body: some View {
        CapturedBoundDisclosureGroup(
            isExpanded: $isExpanded,
            probe: probe
        )
    }
}

private struct CapturedBoundDisclosureGroup: View {

    let isExpanded: Binding<Bool>

    init(isExpanded: Binding<Bool>, probe: BindingProbe<Bool>) {
        self.isExpanded = isExpanded
        probe.capture(isExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            Text("Content")
        } label: {
            Text("Label")
        }
    }
}
