import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Custom Layouts")
struct CustomLayoutTests {

    @Test
    func `a custom vertical layout measures and places its subviews`() {
        let view = BasicVStackLayout() {
            Text("A")
            Text("BB")
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.width == 2)
        #expect(block?.height == 2)
        #expect(block?.lines == ["A ", "BB"])
    }

    @Test
    func `a custom layout forwards its proposal during subview measurement and placement`() {
        let view = ProposedWrappingLayout() {
            Text("Alpha Beta")
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 5))

        #expect(block?.lines == ["Alpha", "Beta "])
    }

    @Test
    func `a custom layout measures a Spacer with an explicit proposal`() {
        let view = SpacerMeasurementLayout() {
            Spacer()
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.width == 4)
        #expect(block?.height == 2)
        #expect(block?.lines == ["    ", "    "])
    }

    @Test
    func `a negative custom layout size clamps to an empty rendered block`() {
        let view = NegativeSizeLayout() {
            Text("A")
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.width == 0)
        #expect(block?.height == 0)
        #expect(block?.lines == [])
    }

    @Test
    func `a custom layout places subviews by anchor and clips them to its bounds`() {
        let view = AnchoredLayout() {
            Text("AB")
            Text("CDE")
            Text("XYZ")
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.lines == [
            "     ",
            "ABCDE",
            "   XY",
        ])
    }

    @Test
    func `a custom layout translates scroll, hit, and focus regions with the placed subview`() {
        let runtime = StateRuntime()
        let tapProbe = LayoutTapGestureProbe()
        let view = RegionOffsetLayout() {
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            .scrollPosition(.constant(ScrollPosition(x: 1)))
            .padding(.horizontal, 1)
            .onTapGesture {
                tapProbe.record("tap")
            }
            .focusable()
        }

        let block = runtime.block(from: view)

        #expect(block?.lines == [
            "       ",
            "  BCD  ",
            "       ",
        ])
        #expect(block?.scrollRegions.map { $0.frame } == [
            RenderedRect(x: 2, y: 1, width: 3, height: 1),
        ])
        #expect(block?.hitRegions.map { $0.frame } == [
            RenderedRect(x: 1, y: 1, width: 5, height: 1),
        ])
        #expect(block?.focusRegions.map { $0.frame } == [
            RenderedRect(x: 1, y: 1, width: 5, height: 1),
        ])
    }

    @Test
    func `a custom layout translates a TextField caret to the placed subview`() {
        let runtime = StateRuntime()
        let view = CaretOffsetTextFieldView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.lines == [
            "       ",
            " Name  ",
            "       ",
        ])
        #expect(block?.caret == RenderedCaret(row: 1, column: 1))
    }

    @Test
    func `a custom layout reads subview priority through AnyView and intervening modifiers`() {
        let view = PriorityWidthLayout() {
            AnyView(
                Text("A")
                    .layoutPriority(2.5)
                    .padding()
                    .frame(width: 5, alignment: .leading)
            )
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.width == 5)
        #expect(block?.lines == ["     ", " A   ", "     "])
    }

    @Test
    func `a custom layout reads explicit layout values and defaults from separate subviews`() {
        let view = LayoutValueRowLayout() {
            Text("A")
                .layoutValue(key: ColumnSpanKey.self, value: 3)
            Text("B")
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.width == 4)
        #expect(block?.lines == ["A  B"])
    }

    @Test
    func `a custom layout reads layout values through AnyView and intervening modifiers`() {
        let view = LayoutValueWidthLayout() {
            AnyView(
                Text("A")
                    .layoutValue(key: ColumnSpanKey.self, value: 5)
                    .padding()
                    .frame(width: 7, alignment: .leading)
            )
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.width == 5)
    }

    @Test
    func `a custom layout reads independent values for multiple layout keys`() {
        let view = LayoutValueRowLayout() {
            Text("A")
                .layoutValue(key: LeadingInsetKey.self, value: 2)
                .layoutValue(key: ColumnSpanKey.self, value: 4)
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.width == 6)
        #expect(block?.lines == ["  A   "])
    }

    @Test
    func `a custom layout reuses its cache between sizing and placement`() {
        let view = CacheBackedLayout() {
            Text("A")
        }

        let block = ViewResolver.block(from: view)

        #expect(block?.lines == ["  A"])
    }
}

