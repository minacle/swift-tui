import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Hover Tracking")
struct HoverTrackingTests {

    @Test
    func `attaching hover handlers leaves rendering unchanged and does not invoke them`() {
        let runtime = StateRuntime()
        let hoverProbe = HoverProbe()

        let block = runtime.block(
            from: Text("A")
                .onHover {
                    hoverProbe.record($0 ? "enter" : "exit")
                }
                .onContinuousHover { phase in
                    hoverProbe.record(String(describing: phase))
                }
        )

        #expect(block?.text == "A")
        #expect(hoverProbe.events.isEmpty)
    }

    @Test
    func `onHover reports one entry and one exit while ignoring movement within the same region`() {
        let runtime = StateRuntime()
        let hoverProbe = HoverProbe()
        let view = Text("AB")
            .onHover {
                hoverProbe.record($0 ? "enter" : "exit")
            }

        _ = runtime.block(from: view)

        dispatchHover(to: runtime, column: 1, row: 1)
        dispatchHover(to: runtime, column: 2, row: 1)
        dispatchHover(to: runtime, column: 3, row: 1)
        dispatchHover(to: runtime, column: 4, row: 1, expecting: .ignored)

        #expect(hoverProbe.events == ["enter", "exit"])
    }

    @Test
    func `continuous hover reports each active location and a single ended phase on exit`() {
        let runtime = StateRuntime()
        let hoverProbe = HoverProbe()
        let view = Text("ABC")
            .onContinuousHover(coordinateSpace: .local) { phase in
                hoverProbe.record(phase)
            }

        _ = runtime.block(from: view)

        dispatchHover(to: runtime, column: 1, row: 1)
        dispatchHover(to: runtime, column: 3, row: 1)
        dispatchHover(to: runtime, column: 4, row: 1)

        #expect(
            hoverProbe.phases == [
                .active(Point(column: 0, row: 0)),
                .active(Point(column: 2, row: 0)),
                .ended,
            ]
        )
    }

    @Test
    func `continuous hover converts pointer positions into local, global, and named coordinate spaces`() {
        let runtime = StateRuntime()
        let locationProbe = TapLocationProbe()
        let view = HStack(spacing: 0) {
            Text("..")
            VStack(alignment: .leading, spacing: 0) {
                Text("x")
                Text("ABCD")
                    .frame(width: 2)
                    .onContinuousHover(coordinateSpace: .local) { phase in
                        if case .active(let location) = phase {
                            locationProbe.record("local", location)
                        }
                    }
                    .onContinuousHover(coordinateSpace: .global) { phase in
                        if case .active(let location) = phase {
                            locationProbe.record("global", location)
                        }
                    }
                    .onContinuousHover(coordinateSpace: .named("stack")) { phase in
                        if case .active(let location) = phase {
                            locationProbe.record("named", location)
                        }
                    }
            }
            .coordinateSpace(.named("stack"))
        }

        _ = runtime.block(from: view)

        dispatchHover(to: runtime, column: 4, row: 2)

        #expect(
            locationProbe.events == [
                TapLocationEvent(name: "named", location: Point(column: 1, row: 1)),
                TapLocationEvent(name: "global", location: Point(column: 3, row: 1)),
                TapLocationEvent(name: "local", location: Point(column: 1, row: 0)),
            ]
        )
    }

    @Test
    func `moving between a child and its parent does not exit and reenter the parent hover region`() {
        let runtime = StateRuntime()
        let hoverProbe = HoverProbe()
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("A")
                .onHover {
                    hoverProbe.record($0 ? "child-enter" : "child-exit")
                }
            Text("B")
        }
        .onHover {
            hoverProbe.record($0 ? "parent-enter" : "parent-exit")
        }

        _ = runtime.block(from: view)

        dispatchHover(to: runtime, column: 1, row: 2)
        dispatchHover(to: runtime, column: 1, row: 1)
        dispatchHover(to: runtime, column: 1, row: 2)
        dispatchHover(to: runtime, column: 2, row: 2)

        #expect(
            hoverProbe.events == [
                "parent-enter",
                "child-enter",
                "child-exit",
                "parent-exit",
            ]
        )
    }

    @Test
    func `a frame clips the hover region of its descendant`() {
        let runtime = StateRuntime()
        let hoverProbe = HoverProbe()
        let view = Text("ABCD")
            .onHover {
                hoverProbe.record($0 ? "enter" : "exit")
            }
            .frame(width: 2)

        _ = runtime.block(from: view)

        dispatchHover(to: runtime, column: 2, row: 1)
        dispatchHover(to: runtime, column: 3, row: 1)

        #expect(hoverProbe.events == ["enter", "exit"])
    }

    @Test
    func `hover entry and exit mutations each invalidate and rerender view state`() {
        let runtime = StateRuntime()
        let view = HoverGestureStateMutationView()

        #expect(runtime.block(from: view)?.text == "false:0")

        dispatchHover(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "true:1")

        dispatchHover(to: runtime, column: 10, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "false:1")
    }

    @Test
    func `a child hover callback can directly mutate and rerender parent state`() {
        let runtime = StateRuntime()
        let view = ParentCallbackDirectStateMutationHoverView()

        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Hover", "empty"])

        dispatchHover(to: runtime, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.runs.map(\.text) == ["Hover", "updated"])
    }
}
