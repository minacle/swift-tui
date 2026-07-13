import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Input Event Matchers")
struct EventMatcherTests {

    @Test
    func `primitive press matchers expose their value and Never body types`() {
        requireInputEvent(
            KeyPressEvent(),
            value: KeyPress.self,
            body: Never.self
        )
        requireInputEvent(
            PointerPressEvent(),
            value: PointerPress.self,
            body: Never.self
        )
        requireInputEvent(
            PointerMotionEvent(),
            value: PointerMotion.self,
            body: Never.self
        )
        requireInputEvent(
            PointerScrollEvent(),
            value: PointerScroll.self,
            body: Never.self
        )
    }

    @Test
    func `KeyPressEvent defaults to every key during key-down and repeat`() {
        let event = KeyPressEvent()

        #expect(event.filter == .any)
        #expect(event.phases == [.down, .repeat])
        #expect(event.matches(KeyPress(key: "a", characters: "a", phase: .down)))
        #expect(event.matches(KeyPress(key: "a", characters: "a", phase: .repeat)))
        #expect(!event.matches(KeyPress(key: "a", characters: "a", phase: .up)))
    }

    @Test
    func `KeyPressEvent matches one key or a key-set only in selected phases`() {
        let returnEvent = KeyPressEvent(.return, phases: .up)
        let navigationEvent = KeyPressEvent(
            keys: [.upArrow, .downArrow],
            phases: .down
        )
        let emptyEvent = KeyPressEvent(keys: [], phases: .all)

        #expect(returnEvent.filter == .keys([.return]))
        #expect(returnEvent.matches(KeyPress(key: .return, characters: "", phase: .up)))
        #expect(!returnEvent.matches(KeyPress(key: .return, characters: "", phase: .down)))
        #expect(navigationEvent.matches(KeyPress(key: .upArrow, characters: "")))
        #expect(!navigationEvent.matches(KeyPress(key: .leftArrow, characters: "")))
        #expect(!emptyEvent.matches(KeyPress(key: "a", characters: "a")))
    }

    @Test
    func `KeyPressEvent character filters require nonempty accepted Unicode scalars`() {
        let event = KeyPressEvent(characters: .decimalDigits)
        let noPhases = KeyPressEvent(characters: .decimalDigits, phases: [])

        #expect(event.filter == .characters(.decimalDigits))
        #expect(event.matches(KeyPress(key: "1", characters: "12")))
        #expect(!event.matches(KeyPress(key: "a", characters: "1a")))
        #expect(!event.matches(KeyPress(key: .return, characters: "")))
        #expect(!noPhases.matches(KeyPress(key: "1", characters: "1")))
    }

    @Test
    func `PointerPressEvent exposes default and configured recognition values`() {
        let defaultEvent = PointerPressEvent()
        let buttonSetEvent = PointerPressEvent(buttons: [.middle])
        let namedSpace = CoordinateSpace.named("editor")
        let configuredEvent = PointerPressEvent(
            buttons: [.right, .middle],
            phases: .up,
            coordinateSpace: namedSpace
        )

        #expect(defaultEvent.buttons == [.left])
        #expect(defaultEvent.phases == .down)
        #expect(defaultEvent.coordinateSpace == .local)
        #expect(buttonSetEvent.buttons == [.middle])
        #expect(buttonSetEvent.phases == .down)
        #expect(configuredEvent.buttons == [.right, .middle])
        #expect(configuredEvent.phases == .up)
        #expect(configuredEvent.coordinateSpace == namedSpace)
    }

    @Test
    func `PointerPressEvent matches buttons and phases but not its coordinate space`() {
        let event = PointerPressEvent(
            .right,
            phases: .up,
            coordinateSpace: .global
        )
        let matchingPress = PointerPress(
            button: .right,
            location: Point(column: 4, row: 2),
            phase: .up
        )
        let wrongPhase = PointerPress(
            button: .right,
            location: .zero,
            phase: .down
        )
        let emptyEvent = PointerPressEvent(phases: [], buttons: [])

        #expect(event.matches(matchingPress))
        #expect(!event.matches(wrongPhase))
        #expect(!emptyEvent.matches(matchingPress))
    }

    @Test
    func `PointerMotion preserves raw values and each filter selects its button state`() {
        let buttonless = PointerMotion(
            button: nil,
            location: Point(column: 3, row: 4),
            modifiers: [.shift]
        )
        let pressed = PointerMotion(
            button: .right,
            location: Point(column: 5, row: 6),
            modifiers: [.control]
        )

        #expect(buttonless.location == Point(column: 3, row: 4))
        #expect(buttonless.modifiers == [.shift])
        #expect(PointerMotionEvent().matches(buttonless))
        #expect(PointerMotionEvent(.buttonless).matches(buttonless))
        #expect(!PointerMotionEvent(.pressed).matches(buttonless))
        #expect(PointerMotionEvent(.pressed).matches(pressed))
        #expect(PointerMotionEvent(.buttons([.right])).matches(pressed))
        #expect(!PointerMotionEvent(.buttons([.left])).matches(pressed))
        #expect(!PointerMotionEvent(.buttons([])).matches(pressed))
        #expect(
            PointerMotionEvent(.buttonless, coordinateSpace: .global).coordinateSpace
                == .global
        )
    }

    @Test
    func `PointerScroll derives axes from signed diagonal and magnitude deltas`() {
        let stationary = PointerScroll(delta: .zero, location: .zero)
        let vertical = PointerScroll(
            delta: Size(columns: 0, rows: -3),
            location: Point(column: 2, row: 1),
            modifiers: [.option]
        )
        let diagonal = PointerScroll(
            delta: Size(columns: 2, rows: 4),
            location: .zero
        )

        #expect(stationary.axes.isEmpty)
        #expect(vertical.axes == [.vertical])
        #expect(vertical.delta == Size(columns: 0, rows: -3))
        #expect(vertical.location == Point(column: 2, row: 1))
        #expect(vertical.modifiers == [.option])
        #expect(diagonal.axes == [.horizontal, .vertical])
        #expect(PointerScrollEvent(.horizontal).matches(diagonal))
        #expect(PointerScrollEvent(.vertical).matches(diagonal))
        #expect(!PointerScrollEvent([]).matches(diagonal))
        #expect(!PointerScrollEvent().matches(stationary))
        #expect(PointerScrollEvent(coordinateSpace: .global).coordinateSpace == .global)
    }
}

private func requireInputEvent<E: InputEvent>(
    _ event: E,
    value: E.Value.Type,
    body: E.Body.Type
) {
    _ = event
    _ = value
    _ = body
}
