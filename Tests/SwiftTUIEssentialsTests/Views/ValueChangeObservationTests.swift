import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Value Change Observation")
struct ValueChangeObservationTests {

    @Test
    func `onChange does not run during initial rendering by default`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(runtime.block(from: OnChangeValueView(value: 1, probe: probe))?.text == "1")
        #expect(probe.events.isEmpty)

        #expect(runtime.block(from: OnChangeValueView(value: 1, probe: probe))?.text == "1")
        #expect(probe.events.isEmpty)
    }

    @Test
    func `onChange with initial delivery enabled runs once for a stable view identity`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: OnChangeValueView(value: 1, initial: true, probe: probe)
            )?.text == "1"
        )
        #expect(probe.events == ["changed 1"])

        #expect(
            runtime.block(
                from: OnChangeValueView(value: 1, initial: true, probe: probe)
            )?.text == "1"
        )
        #expect(probe.events == ["changed 1"])
    }

    @Test
    func `a hidden view still runs its registered onChange action`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: OnChangeValueView(value: 1, initial: true, probe: probe)
                    .hidden()
            )?.runs == []
        )
        #expect(probe.events == ["changed 1"])

        #expect(
            runtime.block(
                from: OnChangeValueView(value: 2, initial: true, probe: probe)
                    .hidden()
            )?.runs == []
        )
        #expect(probe.events == ["changed 1", "changed 2"])
    }

    @Test
    func `onChange runs when the observed value changes`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(runtime.block(from: OnChangeValueView(value: 1, probe: probe))?.text == "1")
        #expect(runtime.block(from: OnChangeValueView(value: 2, probe: probe))?.text == "2")

        #expect(probe.events == ["changed 2"])
    }

    @Test
    func `a two-value onChange action receives the previous and current values`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(runtime.block(from: OnChangePairValueView(value: 1, probe: probe))?.text == "1")
        #expect(runtime.block(from: OnChangePairValueView(value: 2, probe: probe))?.text == "2")

        #expect(probe.events == ["changed 1 -> 2"])
    }

    @Test
    func `a two-value onChange action does not run when the observed value is unchanged`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(runtime.block(from: OnChangePairValueView(value: 1, probe: probe))?.text == "1")
        #expect(runtime.block(from: OnChangePairValueView(value: 1, probe: probe))?.text == "1")

        #expect(probe.events.isEmpty)
    }

    @Test
    func `an initial two-value onChange action runs once for a stable identity with the initial value as both arguments`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: OnChangePairValueView(value: 1, initial: true, probe: probe)
            )?.text == "1"
        )
        #expect(probe.events == ["changed 1 -> 1"])

        #expect(
            runtime.block(
                from: OnChangePairValueView(value: 1, initial: true, probe: probe)
            )?.text == "1"
        )
        #expect(probe.events == ["changed 1 -> 1"])
    }

    @Test
    func `an onChange state mutation invalidates and rerenders the view`() {
        let runtime = StateRuntime()

        #expect(runtime.block(from: OnChangeStateMutationView(value: 1))?.text == "idle")
        #expect(runtime.block(from: OnChangeStateMutationView(value: 2))?.text == "idle")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: OnChangeStateMutationView(value: 2))?.text == "changed")
    }

    @Test
    func `a two-value onChange state mutation receives both values and rerenders the view`() {
        let runtime = StateRuntime()

        #expect(runtime.block(from: OnChangePairStateMutationView(value: 1))?.text == "idle")
        #expect(runtime.block(from: OnChangePairStateMutationView(value: 2))?.text == "idle")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: OnChangePairStateMutationView(value: 2))?.text == "1 -> 2")
    }

    @Test
    func `onChange observes the latest environment values`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: OnChangeEnvironmentView(value: 1, probe: probe)
                    .environment(\.testMarker, "first")
            )?.text == "marker"
        )
        #expect(
            runtime.block(
                from: OnChangeEnvironmentView(value: 2, probe: probe)
                    .environment(\.testMarker, "second")
            )?.text == "marker"
        )

        #expect(probe.events == ["second"])
    }

    @Test
    func `a two-value onChange action observes the latest environment values`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: OnChangePairEnvironmentView(value: 1, probe: probe)
                    .environment(\.testMarker, "first")
            )?.text == "marker"
        )
        #expect(
            runtime.block(
                from: OnChangePairEnvironmentView(value: 2, probe: probe)
                    .environment(\.testMarker, "second")
            )?.text == "marker"
        )

        #expect(probe.events == ["second 1 -> 2"])
    }

    @Test
    func `an initial onChange action runs again when a conditional view is reinserted`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: ConditionalOnChangeView(isVisible: true, value: 1, probe: probe)
            )?.text == "A"
        )
        #expect(probe.events == ["changed 1"])

        #expect(runtime.block(from: ConditionalOnChangeView(isVisible: false, value: 1, probe: probe)) == nil)
        #expect(
            runtime.block(
                from: ConditionalOnChangeView(isVisible: true, value: 1, probe: probe)
            )?.text == "A"
        )
        #expect(probe.events == ["changed 1", "changed 1"])
    }

    @Test
    func `an initial two-value onChange action runs again when a conditional view is reinserted`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: ConditionalOnChangePairView(isVisible: true, value: 1, probe: probe)
            )?.text == "A"
        )
        #expect(probe.events == ["changed 1 -> 1"])

        #expect(runtime.block(from: ConditionalOnChangePairView(isVisible: false, value: 1, probe: probe)) == nil)
        #expect(
            runtime.block(
                from: ConditionalOnChangePairView(isVisible: true, value: 1, probe: probe)
            )?.text == "A"
        )
        #expect(probe.events == ["changed 1 -> 1", "changed 1 -> 1"])
    }

    @Test
    func `reordering ForEach items does not run zero-argument onChange actions`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()
        let first = [
            LifecycleItem(id: "a", label: "A"),
            LifecycleItem(id: "b", label: "B"),
        ]
        let reordered = [
            LifecycleItem(id: "b", label: "B"),
            LifecycleItem(id: "a", label: "A"),
        ]

        #expect(runtime.block(from: ForEachOnChangeView(items: first, probe: probe))?.lines == ["A", "B"])
        #expect(runtime.block(from: ForEachOnChangeView(items: reordered, probe: probe))?.lines == ["B", "A"])
        #expect(probe.events.isEmpty)
    }

    @Test
    func `reordering ForEach items does not run two-value onChange actions`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()
        let first = [
            LifecycleItem(id: "a", label: "A"),
            LifecycleItem(id: "b", label: "B"),
        ]
        let reordered = [
            LifecycleItem(id: "b", label: "B"),
            LifecycleItem(id: "a", label: "A"),
        ]

        #expect(runtime.block(from: ForEachOnChangePairView(items: first, probe: probe))?.lines == ["A", "B"])
        #expect(runtime.block(from: ForEachOnChangePairView(items: reordered, probe: probe))?.lines == ["B", "A"])
        #expect(probe.events.isEmpty)
    }
}
