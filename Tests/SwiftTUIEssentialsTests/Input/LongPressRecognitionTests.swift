import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

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
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(runtime.nextLongPressDeadline == date.addingTimeInterval(0.5))
        #expect(tapProbe.events == ["pressing"])
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.49)) == .ignored)
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.5)) == .handled)
        #expect(tapProbe.events == ["pressing", "long"])
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(0.6)
            ) == .ignored
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
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(0.1)
            ) == .ignored
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
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 3, row: 0), modifiers: []),
                at: date.addingTimeInterval(0.1)
            ) == .ignored
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.6)) == .ignored)
        #expect(tapProbe.events == ["pressing", "ended"])
    }

    @Test
    func `equal-duration long presses run only the innermost action and publish pressing changes outermost first`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onLongPressGesture(
                minimumDuration: 0,
                perform: {
                    tapProbe.record("inner-action")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "inner-true" : "inner-false")
                }
            )
            .onLongPressGesture(
                minimumDuration: 0,
                perform: {
                    tapProbe.record("middle-action")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "middle-true" : "middle-false")
                }
            )
            .onLongPressGesture(
                minimumDuration: 0,
                perform: {
                    tapProbe.record("outer-action")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "outer-true" : "outer-false")
                }
            )

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(
            tapProbe.events == [
                "outer-true",
                "middle-true",
                "inner-true",
                "inner-action",
            ]
        )
        #expect(runtime.nextLongPressDeadline == nil)
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(1)) == .ignored)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(1)
            ) == .ignored
        )
        #expect(
            tapProbe.events == [
                "outer-true",
                "middle-true",
                "inner-true",
                "inner-action",
                "outer-false",
                "middle-false",
                "inner-false",
            ]
        )
    }

    @Test
    func `an inner tap runs after an outer long press ends without recognizing`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onTapGesture {
                tapProbe.record("inner-tap")
            }
            .onLongPressGesture(
                minimumDuration: 0,
                perform: {
                    tapProbe.record("outer-action")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "outer-true" : "outer-false")
                }
            )

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(tapProbe.events == ["outer-true"])
        #expect(runtime.nextLongPressDeadline == nil)
        #expect(runtime.dispatchExpiredLongPressActions(at: date) == .ignored)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(0.1)
            ) == .ignored
        )
        #expect(tapProbe.events == ["outer-true", "outer-false", "inner-tap"])
    }

    @Test
    func `an outer tap runs before a timed-out inner long press ends`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onLongPressGesture(
                minimumDuration: 10,
                perform: {
                    tapProbe.record("inner-action")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "inner-true" : "inner-false")
                }
            )
            .onTapGesture {
                tapProbe.record("outer-tap")
            }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(tapProbe.events == ["inner-true"])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(0.1)
            ) == .ignored
        )
        #expect(tapProbe.events == ["inner-true", "outer-tap", "inner-false"])
    }

    @Test
    func `an earlier innermost long press prevents a later outer action`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onLongPressGesture(minimumDuration: 0.1) {
                tapProbe.record("inner")
            }
            .onLongPressGesture(minimumDuration: 0.2) {
                tapProbe.record("outer")
            }

        _ = runtime.block(from: view)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )

        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
        #expect(tapProbe.events == ["inner"])
        #expect(runtime.nextLongPressDeadline == nil)
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.2)) == .ignored)
        #expect(tapProbe.events == ["inner"])
    }

    @Test
    func `an earlier outer long press prevents a later innermost action`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onLongPressGesture(minimumDuration: 0.2) {
                tapProbe.record("inner")
            }
            .onLongPressGesture(minimumDuration: 0.1) {
                tapProbe.record("outer")
            }

        _ = runtime.block(from: view)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )

        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
        #expect(tapProbe.events == ["outer"])
        #expect(runtime.nextLongPressDeadline == nil)
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.2)) == .ignored)
        #expect(tapProbe.events == ["outer"])
    }

    @Test
    func `movement rejects one long press while a surviving candidate still recognizes`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("AB")
            .onLongPressGesture(
                minimumDuration: 0.5,
                maximumDistance: .zero,
                perform: {
                    tapProbe.record("inner-action")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "inner-true" : "inner-false")
                }
            )
            .onLongPressGesture(
                minimumDuration: 0.5,
                maximumDistance: Size(columns: 1, rows: 0),
                perform: {
                    tapProbe.record("outer-action")
                },
                onPressingChanged: {
                    tapProbe.record($0 ? "outer-true" : "outer-false")
                }
            )

        _ = runtime.block(from: view)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 1, row: 0), modifiers: []),
                at: date.addingTimeInterval(0.1)
            ) == .ignored
        )
        #expect(tapProbe.events == ["outer-true", "inner-true", "inner-false"])

        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.5)) == .handled)
        #expect(tapProbe.events == ["outer-true", "inner-true", "inner-false", "outer-action"])
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .up),
                at: date.addingTimeInterval(0.6)
            ) == .ignored
        )
        #expect(
            tapProbe.events == [
                "outer-true",
                "inner-true",
                "inner-false",
                "outer-action",
                "outer-false",
            ]
        )
    }

    @Test
    func `long-press hit testing selects the deepest region and excludes content clipped by a frame`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = VStack(spacing: 0) {
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
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .up),
                at: date.addingTimeInterval(0.2)
            ) == .ignored
        )

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 2, row: 0), phase: .down),
                at: date.addingTimeInterval(1)
            ) == .ignored
        )
        #expect(tapProbe.events == ["child"])
    }

    @Test
    func `a recognized inner long press suppresses an outer tap on release`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Text("A")
            .onLongPressGesture(minimumDuration: 0.1) {
                tapProbe.record("long")
            }
            .onTapGesture {
                tapProbe.record("tap")
            }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1, at: date)
        #expect(tapProbe.events == ["tap"])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date.addingTimeInterval(1)
            ) == .ignored
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(1.1)) == .handled)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(1.2)
            ) == .ignored
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
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "0:true")

        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1:true")

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(0.2)
            ) == .ignored
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
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
    }
}
