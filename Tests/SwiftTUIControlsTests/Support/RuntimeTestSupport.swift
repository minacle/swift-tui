import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

extension RenderedBlock {

    var trimmedLines: [String] {
        lines.map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }
}

func dispatchClick(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    at date: Date = Date(timeIntervalSinceReferenceDate: 1_000),
    expecting result: InputEventResult = .ignored
) {
    #expect(
        runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: column - 1, row: row - 1),
                phase: .down
            ),
            at: date
        ) == result
    )
    #expect(
        runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: column - 1, row: row - 1),
                phase: .up
            ),
            at: date
        ) == result
    )
}

func dispatchSelectionDrag(
    to runtime: StateRuntime,
    fromColumn: Int,
    fromRow: Int,
    toColumn: Int,
    toRow: Int
) {
    #expect(
        runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: fromColumn - 1, row: fromRow - 1),
                phase: .down
            )
        ) == .ignored
    )
    #expect(
        runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: toColumn - 1, row: toRow - 1),
                modifiers: []
            )
        ) == .ignored
    )
    #expect(
        runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: toColumn - 1, row: toRow - 1),
                phase: .up
            )
        ) == .ignored
    )
}

enum TestWheelDirection {

    case up

    case down

    case left

    case right

    var delta: Size {
        switch self {
        case .up:
            Size(columns: 0, rows: -1)
        case .down:
            Size(columns: 0, rows: 1)
        case .left:
            Size(columns: -1, rows: 0)
        case .right:
            Size(columns: 1, rows: 0)
        }
    }
}

func dispatchWheel(
    to runtime: StateRuntime,
    direction: TestWheelDirection,
    column: Int,
    row: Int,
    modifiers: EventModifiers = [],
    expecting result: InputEventResult = .ignored
) {
    #expect(
        runtime.dispatch(
            PointerScroll(
                delta: direction.delta,
                location: Point(column: column - 1, row: row - 1),
                modifiers: modifiers
            )
        ) == result
    )
}

func dispatchHover(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    button: PointerButton? = nil,
    expecting result: InputEventResult = .ignored
) {
    #expect(
        runtime.dispatch(
            PointerMotion(
                button: button,
                location: Point(column: column - 1, row: row - 1),
                modifiers: []
            )
        ) == result
    )
}
