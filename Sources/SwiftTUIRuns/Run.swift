public import Terminal

/// Terminal display attributes inherited by a run of text.
///
/// A `nil` property inherits the value supplied by an enclosing ``RunGroup``
/// or by the eventual renderer. A non-`nil` Boolean explicitly enables or
/// disables that attribute, so a nested run can override its group.
public struct RunAttributes: Equatable, Sendable {

    /// The run's terminal foreground color, or `nil` to inherit it.
    public var foregroundColor: AnyColor?

    /// The run's terminal background color, or `nil` to inherit it.
    public var backgroundColor: AnyColor?

    /// Whether the run is bold, or `nil` to inherit that choice.
    public var isBold: Bool?

    /// Whether the run is dim, or `nil` to inherit that choice.
    public var isDim: Bool?

    /// Whether the run is italic, or `nil` to inherit that choice.
    public var isItalic: Bool?

    /// Whether the run is underlined, or `nil` to inherit that choice.
    public var isUnderline: Bool?

    /// Whether the run is struck through, or `nil` to inherit that choice.
    public var isStrikethrough: Bool?

    /// Creates attributes that inherit every unspecified value.
    ///
    /// - Parameters:
    ///   - foregroundColor: The foreground color, or `nil` to inherit it.
    ///   - backgroundColor: The background color, or `nil` to inherit it.
    ///   - isBold: Whether bold is explicitly enabled or disabled.
    ///   - isDim: Whether dim text is explicitly enabled or disabled.
    ///   - isItalic: Whether italics are explicitly enabled or disabled.
    ///   - isUnderline: Whether underlining is explicitly enabled or disabled.
    ///   - isStrikethrough: Whether strikethrough is explicitly enabled or disabled.
    public init(
        foregroundColor: AnyColor? = nil,
        backgroundColor: AnyColor? = nil,
        isBold: Bool? = nil,
        isDim: Bool? = nil,
        isItalic: Bool? = nil,
        isUnderline: Bool? = nil,
        isStrikethrough: Bool? = nil
    ) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.isBold = isBold
        self.isDim = isDim
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
    }

    func overriding(_ inherited: RunAttributes) -> RunAttributes {
        RunAttributes(
            foregroundColor: foregroundColor ?? inherited.foregroundColor,
            backgroundColor: backgroundColor ?? inherited.backgroundColor,
            isBold: isBold ?? inherited.isBold,
            isDim: isDim ?? inherited.isDim,
            isItalic: isItalic ?? inherited.isItalic,
            isUnderline: isUnderline ?? inherited.isUnderline,
            isStrikethrough: isStrikethrough ?? inherited.isStrikethrough
        )
    }
}

/// A leaf string and the terminal attributes applied to it.
///
/// A run boundary is an attribute boundary, not a line-breaking opportunity.
/// Layout joins adjacent runs before finding Unicode line breaks and can split
/// one run across several ``RunLayout/Line`` values. If concatenation forms a
/// single grapheme across a boundary, the attributes of the run containing the
/// grapheme's first Unicode scalar apply to that indivisible grapheme.
public struct Run: Equatable, Sendable {

    /// The unsanitized string contributed to the enclosing group.
    public var content: String

    /// The attributes that override values inherited from enclosing groups.
    public var attributes: RunAttributes

    /// Creates a run from string content and optional attributes.
    ///
    /// Control characters and terminal escape sequences are retained. Sanitize
    /// untrusted input before eventually writing the layout to a terminal.
    ///
    /// - Parameters:
    ///   - content: The string contributed by this run.
    ///   - attributes: Attributes applied to the string. The default inherits
    ///     every value.
    public init<S>(_ content: S, attributes: RunAttributes = RunAttributes())
    where S: StringProtocol {
        self.content = String(content)
        self.attributes = attributes
    }
}

/// Supplies value-preserving terminal-attribute modifiers for runs.
extension Run {

    /// Returns a run with an explicit foreground color.
    public func foregroundColor<C>(_ color: C) -> Run where C: Terminal.SGR.Color {
        modifying { $0.foregroundColor = AnyColor(color) }
    }

    /// Returns a run with an explicit background color.
    public func backgroundColor<C>(_ color: C) -> Run where C: Terminal.SGR.Color {
        modifying { $0.backgroundColor = AnyColor(color) }
    }

    /// Returns a run that explicitly enables or disables bold text.
    public func bold(_ isActive: Bool = true) -> Run {
        modifying { $0.isBold = isActive }
    }

    /// Returns a run that explicitly enables or disables dim text.
    public func dim(_ isActive: Bool = true) -> Run {
        modifying { $0.isDim = isActive }
    }

    /// Returns a run that explicitly enables or disables italic text.
    public func italic(_ isActive: Bool = true) -> Run {
        modifying { $0.isItalic = isActive }
    }

    /// Returns a run that explicitly enables or disables underlining.
    public func underline(_ isActive: Bool = true) -> Run {
        modifying { $0.isUnderline = isActive }
    }

    /// Returns a run that explicitly enables or disables strikethrough.
    public func strikethrough(_ isActive: Bool = true) -> Run {
        modifying { $0.isStrikethrough = isActive }
    }

    private func modifying(_ update: (inout RunAttributes) -> Void) -> Run {
        var copy = self
        update(&copy.attributes)
        return copy
    }
}
