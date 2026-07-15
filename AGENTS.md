# SwiftTUI Repository Instructions

## Access control

- Never use the `package` access modifier under any circumstances.
- Never use the `@_spi` or `@_implement` attributes under any circumstances.
- Never apply an access modifier to an `extension` declaration.

## Documentation comments

- Write documentation comments in English for every `public` or `open`
  declaration owned by `SwiftTUIRuns`, `SwiftTUIEssentials`,
  `SwiftTUIControls`, or `SwiftTUI`.
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
  inspect the graphs for all four package modules. Treat any source-owned
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
  --target SwiftTUIRuns \
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

- Write tests with Swift Testing under `Tests/SwiftTUIRunsTests`,
  `Tests/SwiftTUIEssentialsTests`, or `Tests/SwiftTUIControlsTests`, according
  to API ownership.
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

## GitHub issues

- Write GitHub Issue titles and bodies in Korean. Preserve the exact spelling
  of API names, types, modules, terminal sequences, commands, paths, and quoted
  diagnostics when translating the surrounding explanation.
- Base every issue on the current checkout. Distinguish verified behavior from
  a proposed explanation or implementation, and link to relevant issues,
  discussions, documentation, or source locations when they are available.
- Use a concise title that states the observable problem or desired outcome.
  Prefix it with the owning module when that makes the scope clearer, such as
  `Runs:`, `Essentials:`, `Controls:`, or `SwiftTUI:`. Do not prefix the title
  with a category such as `[Bug]` or `[Feature]` unless the repository adopts
  that convention separately.
- Explain why the work matters to a library user or maintainer. Include the
  current behavior, desired behavior, impact, and relevant scope boundaries.
  For a bug, include the smallest reliable reproduction and relevant environment
  information.
- Do not use GitHub task-list syntax such as `- [ ]` or turn an issue into an
  implementation checklist. Use ordinary lists only when they make evidence,
  affected cases, constraints, or alternatives easier to compare.
- Keep a possible implementation separate from the observable contract. Record
  uncertain causes and design ideas as analysis or possible directions rather
  than facts or requirements.
- For a performance issue, report the measurement method, inputs, environment,
  and observed counts or timings. Distinguish stable evidence such as call
  counts or complexity growth from machine-dependent wall-clock measurements.
- Do not invent labels, milestones, assignees, priorities, or release targets.
  Add them only when the user requests them or repository evidence establishes
  them.
- Use the following body shape. Omit optional sections that do not apply instead
  of filling them with placeholders such as `없음` or `해당 없음`:

```markdown
## 요약

관찰한 문제나 달성하려는 결과와 사용자에게 미치는 영향을 간결하게 설명합니다.

## 환경

- 확인한 커밋, Swift 버전, 플랫폼 등 재현에 필요한 환경을 작성합니다.

## 재현

문제를 보여 주는 최소 코드, 명령 또는 절차와 관찰 결과를 작성합니다.

## 기대 동작

사용자나 라이브러리 관점에서 기대하는 동작을 작성합니다.

## 실제 동작

기대 동작과 다르게 관찰되는 결과를 구체적으로 작성합니다.

## 영향

사용자 동작, 정확성, 성능 또는 유지보수에 미치는 영향을 작성합니다.

## 원인 분석

확인한 실행 경로와 근거를 작성하고, 추정은 추정임을 명시합니다.

## 기존 테스트 범위

현재 통과하는 관련 테스트와 아직 검증하지 않는 동작을 작성합니다.

## 가능한 수정 방향

검토할 대안과 수정 후에도 보존해야 하는 기존 계약을 작성합니다.

## 범위

기능 제안이라면 포함할 동작과 의도적으로 제외할 내용을 작성합니다.

## 참고

- 관련 이슈, 문서, 소스 위치 또는 검토할 대안을 작성합니다.
```

## GitHub pull requests

- Always write GitHub Pull Request titles in English, even when the body is in
  Korean. Preserve the exact spelling of API names, types, modules, terminal
  sequences, commands, and paths.
- Use a concise imperative title that states the outcome of the change, such as
  `Add GitHub pull request guidance` or `Fix pointer drag capture`. Do not prefix
  the title with a category such as `[Feature]` or `[Fix]` unless the repository
  adopts that convention separately.
- Base every pull request description on the actual diff against its target
  branch. Describe the completed change and its motivation without promising
  unimplemented follow-up work or repeating the commit history.
- Write the body in Korean unless the user requests another language. Keep
  exact identifiers, commands, paths, quoted diagnostics, and GitHub closing
  keywords in their original spelling.
- Explain the externally observable behavior and important implementation
  boundaries. Call out public API, documentation, compatibility, security, or
  performance effects when they are relevant.
- Report the validation that actually ran, including focused tests, the full
  suite, symbol-graph inspection, DocC generation, or platform-specific checks
  as applicable. Distinguish passing evidence from checks that were not run or
  could not complete.
- Link related issues when known. Use a closing keyword such as `Closes #123`
  only when the pull request fully resolves that issue; do not invent issue
  numbers, labels, reviewers, milestones, or release targets.
- Use the following body shape. Omit optional sections that do not apply instead
  of filling them with placeholders such as `없음` or `해당 없음`:

```markdown
## 요약

이 변경이 필요한 이유와 달성한 결과를 간결하게 설명합니다.

## 변경 사항

- 사용자가 관찰할 수 있는 행동과 주요 구현 경계를 작성합니다.

## 검증

- 실제로 실행한 테스트, 문서 검증, 플랫폼 확인 명령과 결과를 작성합니다.

## 영향 및 호환성

공개 API, 기존 행동, 마이그레이션, 성능 또는 보안에 미치는 영향을 작성합니다.

## 관련 이슈

- Closes #123
```
