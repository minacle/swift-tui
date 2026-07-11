import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Grid Layout")
struct GridLayoutTests {

    @Test
    func `a Grid uses each column's widest cell and each row's tallest cell`() {
        let view = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                VStack(spacing: 0) {
                    Text("X")
                    Text("Y")
                }
            }
            GridRow {
                Text("BBB")
                Text("Z")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == [
            " A X",
            "   Y",
            "BBBZ",
        ])
    }

    @Test
    func `a Grid inserts explicit horizontal and vertical spacing`() {
        let view = Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            GridRow {
                Text("A")
                Text("B")
            }
            GridRow {
                Text("C")
                Text("D")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == [
            "A B",
            "   ",
            "C D",
        ])
    }

    @Test
    func `a Grid inserts two automatic columns and one automatic row`() {
        let view = Grid {
            GridRow {
                Text("A")
                Text("B")
            }
            GridRow {
                Text("C")
                Text("D")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == [
            "A  B",
            "    ",
            "C  D",
        ])
    }

    @Test
    func `negative Grid spacing clamps to zero cells`() {
        let view = Grid(horizontalSpacing: -2, verticalSpacing: -3) {
            GridRow {
                Text("A")
                Text("B")
            }
            GridRow {
                Text("C")
                Text("D")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == ["AB", "CD"])
    }

    @Test
    func `gridColumnAlignment aligns every cell in its column`() {
        let view = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                    .gridColumnAlignment(.trailing)
                Text("X")
            }
            GridRow {
                Text("BBB")
                Text("Y")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == ["  AX", "BBBY"])
    }

    @Test
    func `gridColumnAlignment reads explicit custom guides from every cell`() {
        let view = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                    .alignmentGuide(.gridMarker) { _ in 0 }
                    .gridColumnAlignment(.gridMarker)
            }
            GridRow {
                Text("BBB")
                    .alignmentGuide(.gridMarker) { _ in 2 }
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == ["  A", "BBB"])
    }

    @Test
    func `a GridRow alignment overrides the Grid's vertical alignment`() {
        let view = Grid(
            alignment: .topLeading,
            horizontalSpacing: 0,
            verticalSpacing: 0
        ) {
            GridRow(alignment: .bottom) {
                Text("A")
                VStack(spacing: 0) {
                    Text("B")
                    Text("C")
                }
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == [" B", "AC"])
    }

    @Test
    func `a GridRow custom alignment reads each cell's explicit vertical guide`() {
        let view = Grid(
            alignment: .topLeading,
            horizontalSpacing: 0,
            verticalSpacing: 0
        ) {
            GridRow(alignment: .gridRowMarker) {
                Text("A")
                    .alignmentGuide(.gridRowMarker) { _ in 0 }
                VStack(spacing: 0) {
                    Text("B")
                    Text("C")
                }
                .alignmentGuide(.gridRowMarker) { _ in 1 }
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == [" B", "AC"])
    }

    @Test
    func `gridCellAnchor overrides row and column alignment`() {
        let view = Grid(
            alignment: .topLeading,
            horizontalSpacing: 0,
            verticalSpacing: 0
        ) {
            GridRow {
                Text("A")
                    .gridCellAnchor(.bottomTrailing)
                VStack(spacing: 0) {
                    Text("X")
                    Text("Y")
                }
            }
            GridRow {
                Text("BBB")
                Text("Z")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == [
            "   X",
            "  AY",
            "BBBZ",
        ])
    }

    @Test
    func `gridCellAnchor truncates fractional terminal-cell offsets`() {
        let view = Grid(
            alignment: .topLeading,
            horizontalSpacing: 0,
            verticalSpacing: 0
        ) {
            GridRow {
                Text("A")
                    .gridCellAnchor(UnitPoint(x: 0.75, y: 0))
            }
            GridRow {
                Text("BBBB")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == ["  A ", "BBBB"])
    }

    @Test
    func `gridCellColumns merges columns and normalizes nonpositive spans`() {
        let merged = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("ABCDE")
                    .gridCellColumns(2)
            }
            GridRow {
                Text("X")
                Text("Y")
            }
        }
        let normalized = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                    .gridCellColumns(0)
                Text("B")
            }
        }

        #expect(ViewResolver.block(from: merged)?.lines == ["ABCDE", " X Y "])
        #expect(ViewResolver.block(from: normalized)?.lines == ["AB"])
    }

    @Test
    func `a view outside GridRow spans every Grid column`() {
        let view = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                Text("B")
            }
            Text("-----")
            GridRow {
                Text("C")
                Text("D")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == [
            " A B ",
            "-----",
            " C D ",
        ])
    }

    @Test
    func `gridCellUnsizedAxes prevents a Divider from widening its Grid`() {
        let flexible = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                Text("B")
            }
            Divider()
        }
        let unsized = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                Text("B")
            }
            Divider()
                .gridCellUnsizedAxes(.horizontal)
        }

        #expect(
            ViewResolver.block(
                from: flexible,
                in: RenderProposal(columns: 6)
            )?.lines == [" A  B ", "──────"]
        )
        #expect(
            ViewResolver.block(
                from: unsized,
                in: RenderProposal(columns: 6)
            )?.lines == ["AB", "─ "]
        )
    }

    @Test
    func `flexible Grid rows share proposed height unless the axis is unsized`() {
        let flexible = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Spacer()
                Text("A")
            }
            GridRow {
                Text("B")
                Text("C")
            }
        }
        let unsized = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Spacer()
                    .gridCellUnsizedAxes(.vertical)
                Text("A")
            }
            GridRow {
                Text("B")
                Text("C")
            }
        }

        #expect(
            ViewResolver.block(
                from: flexible,
                in: RenderProposal(rows: 4)
            )?.lines == ["  ", " A", "  ", "BC"]
        )
        #expect(
            ViewResolver.block(
                from: unsized,
                in: RenderProposal(rows: 4)
            )?.lines == [" A", "BC"]
        )
    }

    @Test
    func `ForEach conditional cells and AnyView preserve Grid row structure`() {
        let view = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<2) { row in
                AnyView(
                    GridRow {
                        Text("\(row)")
                        if row == 0 {
                            AnyView(Text("A"))
                        }
                    }
                )
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == ["0A", "1 "])
    }

    @Test
    func `EmptyView omits a Grid cell and a trailing cell remains empty`() {
        let view = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                EmptyView()
                Text("B")
            }
            GridRow {
                Text("C")
                Text("D")
            }
        }

        #expect(ViewResolver.block(from: view)?.lines == ["AB", "CD"])
    }

    @Test
    func `GridRow behaves as transparent content outside a Grid`() {
        let view = HStack(spacing: 0) {
            Text("[")
            GridRow {
                Text("A")
                Text("B")
            }
            Text("]")
        }

        #expect(ViewResolver.block(from: view)?.lines == ["[AB]"])
    }

    @Test
    func `padding on GridRow applies independently to every cell`() {
        let grid = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("A")
                Text("B")
            }
            .padding(.horizontal, 1)
        }
        let stack = HStack(spacing: 0) {
            GridRow {
                Text("A")
                Text("B")
            }
            .padding(.horizontal, 1)
        }

        #expect(ViewResolver.block(from: grid)?.lines == [" A  B "])
        #expect(ViewResolver.block(from: stack)?.lines == [" A  B "])
    }

    @Test
    func `Grid placement translates one final set of hit and focus regions`() {
        let runtime = StateRuntime()
        let view = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("AAA")
                Text("B")
                    .onTapGesture {}
                    .focusable()
            }
        }

        let block = runtime.block(from: view)

        #expect(block?.hitRegions.map(\.frame) == [
            RenderedRect(x: 3, y: 0, width: 1, height: 1),
        ])
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(x: 3, y: 0, width: 1, height: 1),
        ])
    }

    @Test
    func `Grid placement translates a TextField caret to its cell`() {
        let runtime = StateRuntime()
        let view = GridCaretOffsetTextFieldView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        let block = runtime.block(from: view)

        #expect(block?.caret == RenderedCaret(row: 0, column: 3))
    }
}

private nonisolated enum GridMarkerAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        max(context.columns - 1, 0)
    }
}

private extension HorizontalAlignment {
    nonisolated static let gridMarker = HorizontalAlignment(GridMarkerAlignment.self)
}

private nonisolated enum GridRowMarkerAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> Int {
        max(context.rows - 1, 0)
    }
}

private extension VerticalAlignment {
    nonisolated static let gridRowMarker = VerticalAlignment(GridRowMarkerAlignment.self)
}

private struct GridCaretOffsetTextFieldView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("AAA")
                TextField("Name", text: $text)
                    .focused($isFocused)
            }
        }
    }
}
