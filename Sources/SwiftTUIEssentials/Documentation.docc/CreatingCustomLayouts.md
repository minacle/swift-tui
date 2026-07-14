# Creating Custom Layouts

Measure and place child views in terminal-cell coordinates.

## Overview

The ``Layout`` protocol lets a container choose its own measurement and
placement algorithm. Parents supply a ``ProposedViewSize`` whose `columns` and
`rows` are optional. A `nil` dimension asks for the child's natural size on
that axis; a concrete dimension is a proposal that a layout can accept,
constrain, or use to allocate flexible space.

```swift
import SwiftTUIEssentials

struct LeadingColumn: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        subviews.reduce(Size()) { result, subview in
            let child = subview.sizeThatFits(.unspecified)
            return Size(
                columns: max(result.columns, child.columns),
                rows: result.rows + child.rows
            )
        }
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var row = bounds.origin.row

        for subview in subviews {
            let child = subview.sizeThatFits(.unspecified)
            subview.place(
                at: Point(column: bounds.origin.column, row: row),
                proposal: ProposedViewSize(child)
            )
            row += child.rows
        }
    }
}

struct BuildStatus: View {
    var body: some View {
        LeadingColumn {
            Text("Build")
            Text("Ready").foregroundStyle(.green)
        }
    }
}
```

SwiftTUI calls `sizeThatFits(proposal:subviews:cache:)` to obtain the
container's size and then calls
`placeSubviews(in:proposal:subviews:cache:)` with bounds derived from that
result. It can measure a child or evaluate a view body multiple times. Layout
callbacks must not rely on a particular call count or publish unrelated state
changes.

### Measure with pass-scoped proxies

Each ``LayoutSubview`` is valid only during the layout callback that receives
it. Use `sizeThatFits(_:)` for a terminal-cell size, or `dimensions(in:)` when
you also need alignment guides. SwiftTUI reuses equivalent measurements within
one render pass but recalculates them in later passes. Don't retain subview
proxies, the ``LayoutSubviews`` collection, or its indices in a cache or task.

``ProposedViewSize/max`` is a maximum-size query during subview measurement.
Fixed children report intrinsic size, bounded children can report their
maximum, and unbounded flexible children can report `Int.max`. Don't forward
that proposal to `place(at:anchor:proposal:)`, because renderers can interpret
the value as an actual allocation request.

### Place visible and interactive geometry together

Calling `place(at:anchor:proposal:)` records one child's location. Omitting the
call leaves that child unrendered; placing the same proxy again replaces its
earlier placement for the pass. SwiftTUI clips the final child to the bounds
reported by the layout and translates its text caret, hit regions, focus
regions, scroll regions, identified views, and named coordinate spaces with
the visible cells.

Coordinates use zero-based terminal columns and rows. The placement point
identifies where the child's chosen ``Alignment`` anchor lands. Layout bounds
can have a nonzero origin, so use `bounds.origin` rather than assuming the
top-leading point is always `(0, 0)`.

### Cache derived work, not view proxies

Define ``Layout/Cache`` when measurement needs reusable derived data.
`makeCache(subviews:)` creates the cache when the layout appears or its concrete
type changes. `updateCache(_:subviews:)` refreshes a compatible cache on a later
render. The same value is shared with spacing, sizing, placement, and explicit
alignment callbacks and can persist at the layout's rendered identity.

Use ``AnyLayout`` to switch concrete algorithms while preserving the arranged
children's hierarchy position. The wrapper replaces incompatible cache storage
when its concrete layout type changes and forwards layout properties, spacing,
measurement, placement, and explicit guides to the selected layout.

See <doc:RenderingPipeline> for how layout output becomes terminal cells and
interactive regions.

## Topics

### Layout protocol

- ``Layout``
- ``LayoutProperties``
- ``ProposedViewSize``
- ``LayoutSubviews``
- ``LayoutSubview``
- ``AnyLayout``

### Measurement and alignment

- ``ViewDimensions``
- ``ViewSpacing``
- ``Alignment``
- ``HorizontalAlignment``
- ``VerticalAlignment``
- ``AlignmentID``

### Child-provided values

- ``LayoutValueKey``
- ``ContainerValueKey``
- ``ContainerValues``

### Built-in algorithms

- ``HStackLayout``
- ``VStackLayout``
- ``ZStackLayout``
- ``GridLayout``
- ``HStack``
- ``VStack``
- ``ZStack``
- ``Grid``
