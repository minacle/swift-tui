import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

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
    func `the innermost default tap handler alone reports its location at the same view path`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = Text("AB")
            .onTapGesture(coordinateSpace: .local) { location in
                locationProbe.record("inner", location)
            }
            .onTapGesture(coordinateSpace: .global) { location in
                locationProbe.record("middle", location)
            }
            .onTapGesture(coordinateSpace: .local) { location in
                locationProbe.record("outer", location)
            }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 2, row: 1)

        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "inner", location: Point(column: 1, row: 0))
            ]
        )
    }

    @Test
    func `an innermost single tap prevents an outer double tap from accumulating`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Text("A")
            .onTapGesture(count: 1) {
                tapProbe.record("inner-one")
            }
            .onTapGesture(count: 2) {
                tapProbe.record("outer-two")
            }
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.1))

        #expect(tapProbe.events == ["inner-one", "inner-one"])
    }

    @Test
    func `an outer single tap runs only after an innermost double tap fails`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Text("A")
            .onTapGesture(count: 2) {
                tapProbe.record("inner-two")
            }
            .onTapGesture(count: 1) {
                tapProbe.record("outer-one")
            }
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        #expect(tapProbe.events.isEmpty)
        #expect(
            runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(0.51)) == .handled
        )

        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(1))
        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(1.1))

        #expect(tapProbe.events == ["outer-one", "inner-two"])
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
                Text("AB")
                    .onTapGesture(coordinateSpace: .local) { location in
                        locationProbe.record("local", location)
                    }
                Text("CD")
                    .onTapGesture(coordinateSpace: .global) { location in
                        locationProbe.record("global", location)
                    }
            }
        }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 4, row: 2)
        dispatchClick(to: runtime, column: 6, row: 2)

        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "local", location: Point(column: 1, row: 0)),
                TapLocationEvent(name: "global", location: Point(column: 5, row: 1)),
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
    func `an innermost triple tap recognizes before outer lower-count handlers`() {
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
    func `an innermost triple tap falls back to the outer handler matching the timed-out count`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = CountedTapGestureView(tapProbe: tapProbe)
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        #expect(tapProbe.events.isEmpty)
        #expect(
            runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(0.51)) == .handled
        )
        #expect(tapProbe.events == ["one"])

        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(1))
        dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(1.1))

        #expect(tapProbe.events == ["one"])
        #expect(
            runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(1.61)) == .handled
        )
        #expect(tapProbe.events == ["one", "two"])
    }

    @Test
    func `a timed-out inner tap sequence reports its last location to the matching outer handler`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = Text("ABCD")
            .onTapGesture(count: 3, coordinateSpace: .local) { location in
                locationProbe.record("three", location)
            }
            .onTapGesture(count: 2, coordinateSpace: .local) { location in
                locationProbe.record("two", location)
            }
            .onTapGesture(count: 1, coordinateSpace: .local) { location in
                locationProbe.record("one", location)
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
                PointerPress(button: .right, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .up)
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
