import Testing
@testable import SwiftTUI

@Suite("AnyView")
struct AnyViewTests {

    @Test func preservesTextOutputAndStyle() {
        let original = Text("●").color(.green)
        let erased = AnyView(original)

        #expect(ViewResolver.block(from: erased)?.runs == ViewResolver.block(from: original)?.runs)
        #expect(ViewResolver.block(from: erased)?.lines == ViewResolver.block(from: original)?.lines)
    }

    @Test func canWrapEmptyView() {
        #expect(ViewResolver.block(from: AnyView(EmptyView())) == nil)
    }

    @Test func preservesBoldTextStyle() {
        let block = ViewResolver.block(from: AnyView(Text("x").bold()))

        #expect(block?.runs == [
            RenderedRun(
                text: "x",
                style: TextStyle(color: nil, isBold: true)
            ),
        ])
        #expect(block?.lines == ["x"])
    }

    @Test func preservesDimTextStyle() {
        let block = ViewResolver.block(from: AnyView(Text("x").dim()))

        #expect(block?.runs == [
            RenderedRun(
                text: "x",
                style: TextStyle(color: nil, isBold: false, isDim: true)
            ),
        ])
        #expect(block?.lines == ["x"])
    }

    @Test func canWrapStacks() {
        let view = AnyView(HStack {
            Text("a")
            Text("b")
        })

        #expect(ViewResolver.block(from: view)?.lines == ["ab"])
    }

    @Test func optionalStorageRendersFromParentView() {
        struct Row: View {

            let marker: AnyView?

            var body: some View {
                HStack {
                    if let marker {
                        marker
                    }
                    Text("title")
                }
            }
        }

        let marked = Row(marker: AnyView(Text("●").color(.green)))
        let unmarked = Row(marker: nil)

        #expect(ViewResolver.block(from: marked)?.runs == [
            RenderedRun(
                text: "●",
                style: TextStyle(color: .green, isBold: false)
            ),
            RenderedRun(text: "title", column: 1),
        ])
        #expect(ViewResolver.block(from: marked)?.lines == ["●title"])
        #expect(ViewResolver.block(from: unmarked)?.lines == ["title"])
    }

    @Test func preservesLineLimitContext() {
        let view = AnyView(Text("Alpha beta gamma"))
            .lineLimit(2)

        #expect(ViewResolver.block(from: view, in: RenderProposal(columns: 6))?.lines == [
            "Alpha ",
            "bet...",
        ])
    }
}
