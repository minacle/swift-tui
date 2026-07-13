# Input Recognition

Match terminal input, recognize gestures, and control which view receives each
sample.

## Overview

SwiftTUI separates raw terminal input from stateful gestures. An
``InputEvent`` matches one decoded value such as ``KeyPress``,
``PointerPress``, ``PointerMotion``, or ``PointerScroll``. A ``Gesture``
recognizes one or more pointer samples and can publish changed and ended values.

Attach a configured event with ``View/inputEvent(_:including:)`` or attach a
gesture with ``View/gesture(_:including:)``. High-priority variants run in the
high tier, `simultaneous` variants share the view-defined tier, and the plain
attachment methods run in the normal tier. Within each tier, SwiftTUI evaluates
immediate input events, eager deferred events, gestures, and lazy deferred
events in that order.

```swift
struct InputStatus: View {
    @State private var status = "idle"

    var body: some View {
        Text(status)
            .inputEvent(
                KeyPressEvent(.return)
                    .onRecognized { _ in
                        status = "return"
                        return .ignored
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        status = "drag \(value.translation.columns),\(value.translation.rows)"
                    }
            )
    }
}
```

``InputEventResult/handled`` stops the remaining consumable work outside the
current explicit composite and prevents lower tiers from receiving that raw
sample. It reports propagation intent, not whether the callback changed state.
Return ``InputEventResult/ignored`` after an action when later input events,
gestures, global-key fallback, or key resolution should still run. Hover
observation is reconciled after pointer motion and remains independent of this
result.

### Target paths and capture

Key input travels from the root of the focused branch toward the focused input
target. Pointer presses use the deepest hit-tested target, while buttonless
motion and scroll retarget on every sample. A captured drag keeps button motion
and the matching release on its original target even outside the rendered
bounds; scroll input never follows pointer capture.

Coordinates are zero-based terminal columns and rows. Primitive pointer events
convert a location to their requested ``CoordinateSpace`` immediately before a
callback. A missing named space is a programming error when direct recognition
begins; if a named space disappears during an active recognition sequence,
SwiftTUI cancels that sequence instead of invoking its completion callback.

### Composition and transient state

Use `exclusively(before:)`, `simultaneously(with:)`, and `sequenced(before:)`
to build a single recognition graph. Explicit simultaneous siblings finish
their callbacks before an aggregated handled result affects outside consumers.
Sequences retain their first value until a later input completes them or their
attachment is cancelled.

``GestureState`` stores transient gesture data. The `updating(_:body:)` callback
runs before the same sample's `onChanged(_:)` callback. Successful completion
invokes `onEnded(_:)`; failure and cancellation don't. SwiftTUI resets gesture
state after success, failure, disabling, removal, focus or scene loss, and
session shutdown.

### Terminal limitations

The terminal backend reports one pointer identity and two-dimensional cell
coordinates. It doesn't provide touch, multipointer, three-dimensional, or
pixel-precise gesture input. Physical key-up and repeat information is
available only when the active terminal protocol supplies it. Focus-out cleanup
uses xterm focus reporting when supported and also runs when the input session
ends.

## Topics

### Input event graph

- ``InputEvent``
- ``KeyEvent``
- ``PointerEvent``
- ``InputEventResult``
- ``RecognizedInputEvent``
- ``DeferredInputEvent``
- ``DeferredInputEventPriority``

### Primitive input events

- ``KeyPressEvent``
- ``PointerPressEvent``
- ``PointerMotionEvent``
- ``PointerScrollEvent``
- ``KeyPress``
- ``PointerPress``
- ``PointerMotion``
- ``PointerScroll``

### Input event composition

- ``ExclusiveInputEvent``
- ``SimultaneousInputEvent``
- ``SequenceInputEvent``
- ``InputEventMask``

### Gesture graph

- ``Gesture``
- ``TapGesture``
- ``SpatialTapGesture``
- ``LongPressGesture``
- ``DragGesture``
- ``GestureState``
- ``GestureStateGesture``
- ``Transaction``

### Gesture composition

- ``ExclusiveGesture``
- ``SimultaneousGesture``
- ``SequenceGesture``
- ``GestureMask``
