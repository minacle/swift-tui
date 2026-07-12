import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Stack Layout")
struct StackLayoutTests {

    @Test
    func `an HStack places children side by side with explicit zero spacing`() {
        let stack = HStack(spacing: 0) {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.text(from: stack) == "AB")
    }

    @Test
    func `an HStack inserts two automatic spacing columns by default`() {
        let stack = HStack {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.text(from: stack) == "A  B")
    }

    @Test
    func `automatic spacing is reserved before flexible HStack allocation`() {
        let stack = HStack {
            Text("A")
            Spacer(minLength: 0)
            Text("B")
        }

        let block = ViewResolver.block(
            from: stack,
            in: RenderProposal(columns: 8, rows: 1)
        )

        #expect(block?.lines == ["A      B"])
    }

    @Test
    func `an HStack inserts the requested number of spacing columns`() {
        let stack = HStack(spacing: 1) {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.text(from: stack) == "A B")
    }

    @Test
    func `a rendered text run preserves spaces from its content`() {
        let block = ViewResolver.block(from: Text("A B C"))

        #expect(block?.runs == [RenderedRun(text: "A B C")])
    }

    @Test
    func `HStack spacing uses run coordinates without materializing spacer runs`() {
        let block = ViewResolver.block(
            from: HStack(spacing: 3) {
                Text("A")
                Text("B")
            }
        )

        #expect(block?.runs == [
            RenderedRun(text: "A", row: 0, column: 0),
            RenderedRun(text: "B", row: 0, column: 4),
        ])
        #expect(block?.lines == ["A   B"])
    }

    @Test
    func `a VStack places children on adjacent rows with explicit zero spacing`() {
        let stack = VStack(spacing: 0) {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.text(from: stack) == "A\nB")
    }

    @Test
    func `a VStack inserts one automatic spacing row by default`() {
        let stack = VStack {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.text(from: stack) == "A\n\nB")
    }

    @Test
    func `a VStack inserts the requested number of blank spacing rows`() {
        let stack = VStack(spacing: 1) {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.text(from: stack) == "A\n\nB")
    }

    @Test
    func `padding, frame expansion, and Spacers add blank cells without creating text runs`() {
        let padded = ViewResolver.block(from: Text("A").padding())
        let framed = ViewResolver.block(from: Text("A").frame(width: 4, height: 3))
        let spacer = ViewResolver.block(from: Spacer(minLength: 2))

        #expect(padded?.runs == [RenderedRun(text: "A", row: 1, column: 1)])
        #expect(framed?.runs == [RenderedRun(text: "A", row: 1, column: 1)])
        #expect(spacer?.runs == [])
        #expect(spacer?.width == 2)
        #expect(spacer?.height == 2)
    }

    @Test
    func `HStack aligns children vertically`() {
        let top = HStack(alignment: .top, spacing: 1) {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
            Text("X")
        }
        let center = HStack(alignment: .center, spacing: 1) {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
            Text("X")
        }
        let bottom = HStack(alignment: .bottom, spacing: 1) {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
            Text("X")
        }

        #expect(ViewResolver.block(from: top)?.lines == ["A X", "B  ", "C  "])
        #expect(ViewResolver.block(from: center)?.lines == ["A  ", "B X", "C  "])
        #expect(ViewResolver.block(from: bottom)?.lines == ["A  ", "B  ", "C X"])
    }

    @Test
    func `rendered block width counts terminal cells for wide characters`() {
        let block = ViewResolver.block(from: Text("한A"))

        #expect(block?.width == 3)
    }

    @Test
    func `VStack aligns children horizontally`() {
        let leading = VStack(alignment: .leading, spacing: 0) {
            Text("A")
            Text("BBB")
        }
        let center = VStack(alignment: .center, spacing: 0) {
            Text("A")
            Text("BBB")
        }
        let trailing = VStack(alignment: .trailing, spacing: 0) {
            Text("A")
            Text("BBB")
        }

        #expect(ViewResolver.block(from: leading)?.lines == ["A  ", "BBB"])
        #expect(ViewResolver.block(from: center)?.lines == [" A ", "BBB"])
        #expect(ViewResolver.block(from: trailing)?.lines == ["  A", "BBB"])
    }

    @Test
    func `VStack aligns wide text by terminal columns`() {
        let stack = VStack(alignment: .trailing, spacing: 0) {
            Text("한")
            Text("ABC")
        }

        #expect(ViewResolver.block(from: stack)?.lines == [" 한", "ABC"])
    }

    @Test
    func `VStack aligns explicit custom horizontal guides`() {
        let stack = VStack(alignment: .marker, spacing: 0) {
            Text("A")
                .alignmentGuide(HorizontalAlignment.marker) { _ in 0 }
            Text("BBB")
                .alignmentGuide(HorizontalAlignment.marker) { _ in 2 }
        }

        #expect(ViewResolver.block(from: stack)?.lines == ["  A", "BBB"])
    }

    @Test
    func `an out-of-bounds custom guide expands a VStack without clipping`() {
        let stack = VStack(alignment: .marker, spacing: 0) {
            Text("A")
                .alignmentGuide(HorizontalAlignment.marker) { _ in -2 }
            Text("BBB")
                .alignmentGuide(HorizontalAlignment.marker) { _ in 2 }
        }

        #expect(ViewResolver.block(from: stack)?.lines == ["    A", "BBB  "])
    }

    @Test
    func `HStack aligns explicit custom vertical guides`() {
        let stack = HStack(alignment: .marker, spacing: 0) {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
            .alignmentGuide(VerticalAlignment.marker) { _ in 2 }
            Text("X")
                .alignmentGuide(VerticalAlignment.marker) { _ in 0 }
        }

        #expect(ViewResolver.block(from: stack)?.lines == ["A ", "B ", "CX"])
    }

    @Test
    func `a nested VStack propagates its descendants' explicit custom guide`() {
        let stack = VStack(alignment: .marker, spacing: 0) {
            VStack(alignment: .marker, spacing: 0) {
                Text("A")
                    .alignmentGuide(HorizontalAlignment.marker) { _ in 0 }
                Text("BBB")
                    .alignmentGuide(HorizontalAlignment.marker) { _ in 2 }
            }
            Text("Z")
                .alignmentGuide(HorizontalAlignment.marker) { _ in 0 }
        }

        #expect(ViewResolver.block(from: stack)?.lines == ["  A", "BBB", "  Z"])
    }

    @Test
    func `a spacer stores normalized minimum length`() {
        #expect(Spacer().minLength == nil)
        #expect(Spacer(minLength: 2).minLength == 2)
        #expect(Spacer(minLength: -1).minLength == 0)
    }

    @Test
    func `an HStack Spacer collapses to zero width without a proposal`() {
        let stack = HStack(spacing: 0) {
            Text("A")
            Spacer()
            Text("B")
        }

        #expect(ViewResolver.text(from: stack) == "AB")
    }

    @Test
    func `HStack spacer fills proposed columns`() {
        let stack = HStack(spacing: 0) {
            Text("A")
            Spacer()
            Text("B")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 5))

        #expect(block?.lines == ["A   B"])
    }

    @Test
    func `HStack spacers share remaining columns`() {
        let stack = HStack(spacing: 0) {
            Text("A")
            Spacer()
            Text("B")
            Spacer()
            Text("C")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 8))

        #expect(block?.lines == ["A   B  C"])
    }

    @Test
    func `VStack spacer fills proposed rows`() {
        let stack = VStack(spacing: 0) {
            Text("A")
            Spacer()
            Text("B")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(rows: 5))

        #expect(block?.lines == ["A", " ", " ", " ", "B"])
    }

    @Test
    func `a VStack without flexible children keeps its natural height under a taller proposal`() {
        let stack = VStack(spacing: 0) {
            Text("A")
            Text("B")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 4, rows: 5))

        #expect(block?.height == 2)
        #expect(block?.lines == ["A", "B"])
    }
}

private nonisolated enum StackMarkerAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        0
    }
}

extension HorizontalAlignment {
    fileprivate nonisolated static let marker = HorizontalAlignment(StackMarkerAlignment.self)
}

private nonisolated enum StackVerticalMarkerAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        0
    }
}

extension VerticalAlignment {
    fileprivate nonisolated static let marker = VerticalAlignment(StackVerticalMarkerAlignment.self)
}
