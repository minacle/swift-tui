# Managing State and Environment

Store mutable values by rendered identity and propagate dependencies through a
view hierarchy.

## Overview

Use ``State`` for local mutable values that belong to a view identity. SwiftTUI
keeps a state cell while that identity remains rendered and requests another
frame after every assignment. The projected value is a ``Binding`` that reads
and writes the same cell, which lets descendants and editable views update the
source of truth without owning it.

```swift
import SwiftTUIEssentials
import Observation

@Observable
final class BuildModel {
    var completed = 3
}

struct BuildScreen: View {
    @State private var model = BuildModel()

    var body: some View {
        BuildSummary()
            .environment(model)
    }
}

struct BuildSummary: View {
    @Environment(BuildModel.self) private var model

    var body: some View {
        VStack(alignment: .leading) {
            Text("Completed: \(model.completed)")
            Text("Select to record another build").dim()
        }
        .onTapGesture {
            model.completed += 1
        }
    }
}
```

SwiftTUI tracks observable properties read while resolving a rendered view.
Changing one of those properties invalidates the affected hierarchy. Use
``Bindable`` or an environment wrapper's projected value when a child API needs
a binding to a writable property on an observable object.

### Choose a source of truth

A ``Binding`` stores retained getter and setter closures, not a value. Its
behavior therefore depends entirely on the source those closures address. A
constant binding always returns its captured value and ignores writes. A state
binding persists writes and invalidates the active runtime. A binding into an
observable object's property mutates that object, and Observation invalidates
only views that previously read the changed property.

State identity follows the rendered hierarchy rather than the lifetime of a
temporary view value. Removing an identity discards its cell. Recreating the
identity evaluates the state's retained initial-value expression again. Outside
a render or captured action context, ``State`` uses wrapper-local fallback
storage and can't invalidate an application.

### Propagate values and observable objects

Define an ``EnvironmentKey`` to add a value-semantic setting to
``EnvironmentValues``. A key supplies the default used when no ancestor has
installed an override. `environment(_:_:)` replaces a key-path value for a
subtree, and `transformEnvironment(_:transform:)` derives a value from its
inherited setting. A closer modifier wins for the same key path.

Observable objects are installed by exact concrete type with
`environment(_:)`. `@Environment(Model.self)` requires a matching object and
traps when none is present; an optional `@Environment(Model.self)` property
returns `nil` instead. A closer object of the same concrete type shadows an
ancestor's object.

An ``Environment`` wrapper retains the most recently materialized environment
snapshot for that wrapper instance. Read the value while building the relevant
body or capture the resolved value in an action. Don't rely on one escaped
wrapper to recover an earlier snapshot when the same view value is rendered in
multiple environment scopes.

### Coordinate focus

``FocusState`` supports Boolean values and optional hashable values. Attach its
projected binding with `focused(_:)` or `focused(_:equals:)`; either modifier
also makes the view focusable. Programmatic assignments request a matching
rendered focus region, and keyboard or pointer focus changes publish back into
the binding. Descendants can read `EnvironmentValues.isFocused` to choose their
own appearance because focus modifiers don't draw a focus indicator.

Focus ownership follows the nearest focus modifier in the resolved hierarchy.
Consecutive focus modifiers at one view identity share that candidate, while a
focus modifier on a descendant creates a distinct nested candidate and becomes
the focus owner for its subtree. When the descendant gains focus, its
`EnvironmentValues.isFocused` value is `true` and the enclosing candidate's
value is `false` after the focus update rerenders.

Outside a rendered or captured action context, focus state also uses fallback
storage and can't move application focus. If multiple visible regions use the
same optional focus value, the first rendered candidate receives a
programmatic request.

See <doc:BuildingAnApplication> for the lifetime that owns these identities and
<doc:InputRecognition> for callbacks that commonly mutate their values.

## Topics

### Local and shared state

- ``DynamicProperty``
- ``State``
- ``Binding``
- ``Bindable``

### Environment

- ``Environment``
- ``EnvironmentBindable``
- ``EnvironmentValues``
- ``EnvironmentKey``

### Focus

- ``FocusState``

### Environment actions

- ``TerminateAction``
- ``CopyAction``
- ``PasteAction``
- ``OpenURLAction``
- ``ResolveKeyAction``
