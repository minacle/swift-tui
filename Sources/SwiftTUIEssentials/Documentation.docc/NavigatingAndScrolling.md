# Navigating and Scrolling

Present one active destination and move finite terminal viewports over larger
content.

## Overview

``NavigationStack`` renders a root view and one active destination at a time.
It can own an internal path or synchronize pushes and removals through a bound
``NavigationPath`` or homogeneous collection. A ``NavigationLink`` activates
with Return or a completed primary-pointer tap when it is inside a stack and
enabled.

``ScrollView`` measures content without constraining each enabled scrolling
axis, clips the result to its proposed viewport, and translates visible and
interactive geometry together as its offset changes.

```swift
import SwiftTUIEssentials

private enum Route: String, Codable, Hashable {
    case details
}

struct CatalogView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Catalog").bold()
                    ForEach(0..<12) { index in
                        Text("Item \(index)")
                    }
                    NavigationLink("Details", value: Route.details)
                }
            }
            .frame(width: 30, height: 8)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .details:
                    Text("Catalog details")
                }
            }
        }
    }
}
```

### Present destinations

A value link appends its hashable, codable value to the stack's path. The stack
uses the value's exact concrete type to find a matching
`navigationDestination(for:destination:)` registration. ``NavigationPath``
keeps type-erased values in memory; its `Codable` constraints don't make the
path serialize, save, or restore itself.

Use `navigationDestination(isPresented:destination:)` or
`navigationDestination(item:destination:)` for binding-driven presentations.
Escape and a destination's ``DismissAction`` clear the corresponding binding.
``PushAction`` and ``PopAction`` provide programmatic stack operations through
the environment. These actions are scoped to a rendered path or presentation;
prefer reading the current value where it is used instead of retaining an old
action indefinitely.

Navigation links are inactive outside a stack, beneath a disabled ancestor, or
when their optional value is `nil`. The link's label defines its focusable and
pointer-active region; the stack doesn't add a separate platform navigation
bar or transition animation.

### Control a scroll offset

Vertical scrolling is enabled by default. A scroll view accepts pointer-wheel
input over its visible frame without requiring keyboard focus. Use
`scrollDisabled(_:)` to suppress user scrolling while keeping binding- and
proxy-driven changes available.

`scrollPosition(_:)` supplies a ``ScrollPosition`` binding. A concrete point or
edge is resolved against the current content and viewport, clamped to enabled
axes, and written back as a concrete ``ScrollPoint``. User and proxy scrolling
also update that binding. Scope it close to the intended scroll view when
multiple descendants shouldn't share one position.

``ScrollViewReader`` supplies a ``ScrollViewProxy`` for action callbacks.
`scrollTo(_:anchor:)` searches descendant scroll views in render order for a
matching `id(_:)`. With no anchor it moves by the minimum amount needed to
reveal the target; with an anchor it aligns the same ``UnitPoint`` in the target
and viewport. Don't call a proxy while its reader content is being built or
retain it for use outside the rendered reader scope.

### Configure indicators

An installed temporarily hidden indicator overlays the viewport after scrolling
or an explicit flash request. An installed permanently visible indicator
reserves terminal cells, and `never` omits it. `SwiftTUIEssentials` doesn't
install an indicator view by itself. Applications can supply one through
``HorizontalScrollIndicatorAttachmentKey`` or
``VerticalScrollIndicatorAttachmentKey``; a closer installation replaces an
inherited attachment for the same axis. The supplied
``ScrollIndicatorConfiguration`` exposes current geometry and deferred actions,
and retained actions become inert after their scroll view disappears.

See <doc:InputRecognition> for activation and pointer dispatch, and
<doc:ManagingStateAndEnvironment> for the bindings and environment actions used
by both systems.

## Topics

### Navigation

- ``NavigationStack``
- ``NavigationLink``
- ``NavigationPath``
- ``PushAction``
- ``PopAction``
- ``DismissAction``

### Scroll containers and actions

- ``ScrollView``
- ``ScrollViewReader``
- ``ScrollViewProxy``
- ``ScrollPosition``
- ``ScrollPoint``
- ``UnitPoint``
- ``Axis``
- ``Edge``

### Scroll indicators

- ``ScrollIndicatorVisibility``
- ``ScrollIndicatorConfiguration``
- ``HorizontalScrollIndicatorAttachmentKey``
- ``VerticalScrollIndicatorAttachmentKey``
