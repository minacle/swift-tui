import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

struct SingleLineEditableText<Label: View>: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    let prompt: Text?

    let label: Label

    init(
        text: Binding<String>,
        prompt: Text? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.text = text
        self.selection = nil
        self.prompt = prompt
        self.label = label()
    }

    @ViewBuilder
    var body: some View {
        if let selection {
            EditableText(text: text, selection: selection)
                .placeholder {
                    if let prompt {
                        prompt
                    }
                    else {
                        label
                    }
                }
        }
        else {
            EditableText(text: text)
                .placeholder {
                    if let prompt {
                        prompt
                    }
                    else {
                        label
                    }
                }
        }
    }
}

extension SingleLineEditableText where Label == Text {

    init(
        _ title: String,
        text: Binding<String>,
        selection: Binding<TextSelection?>? = nil,
        prompt: Text? = nil
    ) {
        self.text = text
        self.selection = selection
        self.prompt = prompt
        self.label = Text(title)
    }
}

struct MaskedSingleLineEditableText: View {

    let title: String

    let text: Binding<String>

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self.text = text
    }

    var body: some View {
        EditableText(text: text, mask: "•")
            .placeholder {
                Text(title)
            }
    }
}

struct SingleLineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        SingleLineEditableText("Name", text: $text)
            .focused($isFocused)
    }
}

struct SelectionSingleLineEditableTextView: View {

    @State var text: String

    @State var selection: TextSelection?

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let selectionProbe: BindingProbe<TextSelection?>

    var body: some View {
        CapturedSelectionSingleLineEditableText(
            text: $text,
            selection: $selection,
            isFocused: $isFocused,
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
    }
}

struct CapturedSelectionSingleLineEditableText: View {

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
        SingleLineEditableText(
            "Name",
            text: text,
            selection: selection,
            prompt: Text("Enter a name")
        )
        .focused(isFocused)
    }
}

struct OverlayPlaceholderSingleLineEditableTextView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        ZStack {
            SingleLineEditableText("Placeholder", text: $text)
                .focused($isFocused)
            if text.isEmpty {
                Text("Placeholder")
                    .dim()
            }
        }
    }
}

struct NestedOverlaidURLSingleLineEditableTextEditingView: View {

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
                        SingleLineEditableText("Enter URL...", text: $urlString)
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

struct NestedZStackDelimitedSingleLineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            ZStack {
                SingleLineEditableText("URL", text: $text)
                    .focused($isFocused)
            }
            Text("]")
        }
    }
}

struct NestedHStackSingleLineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                SingleLineEditableText("URL", text: $text)
                    .focused($isFocused)
            }
            Text("X")
        }
    }
}

struct NestedMaskedSingleLineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                MaskedSingleLineEditableText("Password", text: $text)
                    .focused($isFocused)
            }
            Text("X")
        }
    }
}

struct DisabledFocusedSingleLineEditableTextView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusedSingleLineEditableText(
            text: $text,
            focus: $isFocused,
            textProbe: textProbe,
            focusProbe: focusProbe
        )
        .disabled(true)
    }
}

struct CapturedDisabledFocusedSingleLineEditableText: View {

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
        SingleLineEditableText("Name", text: text)
            .focused(focus)
    }
}

struct MaskedSingleLineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    var body: some View {
        CapturedMaskedSingleLineEditableText(
            text: $text,
            isFocused: $isFocused,
            textProbe: textProbe
        )
    }
}

struct CapturedMaskedSingleLineEditableText: View {

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
        MaskedSingleLineEditableText("Password", text: text)
            .focused(isFocused)
    }
}

struct TwoSingleLineEditableTextsClickFocusView: View {

    @State var first = ""

    @State var second = ""

    @FocusState var field: FocusField? = .first

    let focusProbe: FocusBindingProbe<FocusField?>

    let textProbe: LabeledStringBindingProbe

    var body: some View {
        CapturedTwoSingleLineEditableTexts(
            field: $field,
            first: $first,
            second: $second,
            focusProbe: focusProbe,
            textProbe: textProbe
        )
    }
}

struct FramedSingleLineEditableTextClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFramedSingleLineEditableText(
            text: $text,
            binding: $isFocused,
            focusProbe: focusProbe
        )
    }
}

struct CapturedFramedSingleLineEditableText: View {

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
        SingleLineEditableText("A", text: text)
            .frame(width: 5, alignment: .leading)
            .focused(binding)
    }
}

struct CapturedTwoSingleLineEditableTexts: View {

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
            SingleLineEditableText("first", text: first)
                .focused(field, equals: .first)
            SingleLineEditableText("second", text: second)
                .focused(field, equals: .second)
        }
    }
}

struct SingleLineEditableTextInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        SingleLineEditableText("Name", text: $text)
            .focused($isFocused)
    }
}

struct PrefixedNarrowSingleLineEditableTextInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("|")
            SingleLineEditableText("Name", text: $text)
                .focused($isFocused)
                .frame(width: 3, alignment: .leading)
        }
    }
}

struct DelimitedSingleLineEditableTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            SingleLineEditableText("Name", text: $text)
                .focused($isFocused)
                .frame(width: 32)
            Text("]")
        }
    }
}

struct ExactFitDelimitedFixedSizeSingleLineEditableTextView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            SingleLineEditableText("Name", text: $text)
                .fixedSize(horizontal: true, vertical: false)
                .focused($isFocused)
            Text("]")
        }
    }
}

struct FlexibleLabeledSingleLineEditableTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 1) {
            Text("Admin Token")
            SingleLineEditableText("Admin Token", text: $text)
                .focused($isFocused)
            Spacer()
        }
    }
}

struct LabeledSingleLineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 1) {
            Text("Label:")
            SingleLineEditableText("Name", text: $text)
                .focused($isFocused)
        }
    }
}

enum DynamicFocusRow: Hashable {

    case row
}

struct DynamicSingleLineEditableTextFocusWithOptionalRowFocusView: View {

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
                    SingleLineEditableText("", text: $draft)
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

struct ScrollWrappedDynamicSingleLineEditableTextFocusView: View {

    var body: some View {
        ScrollView(.vertical) {
            DynamicSingleLineEditableTextFocusWithOptionalRowFocusView()
        }
    }
}
