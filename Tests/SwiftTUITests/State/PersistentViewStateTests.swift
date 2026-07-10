import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Persistent View State")
struct PersistentViewStateTests {

    @Test
    func `State initializers expose their initial wrapped values`() {
        struct Probe {

            @State var wrapped = 1

            @State(initialValue: 2) var initial: Int

            @State var optional: Int?
        }

        let probe = Probe()

        #expect(probe.wrapped == 1)
        #expect(probe.initial == 2)
        #expect(probe.optional == nil)
    }

    @Test
    func `State wrapped and projected values share storage`() {
        let state = State(wrappedValue: 1)

        #expect(state.wrappedValue == 1)

        state.wrappedValue = 2
        let binding = state.projectedValue

        #expect(binding.wrappedValue == 2)

        binding.wrappedValue = 3

        #expect(state.wrappedValue == 3)
    }

    @Test
    func `an observable stored in State is initialized once for a stable view identity`() {
        let runtime = StateRuntime()
        let creationProbe = ObjectCreationProbe()
        let objectProbe = ObjectProbe<TestObservableModel>()

        #expect(
            runtime.block(
                from: StateObservableCounterView(
                    initialCount: 1,
                    creationProbe: creationProbe,
                    objectProbe: objectProbe
                )
            )?.text == "1"
        )
        #expect(creationProbe.createdIDs == [1])

        #expect(
            runtime.block(
                from: StateObservableCounterView(
                    initialCount: 9,
                    creationProbe: creationProbe,
                    objectProbe: objectProbe
                )
            )?.text == "1"
        )
        #expect(creationProbe.createdIDs == [1])
    }

    @Test
    func `mutating an observed property of an observable in State invalidates and rerenders the root view`() {
        let runtime = StateRuntime()
        let creationProbe = ObjectCreationProbe()
        let objectProbe = ObjectProbe<TestObservableModel>()

        #expect(
            runtime.block(
                from: StateObservableCounterView(
                    initialCount: 1,
                    creationProbe: creationProbe,
                    objectProbe: objectProbe
                )
            )?.text == "1"
        )

        objectProbe.object?.count = 3

        #expect(runtime.consumeInvalidation())
        #expect(
            runtime.block(
                from: StateObservableCounterView(
                    initialCount: 1,
                    creationProbe: creationProbe,
                    objectProbe: objectProbe
                )
            )?.text == "3"
        )
    }

    @Test
    func `mutating an unread property of an observable in State does not invalidate the root view`() {
        let runtime = StateRuntime()
        let creationProbe = ObjectCreationProbe()
        let objectProbe = ObjectProbe<TestObservableModel>()

        #expect(
            runtime.block(
                from: StateObservableCounterView(
                    initialCount: 1,
                    creationProbe: creationProbe,
                    objectProbe: objectProbe
                )
            )?.text == "1"
        )

        objectProbe.object?.unreadCount = 10

        #expect(!runtime.consumeInvalidation())
    }

    @Test
    func `a Bindable property binding writes to its model and invalidates the rendered view`() {
        let runtime = StateRuntime()
        let model = TestObservableModel(count: 1)
        let bindingProbe = BindingProbe<Int>()

        #expect(
            runtime.block(
                from: BindableCounterView(model: model, bindingProbe: bindingProbe)
            )?.text == "1"
        )

        bindingProbe.binding?.wrappedValue = 4

        #expect(model.count == 4)
        #expect(runtime.consumeInvalidation())
        #expect(
            runtime.block(
                from: BindableCounterView(model: model, bindingProbe: bindingProbe)
            )?.text == "4"
        )
    }

    @Test
    func `an obsolete one-shot observation invalidates only once after the view switches models`() {
        let runtime = StateRuntime()
        let first = TestObservableModel(count: 1)
        let second = TestObservableModel(count: 10)

        #expect(
            runtime.block(
                from: ConditionalObservableCounterView(
                    first: first,
                    second: second,
                    usesFirst: true
                )
            )?.text == "1"
        )
        #expect(
            runtime.block(
                from: ConditionalObservableCounterView(
                    first: first,
                    second: second,
                    usesFirst: false
                )
            )?.text == "10"
        )

        first.count = 2
        #expect(runtime.consumeInvalidation())

        first.count = 3
        #expect(!runtime.consumeInvalidation())

        second.count = 11
        #expect(runtime.consumeInvalidation())
        #expect(
            runtime.block(
                from: ConditionalObservableCounterView(
                    first: first,
                    second: second,
                    usesFirst: false
                )
            )?.text == "11"
        )
    }

    @Test
    func `reinserting a deleted ForEach identity creates fresh observable state`() {
        let runtime = StateRuntime()
        let creationProbe = ObjectCreationProbe()
        let item = ForEachTestItem(id: "a", label: "A")

        #expect(
            runtime.block(
                from: ForEachStateObservableView(items: [item], creationProbe: creationProbe)
            )?.text == "1"
        )
        #expect(creationProbe.createdIDs == [1])

        #expect(
            runtime.block(
                from: ForEachStateObservableView(items: [], creationProbe: creationProbe)
            ) == nil
        )
        #expect(
            runtime.block(
                from: ForEachStateObservableView(items: [item], creationProbe: creationProbe)
            )?.text == "2"
        )
        #expect(creationProbe.createdIDs == [1, 2])
    }
}
