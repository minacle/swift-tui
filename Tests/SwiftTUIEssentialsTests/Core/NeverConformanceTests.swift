import Testing
@testable import SwiftTUIEssentials

@Suite("Never Protocol Conformances")
struct NeverConformanceTests {

    @Test
    func `Never supplies the shared body for View InputEvent Gesture and Shortcut conformances`() {
        #expect(acceptsView(Never.self, body: Never.self))
        #expect(
            acceptsInputEvent(
                Never.self,
                value: Never.self,
                body: Never.self
            )
        )
        #expect(
            acceptsGesture(
                Never.self,
                value: Never.self,
                body: Never.self
            )
        )
        #expect(
            acceptsShortcut(
                Never.self,
                value: Never.self,
                body: Never.self
            )
        )
    }

    @Test
    func `a custom Shortcut lowers its body through the default protocol witness`() {
        let definition: _ShortcutDefinition<Void> = NeverBodyShortcut()._makeShortcut()

        _ = definition
    }
}

private struct NeverBodyShortcut: Shortcut {

    typealias Value = Void

    var body: some Shortcut<Void> {
        TapShortcut("s")
    }
}

private func acceptsView<Content: View>(
    _: Content.Type,
    body: Content.Body.Type
) -> Bool {
    _ = body
    return true
}

private func acceptsInputEvent<Event: InputEvent>(
    _: Event.Type,
    value: Event.Value.Type,
    body: Event.Body.Type
) -> Bool {
    _ = value
    _ = body
    return true
}

private func acceptsGesture<SomeGesture: Gesture>(
    _: SomeGesture.Type,
    value: SomeGesture.Value.Type,
    body: SomeGesture.Body.Type
) -> Bool {
    _ = value
    _ = body
    return true
}

private func acceptsShortcut<SomeShortcut: Shortcut>(
    _: SomeShortcut.Type,
    value: SomeShortcut.Value.Type,
    body: SomeShortcut.Body.Type
) -> Bool {
    _ = value
    _ = body
    return true
}
