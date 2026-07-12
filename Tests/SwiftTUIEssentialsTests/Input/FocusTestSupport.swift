import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

struct BoolFocusableThenFocusedView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusableThenFocusedText(binding: $isFocused, probe: probe)
    }
}

struct FocusedEnvironmentMarkerView: View {

    @FocusState private var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFocusedEnvironmentMarker(
            binding: $isFocused,
            probe: probe
        )
    }
}

struct CapturedFocusedEnvironmentMarker: View {

    let binding: FocusState<Bool>.Binding

    init(
        binding: FocusState<Bool>.Binding,
        probe: FocusBindingProbe<Bool>
    ) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        IsFocusedEnvironmentMarkerText()
            .focused(binding)
    }
}

struct NestedFocusableEnvironmentMarkerView: View {

    @FocusState private var isFocused = true

    var body: some View {
        VStack(spacing: 0) {
            IsFocusedEnvironmentMarkerText()
                .focusable()
        }
        .focused($isFocused)
    }
}

struct FocusableEnvironmentButton: View {

    var body: some View {
        Button(action: {}) {
            IsFocusedEnvironmentMarkerText()
        }
    }
}

struct FocusableEnvironmentTextField: View {

    @State private var text = ""

    var body: some View {
        TextField(text: $text) {
            IsFocusedEnvironmentMarkerText()
        }
    }
}

struct FocusableEnvironmentNavigationLink: View {

    var body: some View {
        NavigationStack {
            NavigationLink(destination: {
                Text("destination")
            }) {
                IsFocusedEnvironmentMarkerText()
            }
        }
    }
}

struct ClickableFocusedTextView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFocusableText(binding: $isFocused, probe: probe)
    }
}

struct PaddedFramedClickFocusView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("top")
            CapturedFocusableText(binding: $isFocused, probe: probe)
                .padding(.leading, 1)
                .frame(width: 3, alignment: .leading)
        }
    }
}

struct RetortFediLikeConfigurationScreen: View {

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("Title")
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Name", text: $text)
                    Text("Row2")
                    Text("Row3")
                    Text("Row4")
                    Text("Row5")
                }
            }
            Text("Desc")
                .lineLimit(3)
            Spacer()
            HStack(spacing: 0) {
                Text("Footer")
                Spacer()
            }
        }
    }
}

enum GeometryReaderRoute {

    case menu

    case configuration
}

struct GeometryReaderRouteHost: View {

    @State private var route = GeometryReaderRoute.menu

    @FocusState private var menuFocused = true

    var body: some View {
        switch route {
        case .menu:
            Text("Menu")
                .focusable()
                .focused($menuFocused)
                .onKeyPress(.return) {
                    route = .configuration
                    return .handled
                }
        case .configuration:
            GeometryReaderRouteConfigurationScreen()
        }
    }
}

struct GeometryReaderRouteConfigurationScreen: View {

    @State private var selectedRow = 0

    @FocusState private var focusedRow: Int?

    var body: some View {
        GeometryReader { proxy in
            let listRows = max(proxy.rows - 3, 1)

            VStack(alignment: .leading, spacing: 0) {
                Text("Size \(proxy.columns)x\(proxy.rows)")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<6) { row in
                            GeometryReaderRouteRow(
                                row: row,
                                isSelected: row == selectedRow,
                                focusedRow: $focusedRow
                            )
                        }
                    }
                }
                .frame(height: listRows)
                Text("Desc")
                Text("Footer")
            }
            .onAppear {
                focusedRow = selectedRow
            }
            .onKeyPress(.downArrow) {
                selectedRow = min(selectedRow + 1, 5)
                focusedRow = selectedRow
                return .handled
            }
        }
    }
}

struct GeometryReaderRouteRow: View {

    let row: Int

    let isSelected: Bool

    let focusedRow: FocusState<Int?>.Binding

    var body: some View {
        Text("\(isSelected ? ">" : " ") Row\(row)")
            .focusable()
            .focused(focusedRow, equals: row)
            .onKeyPress(.downArrow) {
                .ignored
            }
    }
}

struct ScrolledClickFocusView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("A")
                CapturedFocusableText(binding: $isFocused, probe: probe, text: "B")
            }
        }
        .scrollPosition(.constant(ScrollPosition(y: 1)))
        .frame(width: 1, height: 1)
    }
}

