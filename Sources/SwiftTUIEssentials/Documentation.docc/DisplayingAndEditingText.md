# Displaying and Editing Text

Render styled terminal text and coordinate editable selections with application
state.

## Overview

``Text`` displays a plain string or a `SwiftTUIRuns` ``RunGroup``. It measures
and wraps content in terminal columns, so a Swift character can occupy zero,
one, or multiple cells. Text style modifiers propagate through the environment
and produce terminal SGR attributes when supported by the active terminal.

``EditableText`` is the lower-level editing primitive used to build text
controls. It synchronizes accepted edits through a ``Binding`` and provides
keyboard navigation, pointer selection, and a rendered text caret. It reports
its natural content size instead of owning a viewport; place it in a
``ScrollView`` when content needs clipping, wheel input, or automatic reveal of
the active selection endpoint.

```swift
import SwiftTUIEssentials

struct NotesView: View {
    @State private var notes = """
        Release notes

        - Faster rendering
        - Better input
        """
    @State private var selection: TextSelection?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Notes").bold().foregroundStyle(.cyan)
            ScrollView(.vertical) {
                EditableText(
                    text: $notes,
                    selection: $selection
                )
            }
            .frame(width: 40, height: 8)
        }
    }
}
```

### Style and constrain text

`Text` renders `String` input directly; it doesn't perform localization lookup.
Localize content before constructing the view when needed. Create attributed
terminal content with `Run` and ``RunGroup``. Run attributes merge with the
foreground, background, bold, dim, italic, underline, and strikethrough style
inherited at the view layer.

Use ``AccentColor/accentColor`` through leading-dot syntax to style content
with the tint inherited where the style modifier appears. The default tint is
blue, and clearing the tint causes the semantic color to apply no color.

```swift
Text("Ready")
    .foregroundStyle(.accentColor)
    .tint(.green)
```

Use `lineLimit(_:)` to limit rendered rows and `truncationMode(_:)` to choose
where the last visible line removes content. The truncation marker is up to
three ASCII period characters. `multilineTextAlignment(_:)` aligns lines
within the text's resolved width; plain text doesn't expand to a finite proposal
solely to create alignment space.

Static text selection is disabled by default. `textSelection(.enabled)` lets a
primary-button drag highlight one ``Text`` target, but it doesn't expose the
range through a binding or copy the content automatically. Selection
background comes from `tint(_:)`; `textSelectionForegroundStyle(_:)` can
replace only the selected foreground color.

### Configure editing and scrolling

`EditableText` wraps at terminal-cell boundaries when its proposed column count
is finite. With an unspecified column count it uses its intrinsic width. In
both cases it ignores a proposed row limit and returns the full natural height
of its content. The active selection endpoint is exposed to an enclosing
`ScrollView`, which performs the minimum reveal only after editing or actual
navigation changes that endpoint. Pointer-wheel movement otherwise remains in
place.

``EditableText/InputPolicy`` independently controls whether Return inserts a
newline and whether Up and Down navigate visual lines. Both operations are
enabled by default. A control that reserves those keys can disable them without
changing layout or normalizing newline characters already present in the
binding:

```swift
EditableText(
    text: $query,
    inputPolicy: EditableText.InputPolicy(
        allowsNewlineInsertion: false,
        allowsVerticalNavigation: false
    )
)
```

Disallowed operations do not match the editor's key handler, so ancestor and
global handlers and key-resolution fallback can process them. Editing remains
in the existing view-defined immediate input stage. The rendered text caret is
part of SwiftTUI's rendered block and is distinct from the terminal cursor used
to present it on screen.

A selection binding publishes the editor's insertion point or range while the
view is active. Losing focus leaves the last published value intact. Apply an
external ``TextSelection`` only when its `String.Index` values belong to the
current bound string. Assigning `nil` hides the external selection but retains
a clamped internal caret until another selection change.

### Treat text as terminal data

Plain text, run content, unmasked editable content, mask characters, and
extracted placeholders preserve control characters and escape sequences.
Sanitize untrusted input before it reaches a text view. A mask affects rendered
characters only; the original value remains available to bindings, callbacks,
memory, logging, and persistence and must be protected separately.

See <doc:InputRecognition> for the input path used by editing and
<doc:RenderingPipeline> for terminal-cell measurement and caret presentation.

## Topics

### Display

- ``Text``
- ``TextAlignment``
- ``ShapeStyle``
- ``AnyShapeStyle``
- ``AccentColor``
- ``DefaultColor``

### Edit and select

- ``EditableText``
- ``EditableText/InputPolicy``
- ``TextSelection``
- ``TextSelectionNavigationBehavior``
- ``TextSelectability``
- ``EnabledTextSelectability``
- ``DisabledTextSelectability``

### Attributed terminal runs

- ``Run``
- ``RunGroup``
- ``RunAttributes``
- ``RunLayout``
