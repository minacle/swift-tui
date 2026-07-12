import Foundation
import Observation
import Testing

@testable import SwiftTUIEssentials

struct MultilineEditableText: View {

    let text: Binding<String>

    let selection: Binding<TextSelection?>?

    init(
        text: Binding<String>,
        selection: Binding<TextSelection?>? = nil
    ) {
        self.text = text
        self.selection = selection
    }

    @ViewBuilder
    var body: some View {
        if let selection {
            EditableText(
                text: text,
                selection: selection,
                lineMode: .multiline
            )
        }
        else {
            EditableText(text: text, lineMode: .multiline)
        }
    }
}

struct MultilineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        MultilineEditableText(text: $text)
            .focused($isFocused)
    }
}

struct SelectionMultilineEditableTextView: View {

    @State var text: String

    @State var selection: TextSelection?

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let selectionProbe: BindingProbe<TextSelection?>

    var body: some View {
        CapturedSelectionMultilineEditableText(
            text: $text,
            selection: $selection,
            isFocused: $isFocused,
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
    }
}

struct CapturedSelectionMultilineEditableText: View {

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
        MultilineEditableText(text: text, selection: selection)
            .focused(isFocused)
    }
}

struct FullScreenBackgroundMultilineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        MultilineEditableText(text: $text)
            .focused($isFocused)
            .background(.red)
    }
}

struct FramedMultilineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        MultilineEditableText(text: $text)
            .frame(width: 3, height: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightFramedMultilineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        MultilineEditableText(text: $text)
            .frame(width: 3, alignment: .topLeading)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightOnlyMultilineEditableTextEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        MultilineEditableText(text: $text)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightOnlyMultilineEditableTextClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    var body: some View {
        MultilineEditableText(text: $text)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightConstantMultilineEditableTextBelowScrollViewView: View {

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("")
                }
            }
            HStack(spacing: 0) {
                Box {
                    MultilineEditableText(text: .constant(""))
                        .frame(maxHeight: 4)
                }
                Spacer()
            }
        }
    }
}

struct FramedMultilineEditableTextInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        MultilineEditableText(text: $text)
            .frame(width: 3, height: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MultilineEditableTextBelowScrollViewView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("")
                }
            }
            Box {
                MultilineEditableText(text: $text)
                    .focused($isFocused)
            }
        }
    }
}

struct DisabledFocusedMultilineEditableTextView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusedMultilineEditableText(
            text: $text,
            focus: $isFocused,
            textProbe: textProbe,
            focusProbe: focusProbe
        )
        .disabled(true)
    }
}

struct CapturedDisabledFocusedMultilineEditableText: View {

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
        MultilineEditableText(text: text)
            .focused(focus)
    }
}

struct MultilineEditableTextInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        MultilineEditableText(text: $text)
            .focused($isFocused)
    }
}

struct PrefixedBoundedMultilineEditableTextInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("top")
            MultilineEditableText(text: $text)
                .focused($isFocused)
                .frame(width: 4, height: 2, alignment: .leading)
        }
    }
}

struct FramedMultilineEditableTextClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFramedMultilineEditableText(
            text: $text,
            binding: $isFocused,
            focusProbe: focusProbe
        )
    }
}

struct CapturedFramedMultilineEditableText: View {

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
        MultilineEditableText(text: text)
            .frame(width: 5, height: 3, alignment: .topLeading)
            .focused(binding)
    }
}

struct CapturedMultilineEditableTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    let probe: BindingProbe<String>

    var body: some View {
        CapturedMultilineEditableText(
            text: $text,
            isFocused: $isFocused,
            probe: probe
        )
    }
}

struct CapturedMultilineEditableText: View {

    let text: Binding<String>

    let isFocused: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        probe: BindingProbe<String>
    ) {
        self.text = text
        self.isFocused = isFocused
        probe.capture(text)
    }

    var body: some View {
        MultilineEditableText(text: text)
            .focused(isFocused)
    }
}
