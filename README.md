# SwiftTUI

> [!WARNING]
> This project was developed with assistance from AI systems such as LLMs.
> It may include features or behavior that have not been fully verified.

SwiftTUI is a Swift package for building terminal user interfaces with a
SwiftUI-shaped API. It renders views into terminal character cells, handles
keyboard and mouse input, and provides state, focus, layout, navigation, and
lifecycle primitives for interactive command-line apps.

## Requirements

- Swift 6 language mode.
- Swift tools version 6.3 or newer.
- macOS 15 or newer, as declared by the package manifest.
- An interactive terminal. `App.main()` takes over the terminal session while
  the app is running.

The package exposes one library product:

```swift
.product(name: "SwiftTUI", package: "swift-tui")
```

## Installation

Add the package to a SwiftPM package:

```swift
dependencies: [
    .package(url: "https://github.com/minacle/swift-tui", from: "0.4.1"),
]
```

Then depend on the library product from an executable target:

```swift
.executableTarget(
    name: "Example",
    dependencies: [
        .product(name: "SwiftTUI", package: "swift-tui"),
    ]
)
```

## Minimal App

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
        VStack(spacing: 1) {
            Text("Count: \(count)")
                .bold()

            HStack(spacing: 2) {
                Button("-") {
                    count -= 1
                }

                Button("+") {
                    count += 1
                }
            }
        }
        .padding()
    }
}
```

Run the executable in a real terminal, not through a non-interactive build log
or background process.

## How It Works

SwiftTUI provides a SwiftUI-shaped API for terminal apps. Views are measured in
character cells, rendered as terminal text with SGR styling, and updated from
keyboard and mouse events in an interactive terminal session.

SwiftTUI is not a SwiftUI renderer or native-control bridge. Its layout, focus,
scrolling, navigation, state, and lifecycle behavior are defined by this
package's terminal runtime.

## Validation

Use these commands from the package root:

```sh
swift build --product SwiftTUI
swift test
```

## License

This project is released under the terms in `UNLICENSE`.
