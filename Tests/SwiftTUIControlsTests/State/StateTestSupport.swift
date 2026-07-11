import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

enum FocusField: Hashable {

    case first

    case second
}

struct CapturedCounterText: View {

    let text: String

    init(_ value: Int, binding: Binding<Int>, probe: BindingProbe<Int>) {
        self.text = String(value)
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
    }
}

struct LabeledCapturedCounterText: View {

    let text: String

    init(_ value: Int, binding: Binding<Int>, label: String, probe: LabeledBindingProbe) {
        self.text = String(value)
        probe.capture(binding, label: label)
    }

    var body: some View {
        Text(text)
    }
}

struct RootCounterView: View {

    @State var count = 0

    let probe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(count, binding: $count, probe: probe)
    }
}

struct ParentCounterView: View {

    let probe: BindingProbe<Int>

    var body: some View {
        ChildCounterView(probe: probe)
    }
}

struct ChildCounterView: View {

    @State var count = 0

    let probe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(count, binding: $count, probe: probe)
    }
}

struct SiblingCounterView: View {

    let probe: LabeledBindingProbe

    var body: some View {
        VStack(spacing: 0) {
            LabeledChildCounterView(label: "first", probe: probe)
            LabeledChildCounterView(label: "second", probe: probe)
        }
    }
}

struct ConditionalBranchStateView: View {

    let usesFirstBranch: Bool

    let probe: LabeledBindingProbe

    var body: some View {
        if usesFirstBranch {
            LabeledChildCounterView(label: "first", probe: probe)
        }
        else {
            LabeledChildCounterView(label: "second", probe: probe)
        }
    }
}

struct LabeledChildCounterView: View {

    @State var count = 0

    let label: String

    let probe: LabeledBindingProbe

    var body: some View {
        LabeledCapturedCounterText(
            count,
            binding: $count,
            label: label,
            probe: probe
        )
    }
}

struct StateObservableCounterView: View {

    @State private var model: TestObservableModel

    let objectProbe: ObjectProbe<TestObservableModel>

    init(
        initialCount: Int,
        creationProbe: ObjectCreationProbe,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        _model = State(
            wrappedValue: TestObservableModel(
                count: initialCount,
                creationProbe: creationProbe
            )
        )
        self.objectProbe = objectProbe
    }

    var body: some View {
        CapturedObservableCounterText(
            model: model,
            objectProbe: objectProbe
        )
    }
}

struct BindableCounterView: View {

    @Bindable var model: TestObservableModel

    let bindingProbe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(model.count, binding: $model.count, probe: bindingProbe)
    }
}

struct ConditionalObservableCounterView: View {

    let first: TestObservableModel

    let second: TestObservableModel

    let usesFirst: Bool

    var body: some View {
        if usesFirst {
            Text("\(first.count)")
        }
        else {
            Text("\(second.count)")
        }
    }
}

struct ForEachStateObservableView: View {

    let items: [ForEachTestItem]

    let creationProbe: ObjectCreationProbe

    var body: some View {
        ForEach(items, id: \.id) { item in
            StateObservableRow(label: item.label, creationProbe: creationProbe)
        }
    }
}

struct StateObservableRow: View {

    @State private var model: TestObservableModel

    let label: String

    init(label: String, creationProbe: ObjectCreationProbe) {
        _model = State(
            wrappedValue: TestObservableModel(creationProbe: creationProbe)
        )
        self.label = label
    }

    var body: some View {
        Text("\(model.id)")
    }
}

struct CapturedObservableCounterText: View {

    let text: String

    init(
        model: TestObservableModel,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        self.text = String(model.count)
        objectProbe.capture(model)
    }

    var body: some View {
        Text(text)
    }
}
