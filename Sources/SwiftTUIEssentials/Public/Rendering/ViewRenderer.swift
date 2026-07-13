public import Terminal

/// Renders one view without starting an application or terminal session.
///
/// Use this namespace for one-shot output such as a command-line status view.
/// A render performs one synchronous pass over the supplied view hierarchy and
/// returns content-local plain and ANSI text. It doesn't start an ``App``, read
/// input, inspect terminal dimensions, write to standard output, or rerender
/// after invalidation. A view body can still be evaluated more than once within
/// that pass when layout measures and then places its content.
///
/// ```swift
/// let output = ViewRenderer.render(
///     Text("ready")
///         .bold()
///         .foregroundStyle(.green)
/// )
/// print(output.ansiText, terminator: "")
/// ```
@MainActor
public enum ViewRenderer {

    /// Renders a view hierarchy once with the specified layout proposal.
    ///
    /// The proposal affects measurement and layout but doesn't define an
    /// output viewport. This renderer doesn't add centering or padding after
    /// resolution, although an individual view or layout can choose a proposed
    /// dimension as its resolved size. Use a `frame` modifier when the output
    /// must occupy a fixed canvas. Axis values are forwarded without
    /// normalization, including negative values and `Int.max`. In particular,
    /// ``ProposedViewSize/max`` can cause a view to attempt an impractically
    /// large allocation when used for final rendering.
    ///
    /// Environment modifiers and values available while this method executes
    /// participate in body evaluation. ``State`` and ``FocusState`` use their
    /// wrapper-local fallback values because no state runtime exists. The pass
    /// doesn't run `onAppear`, `onDisappear`, `onChange`, or `task` work; it
    /// also doesn't register input, reconcile focus, subscribe to Observation,
    /// or perform an invalidation-driven rerender.
    ///
    /// SwiftTUI preserves control characters and escape sequences in rendered
    /// text. Sanitize untrusted content before rendering it for a terminal.
    ///
    /// - Parameters:
    ///   - view: The root view to evaluate and render once.
    ///   - proposedSize: Optional column and row proposals for layout. The
    ///     default leaves both axes unspecified so the view can use its
    ///     intrinsic size.
    /// - Returns: An immutable content-local rendering of `view`.
    public static func render<Content: View>(
        _ view: Content,
        proposedSize: ProposedViewSize = .unspecified
    ) -> RenderedView {
        let block = ViewResolver.block(
            from: view,
            in: RenderProposal(
                columns: proposedSize.columns,
                rows: proposedSize.rows
            )
        )
        return RenderedView(block: block)
    }
}

/// An immutable result produced by a one-shot view render.
///
/// The value contains only finalized geometry and output strings. It doesn't
/// retain the internal rendered block, interaction regions, input handlers, or
/// application runtime, so it can be passed across actor boundaries after the
/// main-actor render completes.
public nonisolated struct RenderedView: Sendable {

    /// The content-local output size in terminal columns and rows.
    ///
    /// This size reflects the resolved view rather than the proposed size. A
    /// fixed `frame` in the rendered hierarchy can make the two match.
    public let size: Size

    /// The plain-text output split into layout rows.
    ///
    /// Positioned gaps are materialized as spaces. Rows that reserve their
    /// full width preserve trailing spaces, and reserved empty rows remain in
    /// the array. An empty view produces an empty array.
    public let lines: [String]

    /// The plain-text rows joined with line feeds between rows.
    ///
    /// No line feed is appended after the final row. An empty view produces an
    /// empty string.
    public var text: String {
        lines.joined(separator: "\n")
    }

    /// The rendered text with terminal SGR styling applied.
    ///
    /// This fragment has the same row and cell placement as ``text`` and
    /// includes foreground, background, bold, dim, italic, underline, and
    /// strikethrough enable and reset sequences. It doesn't clear the screen,
    /// move or show the terminal cursor, emit OSC links, switch screen buffers,
    /// or append a final line feed. Embedded control characters from view text
    /// are preserved without validation or escaping.
    public let ansiText: String

    @MainActor
    init(block: RenderedBlock?) {
        guard let block else {
            size = .zero
            lines = []
            ansiText = ""
            return
        }

        size = Size(columns: block.width, rows: block.height)
        lines = block.lines
        ansiText = TerminalOutputEncoder.ansiText(for: block)
    }
}
