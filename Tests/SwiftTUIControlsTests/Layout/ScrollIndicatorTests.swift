import Testing
@testable import SwiftTUIEssentials
@testable import SwiftTUIControls

@Suite("Scroll Indicators")
struct ScrollIndicatorTests {

    @Test
    func `horizontal indicators draw proportional thumbs at the start and end`() {
        #expect(renderHorizontal(offset: 0) == "╺━╾─╴")
        #expect(renderHorizontal(offset: 5) == "╶─╼━╸")
    }

    @Test
    func `vertical indicators draw proportional thumbs at the start and end`() {
        #expect(renderVertical(offset: 0) == ["╻", "┃", "╿", "│", "╵"])
        #expect(renderVertical(offset: 5) == ["╷", "│", "╽", "┃", "╹"])
    }

    @Test
    func `one-cell indicators use a full heavy line`() {
        let configuration = makeConfiguration(offset: 0, viewport: 1, content: 2)

        #expect(ViewResolver.block(from: HorizontalScrollIndicator(configuration: configuration))?.text == "━")
        #expect(ViewResolver.block(from: VerticalScrollIndicator(configuration: configuration))?.text == "┃")
    }

    @Test
    func `pressing the track moves one viewport and balances interaction callbacks`() {
        let runtime = StateRuntime()
        let probe = ScrollIndicatorProbe()
        let configuration = makeConfiguration(offset: 0, probe: probe)
        _ = runtime.block(from: HorizontalScrollIndicator(configuration: configuration))

        dispatchClick(to: runtime, column: 5, row: 1)

        #expect(probe.offsets == [5])
        #expect(probe.interactions == [true, false])
    }

    @Test
    func `dragging a thumb beyond the track clamps to the last offset`() {
        let runtime = StateRuntime()
        let probe = ScrollIndicatorProbe()
        let configuration = makeConfiguration(offset: 0, probe: probe)
        _ = runtime.block(from: HorizontalScrollIndicator(configuration: configuration))

        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)) == .handled)
        #expect(runtime.dispatch(PointerMotion(button: .left, location: Point(column: 19, row: 0), modifiers: [])) == .handled)
        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 19, row: 0), phase: .up)) == .handled)

        #expect(probe.offsets.last == 5)
        #expect(probe.interactions == [true, false])
    }

    @Test
    func `dragging from a mixed thumb cell preserves its heavy-half grab position`() {
        let runtime = StateRuntime()
        let probe = ScrollIndicatorProbe()
        let configuration = makeConfiguration(offset: 0, probe: probe)
        _ = runtime.block(from: HorizontalScrollIndicator(configuration: configuration))

        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .down)) == .handled)
        #expect(runtime.dispatch(PointerMotion(button: .left, location: Point(column: 3, row: 0), modifiers: [])) == .handled)
        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 3, row: 0), phase: .up)) == .handled)

        #expect(probe.offsets == [4])
    }

    private func renderHorizontal(offset: Int) -> String? {
        ViewResolver.block(
            from: HorizontalScrollIndicator(configuration: makeConfiguration(offset: offset))
        )?.text
    }

    private func renderVertical(offset: Int) -> [String]? {
        ViewResolver.block(
            from: VerticalScrollIndicator(configuration: makeConfiguration(offset: offset))
        )?.lines
    }

    private func makeConfiguration(
        offset: Int,
        viewport: Int = 5,
        content: Int = 10,
        probe: ScrollIndicatorProbe = ScrollIndicatorProbe()
    ) -> ScrollIndicatorConfiguration {
        ScrollIndicatorConfiguration(
            offset: offset,
            maximumOffset: max(content - viewport, 0),
            viewportLength: viewport,
            contentLength: content,
            scrollAction: { probe.offsets.append($0) },
            interactionAction: { probe.interactions.append($0) }
        )
    }
}

private final class ScrollIndicatorProbe {
    var offsets: [Int] = []
    var interactions: [Bool] = []
}
