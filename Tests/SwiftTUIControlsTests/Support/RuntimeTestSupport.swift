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
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            PointerEvent(button: .left, column: column, row: row, phase: .down),
            at: date
        ) == result
    )
    #expect(
        runtime.dispatch(
            PointerEvent(button: .left, column: column, row: row, phase: .up),
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
            PointerEvent(
                button: .left,
                column: fromColumn,
                row: fromRow,
                phase: .down
            )
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            PointerEvent(
                button: .left,
                column: toColumn,
                row: toRow,
                phase: .motion
            )
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            PointerEvent(
                button: .left,
                column: toColumn,
                row: toRow,
                phase: .up
            )
        ) == .handled
    )
}

func dispatchWheel(
    to runtime: StateRuntime,
    button: PointerEvent.Button,
    column: Int,
    row: Int,
    modifiers: EventModifiers = [],
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            PointerEvent(
                button: button,
                column: column,
                row: row,
                modifiers: modifiers,
                phase: .down
            )
        ) == result
    )
}

func dispatchHover(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    button: PointerEvent.Button = .other(3),
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            PointerEvent(button: button, column: column, row: row, phase: .motion)
        ) == result
    )
}
