import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Type-Erased Layouts")
struct AnyLayoutTests {

    @Test
    func `AnyLayout switches between horizontal and vertical built-in layouts`() {
        let horizontal = AnyLayout(HStackLayout(spacing: 0))
        let vertical = AnyLayout(VStackLayout(spacing: 0))

        let horizontalBlock = ViewResolver.block(
            from: horizontal {
                Text("A")
                Text("B")
            }
        )
        let verticalBlock = ViewResolver.block(
            from: vertical {
                Text("A")
                Text("B")
            }
        )

        #expect(horizontalBlock?.lines == ["AB"])
        #expect(verticalBlock?.lines == ["A", "B"])
    }

    @Test
    func `AnyLayout forwards the wrapped stack orientation to Divider and Spacer`() {
        let horizontal = AnyLayout(HStackLayout(spacing: 0))
        let vertical = AnyLayout(VStackLayout(spacing: 0))
        let horizontalBlock = ViewResolver.block(
            from: horizontal {
                Divider()
                Spacer()
            },
            in: RenderProposal(columns: 3, rows: 3)
        )
        let verticalBlock = ViewResolver.block(
            from: vertical {
                Divider()
                Spacer()
            },
            in: RenderProposal(columns: 3, rows: 3)
        )

        #expect(horizontalBlock?.lines == ["│  ", "│  ", "│  "])
        #expect(verticalBlock?.lines == ["───", "   ", "   "])
    }

    @Test
    func `AnyLayout forwards GridLayout row structure and grid modifiers`() {
        let layout = AnyLayout(
            GridLayout(horizontalSpacing: 0, verticalSpacing: 0)
        )
        let block = ViewResolver.block(
            from: layout {
                GridRow {
                    Text("A")
                    Text("BB")
                }
                GridRow {
                    Text("CCC")
                        .gridCellColumns(2)
                }
            }
        )

        #expect(block?.lines == ["ABB", "CCC"])
    }

    @Test
    func `AnyLayout forwards a custom layout cache across render passes`() {
        let runtime = StateRuntime()
        let probe = AnyLayoutCacheProbe()
        let view = AnyLayout(AnyLayoutCacheProbeLayout(probe: probe)) {
            Text("A")
        }

        #expect(runtime.block(from: view)?.text == "A")
        #expect(probe.events == ["make", "size 1", "place 2"])

        #expect(runtime.block(from: view)?.text == "A")
        #expect(probe.events == [
            "make",
            "size 1",
            "place 2",
            "update 2",
            "size 12",
            "place 13",
        ])
    }

    @Test
    func `AnyLayout forwards custom spacing and explicit alignment`() {
        let first = AnyLayout(AnyLayoutForwardingLayout()) {
            Text("A")
        }
        let second = AnyLayout(AnyLayoutForwardingLayout()) {
            Text("B")
        }
        let block = ViewResolver.block(
            from: VStack(alignment: .anyLayoutMarker, spacing: 0) {
                HStack {
                    first
                    second
                }
                Text("C")
                    .alignmentGuide(HorizontalAlignment.anyLayoutMarker) { _ in 0 }
            }
        )

        #expect(block?.lines == ["  A  B", "   C  "])
    }

    @Test
    func `AnyLayout replaces an incompatible underlying cache`() {
        let runtime = StateRuntime()
        let first = AnyLayoutCacheProbe()
        let second = AnyLayoutCacheProbe()

        _ = runtime.block(
            from: SwitchingCachedAnyLayoutView(
                usesAlternateLayout: false,
                first: first,
                second: second
            )
        )
        _ = runtime.block(
            from: SwitchingCachedAnyLayoutView(
                usesAlternateLayout: true,
                first: first,
                second: second
            )
        )

        #expect(first.events.first == "make")
        #expect(second.events.first == "make")
        #expect(second.events.allSatisfy { !$0.hasPrefix("update") })
    }

    @Test
    func `switching AnyLayout orientation preserves descendant state identity`() {
        let runtime = StateRuntime()
        let probe = AnyLayoutAppearanceProbe()

        #expect(
            runtime.block(
                from: StatefulAnyLayoutView(isVertical: false, probe: probe)
            )?.text == "0"
        )
        #expect(runtime.consumeInvalidation())
        #expect(
            runtime.block(
                from: StatefulAnyLayoutView(isVertical: true, probe: probe)
            )?.text == "1"
        )
        #expect(probe.appearances == 1)
    }
}

private nonisolated final class AnyLayoutCacheProbe: @unchecked Sendable {

    var events: [String] = []
}

private nonisolated enum AnyLayoutMarkerAlignment: AlignmentID {

    static func defaultValue(in context: ViewDimensions) -> Int {
        0
    }
}

private extension HorizontalAlignment {

    nonisolated static let anyLayoutMarker = HorizontalAlignment(
        AnyLayoutMarkerAlignment.self
    )
}

private nonisolated struct AnyLayoutForwardingLayout: Layout {

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
        Size(columns: 3, rows: 1)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: Point(column: bounds.origin.column + 2, row: bounds.origin.row)
        )
    }

    func explicitAlignment(
        of guide: HorizontalAlignment,
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Int? {
        guide == .anyLayoutMarker ? bounds.origin.column + 2 : nil
    }
}

private nonisolated struct AnyLayoutCacheProbeLayout: Layout {

    let probe: AnyLayoutCacheProbe

    func makeCache(subviews: Subviews) -> Int {
        probe.events.append("make")
        return 1
    }

    func updateCache(_ cache: inout Int, subviews: Subviews) {
        probe.events.append("update \(cache)")
        cache += 10
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Int
    ) -> Size {
        probe.events.append("size \(cache)")
        cache += 1
        return subviews.first?.sizeThatFits(proposal) ?? Size()
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Int
    ) {
        probe.events.append("place \(cache)")
        subviews.first?.place(at: bounds.origin, proposal: proposal)
    }
}

private nonisolated struct AlternateAnyLayoutCacheProbeLayout: Layout {

    let probe: AnyLayoutCacheProbe

    func makeCache(subviews: Subviews) -> String {
        probe.events.append("make")
        return "alternate"
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout String
    ) -> Size {
        probe.events.append("size \(cache)")
        return subviews.first?.sizeThatFits(proposal) ?? Size()
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout String
    ) {
        probe.events.append("place \(cache)")
        subviews.first?.place(at: bounds.origin, proposal: proposal)
    }
}

private struct SwitchingCachedAnyLayoutView: View {

    let usesAlternateLayout: Bool

    let first: AnyLayoutCacheProbe

    let second: AnyLayoutCacheProbe

    var body: some View {
        let layout = usesAlternateLayout
            ? AnyLayout(AlternateAnyLayoutCacheProbeLayout(probe: second))
            : AnyLayout(AnyLayoutCacheProbeLayout(probe: first))
        layout {
            Text("A")
        }
    }
}

private nonisolated final class AnyLayoutAppearanceProbe: @unchecked Sendable {

    var appearances = 0
}

private struct StatefulAnyLayoutView: View {

    let isVertical: Bool

    let probe: AnyLayoutAppearanceProbe

    @State private var count = 0

    var body: some View {
        let layout = isVertical
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        layout {
            Text("\(count)")
                .onAppear {
                    probe.appearances += 1
                    count += 1
                }
        }
    }
}
