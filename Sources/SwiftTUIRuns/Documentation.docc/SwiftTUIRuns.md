# ``SwiftTUIRuns``

Compose and lay out attributed strings in terminal cells.

## Overview

`SwiftTUIRuns` provides a view-independent string representation for terminal
renderers. A ``Run`` is a leaf string, while ``RunGroup`` recursively combines
leaves and applies inherited ``RunAttributes``. ``RunGroup/measure()`` reports
intrinsic cell requirements, and ``RunGroup/layout(fittingColumns:)`` produces
wrapped lines, resolved attributes, and ``RunIndex`` source mapping.
Each ``RunLayout/Line`` can also measure a source subrange, find leading or
trailing ranges that fit a column budget, and identify exact grapheme
boundaries without taking ownership of clipping or truncation policy.

```swift
let content = RunGroup {
    Run("Status: ").bold()
    Run("ready").foregroundColor(Color16.green)
}

let metrics = content.measure()
let layout = content.layout(fittingColumns: 20)
```

The module does not render ANSI output or provide document blocks, links,
alignment, selection, truncation, or editing policy. It also preserves control
characters and escape sequences; sanitize untrusted content before writing a
layout to a terminal.

## Topics

### Content

- ``Run``
- ``RunGroup``
- ``RunGroupBuilder``
- ``RunAttributes``

### Measurement and layout

- ``RunMetrics``
- ``RunLayout``
- ``RunIndex``
