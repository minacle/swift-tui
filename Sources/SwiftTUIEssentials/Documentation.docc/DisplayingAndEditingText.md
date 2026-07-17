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
keyboard navigation, pointer selection, a rendered text caret, and scrolling
that keeps the caret visible.

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
            EditableText(
                text: $notes,
                selection: $selection,
                lineMode: .multiline
            )
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

### Choose an editing mode

``EditableText/LineMode/singleLine`` edits one rendered row and scrolls
horizontally under a finite column proposal. It ignores Return so an enclosing
handler can interpret that key as submission. Existing newline characters in
the binding aren't sanitized or removed.

``EditableText/LineMode/multiline`` inserts newlines, supports vertical caret
navigation, and wraps to a finite proposed width. When either proposed axis is
finite, it scrolls within that axis as needed to keep the rendered text caret
visible. The caret is part of SwiftTUI's rendered block and is distinct from
the terminal cursor used to present it on screen.

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
