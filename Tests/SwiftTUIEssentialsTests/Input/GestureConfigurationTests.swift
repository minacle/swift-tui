import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Gesture Configuration")
struct GestureConfigurationTests {

    @Test
    func `primitive gestures expose their values through Never bodies`() {
        requireGesture(TapGesture(), value: Void.self, body: Never.self)
        requireGesture(
            SpatialTapGesture(),
            value: SpatialTapGesture.Value.self,
            body: Never.self
        )
        requireGesture(
            LongPressGesture(),
            value: Bool.self,
            body: Never.self
        )
        requireGesture(
            DragGesture(),
            value: DragGesture.Value.self,
            body: Never.self
        )
    }

    @Test
    func `tap gestures preserve counts and requested terminal coordinate spaces`() {
        let tap = TapGesture(count: 3)
        let spatial = SpatialTapGesture(
            count: 2,
            coordinateSpace: .named("canvas")
        )

        #expect(tap.count == 3)
        #expect(spatial.count == 2)
        #expect(spatial.coordinateSpace == .named("canvas"))
        #expect(
            SpatialTapGesture.Value(location: Point(column: 4, row: 2)).location
                == Point(column: 4, row: 2)
        )
    }

    @Test
    func `LongPressGesture normalizes negative duration and per-axis distances`() {
        let gesture = LongPressGesture(
            minimumDuration: -1,
            maximumDistance: Size(columns: -2, rows: 3)
        )

        #expect(gesture.minimumDuration == 0)
        #expect(gesture.maximumDistance == Size(columns: 0, rows: 3))
        #expect(LongPressGesture().maximumDistance == .zero)
    }

    @Test
    func `DragGesture normalizes distance and a complete value preserves its samples`() {
        let gesture = DragGesture(
            button: .right,
            minimumDistance: -2,
            coordinateSpace: .global
        )
        let time = Date(timeIntervalSinceReferenceDate: 100)
        let value = DragGesture.Value(
            time: time,
            location: Point(column: 5, row: 4),
            startLocation: Point(column: 2, row: 1),
            translation: Size(columns: 3, rows: 3),
            velocity: .init(columnsPerSecond: 10, rowsPerSecond: -5),
            predictedEndLocation: Point(column: 6, row: 3),
            predictedEndTranslation: Size(columns: 4, rows: 2),
            modifiers: [.shift]
        )

        #expect(gesture.button == .right)
        #expect(gesture.minimumDistance == 0)
        #expect(gesture.coordinateSpace == .global)
        #expect(value.time == time)
        #expect(value.location == Point(column: 5, row: 4))
        #expect(value.startLocation == Point(column: 2, row: 1))
        #expect(value.translation == Size(columns: 3, rows: 3))
        #expect(value.velocity.columnsPerSecond == 10)
        #expect(value.velocity.rowsPerSecond == -5)
        #expect(value.predictedEndLocation == Point(column: 6, row: 3))
        #expect(value.predictedEndTranslation == Size(columns: 4, rows: 2))
        #expect(value.modifiers == [.shift])
    }

    @Test
    func `gesture compositions expose children and conditionally equatable values`() {
        let exclusive = ExclusiveGesture(TapGesture(), LongPressGesture())
        let simultaneous = SimultaneousGesture(TapGesture(), LongPressGesture())
        let sequence = SequenceGesture(TapGesture(), LongPressGesture())

        #expect(exclusive.first == TapGesture())
        #expect(exclusive.second == LongPressGesture())
        #expect(simultaneous.first == TapGesture())
        #expect(simultaneous.second == LongPressGesture())
        #expect(sequence.first == TapGesture())
        #expect(sequence.second == LongPressGesture())
        #expect(
            SimultaneousGesture<TapGesture, LongPressGesture>.Value(
                first: (),
                second: true
            ).second == true
        )
        let sequenceValue = SequenceGesture<TapGesture, LongPressGesture>.Value
            .second((), true)
        guard case .second(_, let second) = sequenceValue else {
            Issue.record("The sequence value did not retain its second stage.")
            return
        }
        #expect(second == true)
    }

    @Test
    func `Transaction starts noncontinuous and GestureState exposes its initial value`() {
        var transaction = Transaction()
        let state = GestureState<Int>(initialValue: 4, resetTransaction: transaction)
        let optional = GestureState<Int?>()

        #expect(!transaction.isContinuous)
        transaction.isContinuous = true
        #expect(transaction.isContinuous)
        #expect(state.wrappedValue == 4)
        #expect(state.projectedValue.wrappedValue == 4)
        #expect(optional.wrappedValue == nil)
    }
}

private func requireGesture<G: Gesture>(
    _ gesture: G,
    value: G.Value.Type,
    body: G.Body.Type
) {
    _ = gesture
    _ = value
    _ = body
}
