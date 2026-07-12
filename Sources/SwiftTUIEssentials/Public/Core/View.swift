/// A type that represents a terminal user interface fragment.
///
/// Conform to `View` by declaring a `body` that returns other SwiftTUI views.
/// Primitive views use `Body == Never` and are rendered directly by SwiftTUI's
/// terminal renderer.
@MainActor
@preconcurrency
public protocol View {

    /// The concrete view hierarchy returned by ``body``.
    ///
    /// Primitive views use the default `Never` value because SwiftTUI renders
    /// them directly instead of evaluating a body.
    associatedtype Body: View = Never

    /// The declarative child hierarchy for this view.
    ///
    /// SwiftTUI may evaluate this property repeatedly during layout,
    /// measurement, and rendering. Keep the getter free of externally visible
    /// side effects and store mutable UI state in ``State`` or an observable
    /// model.
    @ViewBuilder
    var body: Body { get }
}

extension View where Body == Never {

    /// A body implementation for primitive views.
    ///
    /// Primitive views are resolved directly by SwiftTUI and must not evaluate
    /// their `body`.
    public var body: Never {
        fatalError("Primitive SwiftTUI views do not have a body.")
    }
}

/// Makes `Never` the body type used by primitive SwiftTUI views.
///
/// No value of `Never` can be constructed, and SwiftTUI must not attempt to
/// resolve this conformance as a rendered view.
extension Never: View {

    /// Traps if a renderer incorrectly asks `Never` for a view body.
    public var body: Never {
        fatalError("Never has no body.")
    }
}

/// Builds declarative child hierarchies from SwiftTUI view expressions.
///
/// `ViewBuilder` preserves source order, flattens adjacent expressions into a
/// group, and represents conditional branches with public primitive wrapper
/// views. Application code normally uses it through a `@ViewBuilder` parameter
/// or a ``View/body`` declaration rather than calling these methods directly.
@resultBuilder
public enum ViewBuilder {

    /// Builds an empty view from an empty view-builder block.
    ///
    /// - Returns: An ``EmptyView``.
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    /// Starts an incremental view-builder block with the first expression.
    ///
    /// - Parameter content: The first view expression.
    /// - Returns: The same view expression.
    public static func buildPartialBlock<Content: View>(first content: Content) -> Content {
        content
    }

    /// Appends one view expression to an accumulated view-builder block.
    ///
    /// - Parameters:
    ///   - accumulated: The views already collected by the builder.
    ///   - content: The next view expression.
    /// - Returns: A grouped view containing all accumulated children.
    public static func buildPartialBlock<Accumulated: View, Content: View>(
        accumulated: Accumulated,
        next content: Content
    ) -> some View {
        ViewGroup(elements(from: accumulated) + [AnyViewStorage(content)])
    }

    /// Returns a view expression unchanged.
    ///
    /// - Parameter expression: The view expression.
    /// - Returns: The same view expression.
    public static func buildExpression<Content: View>(_ expression: Content) -> Content {
        expression
    }

    /// Builds optional view content from an `if` branch without an `else`.
    ///
    /// - Parameter content: The optional branch content.
    /// - Returns: A public wrapper that renders the content when present.
    public static func buildIf<Content: View>(
        _ content: Content?
    ) -> OptionalViewContent<Content> {
        OptionalViewContent(content)
    }

    /// Builds the first branch of conditional view content.
    ///
    /// - Parameter content: The view produced by the first branch.
    /// - Returns: A conditional wrapper that renders the first branch.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        first content: TrueContent
    ) -> ConditionalViewContent<TrueContent, FalseContent> {
        ConditionalViewContent(first: content)
    }

    /// Builds the second branch of conditional view content.
    ///
    /// - Parameter content: The view produced by the second branch.
    /// - Returns: A conditional wrapper that renders the second branch.
    public static func buildEither<TrueContent: View, FalseContent: View>(
        second content: FalseContent
    ) -> ConditionalViewContent<TrueContent, FalseContent> {
        ConditionalViewContent(second: content)
    }

    /// Wraps content produced by an availability-limited branch.
    ///
    /// - Parameter content: The view produced by the limited-availability branch.
    /// - Returns: A public wrapper that preserves the branch content.
    public static func buildLimitedAvailability<Content: View>(
        _ content: Content
    ) -> LimitedAvailabilityViewContent<Content> {
        LimitedAvailabilityViewContent(content)
    }

    private static func elements<Content: View>(from content: Content) -> [AnyViewStorage] {
        if let group = content as? ViewGroup {
            return group.elements
        }

        return [AnyViewStorage(content)]
    }
}

/// A primitive builder result that renders optional content when present.
///
/// A `nil` value contributes no rendered cells or layout child.
public nonisolated struct OptionalViewContent<Content: View>: View {

    /// The body type for this directly rendered builder result.
    public typealias Body = Never

    let content: Content?

    /// Creates optional view content.
    ///
    /// - Parameter content: The content to render, or `nil` to render nothing.
    public init(_ content: Content?) {
        self.content = content
    }
}

