# ``SwiftTUI``

Build full-screen, interactive terminal applications from declarative Swift
views.

## Overview

`SwiftTUI` is the complete convenience import for the package. It combines the
application lifecycle, state and environment model, terminal-cell layout,
rendering, input, navigation, text primitives, and standard controls owned by
the package's narrower modules.

Declare an ``App`` with one ``WindowGroup``, then compose its content from
``View`` values. SwiftTUI resolves that hierarchy into terminal cells and
updates the current interactive terminal when state, input, deadlines, or the
viewport change.

```swift
import SwiftTUI

@main
struct CounterApp: App {
    var body: some Scene {
        WindowGroup {
            CounterView()
        }
    }
}

struct CounterView: View {
    @Environment(\.terminate) private var terminate
    @State private var count = 0

    var body: some View {
        RoundedBox {
            VStack(alignment: .leading) {
                Text("Counter").bold()
                Divider()
                Text("Count: \(count)")
                HStack {
                    Button("Increment") {
                        count += 1
                    }
                    Button("Quit") {
                        terminate()
                    }
                }
            }
            .padding(1)
        }
        .frame(width: 30)
    }
}
```

Run an app in an interactive terminal. The application runtime owns the
full-screen terminal session until termination, and restores its terminal
configuration when normal shutdown completes. Control-C requests termination;
use ``View/onTerminate(perform:)`` when the app needs to intercept that request
and ``EnvironmentValues/terminate`` to finish the session.

### Choose a dependency boundary

Most applications should depend on and import `SwiftTUI`. Import a narrower
product when a library or executable needs a more explicit boundary:

| Module | Public responsibility |
| --- | --- |
| [`SwiftTUI`](../swifttui/) | Re-exports the complete package through one import. |
| [`SwiftTUIControls`](../swifttuicontrols/) | Adds buttons, disclosure views, editable fields, editors, and interactive scroll indicators to the essentials layer. |
| [`SwiftTUIEssentials`](../swifttuiessentials/) | Owns applications, views, state, environment, layout, rendering, input, focus, navigation, scrolling, text, and shapes. |
| [`SwiftTUIRuns`](../swifttuiruns/) | Owns view-independent attributed text, terminal-cell measurement, Unicode line breaking, wrapping, and source-position mapping. |

`SwiftTUI` adds no UI declarations of its own. It re-exports
`SwiftTUIControls` and `SwiftTUIEssentials`; those modules transitively expose
the lower layers needed by their public APIs.

### Design for terminal cells

SwiftTUI adopts familiar declarative names without importing or wrapping
SwiftUI. Consult each symbol's documentation for its terminal-specific
contract rather than assuming source compatibility or identical behavior.

Dimensions and coordinates are integer terminal columns and rows, not points.
A terminal can vary in the key phases, modifier flags, pointer events, colors,
and Unicode cell widths it supports. ``WindowGroup`` represents one terminal
viewport and doesn't create platform windows. Pointer input represents one
two-dimensional pointer; it doesn't provide touch, multiple pointers, or
pixel-precise locations.

Text APIs preserve control characters and escape sequences. Sanitize untrusted
labels, prompts, links, pasted content, and bound text before rendering them so
external content can't issue commands to the user's terminal. A
``SecureField`` masks its rendered characters only; its binding still contains
the original string.

### Render a view without running an app

Use ``ViewRenderer`` for snapshots, command output, and tests that need one
synchronous render instead of an interactive session:

```swift
let output = ViewRenderer.render(
    Text("Build succeeded")
        .bold()
        .foregroundStyle(.green),
    proposedSize: ProposedViewSize(columns: 40, rows: nil)
)

print(output.ansiText, terminator: "")
```

The resulting ``RenderedView`` contains the resolved rows, plain text,
SGR-styled ANSI text, and terminal-cell size. One-shot rendering doesn't start
the application loop, process input, run lifecycle callbacks or tasks, or
perform terminal-screen positioning.

## Topics

### Application structure

- ``App``
- ``Scene``
- ``WindowGroup``
- ``View``
- ``ViewBuilder``
- ``ForEach``

### State, data, and environment

- ``State``
- ``Binding``
- ``Bindable``
- ``Environment``
- ``EnvironmentValues``
- ``FocusState``

### Layout and scrolling

- ``Layout``
- ``AnyLayout``
- ``ProposedViewSize``
- ``HStack``
- ``VStack``
- ``ZStack``
- ``Grid``
- ``ScrollView``
- ``ViewThatFits``
- ``GeometryReader``

### Text, shapes, and decoration

- ``Text``
- ``EditableText``
- ``TextSelection``
- ``Shape``
- ``Rectangle``
- ``Box``
- ``RoundedBox``
- ``Divider``

### Input and navigation

- ``InputEvent``
- ``KeyPressEvent``
- ``PointerPressEvent``
- ``Gesture``
- ``Shortcut``
- ``NavigationStack``
- ``NavigationLink``
- ``NavigationPath``

### Standard controls

- ``Button``
- ``DisclosureGroup``
- ``TextField``
- ``SecureField``
- ``TextEditor``
- ``View/scrollIndicators(_:axes:)``

### One-shot rendering

- ``ViewRenderer``
- ``RenderedView``
