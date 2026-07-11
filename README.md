# SwiftTUI

> [!WARNING]
> This project was developed with assistance from AI systems such as LLMs.
> It may include features or behavior that have not been fully verified.

SwiftTUI is a Swift package for building terminal user interfaces with a
SwiftUI-shaped API.

## Requirements

- Swift 6.3 or newer
- macOS 15 or newer, or Linux
- An interactive terminal

## Installation

Add the package to a SwiftPM package:

```swift
dependencies: [
    .package(url: "https://github.com/minacle/swift-tui", from: "0.9.0"),
]
```

Add the `SwiftTUI` product to your executable target:

```swift
.executableTarget(
    name: "Example",
    dependencies: [
        .product(name: "SwiftTUI", package: "swift-tui"),
    ]
)
```

The package also provides three narrower products:

- `SwiftTUIRuns` provides recursive attributed string runs, terminal-cell
  measurement, Unicode line breaking, wrapping, and source-position mapping
  without depending on SwiftTUI views or runtime state.

- `SwiftTUIEssentials` contains the application runtime, state, environment,
  layout, rendering, input, navigation, scrolling, text, and `EditableText`
  primitives. It is sufficient for building a complete application without
  the standard controls.
- `SwiftTUIControls` adds `Button`, `TextField`, `SecureField`, and
  `TextEditor`, and re-exports `SwiftTUIEssentials`.

Use one of them in place of `SwiftTUI` when you want an explicit dependency
boundary. The `SwiftTUI` product remains the recommended convenience import
and re-exports the narrower modules.

## Example

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

Run the executable in an interactive terminal.

## License

This project is released under the terms in [UNLICENSE](UNLICENSE).
