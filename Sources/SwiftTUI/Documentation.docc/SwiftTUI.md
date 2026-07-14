# ``SwiftTUI``

Build terminal user interfaces with a SwiftUI-like API.

## Overview

`SwiftTUI` is the package's complete convenience import. It combines the
application lifecycle, view and state model, terminal-cell layout, rendering,
input, navigation, text primitives, and standard controls exposed by the
narrower SwiftTUI modules.

Declare an ``App`` with a ``WindowGroup``, compose its content from ``View``
values, and store local mutable values with ``State``. SwiftTUI runs the root
view in the current interactive terminal and updates its rendered cells as
state and input change.

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
    @State private var count = 0

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") {
                count += 1
            }
        }
    }
}
```

Import `SwiftTUIRuns`, `SwiftTUIEssentials`, or `SwiftTUIControls` directly
when you want an explicit dependency boundary. The umbrella module adds no
separate UI primitives; it re-exports the complete public surface of the
narrower modules.

Browse the [Runs API](../swifttuiruns/),
[Essentials API](../swifttuiessentials/), and
[Controls API](../swifttuicontrols/) for the declarations owned by each module.

## Topics

### Application structure

- ``App``
- ``Scene``
- ``WindowGroup``
- ``View``

### State and content

- ``State``
- ``Binding``
- ``Text``
- ``HStack``
- ``VStack``
- ``ZStack``

### Controls

- ``Button``
- ``DisclosureGroup``
- ``TextField``
- ``SecureField``
- ``TextEditor``
