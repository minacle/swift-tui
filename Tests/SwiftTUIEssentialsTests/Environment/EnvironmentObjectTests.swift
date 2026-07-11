import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Environment Objects")
struct EnvironmentObjectTests {

    @Test
    func `a typed environment object is inherited by descendant views`() {
        let model = TestObservableModel(count: 1)
        let objectProbe = ObjectProbe<TestObservableModel>()
        let view = TypedEnvironmentObjectMarkerText(objectProbe: objectProbe)
            .environment(model)

        #expect(ViewResolver.text(from: view) == "1")
        #expect(objectProbe.object === model)
    }

    @Test
    func `the nearest typed environment object overrides an ancestor object`() {
        let parent = TestObservableModel(count: 1)
        let child = TestObservableModel(count: 2)
        let view = VStack(alignment: .leading, spacing: 0) {
            TypedEnvironmentObjectMarkerText()
            TypedEnvironmentObjectMarkerText()
                .environment(child)
        }
        .environment(parent)

        #expect(ViewResolver.block(from: view)?.lines == ["1", "2"])
    }

    @Test
    func `a typed environment object applies only to the modified subtree`() {
        let parent = TestObservableModel(count: 1)
        let child = TestObservableModel(count: 2)
        let view = VStack(alignment: .leading, spacing: 0) {
            TypedEnvironmentObjectMarkerText()
                .environment(child)
            TypedEnvironmentObjectMarkerText()
        }
        .environment(parent)

        #expect(ViewResolver.block(from: view)?.lines == ["2", "1"])
    }

    @Test
    func `an optional typed environment object is nil when no matching object exists`() {
        #expect(ViewResolver.text(from: OptionalTypedEnvironmentObjectMarkerText()) == "nil")
    }

    @Test
    func `an optional typed environment object resolves the injected instance`() {
        let model = TestObservableModel(count: 4)
        let objectProbe = ObjectProbe<TestObservableModel>()
        let view = OptionalTypedEnvironmentObjectMarkerText(objectProbe: objectProbe)
            .environment(model)

        #expect(ViewResolver.text(from: view) == "4")
        #expect(objectProbe.object === model)
    }

    @Test
    func `typed and key-path environment values coexist in the same view`() {
        let model = TestObservableModel(count: 3)
        let view = TypedAndKeyPathEnvironmentMarkerText()
            .environment(\.testMarker, "marker")
            .environment(model)

        #expect(ViewResolver.text(from: view) == "marker:3")
    }

    @Test
    func `a typed environment object projection provides a writable property binding`() {
        let model = TestObservableModel(token: "initial")
        let probe = BindingProbe<String>()
        let objectProbe = ObjectProbe<TestObservableModel>()
        let view = TypedEnvironmentObjectProjectionMarkerText(
            bindingProbe: probe,
            objectProbe: objectProbe
        )
        .environment(model)

        #expect(ViewResolver.text(from: view) == "initial")
        #expect(objectProbe.object === model)

        probe.binding?.wrappedValue = "updated"
        #expect(model.token == "updated")
        #expect(probe.binding?.wrappedValue == "updated")
    }

    @Test
    func `a missing typed environment object diagnostic identifies the type and injection modifier`() {
        let message = missingObservableObjectMessage(for: TestObservableModel.self)

        #expect(message.contains("TestObservableModel"))
        #expect(message.contains("View.environment(_:)"))
    }

    @Test
    func `a text field bound through a typed environment object reflects external changes and writes user input back`() {
        let runtime = StateRuntime()
        let objectProbe = ObjectProbe<TestObservableModel>()
        let view = TypedEnvironmentTextFieldRootView(
            initialToken: "",
            objectProbe: objectProbe
        )

        #expect(runtime.block(from: view)?.text == "Token")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Token")

        objectProbe.object?.token = "abc"
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "abc ")

        #expect(runtime.dispatch(KeyPress(key: .end, characters: "\u{F72B}")) == .handled)
        #expect(runtime.dispatch(KeyPress(key: "d", characters: "d")) == .handled)
        #expect(objectProbe.object?.token == "abcd")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "abcd ")
    }
}
