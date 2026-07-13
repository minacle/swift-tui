import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Gesture Recognition")
struct GestureRecognitionTests {

    @Test
    func `a custom Gesture body recognizes through its primitive graph`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .gesture(
                CustomTapGesture().onEnded { value in
                    probe.points.append(value.location)
                }
            )

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(probe.points == [.zero])
    }

    @Test
    func `SpatialTapGesture converts the completed location to local coordinates`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = HStack(spacing: 0) {
            Text("XX")
            Text("A")
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        probe.points.append(value.location)
                    }
                )
        }

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 3, row: 1)

        #expect(probe.points == [.zero])
    }

    @Test
    func `TapGesture completes only after its configured number of clicks`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .gesture(
                TapGesture(count: 2)
                    .onEnded { probe.events.append("ended") }
            )

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(probe.events.isEmpty)

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(probe.events == ["ended"])
    }

    @Test
    func `LongPressGesture updates on pointer-down and ends after its deadline`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let gesture = LongPressGesture(minimumDuration: 0.5)
            .onChanged { value in
                probe.events.append("changed-\(value)")
            }
            .onEnded { value in
                probe.events.append("ended-\(value)")
            }
        let view = Text("A").gesture(gesture)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        #expect(probe.events == ["changed-true"])

        runtime.dispatchExpiredRecognitionActions(
            at: start.addingTimeInterval(0.5)
        )
        #expect(probe.events == ["changed-true", "ended-true"])
    }

    @Test
    func `LongPressGesture fails after out-of-range motion without ending`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let gesture = LongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: Size(columns: 1, rows: 0)
        )
            .onEnded { _ in probe.events.append("ended") }
        let view = Text("AAA").gesture(gesture)
        let start = Date(timeIntervalSinceReferenceDate: 100)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        _ = runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: 2, row: 0),
                modifiers: []
            ),
            at: start.addingTimeInterval(0.1)
        )
        runtime.dispatchExpiredRecognitionActions(
            at: start.addingTimeInterval(1)
        )

        #expect(probe.events.isEmpty)
        #expect(runtime.nextRecognitionDeadline == nil)
    }

    @Test
    func `onChanged publishes the same value again after recognition failure`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("AA")
            .gesture(
                LongPressGesture(maximumDistance: .zero)
                    .onChanged { value in
                        probe.events.append("changed-\(value)")
                    }
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        _ = runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: 1, row: 0),
                modifiers: []
            )
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )

        #expect(probe.events == ["changed-true", "changed-true"])
    }

    @Test
    func `DragGesture captures motion and reports velocity and one-sample prediction`() throws {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let view = Text("AAA")
            .gesture(
                DragGesture()
                    .onChanged { value in probe.dragValues.append(value) }
                    .onEnded { value in probe.endedDragValues.append(value) }
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        _ = runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: 2, row: 1),
                modifiers: [.shift]
            ),
            at: start.addingTimeInterval(0.5)
        )
        _ = runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: 2, row: 1),
                modifiers: [.shift],
                phase: .up
            ),
            at: start.addingTimeInterval(0.75)
        )

        #expect(probe.dragValues.count == 2)
        let changed = try #require(probe.dragValues.last)
        #expect(changed.startLocation == .zero)
        #expect(changed.location == Point(column: 2, row: 1))
        #expect(changed.translation == Size(columns: 2, rows: 1))
        #expect(changed.velocity.columnsPerSecond == 4)
        #expect(changed.velocity.rowsPerSecond == 2)
        #expect(changed.predictedEndLocation == Point(column: 4, row: 2))
        #expect(changed.predictedEndTranslation == Size(columns: 4, rows: 2))
        #expect(changed.modifiers == [.shift])

        let ended = try #require(onlyElement(in: probe.endedDragValues))
        #expect(ended.location == changed.location)
        #expect(ended.velocity == changed.velocity)
        #expect(ended.predictedEndLocation == changed.predictedEndLocation)
    }

    @Test
    func `DragGesture begins only after reaching its Chebyshev distance`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("AAAAA")
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in probe.dragValues.append(value) }
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        _ = runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: 1, row: 1),
                modifiers: []
            )
        )
        #expect(probe.dragValues.isEmpty)

        _ = runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: 2, row: 1),
                modifiers: []
            )
        )
        #expect(probe.dragValues.map(\.translation) == [Size(columns: 2, rows: 1)])
    }

    @Test
    func `updating precedes onChanged and success ends before one state reset`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = GestureStateProbeView(probe: probe)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
            ]
        )

        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up)
        )
        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "ended",
                "reset-true-false",
            ]
        )
    }

    @Test
    func `scene cancellation resets GestureState once without ending`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = GestureStateProbeView(probe: probe)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        runtime.dispatchSceneInactive()
        runtime.dispatchSceneInactive()

        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "reset-true-false",
            ]
        )
    }

    @Test
    func `removing an active attachment resets GestureState without ending`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(from: GestureStateProbeView(probe: probe))
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        _ = runtime.block(from: Text("replacement"))

        #expect(
            probe.events == [
                "updating-true-true",
                "changed-true",
                "reset-true-false",
            ]
        )
    }

    @Test
    func `GestureMask enables the current gesture or receiver gestures structurally`() {
        let currentProbe = GestureRecognitionProbe()
        let currentRuntime = StateRuntime()
        let currentView = Text("A")
            .gesture(recordingTap("receiver", in: currentProbe))
            .gesture(
                recordingTap("current", in: currentProbe),
                including: .gesture
            )

        _ = currentRuntime.block(from: currentView)
        dispatchClick(to: currentRuntime, column: 1, row: 1)
        #expect(currentProbe.events == ["current"])

        let receiverProbe = GestureRecognitionProbe()
        let receiverRuntime = StateRuntime()
        let receiverView = Text("A")
            .gesture(recordingTap("receiver", in: receiverProbe))
            .gesture(
                recordingTap("current", in: receiverProbe),
                including: .subviews
            )

        _ = receiverRuntime.block(from: receiverView)
        dispatchClick(to: receiverRuntime, column: 1, row: 1)
        #expect(receiverProbe.events == ["receiver"])
    }

    @Test
    func `a child view-defined tap defeats an ancestor normal gesture`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = VStack {
            Text("A")
                .onTapGesture { probe.events.append("child") }
        }
        .gesture(recordingTap("parent", in: probe))

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(probe.events == ["child"])
    }

    @Test
    func `a child normal gesture defeats an ancestor normal gesture`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = VStack {
            Text("A")
                .gesture(recordingTap("child", in: probe))
        }
        .gesture(recordingTap("parent", in: probe))

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(probe.events == ["child"])
    }

    @Test
    func `the source-innermost gesture wins among attachments on one view`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .gesture(recordingTap("inner", in: probe))
            .gesture(recordingTap("outer", in: probe))

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(probe.events == ["inner"])
    }

    @Test
    func `a drag cancels a competing tap when the drag begins`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .gesture(recordingTap("tap", in: probe))
            .gesture(
                DragGesture().onChanged { _ in
                    probe.events.append("drag")
                }
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up)
        )

        #expect(probe.events == ["drag"])
    }

    @Test
    func `an ancestor high-priority tap defeats a child view-defined tap`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = VStack {
            Text("A")
                .onTapGesture { probe.events.append("child") }
        }
        .highPriorityGesture(recordingTap("parent-high", in: probe))

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(probe.events == ["parent-high"])
    }

    @Test
    func `a high-priority deadline defeats a view-defined long-press deadline`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let view = Text("A")
            .onLongPressGesture(minimumDuration: 0.5) {
                probe.events.append("view-defined")
            }
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in probe.events.append("high") }
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        runtime.dispatchExpiredRecognitionActions(
            at: start.addingTimeInterval(0.5)
        )

        #expect(probe.events == ["high"])
    }

    @Test
    func `a view-defined deadline defeats a normal long-press deadline`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let view = Text("A")
            .onLongPressGesture(minimumDuration: 0.5) {
                probe.events.append("view-defined")
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in probe.events.append("normal") }
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        runtime.dispatchExpiredRecognitionActions(
            at: start.addingTimeInterval(0.5)
        )

        #expect(probe.events == ["view-defined"])
    }

    @Test
    func `removing a view-defined long-press cancels pressing state and its deadline`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let view = Text("A")
            .onLongPressGesture(
                minimumDuration: 0.5,
                perform: { probe.events.append("ended") },
                onPressingChanged: {
                    probe.events.append($0 ? "pressing" : "cancelled")
                }
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        _ = runtime.block(from: Text("replacement"))
        runtime.dispatchExpiredRecognitionActions(
            at: start.addingTimeInterval(1)
        )

        #expect(probe.events == ["pressing", "cancelled"])
        #expect(runtime.nextLongPressDeadline == nil)
    }

    @Test
    func `rerendering a view-defined long-press preserves state with its latest action`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)

        _ = runtime.block(
            from: viewDefinedLongPress(label: "old", probe: probe)
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        _ = runtime.block(
            from: viewDefinedLongPress(label: "new", probe: probe)
        )
        runtime.dispatchExpiredRecognitionActions(
            at: start.addingTimeInterval(0.5)
        )

        #expect(probe.events == ["new"])
    }

    @Test
    func `removing a view-defined multi-tap cancels its pending fallback`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let view = Text("A")
            .onTapGesture(count: 2) {
                probe.events.append("ended")
            }

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up),
            at: start
        )
        _ = runtime.block(from: Text("replacement"))
        runtime.dispatchExpiredRecognitionActions(
            at: start.addingTimeInterval(1)
        )

        #expect(probe.events.isEmpty)
        #expect(runtime.nextTapDeadline == nil)
    }

    @Test
    func `an ancestor simultaneous tap ends before a child view-defined tap`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let view = VStack {
            Text("A")
                .onTapGesture { probe.events.append("child") }
        }
        .simultaneousGesture(recordingTap("parent-simultaneous", in: probe))

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(probe.events == ["parent-simultaneous", "child"])
    }

    @Test
    func `SequenceGesture retains the first success until the second succeeds`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let gesture = SpatialTapGesture()
            .sequenced(before: SpatialTapGesture())
            .onChanged { value in
                switch value {
                case .first:
                    probe.events.append("first")
                case .second(_, nil):
                    probe.events.append("armed")
                case .second(_, .some):
                    probe.events.append("second-changed")
                }
            }
            .onEnded { value in
                if case .second(_, .some) = value {
                    probe.events.append("ended")
                }
            }
        let view = Text("A").gesture(gesture)

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(probe.events == ["armed"])

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(probe.events == ["armed", "ended"])
    }

    @Test
    func `ExclusiveGesture replays the active sequence only after first failure`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let gesture = LongPressGesture(
            minimumDuration: 1,
            maximumDistance: .zero
        )
        .exclusively(before: DragGesture())
        .onEnded { value in
            if case .second = value {
                probe.events.append("second")
            }
        }
        let view = Text("AA").gesture(gesture)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: start
        )
        _ = runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: 1, row: 0),
                modifiers: []
            ),
            at: start.addingTimeInterval(0.1)
        )
        _ = runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: 1, row: 0),
                phase: .up
            ),
            at: start.addingTimeInterval(0.2)
        )

        #expect(probe.events == ["second"])
    }

    @Test
    func `SimultaneousGesture retains a completed child while its sibling continues`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let gesture = TapGesture()
            .onEnded { probe.events.append("first") }
            .simultaneously(
                with: TapGesture(count: 2)
                    .onEnded { probe.events.append("second") }
            )
            .onEnded { _ in probe.events.append("composite") }
        let view = Text("A").gesture(gesture)

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(probe.events == ["first"])

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(probe.events == ["first", "second", "composite"])
    }

    @Test
    func `external cancellation doesn't activate an ExclusiveGesture fallback`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()
        let gesture = LongPressGesture(minimumDuration: 1)
            .exclusively(before: DragGesture())
            .onEnded { value in
                if case .second = value {
                    probe.events.append("second")
                }
            }
        let view = Text("AA").gesture(gesture)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        runtime.dispatchSceneInactive()
        _ = runtime.dispatch(
            PointerMotion(
                button: .left,
                location: Point(column: 1, row: 0),
                modifiers: []
            )
        )
        _ = runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: 1, row: 0),
                phase: .up
            )
        )

        #expect(probe.events.isEmpty)
    }

    @Test
    func `changing a custom Gesture type cancels recognition with an identical body`() {
        let probe = GestureRecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(
            from: customDragIdentityView(FirstCustomDragGesture(), probe: probe)
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )

        _ = runtime.block(
            from: customDragIdentityView(SecondCustomDragGesture(), probe: probe)
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up)
        )

        #expect(probe.events.isEmpty)
    }
}

