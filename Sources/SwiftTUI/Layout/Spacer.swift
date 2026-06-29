/// A flexible space that expands along the major axis of its containing stack.
public struct Spacer: View, Equatable, Sendable {

    public typealias Body = Never

    public let minLength: Int?

    public init(minLength: Int? = nil) {
        self.minLength = minLength.map { max($0, 0) }
    }
}
