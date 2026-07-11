import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("View Lifecycle")
struct ViewLifecycleTests {

    @Test
    func `onAppear runs once for a stable view identity`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()
        let view = Text("A")
            .onAppear {
                probe.events.append("appear")
            }

        #expect(runtime.block(from: view)?.text == "A")
        #expect(probe.events == ["appear"])

        #expect(runtime.block(from: view)?.text == "A")
        #expect(probe.events == ["appear"])
    }

    @Test
    func `onAppear without an action leaves the view unchanged`() {
        let runtime = StateRuntime()

        #expect(runtime.block(from: Text("A").onAppear())?.text == "A")
    }

    @Test
    func `a hidden view still runs its registered onAppear action`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()
        let view = Text("A")
            .onAppear {
                probe.events.append("appear")
            }
            .hidden()

        #expect(runtime.block(from: view)?.runs == [])
        #expect(probe.events == ["appear"])

        #expect(runtime.block(from: view)?.runs == [])
        #expect(probe.events == ["appear"])
    }

    @Test
    func `onDisappear runs when an identity is removed and onAppear runs again when it returns`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        #expect(
            runtime.block(
                from: ConditionalLifecycleView(isVisible: true, probe: probe)
            )?.lines == ["A", "B"]
        )
        #expect(probe.events == ["appear"])

        #expect(
            runtime.block(
                from: ConditionalLifecycleView(isVisible: true, probe: probe)
            )?.lines == ["A", "B"]
        )
        #expect(probe.events == ["appear"])

        #expect(
            runtime.block(
                from: ConditionalLifecycleView(isVisible: false, probe: probe)
            )?.lines == ["B"]
        )
        #expect(probe.events == ["appear", "disappear"])

        #expect(
            runtime.block(
                from: ConditionalLifecycleView(isVisible: true, probe: probe)
            )?.lines == ["A", "B"]
        )
        #expect(probe.events == ["appear", "disappear", "appear"])
    }

    @Test
    func `onAppear and onDisappear state mutations invalidate and rerender their views`() {
        let appearRuntime = StateRuntime()

        #expect(appearRuntime.block(from: LifecycleAppearStateView())?.text == "initial")
        #expect(appearRuntime.consumeInvalidation())
        #expect(appearRuntime.block(from: LifecycleAppearStateView())?.text == "appeared")

        let disappearRuntime = StateRuntime()
        #expect(
            disappearRuntime.block(
                from: LifecycleDisappearStateView(isVisible: true)
            )?.lines == ["visible", "child  "]
        )
        #expect(
            disappearRuntime.block(
                from: LifecycleDisappearStateView(isVisible: false)
            )?.lines == ["visible"]
        )
        #expect(disappearRuntime.consumeInvalidation())
        #expect(
            disappearRuntime.block(
                from: LifecycleDisappearStateView(isVisible: false)
            )?.lines == ["gone"]
        )
    }

    @Test
    func `onAppear reads the environment in which its view is rendered`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()
        let view = EnvironmentLifecycleView(probe: probe)
            .environment(\.testMarker, "parent")

        #expect(runtime.block(from: view)?.text == "marker")
        #expect(probe.events == ["parent"])
    }

    @Test
    func `a task starts once for a stable view identity`() async {
        let runtime = StateRuntime()
        let probe = AsyncTaskProbe()
        let view = Text("A")
            .task {
                probe.record("start")
            }

        #expect(runtime.block(from: view)?.text == "A")
        await probe.waitForCount(1)
        #expect(probe.events == ["start"])

        #expect(runtime.block(from: view)?.text == "A")
        await Task.yield()
        #expect(probe.events == ["start"])
    }

    @Test
    func `a hidden view still starts its registered task`() async {
        let runtime = StateRuntime()
        let probe = AsyncTaskProbe()
        let view = Text("A")
            .task {
                probe.record("start")
            }
            .hidden()

        #expect(runtime.block(from: view)?.runs == [])
        await probe.waitForCount(1)
        #expect(probe.events == ["start"])
    }

    @Test
    func `task accepts name, priority, file, and line metadata`() async {
        let runtime = StateRuntime()
        let probe = AsyncTaskProbe()
        let view = Text("A")
            .task(
                name: "metadata",
                priority: .userInitiated,
                file: "SwiftTUITests.swift",
                line: 1
            ) {
                probe.record("metadata")
            }

        #expect(runtime.block(from: view)?.text == "A")
        await probe.waitForCount(1)
        #expect(probe.events == ["metadata"])
    }

    @Test
    func `changing a task identifier cancels the previous task and starts a new one`() async {
        let runtime = StateRuntime()
        let probe = AsyncTaskProbe()

        #expect(runtime.block(from: IdentifiedTaskView(id: 1, probe: probe))?.text == "1")
        await probe.waitForCount(1)

        #expect(runtime.block(from: IdentifiedTaskView(id: 1, probe: probe))?.text == "1")
        await Task.yield()
        #expect(probe.events == ["start 1"])

        #expect(runtime.block(from: IdentifiedTaskView(id: 2, probe: probe))?.text == "2")
        await probe.waitForCount(3)
        let events = probe.events
        #expect(events.contains("cancel 1"))
        #expect(events.contains("start 2"))

        _ = runtime.block(from: EmptyView())
    }

    @Test
    func `task with an ID accepts name, priority, file, and line metadata`() async {
        let runtime = StateRuntime()
        let probe = AsyncTaskProbe()
        let view = Text("A")
            .task(
                id: 1,
                name: "metadata-id",
                priority: .userInitiated,
                file: "SwiftTUITests.swift",
                line: 1
            ) {
                probe.record("metadata-id")
            }

        #expect(runtime.block(from: view)?.text == "A")
        await probe.waitForCount(1)
        #expect(probe.events == ["metadata-id"])
    }

    @Test
    func `a task is cancelled when its view disappears`() async {
        let runtime = StateRuntime()
        let probe = AsyncTaskProbe()

        #expect(runtime.block(from: ConditionalTaskView(isVisible: true, probe: probe))?.text == "A")
        await probe.waitForCount(1)

        #expect(runtime.block(from: ConditionalTaskView(isVisible: false, probe: probe)) == nil)
        await probe.waitForCount(2)
        #expect(probe.events == ["start", "cancel"])
    }

    @Test
    func `a state mutation after suspension in a task invalidates and rerenders the view`() async {
        let runtime = StateRuntime()
        let probe = AsyncTaskProbe()

        #expect(runtime.block(from: TaskStateMutationView(probe: probe))?.text == "idle")
        await probe.waitForCount(1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: TaskStateMutationView(probe: probe))?.text == "done")
    }

    @Test
    func `reordering ForEach items does not trigger lifecycle actions`() {
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

        #expect(runtime.block(from: ForEachLifecycleView(items: first, probe: probe))?.lines == ["A", "B"])
        #expect(probe.events == ["appear a", "appear b"])

        #expect(runtime.block(from: ForEachLifecycleView(items: reordered, probe: probe))?.lines == ["B", "A"])
        #expect(probe.events == ["appear a", "appear b"])
    }

    @Test
    func `removing a ForEach item runs onDisappear before discarding its state`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()
        let item = LifecycleItem(id: "a", label: "A")

        #expect(
            runtime.block(
                from: StatefulForEachLifecycleView(items: [item], probe: probe)
            )?.text == "A:fresh"
        )
        #expect(runtime.consumeInvalidation())
        #expect(
            runtime.block(
                from: StatefulForEachLifecycleView(items: [item], probe: probe)
            )?.text == "A:active"
        )

        #expect(runtime.block(from: StatefulForEachLifecycleView(items: [], probe: probe)) == nil)
        #expect(probe.events == ["disappear A:active"])

        #expect(
            runtime.block(
                from: StatefulForEachLifecycleView(items: [item], probe: probe)
            )?.text == "A:fresh"
        )
    }

    @Test
    func `stacked lifecycle modifiers run from outermost to innermost`() {
        let runtime = StateRuntime()
        let probe = LifecycleProbe()

        _ = runtime.block(from: StackedLifecycleView(isVisible: true, probe: probe))
        #expect(probe.events == ["outer appear", "inner appear"])

        _ = runtime.block(from: StackedLifecycleView(isVisible: false, probe: probe))
        #expect(
            probe.events == [
                "outer appear",
                "inner appear",
                "outer disappear",
                "inner disappear",
            ]
        )
    }
}
