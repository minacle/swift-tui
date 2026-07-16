# Input Recognition

Match terminal input, recognize gestures and shortcuts, and control which view
receives each sample.

## Overview

SwiftTUI separates raw terminal input from stateful recognition. An
``InputEvent`` matches one decoded value such as ``KeyPress``,
``PointerPress``, ``PointerMotion``, or ``PointerScroll``. A ``Shortcut``
recognizes logical key sequences derived from key events, while a ``Gesture``
recognizes pointer sequences. Both recognition layers can publish changed and
ended values without inheriting from their low-level event types.

Attach a configured event with ``View/inputEvent(_:including:)``, a shortcut
with ``View/shortcut(_:including:)``, or a gesture with
``View/gesture(_:including:)``. High-priority variants run in the high tier,
`simultaneous` variants share the view-defined tier, and the plain attachment
methods run in the normal tier. Within each tier, SwiftTUI evaluates immediate
input events, eager deferred events, stateful recognizers, view-defined
convenience actions, and lazy deferred events in that order.

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
            .shortcut(
                TapShortcut("s", modifiers: .control)
                    .onEnded {
                        status = "save"
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
shortcuts, gestures, global-key fallback, or key resolution should still run.
Shortcut success claims only competing shortcuts: the same key sample still
reaches later low-level key handlers, global-key fallback, and key resolution.
Hover observation is reconciled after pointer motion and remains independent
of this result.

### Target paths and capture

Key input travels from the root of the focused branch toward the focused input
target. Shortcuts on that branch compete by tier, then by proximity to the
focused target and source-modifier nesting. Without a focused target, only
shortcuts attached directly at the rendered root remain eligible; existing
low-level key handlers retain their focus requirements. Pointer presses use the
deepest hit-tested target and offer the sample only to attachments on that path
and its ancestors, plus deeper attachments whose own hit regions contain the
pointer. Selecting a common ancestor doesn't make attachments in another
descendant branch eligible. Buttonless motion and scroll retarget on every
sample. A captured drag keeps button motion and the matching release on its
original target even outside the rendered bounds; scroll input never follows
pointer capture.

Coordinates are zero-based terminal columns and rows. Primitive pointer events
convert a location to their requested ``CoordinateSpace`` immediately before a
callback. Each pointer attachment keeps the structural receiver on which it was
declared and its own rendered hit frame, even when several receivers share an
enclosing focus owner. Hit testing therefore selects only attachments whose
receiver frames contain the pointer. The ``CoordinateSpace/local`` origin is
the selected attachment's rendered frame rather than the enclosing focus
region or another attachment on the same focusable view. A missing named space
is a programming error when direct recognition begins; if a named space
disappears during an active recognition sequence, SwiftTUI cancels that
sequence instead of invoking its completion callback.

### Shortcut recognition

``TapShortcut`` completes one or more exact key-down and key-up pairs. Repeat
phases don't increase its count, and consecutive presses can be separated by at
most 0.5 seconds. ``LongPressShortcut`` starts from an exact key-down, reports a
single changed value, and succeeds at its configured deadline without requiring
a repeat event. The key and modifier set must exactly match on every phase that
participates in either primitive.

Use ``View/onTapShortcut(_:modifiers:count:perform:)`` and
``View/onLongPressShortcut(_:modifiers:minimumDuration:perform:onPressingChanged:)``
for view-defined actions. For one key combination, higher tap counts can defer
lower-count fallbacks, while the shortest long-press deadline receives the
first opportunity to succeed. Different key and modifier combinations compete
independently.

### Composition and transient state

Use `exclusively(before:)`, `simultaneously(with:)`, and `sequenced(before:)`
to build one input-event, gesture, or shortcut recognition graph. An exclusive
shortcut replays stored samples into its second branch only after actual first-
branch failure. Simultaneous shortcut branches observe the same key sequence
independently and retain an early result until both branches terminate.
Sequences retain their first value until a later input completes them or their
attachment is cancelled; they don't add an implicit timeout.

``GestureState`` and ``ShortcutState`` store transient recognition data. The
`updating(_:body:)` callback runs before the same sample's distinct
`onChanged(_:)` callback. Successful completion invokes `onEnded(_:)`; failure
and cancellation don't. SwiftTUI resets updated transient state exactly once
after success, failure, disabling, removal, configuration replacement,
competition loss, focus or scene loss, and session shutdown.

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

### Shortcut graph

- ``Shortcut``
- ``TapShortcut``
- ``LongPressShortcut``
- ``ShortcutState``
- ``ShortcutStateShortcut``

### Shortcut composition

- ``ExclusiveShortcut``
- ``SimultaneousShortcut``
- ``SequenceShortcut``
- ``ShortcutMask``
