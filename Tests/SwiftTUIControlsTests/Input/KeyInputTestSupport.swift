import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

struct ParentKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let childResult: KeyPress.Result

    var body: some View {
        VStack(spacing: 0) {
            CapturedParentChildKeyPressText(
                focusBinding: $isFocused,
                focusProbe: focusProbe,
                keyProbe: keyProbe,
                result: childResult
            )
        }
        .onKeyPress("a") {
            keyProbe.record("parent")
            return .handled
        }
    }
}

struct CapturedParentChildKeyPressText: View {

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

struct OrderedKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    var body: some View {
        CapturedOrderedKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe
        )
    }
}

struct FocusedAndGlobalKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let focusedResult: KeyPress.Result

    var body: some View {
        CapturedFocusedAndGlobalKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            focusedResult: focusedResult
        )
    }
}

struct DisabledInputModifiersView: View {

    @FocusState var isFocused: Bool = true

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let tapProbe: TapGestureProbe

    var body: some View {
        CapturedDisabledInputModifiersText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            tapProbe: tapProbe
        )
        .disabled(true)
    }
}

struct NestedGlobalKeyPressView: View {

    let keyProbe: KeyPressProbe

    let innerResult: KeyPress.Result

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("C")
                    .onGlobalKeyPress("a") {
                        keyProbe.record("inner")
                        return innerResult
                    }
            }
        }
        .onGlobalKeyPress("a") {
            keyProbe.record("outer")
            return .handled
        }
    }
}

struct CapturedDisabledInputModifiersText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let tapProbe: TapGestureProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        tapProbe: TapGestureProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.tapProbe = tapProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("focused")
                return .handled
            }
            .onGlobalKeyPress("g") {
                keyProbe.record("global")
                return .handled
            }
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onPointerPress {
                tapProbe.record("pointer")
                return .handled
            }
            .onHover { _ in
                tapProbe.record("hover")
            }
            .onContinuousHover { _ in
                tapProbe.record("continuous-hover")
            }
    }
}

struct PointerPressFocusableView: View {

    @FocusState private var isFocused = false

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let pointerProbe: PointerPressProbe

    var body: some View {
        CapturedPointerPressFocusableText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            pointerProbe: pointerProbe
        )
    }
}

struct CapturedPointerPressFocusableText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let pointerProbe: PointerPressProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        pointerProbe: PointerPressProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.pointerProbe = pointerProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress(.return) {
                keyProbe.record("return")
                return .handled
            }
            .onPointerPress(buttons: [.right, .middle]) { pointerPress in
                pointerProbe.record("pointer", pointerPress)
                return .handled
            }
    }
}

struct CapturedFocusedAndGlobalKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let focusedResult: KeyPress.Result

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        focusedResult: KeyPress.Result
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.focusedResult = focusedResult
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("focused")
                return focusedResult
            }
            .onGlobalKeyPress("a") {
                keyProbe.record("global")
                return .handled
            }
    }
}

struct GlobalEnvironmentTerminateView: View {

    @Environment(\.terminate) private var terminate

    var body: some View {
        Text("A")
            .onGlobalKeyPress(.escape) {
                terminate()
                return .handled
            }
    }
}

struct CapturedOrderedKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("first")
                return .handled
            }
            .onKeyPress("a") {
                keyProbe.record("second")
                return .handled
            }
    }
}

struct KeyPressOverloadView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    var body: some View {
        CapturedKeyPressOverloadText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe
        )
    }
}

struct CapturedKeyPressOverloadText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress(phases: .up) { _ in
                keyProbe.record("phase")
                return .handled
            }
            .onKeyPress("a") {
                keyProbe.record("plain")
                return .handled
            }
            .onKeyPress("b", phases: [.down, .repeat]) { _ in
                keyProbe.record("exact")
                return .handled
            }
            .onKeyPress(keys: ["c", "d"], phases: .repeat) { _ in
                keyProbe.record("set")
                return .handled
            }
            .onKeyPress(characters: .decimalDigits, phases: .down) { _ in
                keyProbe.record("characters")
                return .handled
            }
    }
}

struct OptionalFocusView: View {

    @FocusState var field: FocusField?

    let probe: FocusBindingProbe<FocusField?>

    var body: some View {
        VStack(spacing: 0) {
            CapturedOptionalFocusedText(
                "First",
                binding: $field,
                value: .first,
                probe: probe
            )
            CapturedOptionalFocusedText(
                "Second",
                binding: $field,
                value: .second,
                probe: probe
            )
        }
    }
}

struct CapturedOptionalFocusedText: View {

    let text: String

    let binding: FocusState<FocusField?>.Binding

    let value: FocusField

    init(
        _ text: String,
        binding: FocusState<FocusField?>.Binding,
        value: FocusField,
        probe: FocusBindingProbe<FocusField?>
    ) {
        self.text = text
        self.binding = binding
        self.value = value
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(binding, equals: value)
    }
}

struct DuplicateFocusValueView: View {

    @FocusState var field: FocusField?

    @FocusState var firstIsFocused: Bool

    @FocusState var secondIsFocused: Bool

    let fieldProbe: FocusBindingProbe<FocusField?>

    let firstProbe: FocusBindingProbe<Bool>

    let secondProbe: FocusBindingProbe<Bool>

    var body: some View {
        VStack(spacing: 0) {
            DuplicateFocusedText(
                "First",
                fieldBinding: $field,
                boolBinding: $firstIsFocused,
                fieldProbe: fieldProbe,
                boolProbe: firstProbe
            )
            DuplicateFocusedText(
                "Second",
                fieldBinding: $field,
                boolBinding: $secondIsFocused,
                fieldProbe: fieldProbe,
                boolProbe: secondProbe
            )
        }
    }
}

struct DuplicateFocusedText: View {

    let text: String

    let fieldBinding: FocusState<FocusField?>.Binding

    let boolBinding: FocusState<Bool>.Binding

    init(
        _ text: String,
        fieldBinding: FocusState<FocusField?>.Binding,
        boolBinding: FocusState<Bool>.Binding,
        fieldProbe: FocusBindingProbe<FocusField?>,
        boolProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.fieldBinding = fieldBinding
        self.boolBinding = boolBinding
        fieldProbe.capture(fieldBinding)
        boolProbe.capture(boolBinding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(fieldBinding, equals: .first)
            .focused(boolBinding)
    }
}
