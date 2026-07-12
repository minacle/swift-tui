# ``SwiftTUIEssentials``

Build complete terminal applications from SwiftTUI's foundational APIs.

## Overview

`SwiftTUIEssentials` provides the application lifecycle, view and state model,
terminal-cell layout and rendering, keyboard and pointer input, focus,
navigation, scrolling, text, and shape primitives. It also re-exports
`SwiftTUIRuns`, whose attributed runs supply the text measurement and wrapping
model used by ``Text`` and ``EditableText``.

Declare an ``App`` with a ``WindowGroup`` and compose its root view with
containers such as ``VStack``, ``Grid``, and ``ScrollView``. The module is
sufficient for a complete application when you want to build interactions from
input modifiers and ``EditableText`` instead of depending on the standard
controls in `SwiftTUIControls`.

```swift
import SwiftTUIEssentials

@main
struct DashboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
    }
}

struct DashboardView: View {
    var body: some View {
        RoundedBox {
            VStack(alignment: .leading) {
                Text("Service status").bold()
                Divider()
                HStack {
                    Text("API")
                    Spacer()
                    Text("ready")
                }
                HStack {
                    Text("Worker")
                    Spacer()
                    Text("ready")
                }
            }
            .padding(1)
        }
        .frame(width: 32)
    }
}
```

Layout dimensions, coordinates, and spacing are measured in terminal columns
and rows rather than points. Input and rendering remain terminal-dependent:
terminals can differ in the keys, modifier flags, pointer events, colors, and
Unicode cell widths they report or display. Sanitize untrusted strings before
rendering them because text APIs preserve terminal control characters.

## Topics

### Application and view composition

- ``App``
- ``Scene``
- ``WindowGroup``
- ``View``
- ``ViewBuilder``
- ``ForEach``

### State and environment

- ``State``
- ``Binding``
- ``Bindable``
- ``Environment``
- ``EnvironmentValues``
- ``FocusState``

### Layout and containers

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

### Rendering model

- <doc:RenderingPipeline>

### Text, shapes, and decoration

- ``Text``
- ``EditableText``
- ``TextSelection``
- ``Shape``
- ``Rectangle``
- ``Box``
- ``Divider``

### Input and navigation

- ``InputEvent``
- ``KeyEvent``
- ``PointerEvent``
- ``KeyPressEvent``
- ``PointerPressEvent``
- ``KeyPress``
- ``PointerPress``
- ``NavigationStack``
- ``NavigationLink``
- ``NavigationPath``