private struct BasicVStackLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        subviews.reduce(Size()) { size, subview in
            let childSize = subview.sizeThatFits(.unspecified)
            return Size(
                columns: max(size.columns, childSize.columns),
                rows: size.rows + childSize.rows
            )
        }
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var row = bounds.origin.row
        for subview in subviews {
            subview.place(
                at: Point(column: bounds.origin.column, row: row),
                anchor: .topLeading,
                proposal: .unspecified
            )
            row += subview.dimensions(in: .unspecified).rows
        }
    }
}

private struct ProposedWrappingLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        subviews.first?.sizeThatFits(
            ProposedViewSize(columns: proposal.columns)
        ) ?? Size()
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: bounds.origin,
            proposal: ProposedViewSize(columns: proposal.columns)
        )
    }
}

private struct SpacerMeasurementLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        subviews[0].sizeThatFits(ProposedViewSize(columns: 4, rows: 2))
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews[0].place(
            at: bounds.origin,
            proposal: ProposedViewSize(columns: bounds.size.columns, rows: bounds.size.rows)
        )
    }
}

private struct NegativeSizeLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: -1, rows: -2)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(at: .zero)
    }
}

private struct AnchoredLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 5, rows: 3)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews[0].place(at: Point(column: 0, row: 1), anchor: .topLeading)
        subviews[1].place(at: Point(column: 5, row: 2), anchor: .bottomTrailing)
        subviews[2].place(at: Point(column: 3, row: 2), anchor: .topLeading)
    }
}

private struct RegionOffsetLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: 7, rows: 3)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: Point(column: 1, row: 1),
            proposal: ProposedViewSize(columns: 5, rows: 1)
        )
    }
}

private struct CaretOffsetTextFieldView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        RegionOffsetLayout() {
            TextField("Name", text: $text)
                .focused($isFocused)
        }
    }
}

private struct PriorityWidthLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: Int(subviews[0].priority * 2), rows: 3)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews[0].place(
            at: bounds.origin,
            proposal: ProposedViewSize(columns: bounds.size.columns, rows: bounds.size.rows)
        )
    }
}

nonisolated enum ColumnSpanKey: LayoutValueKey {

    static let defaultValue = 1
}

nonisolated enum LeadingInsetKey: LayoutValueKey {

    static let defaultValue = 0
}

private struct LayoutValueRowLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        let columns = subviews.reduce(0) { total, subview in
            total + subview[LeadingInsetKey.self] + subview[ColumnSpanKey.self]
        }
        return Size(columns: columns, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var column = bounds.origin.column
        for subview in subviews {
            column += subview[LeadingInsetKey.self]
            subview.place(
                at: Point(column: column, row: bounds.origin.row),
                proposal: ProposedViewSize(
                    columns: subview[ColumnSpanKey.self],
                    rows: 1
                )
            )
            column += subview[ColumnSpanKey.self]
        }
    }
}

private struct LayoutValueWidthLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(columns: subviews[0][ColumnSpanKey.self], rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews[0].place(
            at: bounds.origin,
            proposal: ProposedViewSize(columns: bounds.size.columns, rows: 1)
        )
    }
}

private struct CacheBackedLayout: Layout {

    struct Cache {

        var column = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(column: 1)
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> Size {
        cache.column += subviews[0].sizeThatFits(.unspecified).columns
        return Size(columns: cache.column + 1, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        subviews[0].place(
            at: Point(column: cache.column, row: 0),
            proposal: .unspecified
        )
    }
}

private final class LayoutTapGestureProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}
