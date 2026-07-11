# SwiftTUI Repository Instructions

## Documentation comments

- Write documentation comments in English for every `public` or `open`
  declaration owned by `SwiftTUIEssentials`, `SwiftTUIControls`, or `SwiftTUI`.
  This includes types, protocols, initializers, methods, properties, subscripts,
  type aliases, enum cases, option-set values, and public conformance witnesses.
- Also document internal declarations whose purpose, side effects, lifetime,
  performance, safety requirements, or invariants aren't evident from their
  signatures. Use regular comments for implementation walkthroughs that don't
  belong in generated API documentation.
- Begin with a concise, standalone summary sentence. For a nontrivial API,
  follow it with enough discussion for a library user to understand the
  observable contract without reading the implementation or tests.
- Do not treat a one-line restatement of the declaration as sufficient
  documentation. Describe the behavior that changes a caller's decisions,
  including applicable defaults, state transitions, side effects, propagation
  or scoping rules, and meaningful limitations.
- Document terminal-specific semantics precisely when relevant: proposed
  columns and rows, flexible axes, wrapping or clipping, focus eligibility,
  keyboard and pointer activation, scrolling, binding synchronization,
  selection publication, and caret visibility. Preserve the distinction
  between a rendered text caret and the terminal cursor.
- For APIs involving sensitive text, unsafe inputs, external state, callbacks,
  or retained work, state the security, validation, ownership, cancellation,
  and lifetime boundaries that callers must not infer from the type signature.
- Document every parameter whose role or accepted values aren't completely
  obvious. Use DocC sections such as `- Parameters:`, `- Returns:`, `- Throws:`,
  `- Precondition:`, and `- Complexity:` whenever those contracts apply.
  Explain the semantics of default and `nil` values instead of merely repeating
  their types.
- Add a short compiling example for public types or operations whose intended
  composition isn't clear from a single call. Examples must use APIs that are
  public in the documented module and must reflect the current implementation.
- Use DocC symbol links for related declarations and verify that the links
  resolve in the declaration's owning module. Use exact API spelling and the
  repository's terminal terminology throughout.
- Describe only behavior supported by the implementation and tests. Do not
  promise SwiftUI parity, platform behavior, ordering, thread safety,
  performance, or error handling that the library doesn't guarantee.
- When changing behavior, update its existing documentation in the same patch.
  When deprecating an API, identify the replacement and migration direction.
  When removing an API, remove or redirect stale symbol links and examples.

## Documentation preservation during moves

- Treat documentation as part of the public API when moving declarations or
  splitting targets. Preserve the complete comment first, then update module
  names, symbol links, and behavior that genuinely changed.
- Do not replace a multi-paragraph contract with a generic one-line summary to
  make a move or refactor easier. Review documentation-only changes in the diff
  separately from code movement and investigate every deleted paragraph.
- After a target split, audit each new target independently. A comment visible
  through the umbrella `SwiftTUI` module doesn't prove that the declaration's
  owning module has complete or correctly resolving documentation.
- Compare public symbol graphs before and after structural changes. Account for
  every added, removed, or newly undocumented source-owned symbol; a successful
  build alone isn't evidence that documentation was preserved.

## Documentation validation

- For every public-API or documentation change, dump the symbol graphs and
  inspect the graphs for all three package modules. Treat any source-owned
  public symbol without a documentation comment as a failed check:

```sh
swift package dump-symbol-graph \
  --minimum-access-level public \
  --skip-synthesized-members \
  --pretty-print
```

- Generate the combined DocC archive for the umbrella and owning modules.
  Resolve broken links, malformed markup, duplicate topics, and other DocC
  diagnostics before finishing:

```sh
rm -rf /private/tmp/swift-tui-docc
swift package \
  --allow-writing-to-directory /private/tmp/swift-tui-docc \
  generate-documentation \
  --target SwiftTUI \
  --target SwiftTUIEssentials \
  --target SwiftTUIControls \
  --enable-experimental-combined-documentation \
  --disable-indexing \
  --output-path /private/tmp/swift-tui-docc
```

- Finish with a prose-quality pass. Check that summaries are specific, examples
  use only current public APIs and remain valid Swift at the documented call
  site, parameter descriptions match their declarations, security notes remain
  visible, and moved comments haven't silently lost contract details.

## Test organization

- Write tests with Swift Testing under `Tests/SwiftTUIEssentialsTests` or
  `Tests/SwiftTUIControlsTests`, according to API ownership.
- Place each test in the domain that owns the behavior: `Application`, `Core`,
  `Environment`, `Input`, `Layout`, `Navigation`, `Rendering`, `State`, `Text`,
  or `Views`.
- Reserve `Support` for helpers shared by multiple domains. Do not put test
  cases in `Support`.