private final class GestureRecognitionProbe {
    var events: [String] = []
    var points: [Point] = []
    var dragValues: [DragGesture.Value] = []
    var endedDragValues: [DragGesture.Value] = []
}

private struct CustomTapGesture: Gesture {

    typealias Value = SpatialTapGesture.Value

    var body: some Gesture<SpatialTapGesture.Value> {
        SpatialTapGesture()
    }
}

private struct FirstCustomDragGesture: Gesture {

    typealias Value = DragGesture.Value

    var body: some Gesture<DragGesture.Value> {
        DragGesture()
    }
}

private struct SecondCustomDragGesture: Gesture {

    typealias Value = DragGesture.Value

    var body: some Gesture<DragGesture.Value> {
        DragGesture()
    }
}

private struct GestureStateProbeView: View {

    let probe: GestureRecognitionProbe

    @GestureState private var active = false

    init(probe: GestureRecognitionProbe) {
        self.probe = probe
        _active = GestureState(wrappedValue: false) { value, transaction in
            probe.events.append("reset-\(value)-\(transaction.isContinuous)")
        }
    }

    var body: some View {
        Text("A")
            .gesture(
                DragGesture()
                    .updating($active) { _, active, transaction in
                        active = true
                        probe.events.append(
                            "updating-\(active)-\(transaction.isContinuous)"
                        )
                    }
                    .onChanged { _ in
                        probe.events.append("changed-\(active)")
                    }
                    .onEnded { _ in
                        probe.events.append("ended")
                    }
            )
    }
}

private func recordingTap(
    _ name: String,
    in probe: GestureRecognitionProbe
) -> some Gesture<Void> {
    TapGesture().onEnded { probe.events.append(name) }
}

private func customDragIdentityView<G: Gesture>(
    _ gesture: G,
    probe: GestureRecognitionProbe
) -> some View where G.Value == DragGesture.Value {
    Text("A")
        .gesture(
            gesture.onEnded { _ in
                probe.events.append("ended")
            }
        )
}

private func viewDefinedLongPress(
    label: String,
    probe: GestureRecognitionProbe
) -> some View {
    Text("A")
        .onLongPressGesture(minimumDuration: 0.5) {
            probe.events.append(label)
        }
}

private func onlyElement<Elements: Collection>(
    in elements: Elements
) -> Elements.Element? {
    elements.count == 1 ? elements.first : nil
}
