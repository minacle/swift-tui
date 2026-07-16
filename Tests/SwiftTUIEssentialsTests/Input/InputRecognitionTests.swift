import Foundation
import Testing
@testable import SwiftTUIEssentials

@Suite("Input Recognition")
struct InputRecognitionTests {

    @Test
    func `a custom InputEvent body lowers to its primitive matcher`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .inputEvent(
                CustomPrimaryPressEvent()
                    .onRecognized { press in
                        probe.events.append("custom-\(press.location.column)")
                        return .ignored
                    }
            )

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 0, row: 0),
                    phase: .down
                )
            ) == .ignored
        )
        #expect(probe.events == ["custom-0"])
    }

    @Test
    func `nested onRecognized actions finish inside-out before handled propagation`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let event = PointerPressEvent()
            .onRecognized { _ in
                probe.events.append("inner")
                return .handled
            }
            .onRecognized { _ in
                probe.events.append("outer")
                return .ignored
            }
        let view = Text("A")
            .onPointerPress {
                probe.events.append("later")
                return .ignored
            }
            .highPriorityInputEvent(event)

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: .zero, phase: .down)
            ) == .handled
        )
        #expect(probe.events == ["inner", "outer"])
    }

    @Test
    func `ExclusiveInputEvent selects a matching first branch even when it ignores input`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let event = PointerPressEvent()
            .onRecognized { _ in
                probe.events.append("first")
                return .ignored
            }
            .exclusively(
                before: PointerPressEvent().onRecognized { _ in
                    probe.events.append("second")
                    return .ignored
                }
            )
            .onRecognized { value in
                if case .first = value {
                    probe.events.append("composite-first")
                }
                return .ignored
            }
        let view = Text("A").inputEvent(event)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: .zero, phase: .down))

        #expect(probe.events == ["first", "composite-first"])
    }

    @Test
    func `SimultaneousInputEvent runs both siblings before aggregating handled`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let event = PointerPressEvent()
            .onRecognized { _ in
                probe.events.append("first")
                return .handled
            }
            .simultaneously(
                with: PointerPressEvent().onRecognized { _ in
                    probe.events.append("second")
                    return .ignored
                }
            )
            .onRecognized { value in
                #expect(value.first != nil)
                #expect(value.second != nil)
                probe.events.append("composite")
                return .ignored
            }
        let view = Text("A")
            .onPointerPress {
                probe.events.append("outside")
                return .ignored
            }
            .highPriorityInputEvent(event)

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: .zero, phase: .down)
            ) == .handled
        )
        #expect(probe.events == ["first", "second", "composite"])
    }

    @Test
    func `SequenceInputEvent arms on first input and completes only on a later second input`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let event = PointerPressEvent(.left)
            .onRecognized { _ in
                probe.events.append("first")
                return .ignored
            }
            .sequenced(
                before: PointerPressEvent(.left, phases: .up)
                    .onRecognized { _ in
                        probe.events.append("second")
                        return .ignored
                    }
            )
            .onRecognized { value in
                probe.events.append(
                    "complete-\(value.first.phase == .down)-\(value.second.phase == .up)"
                )
                return .ignored
            }
        let view = Text("A").inputEvent(event)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: .zero, phase: .down))
        _ = runtime.dispatch(PointerPress(button: .right, location: .zero, phase: .up))
        #expect(probe.events == ["first"])

        _ = runtime.dispatch(PointerPress(button: .left, location: .zero, phase: .up))
        #expect(probe.events == ["first", "second", "complete-true-true"])
    }

    @Test
    func `attachment tiers and deferred stages execute in their declared order`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .inputEvent(recordingPress("normal-immediate", in: probe))
            .inputEvent(recordingPress("normal-eager", in: probe).deferred(priority: .eager))
            .gesture(recordingPendingGesture("normal-gesture", in: probe))
            .inputEvent(recordingPress("normal-lazy", in: probe).deferred(priority: .lazy))
            .simultaneousInputEvent(recordingPress("view-immediate", in: probe))
            .simultaneousInputEvent(
                recordingPress("view-eager", in: probe).deferred(priority: .eager)
            )
            .simultaneousGesture(recordingPendingGesture("view-gesture", in: probe))
            .simultaneousInputEvent(
                recordingPress("view-lazy", in: probe).deferred(priority: .lazy)
            )
            .highPriorityInputEvent(recordingPress("high-immediate", in: probe))
            .highPriorityInputEvent(
                recordingPress("high-eager", in: probe).deferred(priority: .eager)
            )
            .highPriorityGesture(recordingPendingGesture("high-gesture", in: probe))
            .highPriorityInputEvent(
                recordingPress("high-lazy", in: probe).deferred(priority: .lazy)
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: .zero, phase: .down))

        #expect(
            probe.events == [
                "high-immediate",
                "high-eager",
                "high-gesture",
                "high-lazy",
                "view-immediate",
                "view-eager",
                "view-gesture",
                "view-lazy",
                "normal-immediate",
                "normal-eager",
                "normal-gesture",
                "normal-lazy",
            ]
        )
    }

    @Test
    func `a handled high-priority event prevents later stages and lower tiers`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .simultaneousGesture(recordingPendingGesture("view-gesture", in: probe))
            .inputEvent(recordingPress("normal", in: probe))
            .highPriorityInputEvent(
                PointerPressEvent().onRecognized { _ in
                    probe.events.append("high")
                    return .handled
                }
            )
            .highPriorityGesture(recordingPendingGesture("high-gesture", in: probe))

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: .zero, phase: .down)
            ) == .handled
        )
        #expect(probe.events == ["high"])
    }

    @Test
    func `pointer-down on a sibling excludes a descendant PointerPressEvent outside its hit region`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let view = HStack(spacing: 0) {
            Text("A")
                .inputEvent(
                    PointerPressEvent().onRecognized { _ in
                        probe.events.append("descendant")
                        return .handled
                    }
                )
            Text("B")
        }
        .inputEvent(
            PointerPressEvent().onRecognized { _ in
                probe.events.append("ancestor")
                return .ignored
            }
        )

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
        #expect(probe.events == ["ancestor"])
    }

    @Test
    func `pointer attachments sharing a focus owner use their own hit regions and local origins`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("AA")
                .inputEvent(
                    PointerPressEvent(.left, coordinateSpace: .local)
                        .onRecognized { press in
                            probe.events.append(
                                "first-\(press.location.column)-\(press.location.row)"
                            )
                            return .ignored
                        }
                )
            Text("BBB")
                .inputEvent(
                    PointerPressEvent(.left, coordinateSpace: .local)
                        .onRecognized { press in
                            probe.events.append(
                                "second-\(press.location.column)-\(press.location.row)"
                            )
                            return .ignored
                        }
                )
                .padding(.leading, 4)
        }
        .focusable()

        #expect(runtime.block(from: view)?.lines == ["AA     ", "    BBB"])

        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 5, row: 1),
                    phase: .down
                )
            ) == .ignored
        )
        #expect(probe.events == ["second-1-0"])

        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 1, row: 0),
                    phase: .down
                )
            ) == .ignored
        )
        #expect(probe.events == ["second-1-0", "first-1-0"])
    }

    @Test
    func `InputEventMask selects the current attachment or receiver registrations structurally`() {
        let currentProbe = RecognitionProbe()
        let currentRuntime = StateRuntime()
        let currentView = Text("A")
            .onPointerPress {
                currentProbe.events.append("receiver")
                return .ignored
            }
            .inputEvent(
                recordingPress("current", in: currentProbe),
                including: .inputEvent
            )

        _ = currentRuntime.block(from: currentView)
        _ = currentRuntime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        #expect(currentProbe.events == ["current"])

        let receiverProbe = RecognitionProbe()
        let receiverRuntime = StateRuntime()
        let receiverView = Text("A")
            .onPointerPress {
                receiverProbe.events.append("receiver")
                return .ignored
            }
            .inputEvent(
                recordingPress("current", in: receiverProbe),
                including: .subviews
            )

        _ = receiverRuntime.block(from: receiverView)
        _ = receiverRuntime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )
        #expect(receiverProbe.events == ["receiver"])
    }

    @Test
    func `disabling an attachment keeps receiver events and hover eligible`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()
        let view = Text("A")
            .onPointerPress {
                probe.events.append("receiver")
                return .ignored
            }
            .onContinuousHover { _ in
                probe.events.append("hover")
            }
            .inputEvent(
                recordingPress("disabled", in: probe),
                isEnabled: false
            )

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: .zero, phase: .down))
        _ = runtime.dispatch(
            PointerMotion(button: nil, location: .zero, modifiers: [])
        )

        #expect(probe.events == ["receiver", "hover"])
    }

    @Test
    func `rerendering replaces an action while preserving an armed sequence`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(from: sequenceView(label: "old", probe: probe))
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )

        _ = runtime.block(from: sequenceView(label: "new", probe: probe))
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up)
        )

        #expect(probe.events == ["new"])
    }

    @Test
    func `changing matcher configuration cancels an armed sequence`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(
            from: configuredSequenceView(
                downButton: .left,
                probe: probe
            )
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )

        _ = runtime.block(
            from: configuredSequenceView(
                downButton: .right,
                probe: probe
            )
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up)
        )

        #expect(probe.events.isEmpty)
    }

    @Test
    func `changing a custom InputEvent type cancels an identical armed body`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(
            from: customSequenceIdentityView(
                FirstCustomPressSequenceEvent(),
                probe: probe
            )
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )

        _ = runtime.block(
            from: customSequenceIdentityView(
                SecondCustomPressSequenceEvent(),
                probe: probe
            )
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up)
        )

        #expect(probe.events.isEmpty)
    }

    @Test
    func `removing a named coordinate space cancels an armed sequence`() {
        let probe = RecognitionProbe()
        let runtime = StateRuntime()

        _ = runtime.block(
            from: namedCoordinateSequenceView(
                renderedSpace: .named("input"),
                probe: probe
            )
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down)
        )

        _ = runtime.block(
            from: namedCoordinateSequenceView(
                renderedSpace: .named("replacement"),
                probe: probe
            )
        )
        _ = runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up)
        )

        #expect(probe.events.isEmpty)
    }
}