- Use one `@Suite` per `*Tests.swift` file. The file stem and suite type must
  match exactly, and the type must end in `Tests`.
- Give the suite a concise, Title Case display name that covers every test in
  the file. When a suite's responsibility changes, rename its display name,
  type, and file together.
- Keep every `@Test` inside a suite. Preserve required suite traits; in
  particular, keep `@Suite("Focused and Global Key Input", .serialized)`
  serialized while its parent-callback tests mutate shared state.
- Aim for roughly 1,000 lines or fewer per test file. Split a large file at a
  coherent behavioral boundary instead of separating fixtures arbitrarily.

Use this shape:

```swift
@Suite("Text Field Selection")
struct TextFieldSelectionTests {
    @Test
    func `an external selection replaces text and publishes the updated caret`() {
        // Test body
    }
}
```

## Test names

- Put `@Test` on its own line and write the function name as a descriptive
  English phrase inside backticks.
- Do not use a `test` prefix, a camelCase test name, or a display-name string
  such as `@Test("...")`. Test traits and arguments may still be passed to
  `@Test` without adding a display-name string.
- Write names in the present tense. Start with lowercase unless the first word
  is an exact API, type, key, or protocol spelling.
- Describe the relevant setup or action and the externally observable result.
  Name every material behavior asserted by the test, or split unrelated
  assertions into separate tests.
- Match the strength of the name to the assertions. Do not claim that a
  behavior is safe, stable, complete, or generally supported when the test
  checks only one concrete example.
- Prefer product and user-facing vocabulary over helper names or runtime
  implementation details. A reader should understand the contract without
  opening the production implementation.
- Do not mechanically insert spaces into an old camelCase name. Rewrite the
  name from the behavior demonstrated by the body and assertions.
- Avoid vague verbs and filler such as `works`, `handles`, `maintains`,
  `honors`, `uses the expected behavior`, `while rendering or editing text`,
  `during input dispatch`, or `across view updates` when a precise condition
  and result can be stated instead.
- Keep test names unique across the target so discovery output and filtered
  runs remain unambiguous. Search existing names before adding a new test.

Prefer names like:

```swift
func `dragging across a text field selects the traversed range for replacement`()
func `pointer-down on a focusable view sets its Boolean focus binding`()
func `a differential render writes only the changed character`()
func `an explicit default background in a ZStack blocks an inherited background`()
```

Do not write names like:

```swift
func testDragSelection()
@Test("Dragging works")
func `while rendering or editing text dragging works`()
func `screen output honors expected behavior`()
```

## Terminology

- Preserve exact API casing in suites and test names, including `SwiftUI`,
  `AnyView`, `ForEach`, `HStack`, `VStack`, `ZStack`, `ScrollView`,
  `ViewThatFits`, `NavigationStack`, `TextField`, `SecureField`, `TextEditor`,
  `TextSelection`, `onAppear`, `onDisappear`, `onChange`, `zIndex`,
  `lineLimit`, and `scrollPosition`.
- Use hyphenated input and rendering terms consistently: `pointer-down`,
  `pointer-up`, `long-press`, `half-cell`, and `full-block`.
- Distinguish the rendered text caret from the terminal cursor. For example,
  `ESC[?25l` hides the terminal cursor; it does not emit or hide a text caret.
- Name keys and controls by the contract exercised by the test, such as
  `Return`, `Tab`, `Shift-Tab`, or `OSC 52`, rather than by a helper's spelling.

## Fixtures and support code

- Keep fixtures and helpers used by only one suite in that suite's file and
  declare them `private`.
- Put helpers shared by suites in the same domain in a narrowly named
  `*TestSupport.swift` file. Leave these declarations internal to the test
  target.
- Put a helper in `Support` only when multiple domains genuinely share it.
- Keep support files free of `@Suite` and `@Test` declarations.
- Do not widen production access or public API solely to share test setup.
- Import only the modules the file uses and follow the surrounding test
  target's import style.

## Validation

- Run the narrowest relevant suite or test filter while iterating.
- Before finishing, list the discovered tests and inspect the changed suite
  paths and names. A pure move or rename must preserve the leaf-test count
  exactly; an intentional addition or removal must change it by exactly the
  expected amount.
- Confirm that no legacy suite path, `@Test("...")` display name, `test`
  prefix, camelCase test identifier, duplicate test, or test outside a suite
  remains.
- Run the complete suite from an isolated scratch path, then check the diff for
  whitespace errors:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-cache \
  swift test --disable-sandbox \
  --scratch-path /private/tmp/swift-tui-tests list

CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-cache \
  swift test --disable-sandbox \
  --scratch-path /private/tmp/swift-tui-tests

git diff --check
```

- Treat a successful build with zero matching tests as a failed focused check;
  verify that the intended test names appear in discovery output.
