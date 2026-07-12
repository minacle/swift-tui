import Testing
@testable import SwiftTUIEssentials

@Suite("Pointer Drags")
struct PointerDragTests {

    @Test
    func `a pointer drag captures motion and release beyond its bounds`() {
        let runtime = StateRuntime()
        let probe = PointerDragProbe()
        let view = Text("AB")
            .onPointerDrag { probe.values.append($0) }

        _ = runtime.block(from: view)
        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)) == .handled)
        #expect(runtime.dispatch(PointerMotion(button: .left, location: Point(column: 7, row: 3), modifiers: [])) == .handled)
        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 7, row: 3), phase: .up)) == .handled)

        #expect(probe.values.map(\.phase) == [.began, .changed, .ended])
        #expect(probe.values.map(\.startLocation) == [Point(column: 0, row: 0), Point(column: 0, row: 0), Point(column: 0, row: 0)])
        #expect(probe.values.map(\.location) == [Point(column: 0, row: 0), Point(column: 7, row: 3), Point(column: 7, row: 3)])
    }

    @Test
    func `a new pointer sequence cancels the captured drag`() {
        let runtime = StateRuntime()
        let probe = PointerDragProbe()
        _ = runtime.block(from: Text("A").onPointerDrag { probe.values.append($0) })

        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)) == .handled)
        #expect(runtime.dispatch(PointerPress(button: .right, location: Point(column: 0, row: 0), phase: .down)) == .ignored)

        #expect(probe.values.map(\.phase) == [.began, .cancelled])
    }

    @Test
    func `a captured pointer sequence suppresses a competing tap`() {
        let runtime = StateRuntime()
        let probe = PointerDragProbe()
        var taps = 0
        let view = Text("A")
            .onTapGesture { taps += 1 }
            .onPointerDrag { probe.values.append($0) }

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(taps == 0)
        #expect(probe.values.map(\.phase) == [.began, .ended])
    }

    @Test
    func `removing the drag target cancels its captured sequence`() {
        let runtime = StateRuntime()
        let probe = PointerDragProbe()
        _ = runtime.block(from: Text("A").onPointerDrag { probe.values.append($0) })
        #expect(runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)) == .handled)

        _ = runtime.block(from: Text("replacement"))

        #expect(probe.values.map(\.phase) == [.began, .cancelled])
    }

    @Test
    func `global pointer-drag locations remain relative to the rendered root`() {
        let runtime = StateRuntime()
        let probe = PointerDragProbe()
        let view = Text("A")
            .padding(.leading, 2)
            .onPointerDrag(coordinateSpace: .global) { probe.values.append($0) }
        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 3, row: 1)

        #expect(probe.values.map(\.location) == [Point(column: 2, row: 0), Point(column: 2, row: 0)])
    }
}

private final class PointerDragProbe {
    var values: [PointerDrag] = []
}
