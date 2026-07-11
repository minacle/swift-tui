/// A visual element that separates other content with a regular line.
///
/// A divider is vertical in an ``HStack`` and horizontal in a ``VStack``.
/// The nearest stack-like container determines the direction. Outside such a
/// container, including in a ``ZStack`` or a custom layout without an explicit
/// stack orientation, a divider is horizontal.
///
/// The divider occupies one cell on its thickness axis and expands across the
/// stack's available minor axis. Without a proposal it renders one horizontal
/// cell. Apply a foreground style to color the line glyph.
public nonisolated struct Divider: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates a divider that uses regular box-drawing glyphs.
    public init() {}
}

/// A visual element that separates other content with a heavy line.
///
/// A heavy divider is vertical in an ``HStack`` and horizontal in a
/// ``VStack``. The nearest stack-like container determines the direction;
/// outside one, the divider is horizontal.
///
/// The divider occupies one cell on its thickness axis and expands across the
/// stack's available minor axis. Apply a foreground style to color the line.
public nonisolated struct HeavyDivider: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates a divider that uses heavy box-drawing glyphs.
    public init() {}
}

/// A visual element that separates other content with a double line.
///
/// A double divider is vertical in an ``HStack`` and horizontal in a
/// ``VStack``. The nearest stack-like container determines the direction;
/// outside one, the divider is horizontal.
///
/// The divider occupies one cell on its thickness axis and expands across the
/// stack's available minor axis. Apply a foreground style to color the line.
public nonisolated struct DoubleDivider: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates a divider that uses double box-drawing glyphs.
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
