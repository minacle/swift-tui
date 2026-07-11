import Foundation
import Observation
import Testing
@testable import SwiftTUI

struct TextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextField("Name", text: $text)
            .focused($isFocused)
    }
}

struct SelectionTextFieldView: View {

    @State var text: String

    @State var selection: TextSelection?

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let selectionProbe: BindingProbe<TextSelection?>

    var body: some View {
        CapturedSelectionTextField(
            text: $text,
            selection: $selection,
            isFocused: $isFocused,
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
    }
}

struct CapturedSelectionTextField: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>

    let isFocused: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        selection: Binding<TextSelection?>,
        isFocused: FocusState<Bool>.Binding,
        textProbe: BindingProbe<String>,
        selectionProbe: BindingProbe<TextSelection?>
    ) {
        self.text = text
        self.selection = selection
        self.isFocused = isFocused
        textProbe.capture(text)
        selectionProbe.capture(selection)
    }

    var body: some View {
        TextField(
            "Name",
            text: text,
            selection: selection,
            prompt: Text("Enter a name")
        )
        .focused(isFocused)
    }
}

struct OverlayPlaceholderTextFieldView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        ZStack {
            TextField("Placeholder", text: $text)
                .focused($isFocused)
            if text.isEmpty {
                Text("Placeholder")
                    .dim()
            }
        }
    }
}

struct NestedOverlaidURLTextFieldEditingView: View {

    @State var urlString = ""

    @FocusState var isFocused = true

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 2) {
                HStack(alignment: .top, spacing: 0) {
                    Text("App Title")
                        .bold()
                    Spacer()
                }
                HStack(spacing: 0) {
                    Text("[")
                        .dim()
                    ZStack {
                        TextField("Enter URL...", text: $urlString)
                            .focused($isFocused)
                        if urlString.isEmpty {
                            Text("Enter URL...")
                                .dim()
                        }
                    }
                    Text("]")
                        .dim()
                }
            }
        }
    }
}

struct NestedZStackDelimitedTextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            ZStack {
                TextField("URL", text: $text)
                    .focused($isFocused)
            }
            Text("]")
        }
    }
}

struct NestedHStackTextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                TextField("URL", text: $text)
                    .focused($isFocused)
            }
            Text("X")
        }
    }
}

struct NestedSecureFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                SecureField("Password", text: $text)
                    .focused($isFocused)
            }
            Text("X")
        }
    }
}

struct DisabledFocusedTextFieldView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusedTextField(
            text: $text,
            focus: $isFocused,
            textProbe: textProbe,
            focusProbe: focusProbe
        )
        .disabled(true)
    }
}

struct CapturedDisabledFocusedTextField: View {

    let text: Binding<String>

    let focus: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        focus: FocusState<Bool>.Binding,
        textProbe: BindingProbe<String>,
        focusProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.focus = focus
        textProbe.capture(text)
        focusProbe.capture(focus)
    }

    var body: some View {
        TextField("Name", text: text)
            .focused(focus)
    }
}

struct SecureFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    var body: some View {
        CapturedSecureField(
            text: $text,
            isFocused: $isFocused,
            textProbe: textProbe
        )
    }
}

struct CapturedSecureField: View {

    let text: Binding<String>

    let isFocused: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        textProbe: BindingProbe<String>
    ) {
        self.text = text
        self.isFocused = isFocused
        textProbe.capture(text)
    }

    var body: some View {
        SecureField("Password", text: text)
            .focused(isFocused)
    }
}

struct TwoTextFieldsClickFocusView: View {

    @State var first = ""

    @State var second = ""

    @FocusState var field: FocusField? = .first

    let focusProbe: FocusBindingProbe<FocusField?>

    let textProbe: LabeledStringBindingProbe

    var body: some View {
        CapturedTwoTextFields(
            field: $field,
            first: $first,
            second: $second,
            focusProbe: focusProbe,
            textProbe: textProbe
        )
    }
}

struct FramedTextFieldClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFramedTextField(
            text: $text,
            binding: $isFocused,
            focusProbe: focusProbe
        )
    }
}

struct CapturedFramedTextField: View {

    let text: Binding<String>

    let binding: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        binding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.binding = binding
        focusProbe.capture(binding)
    }

    var body: some View {
        TextField("A", text: text)
            .frame(width: 5, alignment: .leading)
            .focused(binding)
    }
}

struct CapturedTwoTextFields: View {

    let field: FocusState<FocusField?>.Binding

    let first: Binding<String>

    let second: Binding<String>

    init(
        field: FocusState<FocusField?>.Binding,
        first: Binding<String>,
        second: Binding<String>,
        focusProbe: FocusBindingProbe<FocusField?>,
        textProbe: LabeledStringBindingProbe
    ) {
        self.field = field
        self.first = first
        self.second = second
        focusProbe.capture(field)
        textProbe.capture(first, label: "first")
        textProbe.capture(second, label: "second")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("first", text: first)
                .focused(field, equals: .first)
            TextField("second", text: second)
                .focused(field, equals: .second)
        }
    }
}

struct TextFieldInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        TextField("Name", text: $text)
            .focused($isFocused)
    }
}

struct PrefixedNarrowTextFieldInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("|")
            TextField("Name", text: $text)
                .focused($isFocused)
                .frame(width: 3, alignment: .leading)
        }
    }
}

struct SecureFieldInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        SecureField("Password", text: $text)
            .focused($isFocused)
    }
}

struct DelimitedTextFieldView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            TextField("Name", text: $text)
                .focused($isFocused)
                .frame(width: 32)
            Text("]")
        }
    }
}

struct ExactFitDelimitedFixedSizeTextFieldView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            TextField("Name", text: $text)
                .fixedSize(horizontal: true, vertical: false)
                .focused($isFocused)
            Text("]")
        }
    }
}

struct FlexibleLabeledTextFieldView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 1) {
            Text("Admin Token")
            TextField("Admin Token", text: $text)
                .focused($isFocused)
            Spacer()
        }
    }
}

struct LabeledTextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 1) {
            Text("Label:")
            TextField("Name", text: $text)
                .focused($isFocused)
        }
    }
}

struct TextFieldSubmitView: View {

    @State var text = ""

    @State var submitted = "none"

    @FocusState var isFocused = true

    var body: some View {
        VStack(spacing: 0) {
            TextField("Name", text: $text)
                .focused($isFocused)
                .onSubmit {
                    submitted = text
                }
            Text(submitted)
        }
    }
}

struct SecureFieldSubmitView: View {

    @State var text = ""

    @State var submitted = "none"

    @FocusState var isFocused = true

    var body: some View {
        VStack(spacing: 0) {
            SecureField("Password", text: $text)
                .focused($isFocused)
                .onSubmit {
                    submitted = text
                }
            Text(submitted)
        }
    }
}

enum DynamicFocusRow: Hashable {

    case row
}

struct DynamicTextFieldFocusWithOptionalRowFocusView: View {

    @State var isEditing = false

    @State var draft = ""

    @FocusState var selectedRow: DynamicFocusRow? = .row

    @FocusState var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("row")
                .focusable(!isEditing)
                .focused($selectedRow, equals: .row)

            if isEditing {
                HStack(spacing: 0) {
                    Text("> ")
                    TextField("", text: $draft)
                        .focused($editorFocused)
                    Spacer()
                }
            }
        }
        .onKeyPress(.return) {
            isEditing = true
            editorFocused = true
            return .handled
        }
    }
}

struct ScrollWrappedDynamicTextFieldFocusView: View {

    var body: some View {
        ScrollView(.vertical) {
            DynamicTextFieldFocusWithOptionalRowFocusView()
        }
    }
}
