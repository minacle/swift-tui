import Testing
@testable import SwiftTUIEssentials

@Suite("Shortcut Configuration")
struct ShortcutConfigurationTests {

    @Test
    func `primitive shortcuts expose their values through Never bodies`() {
        requireShortcut(TapShortcut("s"), value: Void.self, body: Never.self)
        requireShortcut(
            LongPressShortcut("s"),
            value: Bool.self,
            body: Never.self
        )
    }

    @Test
    func `TapShortcut preserves its key modifiers and count`() {
        let shortcut = TapShortcut("s", modifiers: [.control, .shift], count: 2)

        #expect(shortcut.key == "s")
        #expect(shortcut.modifiers == [.control, .shift])
        #expect(shortcut.count == 2)
    }

    @Test
    func `LongPressShortcut normalizes a negative duration`() {
        let shortcut = LongPressShortcut(
            "s",
            modifiers: .control,
            minimumDuration: -1
        )

        #expect(shortcut.key == "s")
        #expect(shortcut.modifiers == .control)
        #expect(shortcut.minimumDuration == 0)
        #expect(LongPressShortcut("s").minimumDuration == 0.5)
    }

    @Test
    func `shortcut compositions expose children and conditionally equatable values`() {
        let tap = TapShortcut("s", modifiers: .control)
        let longPress = LongPressShortcut("s", modifiers: .control)
        let exclusive = ExclusiveShortcut(tap, longPress)
        let simultaneous = SimultaneousShortcut(tap, longPress)
        let sequence = SequenceShortcut(tap, longPress)

        #expect(exclusive.first == tap)
        #expect(exclusive.second == longPress)
        #expect(simultaneous.first == tap)
        #expect(simultaneous.second == longPress)
        #expect(sequence.first == tap)
        #expect(sequence.second == longPress)
        #expect(exclusive == ExclusiveShortcut(tap, longPress))
        #expect(simultaneous == SimultaneousShortcut(tap, longPress))
        #expect(sequence == SequenceShortcut(tap, longPress))
        requireSendable(exclusive)
        requireSendable(simultaneous)
        requireSendable(sequence)

        let exclusiveValue:
            ExclusiveShortcut<LongPressShortcut, LongPressShortcut>.Value = .second(true)
        #expect(exclusiveValue == .second(true))
        let simultaneousValue =
            SimultaneousShortcut<LongPressShortcut, LongPressShortcut>.Value(
                first: true,
                second: nil
            )
        #expect(
            simultaneousValue
                == SimultaneousShortcut<LongPressShortcut, LongPressShortcut>.Value(
                    first: true,
                    second: nil
                )
        )
        let equatableSequenceValue:
            SequenceShortcut<LongPressShortcut, LongPressShortcut>.Value =
                .second(true, false)
        #expect(equatableSequenceValue == .second(true, false))
        #expect(
            SimultaneousShortcut<TapShortcut, LongPressShortcut>.Value(
                first: (),
                second: true
            ).second == true
        )
        let sequenceValue = SequenceShortcut<TapShortcut, LongPressShortcut>.Value
            .second((), true)
        guard case .second(_, let second) = sequenceValue else {
            Issue.record("The sequence value did not retain its second stage.")
            return
        }
        #expect(second == true)
        requireSendable(exclusiveValue)
        requireSendable(simultaneousValue)
        requireSendable(equatableSequenceValue)
        requireSendable(sequenceValue)
    }

    @Test
    func `ShortcutState exposes its initial and optional values`() {
        let state = ShortcutState<Int>(initialValue: 4)
        let optional = ShortcutState<Int?>()

        #expect(state.wrappedValue == 4)
        #expect(state.projectedValue.wrappedValue == 4)
        #expect(optional.wrappedValue == nil)
    }
}

private func requireShortcut<S: Shortcut>(
    _ shortcut: S,
    value: S.Value.Type,
    body: S.Body.Type
) {
    _ = shortcut
    _ = value
    _ = body
}

private func requireSendable<Value: Sendable>(_ value: Value) {
    _ = value
}
