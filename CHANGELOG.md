# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Changed

- Removed the direct `swift-system` package dependency and tightened terminal
  platform imports around `System`, `SystemPackage`, `Glibc`, and `Darwin` so
  the package continues to build cleanly on macOS and Linux.
- Reorganized the `SwiftTUI` source tree into `Public` and `Runtime`
  directories without changing the public API, and updated Unicode line-break
  data generation for the new runtime path.

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

[Unreleased]: https://github.com/minacle/swift-tui/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/minacle/swift-tui/releases/tag/v0.3.0
[0.2.0]: https://github.com/minacle/swift-tui/releases/tag/v0.2.0
[0.1.0]: https://github.com/minacle/swift-tui/releases/tag/v0.1.0
