import Foundation
import Observation
import Testing
@testable import SwiftTUI

struct ConditionalLifecycleView: View {

    let isVisible: Bool

    let probe: LifecycleProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isVisible {
                Text("A")
                    .onAppear {
                        probe.events.append("appear")
                    }
                    .onDisappear {
                        probe.events.append("disappear")
                    }
            }
            Text("B")
        }
    }
}

struct LifecycleAppearStateView: View {

    @State private var status = "initial"

    var body: some View {
        Text(status)
            .onAppear {
                status = "appeared"
            }
    }
}

struct LifecycleDisappearStateView: View {

    let isVisible: Bool

    @State private var status = "visible"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(status)
            if isVisible {
                Text("child")
                    .onDisappear {
                        status = "gone"
                    }
            }
        }
    }
}

struct EnvironmentLifecycleView: View {

    let probe: LifecycleProbe

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text("marker")
            .onAppear {
                probe.events.append(marker)
            }
    }
}

struct ConditionalTaskView: View {

    let isVisible: Bool

    let probe: AsyncTaskProbe

    var body: some View {
        if isVisible {
            Text("A")
                .task {
                    probe.record("start")
                    do {
                        try await Task.sleep(nanoseconds: 60_000_000_000)
                    }
                    catch {
                        probe.record("cancel")
                    }
                }
        }
    }
}

struct TaskStateMutationView: View {

    let probe: AsyncTaskProbe

    @State private var status = "idle"

    var body: some View {
        Text(status)
            .task {
                await Task.yield()
                status = "done"
                probe.record("done")
            }
    }
}

struct LifecycleItem: Identifiable, Equatable {

    let id: String

    var label: String
}

struct ForEachLifecycleView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            Text(item.label)
                .onAppear {
                    probe.events.append("appear \(item.id)")
                }
                .onDisappear {
                    probe.events.append("disappear \(item.id)")
                }
        }
    }
}

struct StatefulForEachLifecycleView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            StatefulLifecycleRow(item: item, probe: probe)
        }
    }
}

struct StatefulLifecycleRow: View {

    let item: LifecycleItem

    let probe: LifecycleProbe

    @State private var status = "fresh"

    var body: some View {
        Text("\(item.label):\(status)")
            .onAppear {
                status = "active"
            }
            .onDisappear {
                probe.events.append("disappear \(item.label):\(status)")
            }
    }
}

struct StackedLifecycleView: View {

    let isVisible: Bool

    let probe: LifecycleProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isVisible {
                Text("A")
                    .onAppear {
                        probe.events.append("inner appear")
                    }
                    .onDisappear {
                        probe.events.append("inner disappear")
                    }
                    .onAppear {
                        probe.events.append("outer appear")
                    }
                    .onDisappear {
                        probe.events.append("outer disappear")
                    }
            }
        }
    }
}

struct OnChangeValueView: View {

    let value: Int

    var initial = false

    let probe: LifecycleProbe

    var body: some View {
        Text("\(value)")
            .onChange(of: value, initial: initial) {
                probe.events.append("changed \(value)")
            }
    }
}

struct OnChangePairValueView: View {

    let value: Int

    var initial = false

    let probe: LifecycleProbe

    var body: some View {
        Text("\(value)")
            .onChange(of: value, initial: initial) { oldValue, newValue in
                probe.events.append("changed \(oldValue) -> \(newValue)")
            }
    }
}

struct OnChangeStateMutationView: View {

    let value: Int

    @State private var status = "idle"

    var body: some View {
        Text(status)
            .onChange(of: value) {
                status = "changed"
            }
    }
}

struct OnChangePairStateMutationView: View {

    let value: Int

    @State private var status = "idle"

    var body: some View {
        Text(status)
            .onChange(of: value) { oldValue, newValue in
                status = "\(oldValue) -> \(newValue)"
            }
    }
}

struct OnChangeEnvironmentView: View {

    let value: Int

    let probe: LifecycleProbe

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text("marker")
            .onChange(of: value) {
                probe.events.append(marker)
            }
    }
}

struct OnChangePairEnvironmentView: View {

    let value: Int

    let probe: LifecycleProbe

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text("marker")
            .onChange(of: value) { oldValue, newValue in
                probe.events.append("\(marker) \(oldValue) -> \(newValue)")
            }
    }
}

struct ConditionalOnChangeView: View {

    let isVisible: Bool

    let value: Int

    let probe: LifecycleProbe

    var body: some View {
        if isVisible {
            Text("A")
                .onChange(of: value, initial: true) {
                    probe.events.append("changed \(value)")
                }
        }
    }
}

struct ConditionalOnChangePairView: View {

    let isVisible: Bool

    let value: Int

    let probe: LifecycleProbe

    var body: some View {
        if isVisible {
            Text("A")
                .onChange(of: value, initial: true) { oldValue, newValue in
                    probe.events.append("changed \(oldValue) -> \(newValue)")
                }
        }
    }
}

struct ForEachOnChangeView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            Text(item.label)
                .onChange(of: item.label) {
                    probe.events.append("changed \(item.id)")
                }
        }
    }
}

struct ForEachOnChangePairView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            Text(item.label)
                .onChange(of: item.label) { _, _ in
                    probe.events.append("changed \(item.id)")
                }
        }
    }
}

struct EnvironmentMarkerProbe: View {

    init(binding: Binding<String>, probe: BindingProbe<String>) {
        probe.capture(binding)
    }

    var body: some View {
        EnvironmentMarkerText()
    }
}
