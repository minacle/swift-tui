import Foundation
import Observation
import Testing
@testable import SwiftTUI

struct TextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
    }
}

struct SelectionTextEditorView: View {

    @State var text: String

    @State var selection: TextSelection?

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let selectionProbe: BindingProbe<TextSelection?>

    var body: some View {
        CapturedSelectionTextEditor(
            text: $text,
            selection: $selection,
            isFocused: $isFocused,
            textProbe: textProbe,
            selectionProbe: selectionProbe
        )
    }
}

struct CapturedSelectionTextEditor: View {

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
        TextEditor(text: text, selection: selection)
            .focused(isFocused)
    }
}

struct FullScreenBackgroundTextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .background(.red)
    }
}

struct FramedTextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(width: 3, height: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightFramedTextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(width: 3, alignment: .topLeading)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightOnlyTextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightOnlyTextEditorClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct MaxHeightConstantTextEditorBelowScrollViewView: View {

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    Text("")
                }
            }
            HStack {
                Box {
                    TextEditor(text: .constant(""))
                        .frame(maxHeight: 4)
                }
                Spacer()
            }
        }
    }
}

struct FramedTextEditorInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(width: 3, height: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

struct TextEditorBelowScrollViewView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    Text("")
                }
            }
            Box {
                TextEditor(text: $text)
                    .focused($isFocused)
            }
        }
    }
}

struct DisabledFocusedTextEditorView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusedTextEditor(
            text: $text,
            focus: $isFocused,
            textProbe: textProbe,
            focusProbe: focusProbe
        )
        .disabled(true)
    }
}

struct CapturedDisabledFocusedTextEditor: View {

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
        TextEditor(text: text)
            .focused(focus)
    }
}

struct TextEditorInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
    }
}

struct PrefixedBoundedTextEditorInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("top")
            TextEditor(text: $text)
                .focused($isFocused)
                .frame(width: 4, height: 2, alignment: .leading)
        }
    }
}

struct TextEditorSubmitView: View {

    @State var text = ""

    @State var submitted = "none"

    @FocusState var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $text)
                .focused($isFocused)
                .onSubmit {
                    submitted = text
                }
            Text(submitted)
        }
    }
}

struct FramedTextEditorClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFramedTextEditor(
            text: $text,
            binding: $isFocused,
            focusProbe: focusProbe
        )
    }
}

struct CapturedFramedTextEditor: View {

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
        TextEditor(text: text)
            .frame(width: 5, height: 3, alignment: .topLeading)
            .focused(binding)
    }
}

struct CapturedTextEditorView: View {

    @State var text: String

    @FocusState var isFocused = true

    let probe: BindingProbe<String>

    var body: some View {
        CapturedTextEditor(
            text: $text,
            isFocused: $isFocused,
            probe: probe
        )
    }
}

struct CapturedTextEditor: View {

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
        TextEditor(text: text)
            .focused(isFocused)
    }
}
