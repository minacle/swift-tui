# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.2] - 2026-07-08

### Fixed

- Fixed `Text` and `TextEditor` wrapping so trailing spaces that overflow a
  line no longer pull the preceding word onto the next wrapped row.
- Fixed empty `ScrollView` layout so it still participates in stack expansion
  and receives its proposed viewport.
- Fixed `TextEditor` caret placement so filling the last visible column moves
  the caret to the next wrapped row instead of leaving it pinned to the right
  edge.
- Fixed `TextEditor` rendering inside measured layouts so caret scrolling no
  longer causes an invalidation loop after inserting a newline at the bottom of
  its visible editor area.

## [0.4.1] - 2026-07-08

### Changed

- Pinned the `swift-terminal` dependency to version `0.0.1`.

## [0.4.0] - 2026-07-07

### Added

- Added GitHub Pages documentation deployment for versioned SwiftTUI DocC
  output, including release-tag documentation starting with `v0.3.0`.
- Added SwiftTUI attributed string attributes for foreground color, background
  color, and horizontal text alignment in `Text(AttributedString)`.
- Added public `AnyColor` as a type-erased alias for `Terminal.SGR.AnyColor`,
  with `.default`, `.color16(_:)`, `.color256(_:)`, and `.trueColor(...)`
  conveniences for use anywhere SwiftTUI accepts a `ShapeStyle`.
- Added SwiftUI-compatible `DismissAction` and `EnvironmentValues.dismiss` for
  dismissing the current navigation presentation from the destination
  environment, with dismiss actions scoped to their rendered destination while
  `PushAction` and `PopAction` remain stack-scoped.
- Added SwiftUI-compatible `View.navigationDestination(isPresented:)` and
  `View.navigationDestination(item:)` for binding-driven navigation stack
  presentations that dismiss by resetting their bindings.
- Added `ViewThatFits` for choosing the first child view whose ideal
  terminal-cell size fits the proposed size.
- Added SwiftUI-compatible `Text` initializers for `StringProtocol`,
  `verbatim` strings, and Foundation `AttributedString` content.
- Added attributed `Text` rendering for bold, italic, strikethrough, and link
  runs while preserving terminal wrapping, clipping, and final SGR styling.
- Added `OpenURLAction`, `EnvironmentValues.openURL`, and `View.onOpenURL` so
  apps can handle attributed text links explicitly without a default system URL
  opener.
- Added `View.tint(_:)` for setting terminal tint color used by controls and
  attributed text links.
- Added SwiftUI-compatible optional observable object lookup with
  `@Environment(Type.self) var object: Type?`, returning `nil` when no matching
  object is present in the environment.

### Changed

- Changed `@Environment` to read from the environment snapshot materialized when
  a view's `body` is evaluated, rather than re-reading the current render
  context whenever `wrappedValue` is accessed.
- Updated the `swift-terminal` dependency, removed the direct `swift-system`
  package dependency, and tightened terminal platform imports around `System`,
  `SystemPackage`, `Glibc`, and `Darwin` so the package continues to build
  cleanly on macOS and Linux.
- Reorganized the `SwiftTUI` source tree into `Public` and `Runtime`
  directories without changing the public API, and updated Unicode line-break
  data generation for the new runtime path.
- Clarified the README's library scope and terminal-runtime model without
  changing the package API.

### Fixed

- Fixed `.focused(...)` modifiers so they implicitly make rendered views
  focusable, allowing focus-state bindings and click focus to work without an
  extra `.focusable()` modifier.
- Fixed fallback text wrapping around punctuation so commas, periods,
  exclamation marks, question marks, colons, semicolons, quotes, brackets, and
  CJK punctuation do not detach from preceding text when a line is narrowed,
  while still respecting the proposed terminal column width.
- Fixed one-column text wrapping for East Asian wide characters so text after an
  unrenderable wide character is not incorrectly rendered on a later line.

## [0.3.0] - 2026-07-06

### Added

- Added a SwiftUI-compatible `View.onChange(of:initial:_:)` overload that
  passes old and new values to the change action.
- Added `ScrollViewReader`, `ScrollViewProxy.scrollTo(_:anchor:)`,
  `UnitPoint`, and `View.id(_:)` for programmatic scrolling to identified
  child views.
- Added `LayoutValueKey` and `View.layoutValue(key:value:)` so custom
  `Layout` implementations can read child-specific layout metadata through
  `LayoutSubview`.
- Added `ZStack`, `View.background(alignment:content:)`,
  `View.overlay(alignment:content:)`, and `View.zIndex(_:)` for layering
  terminal-cell views with front-to-back ordering.
