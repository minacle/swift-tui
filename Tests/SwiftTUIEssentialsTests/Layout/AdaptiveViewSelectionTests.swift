import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Adaptive View Selection")
struct AdaptiveViewSelectionTests {

    @Test
    func `ViewThatFits chooses the first child that fits both proposed dimensions by default`() {
        let view = ViewThatFits {
            Text("OK")
            Text("Fallback")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 2, rows: 1))

        #expect(block?.lines == ["OK"])
    }

    @Test
    func `a horizontally constrained ViewThatFits ignores vertical overflow`() {
        let view = ViewThatFits(in: .horizontal) {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
            }
            Text("C")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["A", "B"])
    }

    @Test
    func `a vertically constrained ViewThatFits selects a child by height`() {
        let view = ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
            }
            Text("C")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["C"])
    }

    @Test
    func `ViewThatFits with no constrained axes selects its first renderable child`() {
        let view = ViewThatFits(in: []) {
            Text("First")
            Text("Second")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["F", "i", "r", "s", "t"])
    }

    @Test
    func `ViewThatFits falls back to its final renderable child when no candidate fits`() {
        let view = ViewThatFits(in: .horizontal) {
            Text("AAA")
            Text("DD")
                .fixedSize()
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 1, rows: 1))

        #expect(block?.lines == ["DD"])
    }

    @Test
    func `ViewThatFits compares ideal widths before selecting a horizontally constrained candidate`() {
        let view = ViewThatFits(in: .horizontal) {
            Text("Alpha Beta")
            Text("Short")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 5))

        #expect(block?.lines == ["Short"])
    }

    @Test
    func `an HStack proposes its remaining width to ViewThatFits`() {
        let view = HStack(spacing: 0) {
            Text("A")
            ViewThatFits(in: .horizontal) {
                Text("Long")
                Text("B")
            }
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 2))

        #expect(block?.lines == ["AB"])
    }

    @Test
    func `ViewThatFits registers hit and focus regions only for the selected interactive candidate`() {
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

    @Test
    func `ViewThatFits accepts candidates wrapped in Group, AnyView, and modifiers`() {
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
            PointerPress(button: .left, location: Point(column: column - 1, row: row - 1), phase: .down)
        ) == result
    )
    #expect(
        runtime.dispatch(
            PointerPress(button: .left, location: Point(column: column - 1, row: row - 1), phase: .up)
        ) == result
    )
}