struct ScrollWrappedTextFieldsClickFocusView: View {

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                TextField("Vertical", text: .constant(""))
            }
            ScrollView(.horizontal) {
                TextField("Horizontal", text: .constant(""))
            }
        }
    }
}

struct DisabledClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledClickFocusTextField(
            text: $text,
            binding: $isFocused,
            probe: probe
        )
    }
}

struct CapturedDisabledClickFocusTextField: View {

    let text: Binding<String>

    let binding: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        binding: FocusState<Bool>.Binding,
        probe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        TextField("A", text: text)
            .focusable(false)
            .focused(binding)
    }
}

struct ClickFocusTapGestureView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let tapProbe: TapGestureProbe

    var body: some View {
        CapturedFocusableText(binding: $isFocused, probe: focusProbe)
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onLongPressGesture {
                tapProbe.record("long")
            }
    }
}

struct CapturedFocusableText: View {

    let binding: FocusState<Bool>.Binding

    let text: String

    init(
        binding: FocusState<Bool>.Binding,
        probe: FocusBindingProbe<Bool>,
        text: String = "A"
    ) {
        self.binding = binding
        self.text = text
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(binding)
    }
}

struct FocusedScrollWheelView: View {

    @FocusState var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("focus")
                .focusable()
                .focused($isFocused)
            ScrollView {
                VStack(spacing: 0) {
                    Text("A")
                    Text("B")
                    Text("C")
                }
            }
            .frame(width: 1, height: 2)
        }
    }
}

struct BoolFocusedThenFocusableView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusedThenFocusableText(binding: $isFocused, probe: probe)
    }
}

struct BoolFocusedOnlyView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusedOnlyText(binding: $isFocused, probe: probe)
    }
}

struct ClickableFocusedOnlyTextView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusedOnlyText(binding: $isFocused, probe: probe)
    }
}

struct OptionalFocusedOnlyView: View {

    @FocusState var field: FocusField?

    let probe: FocusBindingProbe<FocusField?>

    var body: some View {
        CapturedOptionalFocusedOnlyText(
            binding: $field,
            value: .first,
            probe: probe
        )
    }
}

struct DisabledFocusableView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusableText(binding: $isFocused, probe: probe)
    }
}

struct CapturedBoolFocusableThenFocusedText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(binding)
    }
}

struct CapturedBoolFocusedThenFocusableText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focused(binding)
            .focusable()
    }
}

struct CapturedBoolFocusedOnlyText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focused(binding)
    }
}

struct CapturedOptionalFocusedOnlyText: View {

    let binding: FocusState<FocusField?>.Binding

    let value: FocusField

    init(
        binding: FocusState<FocusField?>.Binding,
        value: FocusField,
        probe: FocusBindingProbe<FocusField?>
    ) {
        self.binding = binding
        self.value = value
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focused(binding, equals: value)
    }
}

struct CapturedDisabledFocusableText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focusable(false)
            .focused(binding)
    }
}

struct FocusedKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    var body: some View {
        CapturedFocusedKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            result: result
        )
    }
}

struct CapturedFocusedKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        result: KeyPress.Result
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.result = result
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("child")
                return result
            }
    }
}

struct KeyPressStateMutationView: View {

    @State var count = 0

    @FocusState var isFocused = true

    var body: some View {
        Text(String(count))
            .focusable()
            .focused($isFocused)
            .onKeyPress("a") {
                count += 1
                return .handled
            }
    }
}

struct ParentCallbackDirectStateMutationKeyPressView: View {

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParentCallbackKeyPressChildView {
                message = "updated"
            }
            Text(message.isEmpty ? "empty" : message)
        }
    }
}

struct ParentCallbackBindingMutationKeyPressView: View {

    @State private var message = ""

    var body: some View {
        let message = $message

        return VStack(alignment: .leading, spacing: 0) {
            ParentCallbackKeyPressChildView {
                message.wrappedValue = "updated"
            }
            Text(message.wrappedValue.isEmpty ? "empty" : message.wrappedValue)
        }
    }
}

struct ParentCallbackKeyPressChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Press")
            .focusable()
            .onKeyPress(.return) {
                action()
                return .handled
            }
    }
}

func focusParentCallbackKeyPressChild(in runtime: StateRuntime) {
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    #expect(
        runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .down),
            at: date
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            PointerPress(button: .left, location: .zero, phase: .up),
            at: date
        ) == .ignored
    )
}
