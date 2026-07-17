# Building an Application

Create a root terminal scene and attach work to the lifetime of rendered view
identities.

## Overview

An ``App`` is the entry point for an interactive SwiftTUI process. Its
``App/body-swift.property`` resolves to one ``WindowGroup``, which supplies the
root ``View`` for the current terminal viewport. Despite its name, a window
group represents one terminal scene; it doesn't create multiple platform
windows.

```swift
import SwiftTUIEssentials

@main
struct MonitorApp: App {
    var body: some Scene {
        WindowGroup {
            MonitorView()
        }
    }
}

struct MonitorView: View {
    @State private var refreshes = 0

    var body: some View {
        VStack(alignment: .leading) {
            Text("Build monitor").bold()
            Text("Refreshes: \(refreshes)")
            Text("Select to refresh").dim()
        }
        .onTapGesture {
            refreshes += 1
        }
    }
}
```

SwiftTUI starts the terminal session, resolves and renders the root hierarchy,
dispatches terminal input and recognition deadlines, and redraws when observed
state changes. ``TerminateAction`` requests a graceful exit from that loop.
Read it with `@Environment(\.terminate)` when an action should close the app.

### Keep view construction declarative

SwiftTUI can evaluate ``View/body-swift.property`` and view-builder closures
more than once while measuring and rendering a frame. Construct view values and
derive display data there, but don't perform unrelated external work as a side
effect of evaluation. Use lifecycle modifiers or explicit input actions for
work that should happen at a defined time.

The hierarchy's structural path supplies render-time identity. ``State`` and
other dynamic properties persist while that identity remains present. The two
branches of conditional builder content have different identities. ``ForEach``
instead uses each element's stable ID so reordering data can preserve the
corresponding state subtree; IDs must remain unique within the collection.

### Respond to appearance, changes, and disappearance

`onAppear(perform:)` runs after the first render containing an identity, while
`onDisappear(perform:)` runs after that identity is absent from a later
hierarchy. Re-rendering an unchanged identity doesn't repeat either transition.
`onChange(of:initial:_:)` compares the value registered at the same identity
across render passes and invokes its callback after a change. Removing the view
forgets the prior value without calling the change action.

Use `task(priority:_:)` for asynchronous work scoped to a rendered identity.
The application runner starts the task even when no terminal input arrives, and
a state change before or after suspension wakes the runner to redraw. SwiftTUI
requests cancellation when that identity disappears. An `id`-based task also
cancels and restarts when its equatable ID changes; terminal input remains
dispatchable while either task is suspended. Cancellation is cooperative: an
operation that ignores it can continue running and retain its captures after
the view disappears.

### Handle process services through the environment

The application runner installs actions for termination and clipboard access
in ``EnvironmentValues``. ``CopyAction`` can publish text through the terminal
clipboard service, including OSC 52, without redaction or success reporting.
``PasteAction`` returns optional, unvalidated text. Treat pasted content as
untrusted and avoid copying secrets unless transfer to the host clipboard is
intended.

``OpenURLAction`` forwards an unvalidated URL to the installed synchronous
handler. SwiftTUI doesn't open a browser for a `systemAction` result. Incoming
URL delivery through `onOpenURL(perform:)` is a separate callback path from
activating a URL embedded in text.

Continue with <doc:ManagingStateAndEnvironment> for dependency propagation,
<doc:InputRecognition> for terminal interaction, and <doc:RenderingPipeline>
for the work performed during each frame.

## Topics

### Entry point and root scene

- ``App``
- ``Scene``
- ``SceneBuilder``
- ``WindowGroup``
- ``View``
- ``ViewBuilder``

### Identity and dynamic work

- ``ForEach``
- ``State``
- ``DynamicProperty``

### Application services

- ``TerminateAction``
- ``CopyAction``
- ``PasteAction``
- ``OpenURLAction``
- ``EnvironmentValues``
