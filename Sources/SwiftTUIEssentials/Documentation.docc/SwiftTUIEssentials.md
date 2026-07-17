# ``SwiftTUIEssentials``

Build a terminal application from SwiftTUI's view, state, layout, rendering,
and input primitives.

## Overview

`SwiftTUIEssentials` is the foundational application module. It provides the
``App`` lifecycle, declarative ``View`` model, persistent state, environment
propagation, terminal-cell layout, rendering, focus, keyboard and pointer
input, navigation, scrolling, text, and shape primitives. It also re-exports
`SwiftTUIRuns`, whose attributed runs provide the measurement and wrapping
model used by ``Text`` and ``EditableText``.

Declare an app with a ``WindowGroup`` and compose its root view from containers
such as ``VStack``, ``Grid``, and ``ScrollView``. This module is sufficient for
a complete application when you want to build interactions from input
modifiers and ``EditableText``. Import `SwiftTUIControls` instead when you also
want standard controls such as buttons, text fields, and text editors.

```swift
import SwiftTUIEssentials

@main
struct DashboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
    }
}

struct DashboardView: View {
    var body: some View {
        RoundedBox {
            VStack(alignment: .leading) {
                Text("Service status").bold()
                Divider()
                HStack {
                    Text("API")
                    Spacer()
                    Text("ready").foregroundStyle(.green)
                }
                HStack {
                    Text("Worker")
                    Spacer()
                    Text("ready").foregroundStyle(.green)
                }
            }
            .padding(1)
        }
        .frame(width: 32)
    }
}
```

SwiftTUI measures dimensions, positions, spacing, and pointer locations in
terminal columns and rows rather than points or pixels. Terminal capabilities
also affect the key phases, modifier flags, pointer events, colors, and Unicode
cell widths that an application receives or displays.

Text and clipboard APIs preserve their input. Sanitize untrusted strings before
rendering them because embedded terminal control characters and escape
sequences aren't escaped by the rendering pipeline.

## Topics

### Essentials

- <doc:BuildingAnApplication>
- <doc:ManagingStateAndEnvironment>
- <doc:CreatingCustomLayouts>
- <doc:DisplayingAndEditingText>
- <doc:NavigatingAndScrolling>
- <doc:InputRecognition>
- <doc:RenderingPipeline>

### Application and scene structure

- ``App``
- ``Scene``
- ``SceneBuilder``
- ``WindowGroup``

### View composition and identity

- ``View``
- ``ViewBuilder``
- ``Group``
- ``ForEach``
- ``AnyView``
- ``EmptyView``

### State and environment

- ``DynamicProperty``
- ``State``
- ``Binding``
- ``Bindable``
- ``FocusState``
- ``Environment``
- ``EnvironmentBindable``
- ``EnvironmentValues``
- ``EnvironmentKey``
- ``TerminateAction``
- ``CopyAction``
- ``PasteAction``
- ``OpenURLAction``
- ``ResolveKeyAction``

### Layout protocol and geometry

- ``Layout``
- ``AnyLayout``
- ``LayoutProperties``
- ``ProposedViewSize``
- ``LayoutSubviews``
- ``LayoutSubview``
- ``ViewDimensions``
- ``ViewSpacing``
- ``Alignment``
- ``HorizontalAlignment``
- ``VerticalAlignment``
- ``AlignmentID``
- ``LayoutValueKey``
- ``ContainerValueKey``
- ``ContainerValues``

### Layout containers

- ``HStack``
- ``VStack``
- ``ZStack``
- ``Grid``
- ``GridRow``
- ``HStackLayout``
- ``VStackLayout``
- ``ZStackLayout``
- ``GridLayout``
- ``Spacer``
- ``Divider``
- ``ViewThatFits``
- ``GeometryReader``
- ``GeometryProxy``
- ``EdgeInsets``

### Scrolling

- ``ScrollView``
- ``ScrollViewReader``
- ``ScrollViewProxy``
- ``ScrollPosition``
- ``ScrollPoint``
- ``UnitPoint``
- ``Axis``
- ``Edge``
- ``ScrollIndicatorVisibility``
- ``ScrollIndicatorConfiguration``
- ``HorizontalScrollIndicatorAttachmentKey``
- ``VerticalScrollIndicatorAttachmentKey``

### Text and selection

- ``Text``
- ``EditableText``
- ``TextSelection``
- ``TextSelectionNavigationBehavior``
- ``TextAlignment``
- ``ShapeStyle``
- ``AnyShapeStyle``
- ``AccentColor``
- ``TextSelectability``
- ``EnabledTextSelectability``
- ``DisabledTextSelectability``

### Shapes, borders, and decoration

- ``Shape``
- ``ShapeView``
- ``Rectangle``
- ``RectangleHalfCellEdgeStyle``
- ``FillShapeView``
- ``FillStyle``
- ``OffsetShape``
- ``Box``
- ``RoundedBox``
- ``HeavyBox``
- ``DoubleBox``
- ``HeavyDivider``
- ``DoubleDivider``

### Input events, gestures, and shortcuts

- ``InputEvent``
- ``KeyEvent``
- ``PointerEvent``
- ``InputEventResult``
- ``Gesture``
- ``GestureState``
- ``Shortcut``
- ``ShortcutState``
- ``KeyEquivalent``
- ``KeyPress``
- ``PointerPress``
- ``PointerMotion``
- ``PointerScroll``
- ``CoordinateSpace``
- ``EventModifiers``

### Navigation

- ``NavigationStack``
- ``NavigationLink``
- ``NavigationPath``
- ``PushAction``
- ``PopAction``
- ``DismissAction``

### Rendering

- ``ViewRenderer``
- ``RenderedView``

### Container-supplied views

- ``ViewAttachmentKey``
- ``ViewAttachments``
