import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

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
    expecting result: KeyPress.Result = .handled
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
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: toColumn - 1, row: toRow - 1),
                modifiers: []
            )
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: toColumn - 1, row: toRow - 1),
                phase: .up
            )
        ) == .handled
    )
}

func dispatchWheel(
    to runtime: StateRuntime,
    direction: PointerScroll.Direction,
    column: Int,
    row: Int,
    modifiers: EventModifiers = [],
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            PointerScroll(
                direction: direction,
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
    expecting result: KeyPress.Result = .handled
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
