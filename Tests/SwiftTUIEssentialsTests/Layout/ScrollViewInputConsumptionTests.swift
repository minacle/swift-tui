import Testing
@testable import SwiftTUIEssentials

@Suite("Scroll View Input Consumption")
struct ScrollViewInputConsumptionTests {

    @Test
    func `wheel movement consumes the sample before a later handler`() {
        let runtime = StateRuntime()
        let probe = ScrollInputProbe()
        let view = scrollView(probe: probe)

        #expect(runtime.block(from: view)?.lines == ["A", "B"])

        #expect(
            runtime.dispatch(
                PointerScroll(
                    delta: Size(columns: 0, rows: 1),
                    location: Point(column: 0, row: 0)
                )
            ) == .handled
        )
        #expect(probe.events.isEmpty)
        #expect(runtime.block(from: view)?.lines == ["B", "C"])
    }

    @Test
    func `a wheel sample at the scroll boundary remains available to a later handler`() {
        let runtime = StateRuntime()
        let probe = ScrollInputProbe()
        let view = scrollView(probe: probe)
        let scroll = PointerScroll(
            delta: Size(columns: 0, rows: 1),
            location: Point(column: 0, row: 0)
        )

        _ = runtime.block(from: view)
        #expect(runtime.dispatch(scroll) == .handled)
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(scroll) == .ignored)
        #expect(probe.events == ["later"])
    }

    private func scrollView(probe: ScrollInputProbe) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .frame(width: 1, height: 2)
        .simultaneousInputEvent(
            PointerScrollEvent(.vertical)
                .onRecognized { _ in
                    probe.events.append("later")
                    return .ignored
                }
                .deferred(priority: .lazy)
        )
    }
}

private final class ScrollInputProbe {

    var events: [String] = []
}
