/// A type that represents a terminal user interface fragment.
///
/// Conform to `View` by declaring a `body` that returns other SwiftTUI views.
/// Primitive views use `Body == Never` and are rendered directly by SwiftTUI's
/// terminal renderer.
@MainActor
@preconcurrency
public protocol View {

    /// The type of view that represents this view's body.
    associatedtype Body: View = Never

    /// The content and behavior of this view.
    @ViewBuilder
    var body: Body { get }
}

public extension View where Body == Never {

    /// A body implementation for primitive views.
    ///
    /// Primitive views are resolved directly by SwiftTUI and must not evaluate
    /// their `body`.
    var body: Never {
        fatalError("Primitive SwiftTUI views do not have a body.")
    }
}

extension Never: View {

    public var body: Never {
        fatalError("Never has no body.")
    }
}

/// A result builder for SwiftTUI view content.
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

/// A view builder result that renders optional content when present.
public nonisolated struct OptionalViewContent<Content: View>: View {

    /// The body type for this primitive builder result.
    public typealias Body = Never

    let content: Content?

    /// Creates optional view content.
    ///
    /// - Parameter content: The content to render, or `nil` to render nothing.
    public init(_ content: Content?) {
        self.content = content
    }
}

/// A view builder result that renders one branch of conditional content.
public nonisolated struct ConditionalViewContent<TrueContent: View, FalseContent: View>: View {

    /// The body type for this primitive builder result.
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

/// A view builder result that marks content from an availability-limited branch.
public nonisolated struct LimitedAvailabilityViewContent<Content: View>: View {

    /// The body type for this primitive builder result.
    public typealias Body = Never

    let content: Content

    /// Creates limited-availability view content.
    ///
    /// - Parameter content: The view produced by the limited-availability branch.
    public init(_ content: Content) {
        self.content = content
    }
}

/// A view with no visible terminal output.
public nonisolated struct EmptyView: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    /// Creates an empty view.
    public init() {}
}

/// A view that collects multiple child views without adding layout of its own.
public nonisolated struct Group<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let content: Content

    /// Creates a group from view-builder content.
    ///
    /// - Parameter content: The child views to collect.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

/// A view that creates child views from identified collection data.
public struct ForEach<Data, ID, Content>
    where Data: RandomAccessCollection, ID: Hashable
{

    /// The collection used to create child views.
    public let data: Data

    /// The key path that provides each element's stable identity.
    public let id: KeyPath<Data.Element, ID>

    /// The view-builder closure used to create content for each element.
    public let content: (Data.Element) -> Content

    let contextPath: [Int]?
}

extension ForEach: View where Content: View {

    /// The body type for this primitive view.
    public typealias Body = Never
}

public extension ForEach where Content: View {

    /// Creates child views from identified collection data.
    ///
    /// - Parameters:
    ///   - data: A random-access collection of source elements.
    ///   - id: A key path to a stable identity for each element.
    ///   - content: A view builder that creates a view for each element.
    init(
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

public extension ForEach
where Data.Element: Identifiable, ID == Data.Element.ID, Content: View {

    /// Creates child views from identifiable collection data.
    ///
    /// - Parameters:
    ///   - data: A random-access collection whose elements are `Identifiable`.
    ///   - content: A view builder that creates a view for each element.
    init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data, id: \.id, content: content)
    }
}

public extension ForEach where Data == Range<Int>, ID == Int, Content: View {

    /// Creates child views for each integer in a range.
    ///
    /// - Parameters:
    ///   - data: The range of integer values to render.
    ///   - content: A view builder that creates a view for each value.
    init(
        _ data: Range<Int>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.init(data, id: \.self, content: content)
    }
}

/// A type-erased view.
///
/// Use `AnyView` when branches or stored properties need to hide the concrete
/// view type while preserving SwiftTUI rendering behavior.
public nonisolated struct AnyView: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let storage: AnyViewStorage

    /// Type-erases a SwiftTUI view.
    ///
    /// - Parameter content: The concrete view to erase.
    public init<Content: View>(_ content: Content) {
        self.storage = AnyViewStorage(content)
    }
}

nonisolated struct ViewGroup: View {

    typealias Body = Never

    let elements: [AnyViewStorage]

    init(_ elements: [AnyViewStorage]) {
        self.elements = elements
    }
}

nonisolated struct AnyViewStorage {

    private let element: @MainActor (RenderProposal?, [Int], StateRuntime?) -> RenderedElement?

    private let elements: @MainActor (RenderProposal?, [Int], StateRuntime?) -> [RenderedElement]

    private let stackChildElements: @MainActor (RenderProposal?, [Int], StateRuntime?) -> [StackChild]

    private let traits: @MainActor () -> LayoutTraits

    nonisolated init<Content: View>(_ content: Content) {
        let box = AnyViewStorageBox(content)
        self.element = { proposal, path, runtime in
            ViewResolver.element(
                from: box.content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
        self.stackChildElements = { proposal, path, runtime in
            ViewResolver.stackChildren(
                from: box.content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
        self.elements = { proposal, path, runtime in
            ViewResolver.elements(
                from: box.content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
        self.traits = {
            ViewResolver.layoutTraits(from: box.content)
        }
    }

    @MainActor
    func renderedElement(in proposal: RenderProposal? = nil) -> RenderedElement? {
        renderedElement(in: proposal, path: [], runtime: nil)
    }

    @MainActor
    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        element(proposal, path, runtime)
    }

    @MainActor
    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        elements(proposal, path, runtime)
    }

    @MainActor
    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        stackChildElements(proposal, path, runtime)
    }

    @MainActor
    var layoutTraits: LayoutTraits {
        traits()
    }

    @MainActor
    func renderedBlock() -> RenderedBlock? {
        renderedBlock(in: nil)
    }

    @MainActor
    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock? {
        guard case .block(let block) = renderedElement(in: proposal) else {
            return nil
        }

        return block
    }
}

private nonisolated final class AnyViewStorageBox<Content: View>: @unchecked Sendable {

    let content: Content

    init(_ content: Content) {
        self.content = content
    }
}