private final class RecognitionProbe {
    var events: [String] = []
}

private struct CustomPrimaryPressEvent: PointerEvent {

    typealias Value = PointerPress

    var body: some PointerEvent<PointerPress> {
        PointerPressEvent(.left)
    }
}

private typealias PrimaryPressSequence = SequenceInputEvent<
    PointerPressEvent,
    PointerPressEvent
>

private struct FirstCustomPressSequenceEvent: PointerEvent {

    typealias Value = PrimaryPressSequence.Value

    var body: PrimaryPressSequence {
        PointerPressEvent(.left)
            .sequenced(before: PointerPressEvent(.left, phases: .up))
    }
}

private struct SecondCustomPressSequenceEvent: PointerEvent {

    typealias Value = PrimaryPressSequence.Value

    var body: PrimaryPressSequence {
        PointerPressEvent(.left)
            .sequenced(before: PointerPressEvent(.left, phases: .up))
    }
}

private func recordingPress(
    _ name: String,
    in probe: RecognitionProbe
) -> some PointerEvent<PointerPress> {
    PointerPressEvent().onRecognized { press in
        probe.events.append(name)
        return .ignored
    }
}

private func recordingPendingGesture(
    _ name: String,
    in probe: RecognitionProbe
) -> some Gesture<Bool> {
    LongPressGesture(minimumDuration: 60).onChanged { _ in
        probe.events.append(name)
    }
}

