# Rendering Pipeline

Understand how SwiftTUI turns declarative views into incremental terminal output.

## Overview

SwiftTUI evaluates the root ``View`` whenever application state, input, a
deadline, or the terminal viewport invalidates the current frame. Rendering is
a staged transformation:

```text
AppRunner
  -> ViewResolver
  -> measurement and layout
  -> RenderedBlock
  -> terminal screen projection
  -> full or differential ANSI output
```

``ViewRenderer`` enters the same resolution and layout stages for a one-shot
render, then serializes the resulting content-local block without projecting it
into a terminal screen. The remaining stages use internal types rather than
public renderer extension points. Their boundaries explain the observable
behavior of public layout, input, and state APIs without exposing the
implementation as a compatibility contract.

## Render one view without an application loop

Call ``ViewRenderer/render(_:proposedSize:)`` to perform one synchronous render
pass. Layout can evaluate a body more than once while measuring and placing its
content, but no invalidation starts another pass. The supplied
``ProposedViewSize`` influences measurement, wrapping, and flexible layout, but
it isn't a terminal viewport. `ViewRenderer` doesn't center or pad the block
after resolution; an individual view or layout can still choose a proposed
dimension as its resolved size. Add a `frame` modifier when the rendered
fragment needs a fixed canvas.

The returned ``RenderedView`` contains plain rows, joined plain text, ANSI text
with SGR styling, and the resolved terminal-cell size. Its ANSI fragment writes
positioned gaps as literal spaces. It doesn't contain screen clearing, cursor
positioning or visibility, OSC links, alternate-screen transitions, or a final
line feed, so a command-line caller decides how and where to write it.

One-shot rendering has no `StateRuntime`. ``State`` and ``FocusState`` read
their wrapper-local fallback values, while environment modifiers still scope
body evaluation. Lifecycle and change callbacks, view tasks, input and focus
registrations, Observation subscriptions, invalidation stabilization, and
differential rendering don't run.

```swift
let output = ViewRenderer.render(
    Text("Build succeeded")
        .bold()
        .foregroundStyle(.green),
    proposedSize: ProposedViewSize(columns: 40, rows: nil)
)

print(output.ansiText, terminator: "")
```

## Drive rendering until the frame is stable

`AppRunner` owns the terminal session and the application loop. It renders the
root scene initially, then requests terminal input from a serial I/O worker
while servicing the main run loop. A main-run-loop pass ends for delivered
input, a view-task or Observation invalidation, the next gesture or
scroll-indicator deadline, or a terminal viewport signal. The runner then
dispatches input already buffered by the worker, expired actions, and any
required redraw without using finite-interval polling. A pending-input probe
never waits behind the worker's active blocking read, so a redraw or
termination caused by the current input completes without requiring a later
terminal byte.

A render pass may itself register lifecycle work, reconcile focus, or
synchronize control state. After producing a block, the runner publishes the
root frame to the input runtime and checks invalidation again. If the pass
changed observable state, SwiftTUI discards that intermediate result and
repeats resolution before writing to the terminal. Only a stable block becomes
the previous frame used by differential rendering.

## Resolve declarative views

`ViewResolver` recursively turns view values into renderable elements. It
handles primitive views such as ``Text`` directly, delegates containers and
modifiers to their specialized rendering protocols, and evaluates `body` only
for composite views.

Each recursive step carries an integer path. The state runtime uses that path
as render-time identity for dynamic properties, layout caches, handlers, and
interaction regions. A path is an implementation identity, not a public view
identifier; public identity continues to use APIs such as ``ForEach`` and
`id(_:)`.

## Measure and place terminal cells

Parents propose optional column and row counts with `RenderProposal`. An
unspecified dimension asks for intrinsic size on that axis. A concrete
dimension is a proposal that layout may use when allocating flexible space; it
is not a command to create an arbitrarily large buffer. Public custom layouts
express the same contract through ``ProposedViewSize`` and ``Layout``.

Containers may render a child once to measure it and again with its allocated
size. Measurement runs inside `LayoutMeasurementContext`, and interactive
registrations are suppressed. Views and controls must not publish selection,
focus, scrolling, or other externally observable state while they are being
measured.

