import Testing
@testable import SwiftTUI

@Suite("Built-In Layout Values")
struct BuiltInLayoutTests {

    @Test
    func `built-in layout values expose SwiftUI-shaped mutable configuration`() {
        var horizontal = HStackLayout()
        var vertical = VStackLayout()
        var overlay = ZStackLayout()
        var grid = GridLayout()

        #expect(horizontal.alignment == .center)
        #expect(horizontal.spacing == nil)
        #expect(HStackLayout.layoutProperties.stackOrientation == .horizontal)
        #expect(vertical.alignment == .center)
        #expect(vertical.spacing == nil)
        #expect(VStackLayout.layoutProperties.stackOrientation == .vertical)
        #expect(overlay.alignment == .center)
        #expect(grid.alignment == .center)
        #expect(grid.horizontalSpacing == nil)
        #expect(grid.verticalSpacing == nil)

        horizontal.alignment = .top
        horizontal.spacing = 3
        vertical.alignment = .trailing
        vertical.spacing = 2
        overlay.alignment = .bottomTrailing
        grid.alignment = .topLeading
        grid.horizontalSpacing = 4
        grid.verticalSpacing = 5

        #expect(horizontal.alignment == .top)
        #expect(horizontal.spacing == 3)
        #expect(vertical.alignment == .trailing)
        #expect(vertical.spacing == 2)
        #expect(overlay.alignment == .bottomTrailing)
        #expect(grid.alignment == .topLeading)
        #expect(grid.horizontalSpacing == 4)
        #expect(grid.verticalSpacing == 5)
    }

    @Test
    func `HStackLayout and VStackLayout match their stack views`() {
        let horizontal = HStackLayout(alignment: .bottom, spacing: 1) {
            Text("A")
                .padding(.top, 1)
            Text("BB")
        }
        let horizontalView = HStack(alignment: .bottom, spacing: 1) {
            Text("A")
                .padding(.top, 1)
            Text("BB")
        }
        let vertical = VStackLayout(alignment: .trailing, spacing: 1) {
            Text("A")
            Text("BB")
        }
        let verticalView = VStack(alignment: .trailing, spacing: 1) {
            Text("A")
            Text("BB")
        }

        #expect(ViewResolver.block(from: horizontal)?.lines == ["    ", "A BB"])
        #expect(
            ViewResolver.block(from: horizontal)?.lines
                == ViewResolver.block(from: horizontalView)?.lines
        )
        #expect(ViewResolver.block(from: vertical)?.lines == [" A", "", "BB"])
        #expect(
            ViewResolver.block(from: vertical)?.lines
                == ViewResolver.block(from: verticalView)?.lines
        )
    }

    @Test
    func `negative built-in layout spacing remains observable and renders as zero cells`() {
        let horizontal = HStackLayout(spacing: -2)
        let grid = GridLayout(horizontalSpacing: -3, verticalSpacing: -4)

        let horizontalBlock = ViewResolver.block(
            from: horizontal {
                Text("A")
                Text("B")
            }
        )
        let gridBlock = ViewResolver.block(
            from: grid {
                GridRow {
                    Text("A")
                    Text("B")
                }
                GridRow {
                    Text("C")
                    Text("D")
                }
            }
        )

        #expect(horizontal.spacing == -2)
        #expect(grid.horizontalSpacing == -3)
        #expect(grid.verticalSpacing == -4)
        #expect(horizontalBlock?.lines == ["AB"])
        #expect(gridBlock?.lines == ["AB", "CD"])
    }

    @Test
    func `ZStackLayout preserves alignment overlap and zIndex behavior`() {
        let layout = ZStackLayout(alignment: .bottomTrailing)
        let block = ViewResolver.block(
            from: layout {
                Text("ABC")
                Text("X")
                    .zIndex(2)
            }
        )

        #expect(block?.lines == ["ABX"])
    }

    @Test
    func `GridLayout preserves rows spans and cell alignment modifiers`() {
        let layout = GridLayout(
            alignment: .topLeading,
            horizontalSpacing: 1,
            verticalSpacing: 0
        )
        let block = ViewResolver.block(
            from: layout {
                GridRow {
                    Text("A")
                    Text("B")
                        .gridCellAnchor(.bottomTrailing)
                }
                Text("wide")
                GridRow {
                    Text("C")
                        .gridCellColumns(2)
                }
            }
        )

        #expect(block?.lines == ["A  B", "wide", "C   "])
    }
}