private func sequenceView(
    label: String,
    probe: RecognitionProbe
) -> some View {
    configuredSequenceView(
        downButton: .left,
        completion: { probe.events.append(label) }
    )
}

private func configuredSequenceView(
    downButton: PointerButton,
    probe: RecognitionProbe
) -> some View {
    configuredSequenceView(
        downButton: downButton,
        completion: { probe.events.append("completed") }
    )
}

private func configuredSequenceView(
    downButton: PointerButton,
    completion: @escaping () -> Void
) -> some View {
    let event = PointerPressEvent(downButton)
        .sequenced(before: PointerPressEvent(.left, phases: .up))
        .onRecognized { _ in
            completion()
            return .ignored
        }
    return Text("A").inputEvent(event)
}

private func namedCoordinateSequenceView(
    renderedSpace: CoordinateSpace,
    probe: RecognitionProbe
) -> some View {
    let event = PointerPressEvent(
        .left,
        coordinateSpace: .named("input")
    )
    .sequenced(
        before: PointerPressEvent(
            .left,
            phases: .up,
            coordinateSpace: .named("input")
        )
    )
    .onRecognized { _ in
        probe.events.append("completed")
        return .ignored
    }
    return Text("A")
        .inputEvent(event)
        .coordinateSpace(renderedSpace)
}

private func customSequenceIdentityView<Event: InputEvent>(
    _ event: Event,
    probe: RecognitionProbe
) -> some View where Event.Value == PrimaryPressSequence.Value {
    Text("A")
        .inputEvent(
            event.onRecognized { _ in
                probe.events.append("completed")
                return .ignored
            }
        )
}
