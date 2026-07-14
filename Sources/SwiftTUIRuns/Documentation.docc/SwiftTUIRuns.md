# ``SwiftTUIRuns``

Model attributed text, measure its terminal-cell requirements, and lay it out
for a renderer.

## Overview

`SwiftTUIRuns` is the view-independent text foundation used by SwiftTUI. Build
logical content from ``Run`` values, combine it recursively with ``RunGroup``,
and apply inheritable colors and text attributes through ``RunAttributes``.
The resulting value remains independent of a view tree or terminal session, so
the same model can back a custom terminal renderer, document preview, table, or
text interaction layer.

### Compose attributed content

A run contributes one string and its local attribute overrides. A group keeps
its descendants in source order and supplies attributes that a nested run or
group can override. ``RunGroupBuilder`` supports conditionals, optionals, and
loops, and attribute modifiers return modified copies rather than changing the
original values.

```swift
import SwiftTUIRuns

let report = RunGroup {
    Run("Build ").bold()
    Run("succeeded").underline()

    RunGroup {
        Run("\nDuration: ")
        Run("1.4 s").bold()
    }
    .dim()
}

let plainText = report.content
```

Run and group boundaries define attribute inheritance, not line-breaking
opportunities. Layout first treats the descendants as one logical string. If a
single extended grapheme cluster spans an input-run boundary, it stays
indivisible and receives the attributes of the run containing its first
Unicode scalar.

### Measure and wrap in terminal cells

Call ``RunGroup/measure()`` before choosing a width. Its ``RunMetrics`` result
reports the widest grapheme needed for emergency wrapping, the widest
mandatory-line-break-delimited line, and the number of rows before soft
wrapping. Then call ``RunGroup/layout(fittingColumns:)`` with the selected
column budget.

```swift
let metrics = report.measure()
let layout = report.layout(
    fittingColumns: max(metrics.minimumContentColumns, 12)
)

let rows = layout.lines.map { line in
    line.runs.map(\.content).joined()
}
```

Layout uses the module's fixed Unicode 17 line-breaking and terminal-width
rules, including wide CJK and emoji graphemes, combining sequences,
punctuation-aware break opportunities, and emergency wrapping only at extended
grapheme boundaries. Passing `nil` disables soft wrapping but still honors
mandatory line breaks. A nonpositive width produces an empty layout.

The returned ``RunLayout`` contains its occupied terminal-cell size and visual
lines. Each ``RunLayout/Line`` records its visible width, logical source range,
and same-attribute ``RunLayout/Run`` fragments with their starting columns.
These are layout fragments and can differ from the input `Run` boundaries.

### Relate logical text to terminal geometry

``RunIndex`` counts insertion positions in Swift `Character` values, not
Unicode scalars or encoded bytes. Use ``RunLayout/point(at:)`` and
``RunLayout/index(at:)`` to translate between logical insertion positions and
zero-based terminal points. Both operations clamp positions outside the
layout, and a point inside a wide grapheme maps to the insertion position
before that grapheme.

For clipping, selection, or hit-testing policy, a line can measure a logical
subrange with ``RunLayout/Line/columns(in:)``, return whole-grapheme leading or
trailing ranges with ``RunLayout/Line/prefixRange(fittingColumns:)`` and
``RunLayout/Line/suffixRange(fittingColumns:)``, and test exact cell boundaries
with ``RunLayout/Line/isCharacterBoundary(atColumn:)``.

### Add rendering policy at the consumer boundary

The module calculates attributed placement but does not write ANSI output. It
does not add padding, alignment, truncation, selection styling, links, editing
behavior, or an extra caret line. Consumers choose those policies from the
layout's fragments and source mapping.

> Important: Runs preserve control characters and terminal escape sequences.
> Sanitize untrusted content before passing fragment strings to a terminal;
> `SwiftTUIRuns` does not validate or escape them.

## Topics

### Attributed content

- ``Run``
- ``Run/content``
- ``Run/attributes``
- ``RunGroup``
- ``RunGroup/content``
- ``RunGroup/attributes``
- ``RunGroupBuilder``
- ``RunAttributes``

### Run attributes

- ``Run/foregroundColor(_:)``
- ``Run/backgroundColor(_:)``
- ``Run/bold(_:)``
- ``Run/dim(_:)``
- ``Run/italic(_:)``
- ``Run/underline(_:)``
- ``Run/strikethrough(_:)``

### Inherited group attributes

- ``RunGroup/foregroundColor(_:)``
- ``RunGroup/backgroundColor(_:)``
- ``RunGroup/bold(_:)``
- ``RunGroup/dim(_:)``
- ``RunGroup/italic(_:)``
- ``RunGroup/underline(_:)``
- ``RunGroup/strikethrough(_:)``

### Measurement

- ``RunGroup/measure()``
- ``RunMetrics``
- ``RunMetrics/minimumContentColumns``
- ``RunMetrics/maximumContentColumns``
- ``RunMetrics/unwrappedRows``

### Layout results

- ``RunGroup/layout(fittingColumns:)``
- ``RunLayout``
- ``RunLayout/size``
- ``RunLayout/lines``
- ``RunLayout/Line``
- ``RunLayout/Run``

### Source and cell mapping

- ``RunIndex``
- ``RunIndex/characterOffset``
- ``RunLayout/point(at:)``
- ``RunLayout/index(at:)``
- ``RunLayout/Line/sourceRange``
- ``RunLayout/Line/columns(in:)``
- ``RunLayout/Line/prefixRange(fittingColumns:)``
- ``RunLayout/Line/suffixRange(fittingColumns:)``
- ``RunLayout/Line/isCharacterBoundary(atColumn:)``
