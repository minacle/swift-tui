/// A flexible space that expands along the major axis of its containing stack.
///
/// In an ``HStack`` a spacer consumes remaining columns; in a ``VStack`` it
/// consumes remaining rows. Multiple spacers share the available remainder. A
/// custom ``Layout`` can declare the same one-axis behavior through
/// ``LayoutProperties/stackOrientation``; with no declared orientation, a
/// spacer answers maximum-size queries flexibly on both axes.
///
/// Without a finite proposal, a spacer collapses to its minimum length and
/// renders blank terminal cells rather than text runs.
public nonisolated struct Spacer: View, Equatable, Sendable {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// The minimum length in terminal cells, or `nil` for zero.
    public let minLength: Int?

    /// Creates flexible blank space.
    ///
    /// - Parameter minLength: The minimum number of terminal cells the spacer
    ///   should occupy on its flexible axis. `nil` means zero; negative values
    ///   are clamped to zero.
    public init(minLength: Int? = nil) {
        self.minLength = minLength.map { max($0, 0) }
    }
}