- Added `Box`, `HeavyBox`, and `DoubleBox` views for drawing regular, heavy,
  and double-line box drawing borders around terminal-cell content.
- Added `ShapeStyle`, `View.foregroundStyle(_:)`, and
  `View.backgroundStyle(_:)` for terminal SGR color styling.
- Added `View.italic(_:)`, `View.underline(_:)`, and
  `View.strikethrough(_:)` text styling modifiers for terminal SGR italic,
  underline, and strikethrough output.
- Added the Swift DocC plugin dependency so package documentation can be
  generated through SwiftPM.

### Deprecated

- Deprecated `View.color(_:)` in favor of `View.foregroundStyle(_:)`.

## [0.2.0] - 2026-07-05

### Added

- Added `View.disabled(_:)` and `EnvironmentValues.isEnabled` for disabling
  user interaction in descendant controls while preserving rendered output.
- Added `View.hidden()` for hiding terminal output and interactions while
  preserving the view's terminal-cell layout footprint.
- Added `TextEditor` for terminal-native multi-line text editing with
  binding-backed text, focus, cursor movement, Unicode-width-aware rendering,
  and vertical scrolling.
- Added `SecureField` for single-line secure text input that shares
  `TextField` focus, editing, scrolling, styling, and `onSubmit` behavior while
  masking entered text in terminal output.
- Added Observation-based environment object injection and lookup with
  `View.environment(_:)` and `@Environment(Type.self)`, including
  `@Environment` binding projections like `$appState.token` for observable
  object properties.

### Changed

- Pinned SwiftPM dependencies to stable versions or fixed revisions so builds no
  longer depend on mutable branch heads.

### Fixed

- Fixed `onTerminate` handlers that update observable `NavigationStack(path:)`
  state so they trigger an immediate redraw instead of waiting for the next
  input event.
- Fixed standalone Escape key input so it is dispatched immediately when no
  escape-sequence bytes are already buffered.

## [0.1.0] - 2026-07-04

### Added

- Added the initial `SwiftTUI` library product for building interactive terminal
  apps with Swift 6 and a SwiftUI-shaped API.
- Added app and scene entry points with `App`, `Scene`, `WindowGroup`, and
  result builders for terminal session roots.
- Added core view composition APIs including `View`, `ViewBuilder`, `Group`,
  `ForEach`, `EmptyView`, and `AnyView`.
- Added text, editable text, and button controls with `Text`, `TextField`,
  `Button`, `onSubmit`, `onTapGesture`, focused and global `onKeyPress`
  handlers, and public keyboard and mouse event value types.
- Added terminal text styling APIs for foreground color, bold, dim, and line
  limits, including public access to `Terminal.SGR` color types through
  `SwiftTUI`.
- Added state and environment APIs with `@State`, `Binding`, `@Bindable`,
  `@FocusState`, `@Environment`, `EnvironmentValues`, `environment`,
  `transformEnvironment`, and termination actions.
- Added terminal-cell layout APIs with `HStack`, `VStack`, `Spacer`,
  `GeometryReader`, frames, padding, fixed sizing, layout priority, and custom
  `Layout` support through `ProposedViewSize`, `LayoutSubview`, and
  `LayoutSubviews`.
- Added scroll and focus APIs with `ScrollView`, `ScrollPosition`,
  `ScrollPoint`, `Axis`, `Edge`, `scrollPosition`, `focusable`, and `focused`.
- Added navigation APIs with `NavigationStack`, `NavigationLink`,
  `NavigationPath`, `LocalizedStringKey`, `navigationDestination`, and
  environment-backed push and pop actions.
- Added lifecycle APIs with `onAppear`, `onDisappear`, SwiftUI-like async
  `task`, `onChange(of:initial:)`, and `onTerminate`.
- Added terminal rendering and input behavior that accounts for Unicode display
  width and Unicode line-break data.

[Unreleased]: https://github.com/minacle/swift-tui/compare/v0.4.2...HEAD
[0.4.2]: https://github.com/minacle/swift-tui/releases/tag/v0.4.2
[0.4.1]: https://github.com/minacle/swift-tui/releases/tag/v0.4.1
[0.4.0]: https://github.com/minacle/swift-tui/releases/tag/v0.4.0
[0.3.0]: https://github.com/minacle/swift-tui/releases/tag/v0.3.0
[0.2.0]: https://github.com/minacle/swift-tui/releases/tag/v0.2.0
[0.1.0]: https://github.com/minacle/swift-tui/releases/tag/v0.1.0
