import Testing
@testable import SwiftTUI

@Suite("View Spacing")
struct ViewSpacingTests {

    @Test
    func `ViewSpacing defaults to two horizontal cells and one vertical cell`() {
        let spacing = ViewSpacing()

        #expect(spacing.distance(to: spacing, along: .horizontal) == 2)
        #expect(spacing.distance(to: spacing, along: .vertical) == 1)
    }

    @Test
    func `zero spacing leaves an adjacent default preference on both axes`() {
        let spacing = ViewSpacing()

        #expect(spacing.distance(to: .zero, along: .horizontal) == 2)
        #expect(ViewSpacing.zero.distance(to: spacing, along: .horizontal) == 2)
        #expect(spacing.distance(to: .zero, along: .vertical) == 1)
        #expect(ViewSpacing.zero.distance(to: spacing, along: .vertical) == 1)
    }

    @Test
    func `union changes only the selected edges and preserves the receiver`() {
        let spacing = ViewSpacing()
        let horizontalSpacing = ViewSpacing.zero.union(
            spacing,
            edges: .horizontal
        )

        #expect(horizontalSpacing.distance(to: .zero, along: .horizontal) == 2)
        #expect(horizontalSpacing.distance(to: .zero, along: .vertical) == 0)
        #expect(ViewSpacing.zero.distance(to: .zero, along: .horizontal) == 0)
    }

    @Test
    func `formUnion mutates only the selected edges`() {
        let spacing = ViewSpacing()
        var verticalSpacing = ViewSpacing.zero

        verticalSpacing.formUnion(spacing, edges: .vertical)

        #expect(verticalSpacing.distance(to: .zero, along: .horizontal) == 0)
        #expect(verticalSpacing.distance(to: .zero, along: .vertical) == 1)
    }

    @Test
    func `LayoutSubview exposes a primitive view's spacing`() {
        let probe = SubviewSpacingProbe()

        _ = ViewResolver.block(
            from: SubviewSpacingProbeLayout(probe: probe) {
                Text("A")
            }
        )

        #expect(probe.horizontal == 2)
        #expect(probe.vertical == 1)
    }

    @Test
    func `Layout spacing shares its cache with measurement`() {
        let probe = LayoutSpacingCacheProbe()

        _ = ViewResolver.block(
            from: LayoutSpacingCacheLayout(probe: probe) {
                Text("A")
            }
        )

        #expect(probe.valueSeenByMeasurement == 1)
    }

    @Test
    func `custom zero spacing survives a frame and AnyView erasure`() {
        let first = AnyView(
            ZeroSpacingLayout() {
                Text("A")
            }
            .frame(width: 1, height: 1)
        )
        let second = AnyView(
            ZeroSpacingLayout() {
                Text("B")
            }
            .frame(width: 1, height: 1)
        )

        let block = ViewResolver.block(
            from: HStack {
                first
                second
            }
        )

        #expect(block?.lines == ["AB"])
    }

    @Test
    func `ZStack and Grid retain default spacing around zero-spacing children`() {
        let layered = ZStack {
            ZeroSpacingLayout() {
                Text("A")
            }
        }
        let grid = Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ZeroSpacingLayout() {
                    Text("B")
                }
            }
        }

        let block = ViewResolver.block(
            from: HStack {
                layered
                grid
                ZeroSpacingLayout() {
                    Text("C")
                }
            }
        )

        #expect(block?.lines == ["A  B  C"])
    }
}

private nonisolated final class SubviewSpacingProbe: @unchecked Sendable {

    var horizontal: Int?

    var vertical: Int?
}

private struct SubviewSpacingProbeLayout: Layout {

    let probe: SubviewSpacingProbe

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        guard let subview = subviews.first else {
            return Size()
        }
        let spacing = subview.spacing
        probe.horizontal = spacing.distance(to: spacing, along: .horizontal)
        probe.vertical = spacing.distance(to: spacing, along: .vertical)
        return subview.sizeThatFits(proposal)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: bounds.origin,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}

private nonisolated final class LayoutSpacingCacheProbe: @unchecked Sendable {

    var valueSeenByMeasurement: Int?
}

private struct LayoutSpacingCacheLayout: Layout {

    let probe: LayoutSpacingCacheProbe

    func makeCache(subviews: Subviews) -> Int {
        0
    }

    func spacing(
        subviews: Subviews,
        cache: inout Int
    ) -> ViewSpacing {
        cache += 1
        return ViewSpacing()
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Int
    ) -> Size {
        probe.valueSeenByMeasurement = cache
        return subviews.first?.sizeThatFits(proposal) ?? Size()
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Int
    ) {
        subviews.first?.place(
            at: bounds.origin,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}

private struct ZeroSpacingLayout: Layout {

    func spacing(
        subviews: Subviews,
        cache: inout ()
    ) -> ViewSpacing {
        .zero
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        subviews.first?.sizeThatFits(proposal) ?? Size()
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: bounds.origin,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}
