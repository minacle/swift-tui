# SwiftTUI

> [!WARNING]
> This project was developed with assistance from AI systems such as LLMs.
> It may include features or behavior that have not been fully verified.

SwiftTUI builds full-screen, interactive terminal applications from
declarative Swift values. It follows the familiar `App`, `View`, and state
management shape of SwiftUI while providing terminal-cell layout, keyboard and
pointer input, focus, navigation, and incremental ANSI rendering.

SwiftTUI does not import or wrap SwiftUI. Familiar names make the package easier
to learn, but they do not imply source compatibility or identical behavior.

## Project Status

This README documents SwiftTUI 0.10.1.

SwiftTUI is still a pre-1.0 package. It follows Semantic Versioning, but minor
releases can contain source-breaking changes while the public API is being
developed. Review the [changelog](CHANGELOG.md) before updating an existing
application.

## Quick Start

### Requirements

- Swift 6.3 or newer
- macOS 15 or newer, or Linux
- An interactive terminal

### Installation

Add SwiftTUI to the package dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/minacle/swift-tui", from: "0.10.1"),
]
```

Add the `SwiftTUI` product to an executable target:

```swift
.executableTarget(
    name: "Example",
    dependencies: [
        .product(name: "SwiftTUI", package: "swift-tui"),
    ]
)
```

### Your First App

Place the following source in `Sources/Example/main.swift`:

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

    @Environment(\.terminate)
    private var terminate

    @State
    private var count = 0

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

Run the executable in an interactive terminal:

```sh
swift run Example
```

A button responds to a primary-pointer tap and to Return while focused.
Control-C requests application termination. The Quit button demonstrates the
same graceful exit through `@Environment(\.terminate)`.

## How SwiftTUI Differs from SwiftUI

SwiftTUI adapts declarative UI concepts to the constraints of a terminal rather
than reproducing a graphical UI framework.

- Dimensions, coordinates, and spacing are measured in terminal columns and
  rows instead of points.
- `WindowGroup` represents one terminal viewport; it does not create multiple
  platform windows.
- Layout proposals can be finite or unspecified on either terminal axis, and a
  view may choose a different size from the one proposed by its parent.
- Keyboard sequences, modifier flags, pointer events, colors, and Unicode cell
  widths can vary between terminal implementations.
- APIs with SwiftUI-shaped names can offer a smaller surface or
  terminal-specific semantics. Consult the API documentation for their exact
  contracts.

## Choosing a Module

The `SwiftTUI` product is the recommended import for most applications. The
package also provides narrower dependency boundaries:

| Module | Use it when |
| --- | --- |
| `SwiftTUI` | You want the complete package through one convenience import. |
| `SwiftTUIControls` | You want the foundational APIs together with `Button`, `DisclosureGroup`, `TextField`, `SecureField`, `TextEditor`, and interactive scroll indicators. |
| `SwiftTUIEssentials` | You want to build an application from the lifecycle, state, environment, layout, rendering, input, navigation, scrolling, text, and `EditableText` primitives without standard controls. |
| `SwiftTUIRuns` | You need view-independent attributed runs, terminal-cell measurement, Unicode line breaking, wrapping, or source-position mapping. |

`SwiftTUI` re-exports `SwiftTUIControls` and `SwiftTUIEssentials`.
`SwiftTUIControls` re-exports `SwiftTUIEssentials`, and `SwiftTUIEssentials`
re-exports `SwiftTUIRuns`.

## Terminal Behavior and Limitations

The application runtime puts standard input into raw mode, enters the alternate
screen, enables xterm pointer tracking and focus reporting, and restores the
terminal session when the application stops normally. It redraws the viewport
after state changes and terminal resizes, using differential output when a full
repaint is not required.

Terminal capabilities are not uniform:

- Physical key-up and repeat information is available only when the active
  terminal protocol reports it.
- Pointer input represents one pointer in two-dimensional terminal-cell
  coordinates. Touch, multiple pointers, and pixel-precise gestures are not
  available.
- Focus reporting, OSC 52 clipboard access, colors, Unicode grapheme widths,
  and supported escape sequences depend on the terminal and its configuration.
- Control-C is reserved as an application termination request. Use
  `onTerminate` to perform work or present a confirmation flow before calling
  the `terminate` environment action.

## Rendering Without an Application Loop

`ViewRenderer` renders one view synchronously without starting a terminal
session or application event loop:

```swift
import SwiftTUI

let output = ViewRenderer.render(
    Text("Build succeeded")
        .bold()
        .foregroundStyle(.green),
    proposedSize: ProposedViewSize(columns: 40, rows: nil)
)

print(output.ansiText, terminator: "")
```

The returned `RenderedView` provides plain rows, joined plain text, SGR-styled
ANSI text, and the resolved terminal-cell size. It does not clear the screen,
move or show the terminal cursor, enter the alternate screen, or append a final
line feed. State invalidation, input, focus, lifecycle callbacks, and tasks do
not run in this one-shot mode.

## Security Considerations

SwiftTUI text APIs preserve terminal control characters and escape sequences.
Sanitize untrusted labels, prompts, links, and bound text before rendering them
so that external content cannot control the user's terminal.

`SecureField` masks only the characters it renders. Its binding still contains
the original value, and the control does not protect that value from application
memory, logs, persistence, callbacks, or other code with access to the binding.

## Documentation

The [documentation site](https://minacle.github.io/swift-tui/) publishes the
latest development documentation and versioned API references for released
tags. Read the [changelog](CHANGELOG.md) for additions, deprecations, removals,
and migration notes.

## License

This project is released under the terms in [UNLICENSE](UNLICENSE).
