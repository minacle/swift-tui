/// A type that represents a terminal user interface fragment.
@MainActor
@preconcurrency
public protocol View {

    associatedtype Body: View = Never

    @ViewBuilder
    var body: Body { get }
}

public extension View where Body == Never {

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

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildPartialBlock<Content: View>(first content: Content) -> Content {
        content
    }

    public static func buildPartialBlock<Accumulated: View, Content: View>(
        accumulated: Accumulated,
        next content: Content
    ) -> some View {
        ViewGroup(elements(from: accumulated) + [AnyViewStorage(content)])
    }

    public static func buildExpression<Content: View>(_ expression: Content) -> Content {
        expression
    }

    public static func buildIf<Content: View>(
        _ content: Content?
    ) -> OptionalViewContent<Content> {
        OptionalViewContent(content)
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(
        first content: TrueContent
    ) -> ConditionalViewContent<TrueContent, FalseContent> {
        ConditionalViewContent(first: content)
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(
        second content: FalseContent
    ) -> ConditionalViewContent<TrueContent, FalseContent> {
        ConditionalViewContent(second: content)
    }

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

    public typealias Body = Never

    let content: Content?

    public init(_ content: Content?) {
        self.content = content
    }
}

/// A view builder result that renders one branch of conditional content.
public nonisolated struct ConditionalViewContent<TrueContent: View, FalseContent: View>: View {

    public typealias Body = Never

    enum Storage {

        case trueContent(TrueContent)

        case falseContent(FalseContent)
    }

    let storage: Storage

    public init(first content: TrueContent) {
        self.storage = .trueContent(content)
    }

    public init(second content: FalseContent) {
        self.storage = .falseContent(content)
    }
}

/// A view builder result that marks content from an availability-limited branch.
public nonisolated struct LimitedAvailabilityViewContent<Content: View>: View {

    public typealias Body = Never

    let content: Content

    public init(_ content: Content) {
        self.content = content
    }
}

/// A view with no visible terminal output.
public nonisolated struct EmptyView: View {

    public typealias Body = Never

    public init() {}
}

/// A view that collects multiple child views without adding layout of its own.
public nonisolated struct Group<Content: View>: View {

    public typealias Body = Never

    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

/// A view that creates child views from identified collection data.
public struct ForEach<Data, ID, Content>
    where Data: RandomAccessCollection, ID: Hashable
{

    public let data: Data

    public let id: KeyPath<Data.Element, ID>

    public let content: (Data.Element) -> Content

    let contextPath: [Int]?
}

extension ForEach: View where Content: View {

    public typealias Body = Never
}

public extension ForEach where Content: View {

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

    init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data, id: \.id, content: content)
    }
}

public extension ForEach where Data == Range<Int>, ID == Int, Content: View {

    init(
        _ data: Range<Int>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.init(data, id: \.self, content: content)
    }
}

/// A type-erased view.
public nonisolated struct AnyView: View {

    public typealias Body = Never

    let storage: AnyViewStorage

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
