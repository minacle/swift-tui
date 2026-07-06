import Testing
@testable import SwiftTUI

@Suite("ViewThatFits")
struct ViewThatFitsTests {

    @Test func defaultAxesChooseFirstChildThatFitsBothDimensions() {
        let view = ViewThatFits {
            Text("OK")
            Text("Fallback")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 2, rows: 1))

        #expect(block?.lines == ["OK"])
    }

    @Test func horizontalAxisIgnoresHeightOverflow() {
        let view = ViewThatFits(in: .horizontal) {
            VStack {
                Text("A")
                Text("B")
            }
            Text("C")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["A", "B"])
    }

    @Test func verticalAxisChoosesByHeight() {
        let view = ViewThatFits(in: .vertical) {
            VStack {
                Text("A")
                Text("B")
            }
            Text("C")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["C"])
    }

    @Test func emptyAxesChooseFirstRenderableChild() {
        let view = ViewThatFits(in: []) {
            Text("First")
            Text("Second")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["F", "i", "r", "s", "t"])
    }

    @Test func noFitFallsBackToLastRenderableChild() {
        let view = ViewThatFits(in: .horizontal) {
            Text("AAA")
            Text("DD")
                .fixedSize()
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["DD"])
    }

    @Test func constrainedAxesMeasureIdealSizeBeforeChoosing() {
        let view = ViewThatFits(in: .horizontal) {
            Text("Alpha Beta")
            Text("Short")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 5))

        #expect(block?.lines == ["Short"])
    }

    @Test func hStackProposesRemainingWidthToViewThatFits() {
        let view = HStack {
            Text("A")
            ViewThatFits(in: .horizontal) {
                Text("Long")
                Text("B")
            }
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 2))

        #expect(block?.lines == ["AB"])
    }

    @Test func registersOnlySelectedInteractiveCandidate() {
        let runtime = StateRuntime()
        let probe = ViewThatFitsTapProbe()
        let view = ViewThatFits(in: .horizontal) {
            Text("Discard")
                .focusable()
                .onTapGesture {
                    probe.record("discard")
                }
            Text("Keep")
                .focusable()
                .onTapGesture {
                    probe.record("keep")
                }
        }

        let block = runtime.block(from: view, in: RenderProposal(columns: 4))

        #expect(block?.lines == ["Keep"])
        #expect(block?.hitRegions.map(\.frame) == [
            RenderedRect(width: 4, height: 1),
        ])
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(width: 4, height: 1),
        ])

        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(probe.events == ["keep"])
    }

    @Test func supportsGroupAnyViewAndModifierWrappedCandidates() {
        let view = ViewThatFits(in: .horizontal) {
            Group {
                AnyView(
                    Text("Too long")
                        .padding(.horizontal, 1)
                )
                AnyView(
                    Text("OK")
                        .bold()
                        .padding(.leading, 1)
                )
            }
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 3))

        #expect(block?.runs == [
            RenderedRun(
                text: "OK",
                row: 0,
                column: 1,
                style: TextStyle(isBold: true)
            ),
        ])
        #expect(block?.lines == [" OK"])
    }
}

private final class ViewThatFitsTapProbe {

    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private func dispatchClick(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .down)
        ) == result
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .up)
        ) == result
    )
}
