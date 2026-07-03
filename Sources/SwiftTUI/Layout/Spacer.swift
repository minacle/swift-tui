/// A flexible space that expands along the major axis of its containing stack.
public nonisolated struct Spacer: View, Equatable, Sendable {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// The minimum length in terminal cells, or `nil` for the default length.
    public let minLength: Int?

    /// Creates flexible space.
    ///
    /// - Parameter minLength: The minimum number of terminal cells the spacer
    ///   should occupy. Negative values are clamped to zero.
    public init(minLength: Int? = nil) {
        self.minLength = minLength.map { max($0, 0) }
    }
}
