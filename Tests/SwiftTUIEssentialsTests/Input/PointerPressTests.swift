import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Pointer Press Handling")
struct PointerPressTests {

    @Test
    func `the default pointer-press handler matches only left-button down events`() {
        let runtime = StateRuntime()
        let pointerProbe = PointerPressProbe()
        let view = Text("A")
            .onPointerPress {
                pointerProbe.record("default")
                return .handled
            }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .right, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 0, row: 0), modifiers: [])
            ) == .ignored
        )
        #expect(pointerProbe.names == ["default"])
    }

    @Test
    func `a pointer-press handler can opt into both down and up phases`() {
        let runtime = StateRuntime()
        let pointerProbe = PointerPressProbe()
        let view = Text("A")
            .onPointerPress(phases: [.down, .up]) { pointerPress in
                pointerProbe.record("press", pointerPress)
                return .handled
            }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up)
            ) == .handled
        )
        #expect(
            pointerProbe.events.map(\.phase) == [
                .down,
                .up,
            ]
        )
    }

    @Test
    func `a pointer-press handler filtered to right and middle buttons handles both without moving keyboard focus`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<Bool>()
        let keyProbe = KeyPressProbe()
        let pointerProbe = PointerPressProbe()
        let view = PointerPressFocusableView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            pointerProbe: pointerProbe
        )

        _ = runtime.block(from: view)

        #expect(focusProbe.binding?.wrappedValue == false)
        #expect(
            runtime.dispatch(
                PointerPress(button: .right, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .middle, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(keyProbe.events.isEmpty)
        #expect(pointerProbe.events.map(\.button) == [.right, .middle])
        #expect(focusProbe.binding?.wrappedValue == false)
    }

    @Test
    func `pointer-press events preserve modifiers and convert locations into local, global, and named coordinate spaces`() {
        let runtime = StateRuntime()
        let pointerProbe = PointerPressProbe()
        let view = HStack(spacing: 0) {
            Text("..")
            VStack(alignment: .leading, spacing: 0) {
                Text("x")
                Text("ABCD")
                    .frame(width: 2)
                    .onPointerPress(coordinateSpace: .local) { pointerPress in
                        pointerProbe.record("local", pointerPress)
                        return .ignored
                    }
                    .onPointerPress(coordinateSpace: .global) { pointerPress in
                        pointerProbe.record("global", pointerPress)
                        return .ignored
                    }
                    .onPointerPress(coordinateSpace: .named("stack")) { pointerPress in
                        pointerProbe.record("named", pointerPress)
                        return .ignored
                    }
            }
            .coordinateSpace(.named("stack"))
        }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 3, row: 1),
                    modifiers: [.shift, .control],
                    phase: .down
                )
            ) == .ignored
        )
        #expect(
            pointerProbe.events == [
                RecordedPointerPress(
                    name: "named",
                    button: .left,
                    location: Point(column: 1, row: 1),
                    modifiers: [.shift, .control],
                    phase: .down
                ),
                RecordedPointerPress(
                    name: "global",
                    button: .left,
                    location: Point(column: 3, row: 1),
                    modifiers: [.shift, .control],
                    phase: .down
                ),
                RecordedPointerPress(
                    name: "local",
                    button: .left,
                    location: Point(column: 1, row: 0),
                    modifiers: [.shift, .control],
                    phase: .down
                ),
            ]
        )
    }

    @Test
    func `a handling parent prevents an ignored child pointer press from receiving input`() {
        let runtime = StateRuntime()
        let pointerProbe = PointerPressProbe()
        let view = VStack(spacing: 0) {
            Text("A")
                .onPointerPress {
                    pointerProbe.record("child")
                    return .ignored
                }
        }
        .onPointerPress {
            pointerProbe.record("parent")
            return .handled
        }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(pointerProbe.names == ["parent"])
    }

    @Test
    func `an ignored parent pointer press propagates to a handling child`() {
        let runtime = StateRuntime()
        let pointerProbe = PointerPressProbe()
        let view = VStack(spacing: 0) {
            Text("A")
                .onPointerPress {
                    pointerProbe.record("child")
                    return .handled
                }
        }
        .onPointerPress {
            pointerProbe.record("parent")
            return .ignored
        }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )
        #expect(pointerProbe.names == ["parent", "child"])
    }

    @Test
    func `pointer-down on a sibling excludes a descendant onPointerPress outside its hit region`() {
        let runtime = StateRuntime()
        let pointerProbe = PointerPressProbe()
        let view = HStack(spacing: 0) {
            Text("A")
                .onPointerPress {
                    pointerProbe.record("descendant")
                    return .handled
                }
            Text("B")
        }
        .onPointerPress {
            pointerProbe.record("ancestor")
            return .ignored
        }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 1, row: 0),
                    phase: .down
                )
            ) == .ignored
        )
        #expect(pointerProbe.names == ["ancestor"])
    }

    @Test
    func `handling pointer-up prevents a competing tap from completing`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let pointerProbe = PointerPressProbe()
        let view = Text("A")
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onPointerPress(phases: .up) { pointerPress in
                pointerProbe.record("up", pointerPress)
                return .handled
            }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up)
            ) == .handled
        )
        #expect(pointerProbe.names == ["up"])
        #expect(tapProbe.events.isEmpty)
    }

    @Test
    func `ignoring pointer-up allows a competing tap to complete`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let pointerProbe = PointerPressProbe()
        let view = Text("A")
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onPointerPress(phases: .up) { pointerPress in
                pointerProbe.record("up", pointerPress)
                return .ignored
            }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up)
            ) == .ignored
        )
        #expect(pointerProbe.names == ["up"])
        #expect(tapProbe.events == ["tap"])
    }

    @Test
    func `a pointer-press handler can mutate state and trigger an updated render`() {
        let runtime = StateRuntime()
        let view = PointerPressStateMutationView()

        #expect(runtime.block(from: view)?.text == "0")
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .handled
        )

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1")
    }
}
