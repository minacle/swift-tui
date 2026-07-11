import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Programmatic Scrolling")
struct ProgrammaticScrollingTests {

    @Test
    func `a frame exposes viewport to nested scroll view`() {
        let view = ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                Text("ABCDE")
                Text("FGHIJ")
                Text("KLMNO")
            }
        }
        .scrollPosition(.constant(ScrollPosition(x: 1, y: 1)))
        .frame(width: 3, height: 2)

        let block = ViewResolver.block(from: view)

        #expect(block?.lines == ["GHI", "LMN"])
    }

    @Test
    func `a scroll position binding clamps an oversized point to the maximum valid offset`() {
        var position = ScrollPosition(x: 99, y: 99)
        let scrollView = ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                Text("ABCDE")
                Text("FGHIJ")
                Text("KLMNO")
            }
        }
        .scrollPosition(
            Binding(
                get: { position },
                set: { position = $0 }
            )
        )

        let block = ViewResolver.block(
            from: scrollView,
            in: RenderProposal(columns: 3, rows: 2)
        )

        #expect(block?.lines == ["HIJ", "MNO"])
        #expect(position.point == ScrollPoint(x: 2, y: 1))
    }

    @Test
    func `an edge-based scroll position resolves to its clamped point offset`() {
        var position = ScrollPosition(edge: .bottom)
        let scrollView = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .scrollPosition(
            Binding(
                get: { position },
                set: { position = $0 }
            )
        )

        let block = ViewResolver.block(from: scrollView, in: RenderProposal(rows: 2))

        #expect(block?.lines == ["B", "C"])
        #expect(position.point == ScrollPoint(y: 1))
    }

    @Test
    func `a scroll view reader scrolls to identified view from button action`() {
        let runtime = StateRuntime()
        let view = ReaderScrollToBottomView()

        #expect(runtime.block(from: view)?.lines == ["go", "A ", "B "])
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["go", "C ", "D "])
    }

    @Test
    func `ScrollViewReader applies explicit top and bottom anchors when scrolling to an identified view`() {
        let runtime = StateRuntime()
        let bottom = ReaderAnchorScrollView(anchor: .bottom)

        #expect(runtime.block(from: bottom)?.lines == ["go", "A ", "B "])
        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: bottom)?.lines == ["go", "B ", "C "])

        let topRuntime = StateRuntime()
        let top = ReaderAnchorScrollView(anchor: .top)
        #expect(topRuntime.block(from: top)?.lines == ["go", "A ", "B "])
        dispatchClick(to: topRuntime, column: 1, row: 1)
        #expect(topRuntime.consumeInvalidation())
        #expect(topRuntime.block(from: top)?.lines == ["go", "C ", "D "])
    }

    @Test
    func `a scroll view reader updates scroll position binding`() {
        var position = ScrollPosition()
        let runtime = StateRuntime()
        let view = ReaderBindingScrollView(
            position: Binding(
                get: { position },
                set: { position = $0 }
            )
        )

        #expect(runtime.block(from: view)?.lines == ["go", "A ", "B "])
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(position.point == ScrollPoint(y: 1))
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["go", "B ", "C "])
    }

    @Test
    func `ScrollViewReader scrolls horizontally and across both axes`() {
        let horizontalRuntime = StateRuntime()
        let horizontal = ReaderHorizontalScrollView()

        #expect(horizontalRuntime.block(from: horizontal)?.lines == ["go", "AB"])
        dispatchClick(to: horizontalRuntime, column: 1, row: 1)
        #expect(horizontalRuntime.consumeInvalidation())
        #expect(horizontalRuntime.block(from: horizontal)?.lines == ["go", "BC"])

        let twoAxisRuntime = StateRuntime()
        let twoAxis = ReaderTwoAxisScrollView()

        #expect(twoAxisRuntime.block(from: twoAxis)?.lines == ["go", "AB", "DE"])
        dispatchClick(to: twoAxisRuntime, column: 1, row: 1)
        #expect(twoAxisRuntime.consumeInvalidation())
        #expect(twoAxisRuntime.block(from: twoAxis)?.lines == ["go", "EF", "HI"])
    }

    @Test
    func `ScrollViewReader ignores missing IDs and IDs outside its reader scope`() {
        let missingRuntime = StateRuntime()
        let missing = ReaderMissingIDView()

        #expect(missingRuntime.block(from: missing)?.lines == ["go", "A ", "B "])
        dispatchClick(to: missingRuntime, column: 1, row: 1)
        _ = missingRuntime.consumeInvalidation()
        #expect(missingRuntime.block(from: missing)?.lines == ["go", "A ", "B "])

        let scopedRuntime = StateRuntime()
        let scoped = ReaderOutOfScopeView()
        #expect(scopedRuntime.block(from: scoped)?.lines == ["go", "X ", "A ", "B "])
        dispatchClick(to: scopedRuntime, column: 1, row: 1)
        _ = scopedRuntime.consumeInvalidation()
        #expect(scopedRuntime.block(from: scoped)?.lines == ["go", "X ", "A ", "B "])
    }

    @Test
    func `scrollPosition affects only a scrollable descendant within the modified subtree`() {
        let scrolled = HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("A")
                    Text("B")
                    Text("C")
                }
            }
        }
        .scrollPosition(.constant(ScrollPosition(y: 1)))
        let unchanged = Text("Hello").scrollPosition(.constant(ScrollPosition(y: 9)))

        let scrolledBlock = ViewResolver.block(from: scrolled, in: RenderProposal(rows: 2))
        let unchangedBlock = ViewResolver.block(from: unchanged, in: RenderProposal(rows: 1))

        #expect(scrolledBlock?.lines == ["B", "C"])
        #expect(unchangedBlock?.lines == ["Hello"])
    }

    @Test
    func `ScrollView clipping preserves the style of the visible text segment`() {
        let scrollView = ScrollView(.horizontal) {
            Text("ABCDE")
                .foregroundStyle(.magenta)
        }
        .scrollPosition(.constant(ScrollPosition(x: 2)))

        let block = ViewResolver.block(
            from: scrollView,
            in: RenderProposal(columns: 3, rows: 1)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "CDE",
                style: TextStyle(foregroundStyle: AnyColor(Color16.magenta))
            ),
        ])
        #expect(block?.lines == ["CDE"])
    }
}
