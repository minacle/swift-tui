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
    .package(url: "https://github.com/minacle/swift-tui", from: "0.7.0"),
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
