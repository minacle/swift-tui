import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Layered Views")
struct LayeredViewTests {

    @Test
    func `a later ZStack child replaces overlapping cells from earlier children`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Text("AB")
                Text(" Z")
            }
        )

        #expect(block?.lines == [" Z"])
    }

    @Test
    func `a ZStack preserves earlier cells that a later child does not cover`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Text("ABC")
                Text("XY")
                    .padding(.leading, 1)
            }
        )

        #expect(block?.lines == ["AXY"])
    }

    @Test
    func `a ZStack aligns children within the bounds of its largest child`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .bottomTrailing) {
                Text("AAA")
                    .frame(width: 3, height: 3, alignment: .topLeading)
                Text("X")
            }
        )

        #expect(block?.lines == [
            "AAA",
            "   ",
            "  X",
        ])
    }

    @Test
    func `an out-of-bounds custom guide expands a ZStack without clipping`() {
        let block = ViewResolver.block(
            from: ZStack(
                alignment: Alignment(horizontal: .layerMarker, vertical: .top)
            ) {
                Text("A")
                    .alignmentGuide(.layerMarker) { _ in -2 }
                Text("BBB")
                    .alignmentGuide(.layerMarker) { _ in 2 }
            }
        )

        #expect(block?.lines == ["BBB A"])
    }

    @Test
    func `ZStack propagates flexible axes from layered content`() {
        let runtime = StateRuntime()
        let view = ZStackTextEditorLayoutView()
        let proposal = RenderProposal(columns: 20, rows: 5)

        _ = runtime.block(from: view, in: proposal)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view, in: proposal)

        #expect(block?.width == 20)
        #expect(block?.height == 5)
        #expect(block?.lines.first == "┌── Text Editor ───┐")
    }

    @Test
    func `a later ZStack child keeps the earlier background without inheriting its foreground attributes`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Text("AB")
                    .foregroundStyle(.red)
                    .background(.blue)
                    .bold()
                Text(" C")
            }
        )

        #expect(block?.runs == [
            RenderedRun(
                text: " C",
                style: TextStyle(backgroundStyle: AnyColor(Color16.blue))
            ),
        ])
        #expect(block?.lines == [" C"])
    }

    @Test
    func `a foreground-styled Rectangle in a ZStack does not color overlapping plain text`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.red)
                    .frame(width: 1, height: 1)
                Text("A")
            }
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "A"
            ),
        ])
    }

    @Test
    func `an explicit default background in a ZStack blocks an inherited background`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.red)
                    .frame(width: 1, height: 1)
                Text("A")
                    .background(.default)
            }
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "A",
                style: TextStyle(backgroundStyle: AnyColor(DefaultColor.default))
            ),
        ])
    }

    @Test
    func `a default background on a middle ZStack child blocks a deeper background`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.red)
                    .frame(width: 1, height: 1)
                Text("A")
                    .background(.default)
                Text("B")
            }
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "B",
                style: TextStyle(backgroundStyle: AnyColor(DefaultColor.default))
            ),
        ])
    }

    @Test
    func `zIndex takes precedence over source order for overlapping ZStack children`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Text("A")
                    .zIndex(1)
                Text("B")
            }
        )

        #expect(block?.lines == ["A"])
    }

    @Test
    func `equal zIndex values preserve ZStack source order`() {
        let block = ViewResolver.block(
            from: ZStack(alignment: .topLeading) {
                Text("A")
                    .zIndex(1)
                Text("B")
                    .zIndex(1)
            }
        )

        #expect(block?.lines == ["B"])
    }

    @Test
    func `a background renders behind its base view without changing the base size`() {
        let block = ViewResolver.block(
            from: Text("A")
                .frame(width: 3, height: 3)
                .background(alignment: .bottomTrailing) {
                    Text("B")
                }
        )

        #expect(block?.width == 3)
        #expect(block?.height == 3)
        #expect(block?.lines == [
            "   ",
            " A ",
            "  B",
        ])
    }

    @Test
    func `a color background applies to the rendered text cell`() {
        let block = ViewResolver.block(
            from: Text("A")
                .background(.red)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "A",
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `a color background fills the entire rendered bounds`() {
        let block = ViewResolver.block(
            from: Text("A")
                .frame(width: 3, height: 2, alignment: .topLeading)
                .background(.red)
        )

        #expect(block?.width == 3)
        #expect(block?.height == 2)
        #expect(block?.runs == [
            RenderedRun(
                text: "A  ",
                row: 0,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(
                text: "   ",
                row: 1,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `background placement relative to padding controls the filled bounds`() {
        let beforePadding = ViewResolver.block(
            from: Text("A")
                .background(.red)
                .padding(.leading, 1)
        )
        let afterPadding = ViewResolver.block(
            from: Text("A")
                .padding(.leading, 1)
                .background(.red)
        )

        #expect(beforePadding?.runs == [
            RenderedRun(
                text: "A",
                row: 0,
                column: 1,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
        #expect(afterPadding?.runs == [
            RenderedRun(
                text: " A",
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `a background accepts a custom color shape style`() {
        let block = ViewResolver.block(
            from: Text("A")
                .background(CustomShapeStyle())
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "A",
                style: TextStyle(backgroundStyle: AnyColor(CustomShapeStyle()))
            ),
        ])
    }

    @Test
    func `an internal background style propagates through the environment to descendant text`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .leading) {
                Text("A")
                Text("B")
            }
            ._backgroundStyle(.red)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "A",
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(
                text: "B",
                row: 1,
                style: TextStyle(backgroundStyle: AnyColor(Color16.red))
            ),
        ])
    }

    @Test
    func `an overlay renders in front of its base view without changing the base size`() {
        let block = ViewResolver.block(
            from: Text("A")
                .frame(width: 3, height: 3)
                .overlay(alignment: .topLeading) {
                    Text("B")
                }
        )

        #expect(block?.width == 3)
        #expect(block?.height == 3)
        #expect(block?.lines == [
            "B  ",
            " A ",
            "   ",
        ])
    }

    @Test
    func `overlay content follows implicit ZStack source order`() {
        let block = ViewResolver.block(
            from: Text("A")
                .overlay {
                    Text("B")
                    Text("C")
                }
        )

        #expect(block?.lines == ["C"])
    }

    @Test
    func `a foreground-colored rectangle in an overlay does not tint plain text`() {
        let block = ViewResolver.block(
            from: Rectangle()
                .fill(.red)
                .frame(width: 1, height: 1)
                .overlay {
                    Text("A")
                }
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "A"
            ),
        ])
    }

    @Test
    func `a custom layout orders overlapping placements by zIndex`() {
        let block = ViewResolver.block(
            from: OverlappingLayout() {
                Text("A")
                    .zIndex(1)
                Text("B")
            }
        )

        #expect(block?.lines == ["A"])
    }
}

private nonisolated enum LayerMarkerAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        0
    }
}

private extension HorizontalAlignment {
    nonisolated static let layerMarker = HorizontalAlignment(LayerMarkerAlignment.self)
}

private struct OverlappingLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 1, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            subview.place(at: bounds.origin)
        }
    }
}

private struct ZStackTextEditorLayoutView: View {

    @State var text = "Lorem ipsum dolor sit amet."

    var body: some View {
        VStack {
            ZStack {
                Box {
                    TextEditor(text: $text)
                        .padding(.horizontal, 1)
                }
                .background(.red)
                VStack {
                    Text(" Text Editor ")
                    Spacer()
                }
            }
        }
    }
}
