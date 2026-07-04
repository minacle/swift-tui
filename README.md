# SwiftTUI

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
    .package(url: "https://github.com/minacle/swift-tui", from: "0.1.0"),
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

## Core Concepts

SwiftTUI views measure and render in terminal character cells. Widths are
columns, heights are rows, and layout proposals may leave either dimension
unspecified. Text rendering accounts for Unicode display width and line
wrapping, but the final output is still terminal text and SGR styling.

- `App`, `Scene`, and `WindowGroup` define the root terminal session.
- `View`, `ViewBuilder`, `Group`, `ForEach`, `EmptyView`, and `AnyView` define
  composable terminal view content.
- `Text`, `TextField`, `SecureField`, `TextEditor`, and text modifiers render
  styled and editable text.
- `Button`, `onTapGesture`, `onKeyPress`, and `onGlobalKeyPress` handle input.
- `HStack`, `VStack`, `Spacer`, `GeometryReader`, frame modifiers, padding,
  `hidden`, and custom `Layout` implementations control terminal-cell layout.
- `ScrollView` and `ScrollPosition` provide bounded scrolling in horizontal and
  vertical axes.
- `@State`, `Binding`, `@Bindable`, `@FocusState`, `focused`, and `focusable`
  manage local state and keyboard focus.
- `@Environment` and `View.environment(_:)` pass key-path values and
  Observation objects through the view tree, including bindings such as
  `$appState.token` for typed observable environment objects.
- `disabled(_:)` and `@Environment(\.isEnabled)` control user interaction for
  descendant views.
- `NavigationStack`, `NavigationLink`, `NavigationPath`, `navigationDestination`,
  `@Environment(\.push)`, and `@Environment(\.pop)` provide stack navigation.
- `onAppear`, `onDisappear`, `task`, `onChange`, `onSubmit`, and `onTerminate`
  provide lifecycle and event hooks.

SwiftTUI intentionally resembles SwiftUI where that makes terminal apps easier
to write, but it is not a complete SwiftUI implementation. Its behavior is
defined by the terminal renderer, input loop, and character-cell layout model in
this package.

## Validation

Use these commands from the package root:

```sh
swift build --product SwiftTUI
swift test
```

## License

This project is released under the terms in `UNLICENSE`.
