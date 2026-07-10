import Foundation
import Observation
import Testing
@testable import SwiftTUI

struct ForEachTestItem: Identifiable {

    let id: String

    let label: String
}

struct TestMarkerKey: EnvironmentKey {

    nonisolated static let defaultValue = "default"
}

extension EnvironmentValues {

    var testMarker: String {
        get {
            self[TestMarkerKey.self]
        }
        set {
            self[TestMarkerKey.self] = newValue
        }
    }
}

struct EnvironmentMarkerText: View {

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text(marker)
    }
}

struct LineLimitEnvironmentMarkerText: View {

    @Environment(\.lineLimit) private var lineLimit

    var body: some View {
        Text(lineLimit.map(String.init) ?? "nil")
    }
}

struct TruncationModeEnvironmentMarkerText: View {

    @Environment(\.truncationMode) private var truncationMode

    var body: some View {
        Text(String(describing: truncationMode))
    }
}

struct MultilineTextAlignmentEnvironmentMarkerText: View {

    @Environment(\.multilineTextAlignment) private var alignment

    var body: some View {
        Text(String(describing: alignment))
    }
}

struct IsFocusedEnvironmentMarkerText: View {

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Text(isFocused ? "focused" : "unfocused")
    }
}

struct IsPresentedEnvironmentMarkerText: View {

    @Environment(\.isPresented) private var isPresented

    let rootLabel: String

    var body: some View {
        Text(isPresented ? "presented" : rootLabel)
    }
}

struct IsScrollEnabledEnvironmentMarkerText: View {

    @Environment(\.isScrollEnabled) private var isScrollEnabled

    var body: some View {
        Text(isScrollEnabled ? "enabled" : "disabled")
    }
}

struct TypedEnvironmentObjectMarkerText: View {

    @Environment(TestObservableModel.self) private var model

    let objectProbe: ObjectProbe<TestObservableModel>?

    init(objectProbe: ObjectProbe<TestObservableModel>? = nil) {
        self.objectProbe = objectProbe
    }

    var body: some View {
        CapturedTypedEnvironmentObjectMarker(
            model: model,
            objectProbe: objectProbe
        )
    }
}

struct CapturedTypedEnvironmentObjectMarker: View {

    let model: TestObservableModel

    init(
        model: TestObservableModel,
        objectProbe: ObjectProbe<TestObservableModel>?
    ) {
        self.model = model
        objectProbe?.capture(model)
    }

    var body: some View {
        Text("\(model.count)")
    }
}

struct OptionalTypedEnvironmentObjectMarkerText: View {

    @Environment(TestObservableModel.self) private var model: TestObservableModel?

    let objectProbe: ObjectProbe<TestObservableModel>?

    init(objectProbe: ObjectProbe<TestObservableModel>? = nil) {
        self.objectProbe = objectProbe
    }

    var body: some View {
        CapturedOptionalTypedEnvironmentObjectMarker(
            model: model,
            objectProbe: objectProbe
        )
    }
}

struct CapturedOptionalTypedEnvironmentObjectMarker: View {

    let model: TestObservableModel?

    init(
        model: TestObservableModel?,
        objectProbe: ObjectProbe<TestObservableModel>?
    ) {
        self.model = model
        if let model {
            objectProbe?.capture(model)
        }
    }

    var body: some View {
        Text(model.map { "\($0.count)" } ?? "nil")
    }
}

struct TypedAndKeyPathEnvironmentMarkerText: View {

    @Environment(\.testMarker) private var marker

    @Environment(TestObservableModel.self) private var model

    var body: some View {
        Text("\(marker):\(model.count)")
    }
}

struct TypedEnvironmentObjectProjectionMarkerText: View {

    @Environment(TestObservableModel.self) private var model

    let bindingProbe: BindingProbe<String>

    let objectProbe: ObjectProbe<TestObservableModel>

    var body: some View {
        CapturedTypedEnvironmentObjectProjectionMarker(
            text: $model.token,
            model: model,
            bindingProbe: bindingProbe,
            objectProbe: objectProbe
        )
    }
}

struct CapturedTypedEnvironmentObjectProjectionMarker: View {

    let text: Binding<String>

    init(
        text: Binding<String>,
        model: TestObservableModel,
        bindingProbe: BindingProbe<String>,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        self.text = text
        bindingProbe.capture(text)
        objectProbe.capture(model)
    }

    var body: some View {
        Text(text.wrappedValue)
    }
}

struct TypedEnvironmentTextFieldRootView: View {

    @State private var model: TestObservableModel

    let objectProbe: ObjectProbe<TestObservableModel>

    init(initialToken: String, objectProbe: ObjectProbe<TestObservableModel>) {
        _model = State(wrappedValue: TestObservableModel(token: initialToken))
        self.objectProbe = objectProbe
    }

    var body: some View {
        TypedEnvironmentTextField(objectProbe: objectProbe)
            .environment(model)
    }
}

struct TypedEnvironmentTextField: View {

    @Environment(TestObservableModel.self) private var model

    @FocusState private var isFocused = true

    let objectProbe: ObjectProbe<TestObservableModel>

    var body: some View {
        CapturedTypedEnvironmentTextField(
            text: $model.token,
            model: model,
            focus: $isFocused,
            objectProbe: objectProbe
        )
    }
}

struct CapturedTypedEnvironmentTextField: View {

    let text: Binding<String>

    let focus: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        model: TestObservableModel,
        focus: FocusState<Bool>.Binding,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        self.text = text
        self.focus = focus
        objectProbe.capture(model)
    }

    var body: some View {
        TextField("Token", text: text)
            .focused(focus)
    }
}

struct ButtonSizingMarkerText: View {

    @Environment(\.buttonSizing) private var sizing

    var body: some View {
        if sizing == .flexible {
            Text("flexible")
        }
        else if sizing == .fitted {
            Text("fitted")
        }
        else {
            Text("automatic")
        }
    }
}

struct IsEnabledMarkerText: View {

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Text(isEnabled ? "enabled" : "disabled")
    }
}

struct EnvironmentStateMarkerView: View {

    @State var marker = "initial"

    let probe: BindingProbe<String>

    var body: some View {
        EnvironmentMarkerProbe(
            binding: $marker,
            probe: probe
        )
        .environment(\.testMarker, marker)
    }
}

struct ParentCapturedEnvironmentMarkerView: View {

    @Environment(\.testMarker) private var marker

    var body: some View {
        CapturedEnvironmentMarkerText(capturedMarker: marker)
            .environment(\.testMarker, "child")
    }
}

struct CapturedEnvironmentMarkerText: View {

    @Environment(\.testMarker) private var directMarker

    let capturedMarker: String

    var body: some View {
        Text("captured \(capturedMarker) direct \(directMarker)")
    }
}
