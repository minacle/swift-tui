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
    func `an oversized point stays in its binding without invoking its setter while the viewport clamps it`() {
        var position = ScrollPosition(x: 99, y: 99)
        var setterCallCount = 0
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
                set: {
                    setterCallCount += 1
                    position = $0
                }
            )
        )

        let block = ViewResolver.block(
            from: scrollView,
            in: RenderProposal(columns: 3, rows: 2)
        )

        #expect(block?.lines == ["HIJ", "MNO"])
        #expect(position.point == ScrollPoint(x: 99, y: 99))
        #expect(setterCallCount == 0)
    }

    @Test
    func `an edge stays in its binding without invoking its setter while the viewport aligns it`() {
        var position = ScrollPosition(edge: .bottom)
        var setterCallCount = 0
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
                set: {
                    setterCallCount += 1
                    position = $0
                }
            )
        )

        let block = ViewResolver.block(from: scrollView, in: RenderProposal(rows: 2))

        #expect(block?.lines == ["B", "C"])
        #expect(position.edge == .bottom)
        #expect(position.point == nil)
        #expect(setterCallCount == 0)
    }

    @Test
    func `repeated edge requests evaluate the root once and leave no residual invalidation`() {
        let runtime = StateRuntime()
        let probe = RootBodyProbe()
        let view = RepeatedEdgeRequestView(probe: probe)

        #expect(runtime.block(from: view)?.trimmedLines == ["go", "B", "C"])
        #expect(!runtime.consumeInvalidation())

        for _ in 1 ... 3 {
            let previousEvaluationCount = probe.evaluationCount
            dispatchButtonClick(to: runtime, column: 1, row: 1)
            #expect(runtime.consumeInvalidation())

            #expect(runtime.block(from: view)?.trimmedLines == ["go", "B", "C"])
            #expect(probe.evaluationCount == previousEvaluationCount + 1)
            #expect(!runtime.consumeInvalidation())
        }
    }

    @Test
    func `a bottom edge follows appended content without changing its binding`() {
        var position = ScrollPosition(edge: .bottom)
        var setterCallCount = 0
        let model = ScrollContentModel()
        let runtime = StateRuntime()
        let view = EdgeFollowingContentView(
            model: model,
            position: Binding(
                get: { position },
                set: {
                    setterCallCount += 1
                    position = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.lines == ["B", "C"])
        #expect(!runtime.consumeInvalidation())

        model.includesFourthRow = true
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["C", "D"])
        #expect(position.edge == .bottom)
        #expect(setterCallCount == 0)
    }

    @Test
    func `an onAppear state change still invalidates an edge-positioned render`() {
        let runtime = StateRuntime()
        let view = EdgePositionLifecycleView()

        #expect(runtime.block(from: view)?.trimmedLines == ["B", "waiting"])
        #expect(runtime.consumeInvalidation())

        #expect(runtime.block(from: view)?.trimmedLines == ["B", "ready"])
        #expect(!runtime.consumeInvalidation())
    }

    @Test
    func `a scroll view reader scrolls to identified view from button action`() {
        let runtime = StateRuntime()
        let view = ReaderScrollToBottomView()

        #expect(runtime.block(from: view)?.lines == ["go", "A ", "B "])
        dispatchButtonClick(to: runtime, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["go", "C ", "D "])
    }

    @Test
    func `ScrollViewReader applies explicit top and bottom anchors when scrolling to an identified view`() {
        let runtime = StateRuntime()
        let bottom = ReaderAnchorScrollView(anchor: .bottom)

        #expect(runtime.block(from: bottom)?.lines == ["go", "A ", "B "])
        dispatchButtonClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: bottom)?.lines == ["go", "B ", "C "])

        let topRuntime = StateRuntime()
        let top = ReaderAnchorScrollView(anchor: .top)
        #expect(topRuntime.block(from: top)?.lines == ["go", "A ", "B "])
        dispatchButtonClick(to: topRuntime, column: 1, row: 1)
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
        dispatchButtonClick(to: runtime, column: 1, row: 1)

        #expect(position.point == ScrollPoint(y: 1))
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["go", "B ", "C "])
    }

    @Test
    func `ScrollViewReader scrolls horizontally and across both axes`() {
        let horizontalRuntime = StateRuntime()
        let horizontal = ReaderHorizontalScrollView()

        #expect(horizontalRuntime.block(from: horizontal)?.lines == ["go", "AB"])
        dispatchButtonClick(to: horizontalRuntime, column: 1, row: 1)
        #expect(horizontalRuntime.consumeInvalidation())
        #expect(horizontalRuntime.block(from: horizontal)?.lines == ["go", "BC"])

        let twoAxisRuntime = StateRuntime()
        let twoAxis = ReaderTwoAxisScrollView()

        #expect(twoAxisRuntime.block(from: twoAxis)?.lines == ["go", "AB", "DE"])
        dispatchButtonClick(to: twoAxisRuntime, column: 1, row: 1)
        #expect(twoAxisRuntime.consumeInvalidation())
        #expect(twoAxisRuntime.block(from: twoAxis)?.lines == ["go", "EF", "HI"])
    }

    @Test
    func `ScrollViewReader ignores missing IDs and IDs outside its reader scope`() {
        let missingRuntime = StateRuntime()
        let missing = ReaderMissingIDView()

        #expect(missingRuntime.block(from: missing)?.lines == ["go", "A ", "B "])
        dispatchButtonClick(to: missingRuntime, column: 1, row: 1)
        _ = missingRuntime.consumeInvalidation()
        #expect(missingRuntime.block(from: missing)?.lines == ["go", "A ", "B "])

        let scopedRuntime = StateRuntime()
        let scoped = ReaderOutOfScopeView()
        #expect(scopedRuntime.block(from: scoped)?.lines == ["go", "X ", "A ", "B "])
        dispatchButtonClick(to: scopedRuntime, column: 1, row: 1)
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

@MainActor
private final class RootBodyProbe {

    var evaluationCount = 0
}

@MainActor
private struct RepeatedEdgeRequestView: View {

    @State
    private var position = ScrollPosition(edge: .bottom)

    let probe: RootBodyProbe

    var body: some View {
        probe.evaluationCount += 1
        return VStack(alignment: .leading, spacing: 0) {
            Button("go") {
                position.scrollTo(edge: .bottom)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("A")
                    Text("B")
                    Text("C")
                }
            }
            .scrollPosition($position)
            .frame(width: 1, height: 2)
        }
    }
}

@MainActor
@Observable
private final class ScrollContentModel {

    var includesFourthRow = false
}

@MainActor
private struct EdgeFollowingContentView: View {

    let model: ScrollContentModel

    let position: Binding<ScrollPosition>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
                if model.includesFourthRow {
                    Text("D")
                }
            }
        }
        .scrollPosition(position)
        .frame(width: 1, height: 2)
    }
}

@MainActor
private struct EdgePositionLifecycleView: View {

    @State
    private var position = ScrollPosition(edge: .bottom)

    @State
    private var status = "waiting"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("A")
                Text("B")
                Text(status)
            }
        }
        .scrollPosition($position)
        .frame(width: 7, height: 2, alignment: .leading)
        .onAppear {
            status = "ready"
        }
    }
}