/// A primitive builder result that renders one branch of conditional content.
///
/// SwiftTUI assigns the two branch alternatives distinct structural identity
/// paths, so changing branches removes state owned by the previous branch.
public nonisolated struct ConditionalViewContent<TrueContent: View, FalseContent: View>: View {

    /// The body type for this directly rendered builder result.
    public typealias Body = Never

    enum Storage {

        case trueContent(TrueContent)

        case falseContent(FalseContent)
    }

    let storage: Storage

    /// Creates conditional content for the first branch.
    ///
    /// - Parameter content: The view produced by the first branch.
    public init(first content: TrueContent) {
        self.storage = .trueContent(content)
    }

    /// Creates conditional content for the second branch.
    ///
    /// - Parameter content: The view produced by the second branch.
    public init(second content: FalseContent) {
        self.storage = .falseContent(content)
    }
}

/// A primitive builder result for content from an availability-limited branch.
///
/// The wrapper preserves the child view's rendering and layout traits without
/// adding terminal output or layout of its own.
public nonisolated struct LimitedAvailabilityViewContent<Content: View>: View {

    /// The body type for this directly rendered builder result.
    public typealias Body = Never

    let content: Content

    /// Creates limited-availability view content.
    ///
    /// - Parameter content: The view produced by the limited-availability branch.
    public init(_ content: Content) {
        self.content = content
    }
}

/// A view that contributes no rendered cells or layout size.
public nonisolated struct EmptyView: View {

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    /// Creates a view with no visible output, interactive regions, or layout
    /// footprint.
    public init() {}
}

/// A view that collects multiple child views without adding layout of its own.
///
/// Containers such as stacks and grids flatten a group into their own child
/// sequence, preserving the grouped views' source order.
public nonisolated struct Group<Content: View>: View {

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let content: Content

    /// Collects view-builder content into one transparent structural value.
    ///
    /// - Parameter content: The child views to collect.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

/// A view that creates child views from identified collection data.
///
/// `ForEach` emits children in collection order and uses each element's ID as
/// its persistent identity. Reordering elements preserves their state, while
/// removing an ID discards the state subtree associated with that element.
/// IDs must be unique within the collection on every render.
public struct ForEach<Data, ID, Content>
    where Data: RandomAccessCollection, ID: Hashable
{

    /// The random-access collection traversed in collection order.
    public let data: Data

    /// The key path that provides each element's unique, stable identity.
    public let id: KeyPath<Data.Element, ID>

    /// The retained view-builder closure used to create each element's child
    /// hierarchy.
    ///
    /// SwiftTUI can invoke this closure repeatedly during measurement and
    /// rendering; don't rely on it running exactly once per element.
    public let content: (Data.Element) -> Content

    let contextPath: [Int]?
}

extension ForEach: View where Content: View {

    /// The body type for this primitive view.
    public typealias Body = Never
}

extension ForEach where Content: View {

    /// Creates child views from identified collection data.
    ///
    /// - Parameters:
    ///   - data: A random-access collection of source elements.
    ///   - id: A key path to a stable identity for each element.
    ///   - content: A view builder that creates a view for each element.
    /// - Precondition: Every element produces a unique value at `id` during a
    ///   render pass.
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.id = id
        self.content = content
        self.contextPath = StateContext.currentPath
    }
}

extension ForEach
where Data.Element: Identifiable, ID == Data.Element.ID, Content: View {

    /// Creates child views from identifiable collection data.
    ///
    /// - Parameters:
    ///   - data: A random-access collection whose elements are `Identifiable`.
    ///   - content: A view builder that creates a view for each element.
    /// - Precondition: Every element has a unique `id` during a render pass.
    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data, id: \.id, content: content)
    }
}

extension ForEach where Data == Range<Int>, ID == Int, Content: View {

    /// Creates child views for each integer in a range.
    ///
    /// - Parameters:
    ///   - data: The range of integer values to render.
    ///   - content: A view builder that creates a view for each value.
    public init(
        _ data: Range<Int>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.init(data, id: \.self, content: content)
    }
}

/// A type-erased view.
///
/// Use `AnyView` when branches or stored properties need to hide the concrete
/// view type. Type erasure preserves the original view's layout traits,
/// rendering behavior, environment propagation, and interactive regions, but
/// it doesn't capture a separate environment snapshot. Callers can no longer
/// inspect the concrete view type through the generic signature.
public nonisolated struct AnyView: View {

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let storage: AnyViewStorage

    /// Type-erases a SwiftTUI view.
    ///
    /// - Parameter content: The concrete view to erase.
    public init<Content: View>(_ content: Content) {
        self.storage = AnyViewStorage(content)
    }
}
