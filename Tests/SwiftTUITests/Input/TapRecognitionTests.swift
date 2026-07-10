import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Tap Recognition")
struct TapRecognitionTests {

    @Test
    func `attaching a tap handler leaves rendering unchanged and does not invoke it`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()

        let block = runtime.block(
            from: Text("A")
                .onTapGesture {
                    tapProbe.record("tap")
                }
        )

        #expect(block?.text == "A")
        #expect(tapProbe.events.isEmpty)
    }

    @Test
    func `a tap handler can mutate state and trigger an updated render`() {
        let runtime = StateRuntime()
        let view = TapGestureStateMutationView()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(runtime.block(from: view)?.text == "0")

        dispatchClick(to: runtime, column: 1, row: 1, at: date)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1")
    }

    @Test
    func `a child tap callback can directly mutate and rerender parent state`() {
        let runtime = StateRuntime()
        let view = ParentCallbackDirectStateMutationTapView()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Tap", "empty"])

        dispatchClick(to: runtime, column: 1, row: 1, at: date)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Tap", "updated"])
    }

    @Test
    func `tap hit testing maps stacked views to their rendered row and column regions`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = StackTapGestureView(tapProbe: tapProbe)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1)
        dispatchClick(to: runtime, column: 3, row: 1)
        dispatchClick(to: runtime, column: 1, row: 2)
        dispatchClick(to: runtime, column: 2, row: 1, expecting: .ignored)

        #expect(tapProbe.events == ["left", "right", "bottom"])
    }

    @Test
    func `nested tap regions dispatch only to the deepest matching handler`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = NestedTapGestureView(tapProbe: tapProbe)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(tapProbe.events == ["child"])
    }

    @Test
    func `a frame clips the tap region of its descendant`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Text("ABCD")
            .onTapGesture {
                tapProbe.record("tap")
            }
            .frame(width: 2)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 2, row: 1)
        dispatchClick(to: runtime, column: 3, row: 1, expecting: .ignored)

        #expect(tapProbe.events == ["tap"])
    }

    @Test
    func `tap handlers convert pointer positions into local and global coordinates`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("top")
            HStack(spacing: 0) {
                Text("..")
                Text("ABCD")
                    .frame(width: 2)
                    .onTapGesture(coordinateSpace: .local) { location in
                        locationProbe.record("local", location)
                    }
                    .onTapGesture(coordinateSpace: .global) { location in
                        locationProbe.record("global", location)
                    }
            }
        }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 4, row: 2)

        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "global", location: Point(column: 3, row: 1)),
                TapLocationEvent(name: "local", location: Point(column: 1, row: 0)),
            ]
        )
    }

    @Test
    func `a tap handler reports positions in a named ancestor coordinate space`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = HStack(spacing: 0) {
            Text("..")
            VStack(alignment: .leading, spacing: 0) {
                Text("x")
                Text("AB")
                    .onTapGesture(coordinateSpace: .named("stack")) { location in
                        locationProbe.record("named", location)
                    }
            }
            .coordinateSpace(.named("stack"))
        }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 4, row: 2)

        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "named", location: Point(column: 1, row: 1))
            ]
        )
    }

    @Test
    func `when coordinate-space names repeat, tap locations use the nearest matching ancestor`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = HStack(spacing: 0) {
            Text("..")
            VStack(alignment: .leading, spacing: 0) {
                Text("x")
                Text("AB")
                    .onTapGesture(coordinateSpace: .named("space")) { location in
                        locationProbe.record("named", location)
                    }
            }
            .coordinateSpace(.named("space"))
        }
        .coordinateSpace(.named("space"))

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 4, row: 2)

        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "named", location: Point(column: 1, row: 1))
            ]
        )
    }

    @Test
    func `named tap coordinates remain correct through padding, framing, alignment, and layering`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = ZStack(alignment: .topLeading) {
            Text("....")
            Text("AB")
                .onTapGesture(coordinateSpace: .named("target")) { location in
                    locationProbe.record("named", location)
                }
                .coordinateSpace(.named("target"))
                .padding(.leading, 1)
                .frame(width: 4, alignment: .trailing)
        }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 4, row: 1)

        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "named", location: Point(column: 1, row: 0))
            ]
        )
    }

    @Test
    func `a tap sequence waits while a higher registered tap count remains reachable`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = CountedTapGestureView(tapProbe: tapProbe)
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        #expect(tapProbe.events.isEmpty)

        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.1))
        #expect(tapProbe.events.isEmpty)

        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.2))
        #expect(tapProbe.events == ["three"])
    }

    @Test
    func `after a timeout, a partial tap sequence performs the highest reached registered count`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = CountedTapGestureView(tapProbe: tapProbe)
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.1))

        #expect(tapProbe.events.isEmpty)
        #expect(
            runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(0.61)) == .handled
        )
        #expect(tapProbe.events == ["two"])
    }

    @Test
    func `after a timeout, a partial tap sequence invokes the highest reached handler with the last tap location`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = Text("ABCD")
            .onTapGesture(count: 1, coordinateSpace: .local) { location in
                locationProbe.record("one", location)
            }
            .onTapGesture(count: 2, coordinateSpace: .local) { location in
                locationProbe.record("two", location)
            }
            .onTapGesture(count: 3, coordinateSpace: .local) { location in
                locationProbe.record("three", location)
            }
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        dispatchClick(to: runtime, column: 3, row: 1, at: date.addingTimeInterval(0.1))

        #expect(locationProbe.events.isEmpty)
        #expect(
            runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(0.61)) == .handled
        )
        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "two", location: Point(column: 2, row: 0))
            ]
        )
    }

    @Test
    func `tap recognition rejects non-left buttons and releases outside the pressed region`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Text("A")
            .onTapGesture {
                tapProbe.record("tap")
            }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerEvent(button: .right, column: 1, row: 1, phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 2, row: 1, phase: .up)
            ) == .ignored
        )

        #expect(tapProbe.events.isEmpty)
    }

    @Test
    func `a disabled named-coordinate tap handler ignores clicks`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = Text("A")
            .onTapGesture(coordinateSpace: .named("disabled")) { location in
                locationProbe.record("tap", location)
            }
            .coordinateSpace(.named("disabled"))
            .disabled(true)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)

        #expect(locationProbe.events.isEmpty)
    }
}
