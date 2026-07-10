import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("ForEach Behavior")
struct ForEachBehaviorTests {

    @Test
    func `ForEach with an explicit ID key path renders elements in collection order`() {
        let items = [
            ForEachTestItem(id: "a", label: "A"),
            ForEachTestItem(id: "b", label: "B"),
        ]

        let view = ForEach(items, id: \.id) { item in
            Text(item.label)
        }

        #expect(ViewResolver.block(from: view)?.lines == ["A", "B"])
    }

    @Test
    func `ForEach over Identifiable elements renders them in collection order`() {
        let items = [
            ForEachTestItem(id: "a", label: "A"),
            ForEachTestItem(id: "b", label: "B"),
        ]

        let view = ForEach(items) { item in
            Text(item.label)
        }

        #expect(ViewResolver.block(from: view)?.lines == ["A", "B"])
    }

    @Test
    func `ForEach over a range renders values in range order`() {
        let view = ForEach(0..<3) { value in
            Text(String(value))
        }

        #expect(ViewResolver.block(from: view)?.lines == ["0", "1", "2"])
    }

    @Test
    func `ForEach preserves child state by ID when elements reorder`() {
        let runtime = StateRuntime()
        let probe = LabeledBindingProbe()
        let firstOrder = [
            ForEachTestItem(id: "a", label: "A"),
            ForEachTestItem(id: "b", label: "B"),
        ]
        let secondOrder = [
            ForEachTestItem(id: "b", label: "B"),
            ForEachTestItem(id: "a", label: "A"),
        ]

        #expect(
            runtime.block(from: ForEachStateView(items: firstOrder, probe: probe))?.lines
                == ["0", "0"]
        )

        probe.bindings["a"]?.wrappedValue = 7

        #expect(runtime.consumeInvalidation())
        #expect(
            runtime.block(from: ForEachStateView(items: secondOrder, probe: probe))?.lines
                == ["0", "7"]
        )
    }

    @Test
    func `removing and reinserting a ForEach element creates fresh child state`() {
        let runtime = StateRuntime()
        let probe = LabeledBindingProbe()
        let item = ForEachTestItem(id: "a", label: "A")

        #expect(runtime.block(from: ForEachStateView(items: [item], probe: probe))?.lines == ["0"])

        probe.bindings["a"]?.wrappedValue = 5

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: ForEachStateView(items: [], probe: probe)) == nil)
        #expect(runtime.block(from: ForEachStateView(items: [item], probe: probe))?.lines == ["0"])
    }

    @Test
    func `ForEach tap hit testing follows rendered rows after reordering`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let firstOrder = [
            ForEachTestItem(id: "a", label: "A"),
            ForEachTestItem(id: "b", label: "B"),
        ]
        let secondOrder = [
            ForEachTestItem(id: "b", label: "B"),
            ForEachTestItem(id: "a", label: "A"),
        ]

        _ = runtime.block(from: ForEachTapView(items: firstOrder, tapProbe: tapProbe))
        dispatchClick(to: runtime, column: 1, row: 2)

        _ = runtime.block(from: ForEachTapView(items: secondOrder, tapProbe: tapProbe))
        dispatchClick(to: runtime, column: 1, row: 2)

        #expect(tapProbe.events == ["b", "a"])
    }

    @Test
    func `ForEach button hit testing follows rendered rows after reordering`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let firstOrder = [
            ForEachTestItem(id: "a", label: "A"),
            ForEachTestItem(id: "b", label: "B"),
        ]
        let secondOrder = [
            ForEachTestItem(id: "b", label: "B"),
            ForEachTestItem(id: "a", label: "A"),
        ]

        _ = runtime.block(from: ForEachButtonView(items: firstOrder, tapProbe: tapProbe))
        dispatchClick(to: runtime, column: 1, row: 2)

        _ = runtime.block(from: ForEachButtonView(items: secondOrder, tapProbe: tapProbe))
        dispatchClick(to: runtime, column: 1, row: 2)

        #expect(tapProbe.events == ["b", "a"])
    }
}
