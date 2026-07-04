# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/minacle/swift-tui/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/minacle/swift-tui/releases/tag/v0.1.0
