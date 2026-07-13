import Testing
@testable import SwiftTUIEssentials

@Suite("Never Protocol Conformances")
struct NeverConformanceTests {

    @Test
    func `Never supplies the shared body for View InputEvent and Gesture conformances`() {
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
