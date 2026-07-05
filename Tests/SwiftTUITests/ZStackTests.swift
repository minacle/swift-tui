import Testing
@testable import SwiftTUI

@Test func zStackLaterChildOverwritesEarlierChildCells() {
    let block = ViewResolver.block(
        from: ZStack(alignment: .topLeading) {
            Text("AB")
            Text(" Z")
        }
    )

    #expect(block?.lines == [" Z"])
}

@Test func zStackPartiallyOverlappingChildPreservesUncoveredCells() {
    let block = ViewResolver.block(
        from: ZStack(alignment: .topLeading) {
            Text("ABC")
            Text("XY")
                .padding(.leading, 1)
        }
    )

    #expect(block?.lines == ["AXY"])
}

@Test func zStackAlignsChildrenWithinLargestChildBounds() {
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

@Test func zStackKeepsLayerStylesIndependent() {
    let block = ViewResolver.block(
        from: ZStack(alignment: .topLeading) {
            Text("AB")
                .foregroundStyle(.red)
                .backgroundStyle(.blue)
                .bold()
            Text(" C")
        }
    )

    #expect(block?.runs == [
        RenderedRun(text: " C"),
    ])
    #expect(block?.lines == [" C"])
}

@Test func zStackUsesZIndexBeforeSourceOrder() {
    let block = ViewResolver.block(
        from: ZStack(alignment: .topLeading) {
            Text("A")
                .zIndex(1)
            Text("B")
        }
    )

    #expect(block?.lines == ["A"])
}

@Test func zStackPreservesSourceOrderForEqualZIndex() {
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

@Test func backgroundRendersBehindBaseAndKeepsBaseSize() {
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

@Test func overlayRendersInFrontOfBaseAndKeepsBaseSize() {
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

@Test func overlayContentUsesImplicitZStackOrdering() {
    let block = ViewResolver.block(
        from: Text("A")
            .overlay {
                Text("B")
                Text("C")
            }
    )

    #expect(block?.lines == ["C"])
}

@Test func customLayoutUsesZIndexForOverlappingPlacements() {
    let block = ViewResolver.block(
        from: OverlappingLayout() {
            Text("A")
                .zIndex(1)
            Text("B")
        }
    )

    #expect(block?.lines == ["A"])
}

private struct OverlappingLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> GeometrySize {
        GeometrySize(columns: 1, rows: 1)
    }

    func placeSubviews(
        in bounds: GeometryFrame,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            subview.place(at: bounds.origin)
        }
    }
}
