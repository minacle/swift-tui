# ``SwiftTUIControls``

Compose terminal-native actions, disclosure rows, editable text, and scroll
indicators.

## Overview

`SwiftTUIControls` adds standard interactive controls to the application,
layout, state, focus, and input systems in `SwiftTUIEssentials`. The module
re-exports those foundational APIs, so importing `SwiftTUIControls` is enough
to declare an ``App``, build a view hierarchy, store model values with
``State``, and connect them to controls through ``Binding``.

### Choose a control

| Need | API | Observable contract |
| --- | --- | --- |
| Run an action | ``Button`` | Runs its action synchronously after a completed primary-pointer tap or for Return key-down and repeat events while focused, then handles the completing input sample. |
| Reveal optional content | ``DisclosureGroup`` | Toggles only when its leading triangle receives a completed primary-pointer tap; it adds no focus or keyboard interaction. |
| Edit one rendered row | ``TextField`` | Within a finite width, scrolls horizontally to keep its caret visible; Return invokes an installed submission action and then handles the sample without inserting a newline. |
| Mask one rendered row | ``SecureField`` | Uses the same editing and conditional Return-handling model as `TextField`, but renders one bullet per `Character`. |
| Edit wrapped, multi-line text | ``TextEditor`` | Is flexible in both axes, wraps to a finite column proposal, and inserts a newline for Return. |
| Show scroll position | ``View/scrollIndicators(_:axes:)`` | Installs the standard horizontal and vertical indicator attachments on the selected axes. |

``TextField`` and ``SecureField`` invoke the nearest
``View/onSubmit(_:)`` action as an eager deferred event for Return. Immediate
key handlers run first; after invoking the submission action, the field handles
the sample before later input events, global-key fallback, or key resolution.
Return remains unhandled when no submission action is installed. ``TextEditor``
never invokes that action. Single-line describes the fields' layout and input
behavior, not validation: they don't remove newline characters already present
in a bound string. Editable controls request focus from primary-pointer presses
and use keyboard and pointer selection while enabled.

### Compose controls with shared state

The controls read and write bindings, so an action, disclosure row, and editor
can share one model without an intermediate control object:

```swift
import SwiftTUIControls

@main
struct ProfileEditorApp: App {
    var body: some Scene {
        WindowGroup {
            ProfileEditor()
        }
    }
}

struct ProfileEditor: View {
    @State private var name = ""
    @State private var password = ""
    @State private var showsNotes = true
    @State private var notes = """
        Follow up on Tuesday.
        Confirm the terminal deployment.
        """
    @State private var status = "Not saved"

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Profile").bold()

            TextField("Name", text: $name, prompt: Text("Required"))
                .onSubmit {
                    save()
                }
            SecureField("Password", text: $password)

            DisclosureGroup("Notes", isExpanded: $showsNotes) {
                TextEditor(text: $notes)
                    .frame(width: 40, height: 6, alignment: .topLeading)
            }

            Button("Save") {
                save()
            }
            .buttonSizing(.flexible)

            Text(status)
        }
        .frame(width: 40, alignment: .leading)
    }

    private func save() {
        status = name.isEmpty ? "Enter a name" : "Saved \(name)"
    }
}
```

``ButtonSizing/flexible`` makes the trailing columns added to fill the proposed
width part of the button's focus and pointer hit region. A bound
``DisclosureGroup`` publishes triangle-driven changes through its binding;
omit `isExpanded` when the group should instead start collapsed and retain
expansion state locally.

> Important: ``SecureField`` masks only rendered characters and still reveals
> the value's `Character` count. Its binding contains the original string, and
> the control doesn't erase or protect that value in application memory, logs,
> persistence, callbacks, or other code. SwiftTUI text APIs also preserve
> terminal control characters, so validate or sanitize untrusted labels,
> prompts, and displayed values before rendering them.

### Add standard scroll indicators

Apply ``View/scrollIndicators(_:axes:)`` around a ``ScrollView`` to install
the standard interactive track and thumb for each selected axis:

```swift
import SwiftTUIControls

struct ActivityLog: View {
    var body: some View {
        ScrollView {
            Text("""
                09:00 Started worker
                09:01 Connected to database
                09:02 Processed first batch
                09:03 Processed second batch
                09:04 Waiting for work
                09:05 Received shutdown signal
                """)
        }
        .frame(width: 32, height: 5, alignment: .topLeading)
        .scrollIndicators(.visible, axes: .vertical)
    }
}
```

``ScrollIndicatorVisibility/visible`` reserves one terminal column for a
vertical indicator or one row for a horizontal indicator, and shows it only
while that axis can scroll. ``ScrollIndicatorVisibility/hidden`` instead
overlays a temporarily shown indicator without reserving cells; combine it
with ``View/scrollIndicatorsFlash(onAppear:)`` or
``View/scrollIndicatorsFlash(trigger:)`` when the interface needs an explicit
visibility cue. ``ScrollIndicatorVisibility/never`` prevents an indicator
from being created or shown.

``HorizontalScrollIndicator`` and ``VerticalScrollIndicator`` are the standard
attachment views. They draw a proportional thumb at half-cell resolution;
dragging the thumb changes the offset, while pressing the track before or after
it moves by one viewport. Their attachment keys pass a
``ScrollIndicatorConfiguration`` from a ``ScrollView`` to a custom indicator
view when the interface needs a different presentation or input treatment.

For the re-exported application, layout, state, and input APIs, browse the
[SwiftTUIEssentials API](../swifttuiessentials/).

## Topics

### Buttons and actions

- ``Button``
- ``ButtonSizing``
- ``View/buttonSizing(_:)``
- ``EnvironmentValues/buttonSizing``

### Disclosure

- ``DisclosureGroup``

### Single-line text input

- ``TextField``
- ``SecureField``
- ``View/onSubmit(_:)``

### Multi-line text input

- ``TextEditor``

### Editing state

- ``Binding``
- ``TextSelection``

### Standard scroll indicators

- ``View/scrollIndicators(_:axes:)``
- ``HorizontalScrollIndicator``
- ``VerticalScrollIndicator``
- ``ScrollIndicatorVisibility``
- ``View/scrollIndicatorsFlash(onAppear:)``
- ``View/scrollIndicatorsFlash(trigger:)``

### Scroll-indicator customization

- ``ScrollIndicatorConfiguration``
- ``HorizontalScrollIndicatorAttachmentKey``
- ``VerticalScrollIndicatorAttachmentKey``
- ``EnvironmentValues/horizontalScrollIndicatorVisibility``
- ``EnvironmentValues/verticalScrollIndicatorVisibility``
