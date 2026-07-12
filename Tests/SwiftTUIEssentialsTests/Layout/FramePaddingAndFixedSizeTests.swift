import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Frame, Padding, and Fixed-Size Layout")
struct FramePaddingAndFixedSizeTests {

    @Test
    func `a fixed frame pads smaller content to its dimensions`() {
        let view = Text("AB").frame(width: 4, height: 2)

        let block = ViewResolver.block(from: view)

        #expect(block?.lines == [" AB ", "    "])
    }

    @Test
    func `a frame clips wide text by terminal columns`() {
        let view = Text("한A").frame(width: 2, height: 1)

        let block = ViewResolver.block(from: view)

        #expect(block?.lines == ["한"])
        #expect(block?.width == 2)
    }

    @Test
    func `Edge set constants match equivalent edge literals and combinations`() {
        let horizontal: Edge.Set = [.leading, .trailing]
        let vertical: Edge.Set = [.top, .bottom]

        #expect(Edge.Set(.top) == .top)
        #expect(horizontal == .horizontal)
        #expect(vertical == .vertical)
        #expect(Edge.Set.all == [.horizontal, .vertical])
    }

    @Test
    func `EdgeInsets clamp negative components to zero`() {
        let insets = EdgeInsets(top: -1, leading: 2, bottom: -3, trailing: 4)

        #expect(insets == EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 4))
    }

    @Test
    func `padding adds one cell on every edge by default`() {
        let block = ViewResolver.block(from: Text("A").padding())

        #expect(block?.lines == ["   ", " A ", "   "])
    }

    @Test
    func `padding applies explicit lengths through edge sets and EdgeInsets`() {
        let horizontal = ViewResolver.block(from: Text("A").padding(.horizontal, 2))
        let insets = ViewResolver.block(
            from: Text("A").padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 2))
        )

        #expect(horizontal?.lines == ["  A  "])
        #expect(insets?.lines == ["   ", "A  "])
    }

    @Test
    func `padding preserves the terminal-cell width of wide text`() {
        let block = ViewResolver.block(from: Text("한A").padding(.trailing, 1))

        #expect(block?.lines == ["한A "])
        #expect(block?.width == 4)
    }

    @Test
    func `padding subtracts its insets from the child proposal`() {
        let view = GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
        .padding()

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 6, rows: 3))

        #expect(block?.lines == ["      ", " 4x1  ", "      "])
    }

    @Test
    func `padding translates a TextField caret by its top and leading insets`() {
        let runtime = StateRuntime()
        let view = TextFieldEditingView()
            .padding(EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 0))

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == ["      ", "  Name"])
        #expect(block?.caret == RenderedCaret(row: 1, column: 2))
    }

    @Test
    func `padding translates tap hit testing by its top and leading insets`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Text("A")
            .onTapGesture {
                tapProbe.record("tap")
            }
            .padding(EdgeInsets(top: 1, leading: 1, bottom: 0, trailing: 0))

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
        dispatchClick(to: runtime, column: 2, row: 2)

        #expect(tapProbe.events == ["tap"])
    }

    @Test
    func `a frame aligns content within larger size`() {
        let block = ViewResolver.block(
            from: Text("A").frame(width: 4, height: 3, alignment: .bottomTrailing)
        )

        #expect(block?.lines == ["    ", "    ", "   A"])
    }

    @Test
    func `a frame aligns content by its explicit custom guide`() {
        let block = ViewResolver.block(
            from: Text("A")
                .alignmentGuide(.frameMarker) { _ in 0 }
                .frame(
                    width: 3,
                    alignment: Alignment(horizontal: .frameMarker, vertical: .top)
                )
        )

        #expect(block?.lines == ["  A"])
    }

    @Test
    func `a frame alignment controls clipping origin`() {
        let center = ViewResolver.block(
            from: Text("ABCDE")
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 3)
        )
        let trailing = ViewResolver.block(
            from: Text("ABCDE")
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 3, alignment: .trailing)
        )

        #expect(center?.lines == ["BCD"])
        #expect(trailing?.lines == ["CDE"])
    }

    @Test
    func `minimum frame dimensions expand smaller fixed content`() {
        let block = ViewResolver.block(
            from: Text("A").frame(minWidth: 3, minHeight: 2, alignment: .topLeading)
        )

        #expect(block?.lines == ["A  ", "   "])
    }

    @Test
    func `a maximum frame width clips larger content from the selected alignment`() {
        let block = ViewResolver.block(
            from: Text("ABCDE").frame(maxWidth: 3, alignment: .trailing)
        )

        #expect(block?.lines == ["CDE"])
    }

    @Test
    func `a maximum frame width clamps an oversized parent proposal`() {
        let view = Text("A").frame(minWidth: 2, maxWidth: 4, alignment: .trailing)

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 5))

        #expect(block?.lines == ["   A"])
    }

    @Test
    func `ideal frame dimensions do not expand fixed content`() {
        let block = ViewResolver.block(
            from: Text("A").frame(idealWidth: 4, idealHeight: 2, alignment: .bottomTrailing)
        )

        #expect(block?.lines == ["A"])
    }

    @Test
    func `ideal frame dimensions become the proposal for flexible content`() {
        let view = GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
        .frame(idealWidth: 4, idealHeight: 2, alignment: .bottomTrailing)

        let block = ViewResolver.block(from: view)

        #expect(block?.lines == ["4x2 ", "    "])
    }

    @Test
    func `flexible frame dimensions clamp negative lengths to zero`() {
        let block = ViewResolver.block(
            from: Text("A").frame(minWidth: -2, maxWidth: -1, minHeight: -2, maxHeight: -1)
        )

        #expect(block?.lines == [])
    }

    @Test
    func `fixedSize discards the parent proposal only along its selected axes`() {
        let horizontal = GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
        .fixedSize(horizontal: true, vertical: false)
        let vertical = GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
        .fixedSize(horizontal: false, vertical: true)
        let both = GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
        .fixedSize()

        #expect(
            ViewResolver.block(from: horizontal, in: RenderProposal(columns: 5, rows: 2))?.lines
                == ["0x2", "   "]
        )
        #expect(
            ViewResolver.block(from: vertical, in: RenderProposal(columns: 5, rows: 2))?.lines
                == ["5x0  "]
        )
        #expect(
            ViewResolver.block(from: both, in: RenderProposal(columns: 5, rows: 2))?.lines
                == ["0x0"]
        )
    }
}

private nonisolated enum FrameMarkerAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        max(context.columns - 1, 0)
    }
}

extension HorizontalAlignment {
    fileprivate nonisolated static let frameMarker = HorizontalAlignment(FrameMarkerAlignment.self)
}
