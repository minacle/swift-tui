import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Type-Erased Views")
struct TypeErasedViewTests {

    @Test
    func `AnyView preserves text content and foreground style`() {
        let original = Text("●").foregroundStyle(.green)
        let erased = AnyView(original)

        #expect(ViewResolver.block(from: erased)?.runs == ViewResolver.block(from: original)?.runs)
        #expect(ViewResolver.block(from: erased)?.lines == ViewResolver.block(from: original)?.lines)
    }

    @Test
    func `AnyView renders an empty view as no content`() {
        #expect(ViewResolver.block(from: AnyView(EmptyView())) == nil)
    }

    @Test
    func `AnyView preserves bold text style`() {
        let block = ViewResolver.block(from: AnyView(Text("x").bold()))

        #expect(block?.runs == [
            RenderedRun(
                text: "x",
                style: TextStyle(isBold: true)
            ),
        ])
        #expect(block?.lines == ["x"])
    }

    @Test
    func `AnyView preserves dim text style`() {
        let block = ViewResolver.block(from: AnyView(Text("x").dim()))

        #expect(block?.runs == [
            RenderedRun(
                text: "x",
                style: TextStyle(isDim: true)
            ),
        ])
        #expect(block?.lines == ["x"])
    }

    @Test
    func `AnyView preserves italic, underline, and strikethrough styles`() {
        let block = ViewResolver.block(
            from: AnyView(
                Text("x")
                    .italic()
                    .underline()
                    .strikethrough()
            )
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "x",
                style: TextStyle(
                    isItalic: true,
                    isUnderline: true,
                    isStrikethrough: true
                )
            ),
        ])
        #expect(block?.lines == ["x"])
    }

    @Test
    func `AnyView preserves horizontal stack layout`() {
        let view = AnyView(HStack {
            Text("a")
            Text("b")
        })

        #expect(ViewResolver.block(from: view)?.lines == ["ab"])
    }

    @Test
    func `an optional AnyView renders when present and contributes no content when absent`() {
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

        let marked = Row(marker: AnyView(Text("●").foregroundStyle(.green)))
        let unmarked = Row(marker: nil)

        #expect(ViewResolver.block(from: marked)?.runs == [
            RenderedRun(
                text: "●",
                style: TextStyle(foregroundStyle: AnyColor(Color16.green))
            ),
            RenderedRun(text: "title", column: 1),
        ])
        #expect(ViewResolver.block(from: marked)?.lines == ["●title"])
        #expect(ViewResolver.block(from: unmarked)?.lines == ["title"])
    }

    @Test
    func `a line limit applied to AnyView constrains wrapped output`() {
        let view = AnyView(Text("Alpha beta gamma"))
            .lineLimit(2)

        #expect(ViewResolver.block(from: view, in: RenderProposal(columns: 6))?.lines == [
            "Alpha ",
            "bet...",
        ])
    }
}