Custom layout caches are stored by view path and survive while the layout
remains active. Repeated child measurements use a separate store that lasts
only for the current render generation. Removing a layout path removes its
persistent cache; starting or finishing a render clears the generation-local
measurement store.

``LazyHStack`` and ``LazyVStack`` retain only child geometry across render
passes. In a bounded same-axis ``ScrollView``, they keep the estimated logical
content extent separate from the sparse runs and interaction metadata created
for the current viewport. Visible measurements refine subsequent child frames;
offscreen `ForEach` state remains associated with its ID even though lifecycle,
task, focus, pointer, and caret registrations are absent until that child is
rendered again.

When a flexible scroll view receives a finite same-axis proposal from an
`HStack` or `VStack`, the parent preserves that bound for its registration-free
measurement. The measured block doesn't become a fixed minimum: the stack
continues to divide its remainder among flexible children, then renders the
scroll view at the allocated viewport. An unspecified same-axis proposal keeps
the eager natural-size path.

## Carry pixels and interaction metadata together

Layout produces a `RenderedBlock`. A block contains positioned text runs,
terminal styles, links, dimensions, a rendered text caret, and regions used by
hit testing, scrolling, focus, identified views, and named coordinate spaces.
All coordinates are zero-based and local to the block.

Framing, padding, offsetting, clipping, and composition transform visible runs
and interaction regions together. This keeps pointer dispatch and focus
navigation aligned with what the user sees. `HStack` and `VStack` place child
blocks along one axis, while `ZStack` orders children by z-index and composites
overlapping terminal cells.

Text measurement comes from the attributed runs and Unicode layout model
re-exported from `SwiftTUIRuns`. Widths are terminal columns rather than Swift
string counts, so a grapheme can occupy zero, one, or multiple cells. A
`RenderedCaret` is the text insertion point produced by an editable view. It is
not the terminal cursor used to present that caret.

## Project and update the terminal screen

`TerminalScreenRenderer` centers the root block within the current viewport
and projects its runs into a complete grid of terminal cells. Wide graphemes
use one leading cell and continuation cells for their remaining width. The
projection stores text, style, and link information so visual or style changes
are detectable even when the source character is unchanged.

The renderer clears and repaints the complete screen when there is no previous
block or when the viewport size changes. Otherwise it compares the old and new
cell grids, expands each difference across every cell occupied by the old and
new graphemes, merges adjacent cells with matching styles, and emits cursor
positioning plus SGR sequences only for the changed runs. This expansion is
what clears stale continuation cells during wide-to-narrow and narrow-to-wide
transitions.

Every output ends by updating terminal-cursor visibility and position. A block
without a rendered text caret hides the terminal cursor; a block with a caret
shows and positions it inside the viewport.

## Feed rendered geometry back into input

After resolution, the state runtime gives the block's hit, scroll, focus, and
coordinate-space regions to the input runtime. It also records the root
block's one-based terminal origin. Pointer dispatch subtracts that origin,
finds the matching local region, and invokes the registered handler inside the
view path and environment that created it. State changes from the handler
invalidate the next frame and restart the pipeline.

## Implementation map

| Stage | Primary internal types | Source responsibility |
| --- | --- | --- |
| Render model | `RenderProposal`, `StackChild`, `LayoutTraits` | Measurement contracts and container traits |
| View resolution | `ViewResolver`, `FlattenableViewContent` | Primitive dispatch, body evaluation, and child flattening |
| Text layout | `TextLayoutRenderer` | Wrapping, selection styling, and positioned text runs |
| Block representation | `RenderedBlock`, `RenderedRun` | Visible cells and interaction metadata |
| Container layout | `StackRenderer`, `ZStackRenderer` | Measurement, placement, alignment, and composition |
| Terminal output | `TerminalOutputEncoder`, `TerminalScreenRenderer` | One-shot fragments, screen projection, diffing, ANSI output, and cursor presentation |

> Important: SwiftTUI text preserves terminal control characters. Sanitize
> untrusted strings before rendering them; the rendering pipeline does not
> validate or escape terminal commands embedded in application content.
