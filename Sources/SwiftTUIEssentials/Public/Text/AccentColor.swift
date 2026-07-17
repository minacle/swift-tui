import Terminal

/// A semantic terminal color that follows the current tint.
///
/// SwiftTUI resolves this color from the nearest
/// ``View/tint(_:)-(Color16?)`` modifier
/// when it appears in a view foreground, background, shape fill, or text
/// selection style. The default tint is `Color16.blue`. Clearing the tint
/// causes the semantic color to apply no foreground or background at that
/// location.
///
/// When a caller uses this value directly as a terminal SGR ``Color`` outside
/// SwiftTUI's view-rendering environment, it produces the blue fallback SGR
/// parameters.
@frozen
public nonisolated struct AccentColor: Color, ShapeStyle {

    fileprivate init() {
    }

    /// The blue fallback SGR background parameter.
    ///
    /// SwiftTUI view rendering replaces this fallback with the current tint
    /// before producing background runs.
    public var background: String {
        Color16.blue.background
    }

    /// The blue fallback SGR foreground parameter.
    ///
    /// SwiftTUI view rendering replaces this fallback with the current tint
    /// before producing foreground runs.
    public var foreground: String {
        Color16.blue.foreground
    }
}

extension ShapeStyle where Self == AccentColor {

    /// A semantic shape style that follows the current tint.
    ///
    /// Use this style anywhere SwiftTUI accepts a terminal color shape style:
    ///
    /// ```swift
    /// Text("Accent")
    ///     .foregroundStyle(.accentColor)
    ///     .tint(.green)
    /// ```
    ///
    /// If no tint modifier is present, the style uses `Color16.blue`. If the
    /// tint is explicitly cleared, the style contributes no color.
    public static var accentColor: AccentColor {
        AccentColor()
    }
}

extension AnyColor {

    /// Replaces a possibly type-erased accent color with the supplied tint.
    ///
    /// `AnyShapeStyle` can add multiple `AnyColor` erasure layers, so the
    /// semantic marker must be detected recursively without unwrapping an
    /// ordinary concrete color.
    nonisolated func resolvingAccentColor(to tint: AnyColor?) -> AnyColor? {
        containsAccentColor ? tint : self
    }

    private nonisolated var containsAccentColor: Bool {
        if base is AccentColor {
            return true
        }
        if let base = base as? AnyColor {
            return base.containsAccentColor
        }
        return false
    }
}

extension TextStyle {

    /// Resolves semantic foreground and background colors after style merging.
    nonisolated func resolvingAccentColor(to tint: AnyColor?) -> TextStyle {
        var resolved = self
        resolved.foregroundStyle = foregroundStyle.flatMap {
            $0.resolvingAccentColor(to: tint)
        }
        resolved.backgroundStyle = backgroundStyle.flatMap {
            $0.resolvingAccentColor(to: tint)
        }
        return resolved
    }
}
