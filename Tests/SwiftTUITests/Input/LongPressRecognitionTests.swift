import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Long Press Recognition")
struct LongPressRecognitionTests {

    @Test
    func `attaching a long-press handler leaves rendering unchanged and does not invoke it`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()

        let block = runtime.block(
            from: Text("A")
                .onLongPressGesture {
                    tapProbe.record("long")
                }
        )

        #expect(block?.text == "A")
        #expect(tapProbe.events.isEmpty)
    }

    @Test
    func `a long press begins on pointer-down, fires at its minimum duration, and ends on release`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onLongPressGesture(
                minimumDuration: 0.5,
                maximumDistance: Size(columns: 10, rows: 10),
                perform: {
                    tapProbe.record("long")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "pressing" : "ended")
                }
            )

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down),
                at: date
            ) == .handled
        )
        #expect(runtime.nextLongPressDeadline == date.addingTimeInterval(0.5))
        #expect(tapProbe.events == ["pressing"])
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.49)) == .ignored)
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.5)) == .handled)
        #expect(tapProbe.events == ["pressing", "long"])
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .up),
                at: date.addingTimeInterval(0.6)
            ) == .handled
        )
        #expect(tapProbe.events == ["pressing", "long", "ended"])
    }

    @Test
    func `releasing before the minimum duration cancels the long press without performing it`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onLongPressGesture(
                minimumDuration: 0.5,
                perform: {
                    tapProbe.record("long")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "pressing" : "ended")
                }
            )

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down),
                at: date
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .up),
                at: date.addingTimeInterval(0.1)
            ) == .handled
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.6)) == .ignored)
        #expect(tapProbe.events == ["pressing", "ended"])
    }

    @Test
    func `moving beyond the maximum distance cancels the pending long press`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("ABCDE")
            .onLongPressGesture(
                minimumDuration: 0.5,
                maximumDistance: Size(columns: 2, rows: 0),
                perform: {
                    tapProbe.record("long")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "pressing" : "ended")
                }
            )

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down),
                at: date
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 4, row: 1, phase: .motion),
                at: date.addingTimeInterval(0.1)
            ) == .handled
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.6)) == .ignored)
        #expect(tapProbe.events == ["pressing", "ended"])
    }

    @Test
    func `long-press hit testing selects the deepest region and excludes content clipped by a frame`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = VStack {
            Text("ABCD")
                .frame(width: 2)
                .onLongPressGesture(minimumDuration: 0.1) {
                    tapProbe.record("child")
                }
        }
        .onLongPressGesture(minimumDuration: 0.1) {
            tapProbe.record("parent")
        }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 2, row: 1, phase: .down),
                at: date
            ) == .handled
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 2, row: 1, phase: .up),
                at: date.addingTimeInterval(0.2)
            ) == .handled
        )

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 3, row: 1, phase: .down),
                at: date.addingTimeInterval(1)
            ) == .ignored
        )
        #expect(tapProbe.events == ["child"])
    }

    @Test
    func `a recognized long press suppresses the competing tap on release`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onLongPressGesture(minimumDuration: 0.1) {
                tapProbe.record("long")
            }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        #expect(tapProbe.events == ["tap"])

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down),
                at: date.addingTimeInterval(1)
            ) == .handled
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(1.1)) == .handled)
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .up),
                at: date.addingTimeInterval(1.2)
            ) == .handled
        )
        #expect(tapProbe.events == ["tap", "long"])
    }

    @Test
    func `pressing, recognition, and release mutations each invalidate and rerender view state`() {
        let runtime = StateRuntime()
        let view = LongPressGestureStateMutationView()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(runtime.block(from: view)?.text == "0:false")

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down),
                at: date
            ) == .handled
        )
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "0:true")

        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1:true")

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .up),
                at: date.addingTimeInterval(0.2)
            ) == .handled
        )
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1:false")
    }

    @Test
    func `a child long-press callback can directly mutate and rerender parent state`() {
        let runtime = StateRuntime()
        let view = ParentCallbackDirectStateMutationLongPressView()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down),
                at: date
            ) == .handled
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
    }
}
