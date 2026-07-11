# SwiftTUI Repository Instructions

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
