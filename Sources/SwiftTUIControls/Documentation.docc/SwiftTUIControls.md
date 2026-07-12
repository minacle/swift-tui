# ``SwiftTUIControls``

Add standard buttons and editable text controls to a SwiftTUI application.

## Overview

`SwiftTUIControls` provides ``Button``, ``TextField``, ``SecureField``, and
``TextEditor``. It re-exports `SwiftTUIEssentials`, so a target that imports
this module can also declare an ``App``, compose views, manage state, and use
the complete foundational API without importing the essentials module
separately.

Controls participate in SwiftTUI's focus and input systems. Buttons respond to
Return and primary-pointer taps. Text fields and editors synchronize edits
through ``Binding`` values, accept keyboard and pointer selection, render a
text caret while focused, and scroll as needed to keep that caret visible.

```swift
import SwiftTUIControls

@main
struct EditorApp: App {
    var body: some Scene {
        WindowGroup {
            EditorView()
        }
    }
}

struct EditorView: View {
    @State private var title = ""
    @State private var notes = """
        Highlights

        - Faster rendering
        - Better keyboard input
        """

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Title", text: $title)
            TextEditor(text: $notes)
                .frame(width: 40, height: 8)
            Button("Clear") {
                title = ""
                notes = ""
            }
        }
    }
}
```

``SecureField`` masks only rendered characters. Its binding still contains the
original string, and the control doesn't protect that value from application
memory, logs, persistence, callbacks, or other code with access to the
binding. Sanitize untrusted labels, prompts, and bound text before rendering
because the underlying text APIs preserve terminal control characters.

## Topics

### Buttons

- ``Button``
- ``ButtonSizing``
- ``View/buttonSizing(_:)``

### Single-line text input

- ``TextField``
- ``SecureField``
- ``View/onSubmit(_:)``

### Multi-line text input

- ``TextEditor``

### Shared editing state

- ``Binding``
- ``TextSelection``
