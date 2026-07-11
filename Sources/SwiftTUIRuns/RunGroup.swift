public import Terminal

/// A recursive, ordered collection of attributed terminal-text runs.
///
/// Groups can contain runs and other groups. Attributes on a nested run or
/// group override matching values inherited from its ancestors. Group
/// boundaries do not create line-breaking opportunities.
public struct RunGroup: Equatable, Sendable {

    enum Child: Equatable, Sendable {
        case run(Run)
        case group(RunGroup)
    }

    var children: [Child]

    /// Attributes inherited by descendants that do not override them.
    public var attributes: RunAttributes

    /// Creates a group from a run-builder closure.
    ///
    /// - Parameters:
    ///   - attributes: Attributes inherited by the closure's content.
    ///   - content: Runs and nested groups in display order.
    public init(
        attributes: RunAttributes = RunAttributes(),
        @RunGroupBuilder content: () -> RunGroup
    ) {
        self = content()
        self.attributes = attributes.overriding(self.attributes)
    }

    /// Creates a group containing one run.
    ///
    /// - Parameter run: The run to place in the group.
    public init(_ run: Run) {
        self.init(children: [.run(run)])
    }

    /// Creates a group containing one plain run.
    ///
    /// - Parameter content: Unsanitized string content for the run.
    public init<S>(_ content: S) where S: StringProtocol {
        self.init(Run(content))
    }

    init(
        children: [Child] = [],
        attributes: RunAttributes = RunAttributes()
    ) {
        self.children = children
        self.attributes = attributes
    }

    /// The plain string formed by concatenating every descendant run.
    ///
    /// This value omits attributes and does not sanitize control characters or
    /// escape sequences.
    ///
    /// - Complexity: O(n), where n is the total number of characters.
    public var content: String {
        children.map { child in
            switch child {
            case .run(let run):
                run.content
            case .group(let group):
                group.content
            }
        }.joined()
    }
}

/// Builds recursive run groups with ordinary Swift control flow.
@resultBuilder
public enum RunGroupBuilder {

    /// Converts a leaf run into a group-builder component.
    public static func buildExpression(_ expression: Run) -> RunGroup {
        RunGroup(expression)
    }

    /// Preserves a nested group as a group-builder component.
    public static func buildExpression(_ expression: RunGroup) -> RunGroup {
        expression
    }

    /// Combines components in source order.
    public static func buildBlock(_ components: RunGroup...) -> RunGroup {
        RunGroup(children: components.map(RunGroup.Child.group))
    }

    /// Builds an empty group when optional content is absent.
    public static func buildOptional(_ component: RunGroup?) -> RunGroup {
        component ?? RunGroup(children: [])
    }

    /// Selects the first branch of conditional builder content.
    public static func buildEither(first component: RunGroup) -> RunGroup {
        component
    }

    /// Selects the second branch of conditional builder content.
    public static func buildEither(second component: RunGroup) -> RunGroup {
        component
    }

    /// Combines the components produced by a `for` loop.
    public static func buildArray(_ components: [RunGroup]) -> RunGroup {
        RunGroup(children: components.map(RunGroup.Child.group))
    }

    /// Preserves content guarded by an availability check.
    public static func buildLimitedAvailability(_ component: RunGroup) -> RunGroup {
        component
    }
}

/// Supplies value-preserving inherited-attribute modifiers for run groups.
public extension RunGroup {

    /// Returns a group whose descendants inherit the given foreground color.
    func foregroundColor<C>(_ color: C) -> RunGroup where C: Terminal.SGR.Color {
        modifying { $0.foregroundColor = AnyColor(color) }
    }

    /// Returns a group whose descendants inherit the given background color.
    func backgroundColor<C>(_ color: C) -> RunGroup where C: Terminal.SGR.Color {
        modifying { $0.backgroundColor = AnyColor(color) }
    }

    /// Returns a group that explicitly enables or disables inherited bold text.
    func bold(_ isActive: Bool = true) -> RunGroup {
        modifying { $0.isBold = isActive }
    }

    /// Returns a group that explicitly enables or disables inherited dim text.
    func dim(_ isActive: Bool = true) -> RunGroup {
        modifying { $0.isDim = isActive }
    }

    /// Returns a group that explicitly enables or disables inherited italic text.
    func italic(_ isActive: Bool = true) -> RunGroup {
        modifying { $0.isItalic = isActive }
    }

    /// Returns a group that explicitly enables or disables inherited underlining.
    func underline(_ isActive: Bool = true) -> RunGroup {
        modifying { $0.isUnderline = isActive }
    }

    /// Returns a group that explicitly enables or disables inherited strikethrough.
    func strikethrough(_ isActive: Bool = true) -> RunGroup {
        modifying { $0.isStrikethrough = isActive }
    }

    private func modifying(_ update: (inout RunAttributes) -> Void) -> RunGroup {
        var copy = self
        update(&copy.attributes)
        return copy
    }
}
