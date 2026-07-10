# SwiftTUI

> [!WARNING]
> This project was developed with assistance from AI systems such as LLMs.
> It may include features or behavior that have not been fully verified.

SwiftTUI is a Swift package for building terminal user interfaces with a
SwiftUI-shaped API. It renders views into terminal character cells, handles
keyboard and pointer input, and provides state, focus, layout, navigation, and
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
    .package(url: "https://github.com/minacle/swift-tui", from: "0.6.0"),
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
keyboard and pointer events in an interactive terminal session.

SwiftTUI is not a SwiftUI renderer or native-control bridge. Its layout, focus,
scrolling, navigation, state, and lifecycle behavior are defined by this
package's terminal runtime.

## Text Selection

Enable drag selection for static text with `textSelection(_:)`. The current
`tint` supplies the selection background and defaults to `Color16.blue`:

```swift
Text("Drag to select this text")
    .textSelection(.enabled)
    .tint(.blue)
```

Use `textSelectionForegroundStyle(_:)` to replace the foreground of selected
characters. It accepts any supported `ShapeStyle`, which SwiftTUI stores as an
`AnyShapeStyle` in the environment:

```swift
Text("Selected text uses white on blue")
    .foregroundStyle(.yellow)
    .textSelection(.enabled)
    .tint(.blue)
    .textSelectionForegroundStyle(Optional(Color16.white))
```

The environment value is optional. Its default value is `nil`, which preserves
the original foreground of each selected run, including attributed text and
links. A nested view can clear an outer override explicitly:

```swift
Text("Keep my original foreground")
    .environment(\.textSelectionForegroundStyle, nil)
```

Passing `nil` to `tint(_:)` independently clears selection backgrounds and link
tint without changing the selected-text foreground setting.

Editable text controls use `TextSelectionNavigationBehavior` when a
Shift-modified navigation key continues a pointer selection. On iOS, macOS,
tvOS, visionOS, and watchOS, the default `.navigationDirection` behavior first
expands toward the navigation command and then fixes that endpoint as the
active caret. Other platforms default to `.dragEndpoint`, which continues from
the endpoint where the pointer drag finished.

Use `textSelectionNavigationBehavior(_:)` or its environment value to override
the platform default for a view hierarchy:

```swift
TextEditor(text: $text)
    .textSelectionNavigationBehavior(.dragEndpoint)

TextField("Name", text: $name)
    .environment(\.textSelectionNavigationBehavior, .navigationDirection)
```

Use a `TextSelection` binding to read or set the insertion point or selected
range of a `TextField` or `TextEditor`:

```swift
@State var text = "Edit this text"
@State var selection: TextSelection?

TextEditor(text: $text, selection: $selection)

if let selection, case .selection(let range) = selection.indices {
    let selectedText = text[range]
}
```

SwiftTUI currently supports one selection. Create an insertion point with
`TextSelection(insertionPoint:)` or a range with `TextSelection(range:)`.

Read the `copy` and `paste` environment actions to exchange UTF-8 text with a
terminal clipboard that supports OSC 52. `CopyAction` accepts a `Substring`,
so a bound text selection can be copied directly:

```swift
@State var text = "Edit this text"
@State var selection: TextSelection?

@Environment(\.copy) var copy
@Environment(\.paste) var paste

func copySelection() {
    guard
        let selection,
        case .selection(let range) = selection.indices,
        !range.isEmpty
    else {
        return
    }

    copy(text[range])
}

func pasteAtEnd() {
    if let pastedText = paste() {
        text.append(pastedText)
    }
}
```

`paste()` performs a synchronous OSC 52 query and returns `nil` when the
terminal doesn't respond with Base64-encoded UTF-8 text. Each response byte
has a 100 millisecond timeout that restarts when another byte arrives. Terminal
and multiplexer clipboard support and permission settings determine whether
OSC 52 reads and writes succeed. SwiftTUI doesn't automatically insert pasted
text or attach copy and paste keyboard shortcuts.

## Validation

Use these commands from the package root:

```sh
swift build --product SwiftTUI
swift test
```

## License

This project is released under the terms in `UNLICENSE`.
