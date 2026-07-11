/// A visual element that separates other content with a regular line.
///
/// A divider is vertical in an ``HStack`` and horizontal in a ``VStack``.
/// Outside those stacks, a divider is horizontal.
public nonisolated struct Divider: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates a regular-line divider.
    public init() {}
}

/// A visual element that separates other content with a heavy line.
///
/// A heavy divider is vertical in an ``HStack`` and horizontal in a
/// ``VStack``. Outside those stacks, a heavy divider is horizontal.
public nonisolated struct HeavyDivider: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates a heavy-line divider.
    public init() {}
}

/// A visual element that separates other content with a double line.
///
/// A double divider is vertical in an ``HStack`` and horizontal in a
/// ``VStack``. Outside those stacks, a double divider is horizontal.
public nonisolated struct DoubleDivider: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates a double-line divider.
    public init() {}
}

protocol DividerRenderable {

    var dividerDrawingSet: BoxDrawingSet { get }
}

extension Divider: DividerRenderable, LayoutTraitRenderable {

    var dividerDrawingSet: BoxDrawingSet {
        .regular
    }

    var layoutTraits: LayoutTraits {
        DividerRenderer.layoutTraits
    }
}

extension HeavyDivider: DividerRenderable, LayoutTraitRenderable {

    var dividerDrawingSet: BoxDrawingSet {
        .heavy
    }

    var layoutTraits: LayoutTraits {
        DividerRenderer.layoutTraits
    }
}

extension DoubleDivider: DividerRenderable, LayoutTraitRenderable {

    var dividerDrawingSet: BoxDrawingSet {
        .double
    }

    var layoutTraits: LayoutTraits {
        DividerRenderer.layoutTraits
    }
}

enum DividerRenderer {

    static var layoutTraits: LayoutTraits {
        LayoutTraits(
            flexibleAxes: StackAxisContext.axis == .horizontal ? .vertical : .horizontal,
            fillsStackMinorAxis: true
        )
    }

    static func renderedBlock(
        drawingSet: BoxDrawingSet,
        proposal: RenderProposal?
    ) -> RenderedBlock? {
        let style = BoxRenderer.borderStyle(
            from: EnvironmentRenderContext.current.textStyle
        )

        if StackAxisContext.axis == .horizontal {
            let length = proposal?.rows ?? 1
            guard length > 0 else {
                return RenderedBlock(lines: [])
            }

            return RenderedBlock(
                runs: (0..<length).map {
                    RenderedRun(text: drawingSet.vertical, row: $0, style: style)
                },
                width: 1,
                height: length,
                paddedRows: Set(0..<length)
            )
        }

        let length = proposal?.columns ?? 1
        guard length > 0 else {
            return RenderedBlock(lines: [])
        }

        return RenderedBlock(
            runs: [
                RenderedRun(
                    text: String(repeating: drawingSet.horizontal, count: length),
                    style: style
                ),
            ],
            width: length,
            height: 1,
            paddedRows: [0]
        )
    }
}
