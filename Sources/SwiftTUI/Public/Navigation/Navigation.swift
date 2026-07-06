import Foundation

/// A key used to create localized text.
///
/// SwiftTUI stores the key as a plain string and uses it as rendered text.
public nonisolated struct LocalizedStringKey: Equatable, Hashable, Sendable,
    ExpressibleByStringLiteral
{

    /// The string key rendered by SwiftTUI.
    public var key: String

    /// Creates a localized string key.
    public init(_ key: String) {
        self.key = key
    }

    /// Creates a localized string key from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public extension Text {

    /// Creates text from a localized string key.
    ///
    /// - Parameter key: The localized string key whose stored string is rendered.
    init(_ key: LocalizedStringKey) {
        self.init(key.key)
    }
}

/// An action that pops the current navigation stack.
///
/// Read this action with `Environment(\.pop)` inside a navigation stack.
@available(*, deprecated, message: "Use EnvironmentValues.dismiss from a presented destination instead.")
public nonisolated struct PopAction {

    private let action: @MainActor () -> Void

    /// Creates a pop action.
    ///
    /// - Parameter action: The closure to invoke when the action is called.
    public init(_ action: @escaping @MainActor () -> Void = {}) {
        self.action = action
    }

    /// Pops the current navigation stack when a stack-provided action is installed.
    @MainActor public func callAsFunction() {
        action()
    }
}

/// An action that dismisses the current presentation.
///
/// Read this action with `Environment(\.dismiss)` inside a presented view.
public nonisolated struct DismissAction: @unchecked Sendable {

    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void = {}) {
        self.action = action
    }

    /// Dismisses the current presentation when a presentation-provided action is installed.
    @MainActor public func callAsFunction() {
        action()
    }
}

/// An action that pushes a value or destination onto the current navigation stack.
///
/// Read this action with `Environment(\.push)` inside a navigation stack.
@available(*, deprecated, message: "Use a NavigationStack path binding for programmatic navigation instead.")
public nonisolated struct PushAction {

    private let pushValue: @MainActor (AnyNavigationValue) -> Void

    private let pushDestination: @MainActor (NavigationDestination) -> Void

    /// Creates an inert push action.
    public init() {
        self.pushValue = { _ in }
        self.pushDestination = { _ in }
    }

    init(
        value: @escaping @MainActor (AnyNavigationValue) -> Void,
        destination: @escaping @MainActor (NavigationDestination) -> Void
    ) {
        self.pushValue = value
        self.pushDestination = destination
    }

    /// Pushes a hashable codable value onto the current navigation stack.
    ///
    /// The stack resolves the value through a matching `navigationDestination`
    /// modifier.
    ///
    /// - Parameter value: The value to append to the navigation path.
    @MainActor public func callAsFunction<Value>(_ value: Value)
        where Value: Decodable, Value: Encodable, Value: Hashable
    {
        pushValue(AnyNavigationValue(value))
    }

    /// Pushes an explicit destination view onto the current navigation stack.
    ///
    /// - Parameter destination: A view builder that creates the destination.
    @MainActor public func callAsFunction<Destination>(
        @ViewBuilder _ destination: @escaping () -> Destination
    ) where Destination: View {
        pushDestination(
            NavigationDestination(
                environment: EnvironmentRenderContext.current,
                contextPath: StateContext.currentPath,
                destination: destination
            )
        )
    }
}

/// A type-erased list of data representing the content of a navigation stack.
///
/// Values appended to a `NavigationPath` must be hashable and codable so
/// SwiftTUI can preserve identity and match destinations by concrete type.
public struct NavigationPath: Equatable {

    private var elements: [AnyNavigationValue]

    /// Creates a new, empty navigation path.
    public init() {
        self.elements = []
    }

    /// A Boolean value that indicates whether this path is empty.
    public var isEmpty: Bool {
        elements.isEmpty
    }

    /// The number of elements in this path.
    public var count: Int {
        elements.count
    }

    internal var lastValue: AnyNavigationValue? {
        elements.last
    }

    internal var values: [AnyNavigationValue] {
        elements
    }

    /// Appends a new codable value to the end of this path.
    ///
    /// - Parameter value: The value to append.
    public mutating func append<Value>(_ value: Value)
        where Value: Decodable, Value: Encodable, Value: Hashable
    {
        elements.append(AnyNavigationValue(value))
    }

    /// Removes values from the end of this path.
    ///
    /// - Parameter count: The number of values to remove.
    public mutating func removeLast(_ count: Int = 1) {
        elements.removeLast(count)
    }

    internal mutating func append(_ value: AnyNavigationValue) {
        elements.append(value)
    }
}

/// A view that displays a root view and presents additional views over it.
///
/// `NavigationStack` renders the root view and one active destination at a time.
/// It can manage its own path or use a caller-provided path binding.
public struct NavigationStack<Data, Root: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let root: Root

    let makePathAccessor: (StateRuntime?, [Int]) -> NavigationPathAccessor

    /// Creates a navigation stack that manages its own navigation state.
    ///
    /// - Parameter root: A view builder that creates the root view.
    public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {
        self.root = root()
        self.makePathAccessor = { runtime, path in
            runtime?.managedNavigationPathAccessor(at: path) ?? .empty
        }
    }

    /// Creates a navigation stack with heterogeneous navigation state that you can control.
    ///
    /// - Parameters:
    ///   - path: A binding to the stack's type-erased navigation path.
    ///   - root: A view builder that creates the root view.
    public init(
        path: Binding<NavigationPath>,
        @ViewBuilder root: () -> Root
    ) where Data == NavigationPath {
        self.root = root()
        let context = StateContext.captureActionContext()
        self.makePathAccessor = { _, _ in
            NavigationPathAccessor(path, context: context)
        }
    }

    /// Creates a navigation stack with homogeneous navigation state that you can control.
    ///
    /// - Parameters:
    ///   - path: A binding to a mutable random-access collection of hashable values.
    ///   - root: A view builder that creates the root view.
    public init(
        path: Binding<Data>,
        @ViewBuilder root: () -> Root
    )
    where
        Data: MutableCollection,
        Data: RandomAccessCollection,
        Data: RangeReplaceableCollection,
        Data.Element: Hashable
    {
        self.root = root()
        let context = StateContext.captureActionContext()
        self.makePathAccessor = { _, _ in
            NavigationPathAccessor(path, context: context)
        }
    }
}

/// A view that controls a navigation presentation.
///
/// A navigation link is focusable through its rendered label and activates by
/// pushing either an explicit destination or a value.
public struct NavigationLink<Label: View, Destination: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let label: Label

    let activation: NavigationLinkActivation

    /// Creates a navigation link that presents a destination view.
    ///
    /// - Parameters:
    ///   - destination: A view builder that creates the destination to push.
    ///   - label: A view builder that creates the rendered link label.
    public init(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        let contextPath = StateContext.currentPath
        self.activation = .destination { environment in
            NavigationDestination(
                environment: environment,
                contextPath: contextPath,
                destination: destination
            )
        }
    }
}

public extension NavigationLink where Label == Text {

    /// Creates a navigation link that presents a destination view, with a text label.
    ///
    /// - Parameters:
    ///   - titleKey: The text used as the link label.
    ///   - destination: A view builder that creates the destination to push.
    init(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.init(destination: destination) {
            Text(titleKey)
        }
    }
}

public extension NavigationLink where Destination == Never {

    /// Creates a navigation link that presents the view corresponding to a value.
    ///
    /// - Parameters:
    ///   - value: The value to append to the navigation path, or `nil` to make
    ///     the link inactive.
    ///   - label: A view builder that creates the rendered link label.
    init<Value>(
        value: Value?,
        @ViewBuilder label: () -> Label
    ) where Value: Decodable, Value: Encodable, Value: Hashable {
        self.label = label()
        self.activation = .value(value.map(AnyNavigationValue.init))
    }
}

public extension NavigationLink where Label == Text, Destination == Never {

    /// Creates a navigation link that presents the view corresponding to a value, with a text label.
    ///
    /// - Parameters:
    ///   - titleKey: The text used as the link label.
    ///   - value: The value to append to the navigation path, or `nil` to make
    ///     the link inactive.
    init<Value>(
        _ titleKey: LocalizedStringKey,
        value: Value?
    ) where Value: Decodable, Value: Encodable, Value: Hashable {
        self.init(value: value) {
            Text(titleKey)
        }
    }
}

public extension View {

    /// Associates a destination view with a presented data type for use within a navigation stack.
    ///
    /// - Parameters:
    ///   - data: The value type this destination handles.
    ///   - destination: A view builder that creates a destination for a value.
    /// - Returns: A view that registers the destination for descendant navigation stacks.
    func navigationDestination<Value, Destination>(
        for data: Value.Type,
        @ViewBuilder destination: @escaping (Value) -> Destination
    ) -> some View where Value: Hashable, Destination: View {
        NavigationDestinationView(
            content: self,
            data: data,
            destination: destination,
            contextPath: StateContext.currentPath
        )
    }

    /// Associates a destination view with a binding that can push the view onto a navigation stack.
    ///
    /// - Parameters:
    ///   - isPresented: A binding that indicates whether the destination is presented.
    ///   - destination: A view builder that creates the destination to present.
    /// - Returns: A view that presents the destination while the binding is `true`.
    func navigationDestination<Destination>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View where Destination: View {
        NavigationPresentedDestinationView(
            content: self,
            isPresented: isPresented,
            destination: destination,
            contextPath: StateContext.currentPath,
            actionContext: StateContext.captureActionContext()
        )
    }

    /// Associates a destination view with a bound value for use within a navigation stack.
    ///
    /// - Parameters:
    ///   - item: A binding to the data to present, or `nil` when no destination is presented.
    ///   - destination: A view builder that creates a destination for a non-`nil` item.
    /// - Returns: A view that presents the destination while the item binding is non-`nil`.
    func navigationDestination<Item, Destination>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View where Item: Hashable, Destination: View {
        NavigationItemDestinationView(
            content: self,
            item: item,
            destination: destination,
            contextPath: StateContext.currentPath,
            actionContext: StateContext.captureActionContext()
        )
    }
}

struct AnyNavigationValue: Equatable {

    let base: Any

    let hashable: AnyHashable

    let typeID: ObjectIdentifier

    init<Value: Hashable>(_ value: Value) {
        self.base = value
        self.hashable = AnyHashable(value)
        self.typeID = ObjectIdentifier(Value.self)
    }

    static func == (lhs: AnyNavigationValue, rhs: AnyNavigationValue) -> Bool {
        lhs.typeID == rhs.typeID && lhs.hashable == rhs.hashable
    }
}

struct NavigationPathAccessor {

    let values: () -> [AnyNavigationValue]

    let topValue: () -> AnyNavigationValue?

    let append: (AnyNavigationValue) -> Bool

    let removeLast: () -> Bool

    let count: () -> Int

    static let empty = NavigationPathAccessor(
        values: {
            []
        },
        topValue: {
            nil
        },
        append: { _ in
            false
        },
        removeLast: {
            false
        },
        count: {
            0
        }
    )

    init(
        values: @escaping () -> [AnyNavigationValue],
        topValue: @escaping () -> AnyNavigationValue?,
        append: @escaping (AnyNavigationValue) -> Bool,
        removeLast: @escaping () -> Bool,
        count: @escaping () -> Int
    ) {
        self.values = values
        self.topValue = topValue
        self.append = append
        self.removeLast = removeLast
        self.count = count
    }

    init(_ path: Binding<NavigationPath>, context: StateActionContext? = nil) {
        func withContext<Value>(
            mode: StateRenderContextMode = .action,
            _ operation: () -> Value
        ) -> Value {
            context?.perform(mode: mode, operation) ?? operation()
        }

        self.init(
            values: {
                withContext(mode: .render) {
                    path.wrappedValue.values
                }
            },
            topValue: {
                withContext(mode: .render) {
                    path.wrappedValue.lastValue
                }
            },
            append: { value in
                withContext {
                    var pathValue = path.wrappedValue
                    pathValue.append(value)
                    path.wrappedValue = pathValue
                    return true
                }
            },
            removeLast: {
                withContext {
                    var pathValue = path.wrappedValue
                    guard !pathValue.isEmpty else {
                        return false
                    }

                    pathValue.removeLast()
                    path.wrappedValue = pathValue
                    return true
                }
            },
            count: {
                withContext {
                    path.wrappedValue.count
                }
            }
        )
    }

    init<Data>(_ path: Binding<Data>, context: StateActionContext? = nil)
        where
            Data: MutableCollection,
            Data: RandomAccessCollection,
            Data: RangeReplaceableCollection,
            Data.Element: Hashable
    {
        func withContext<Value>(
            mode: StateRenderContextMode = .action,
            _ operation: () -> Value
        ) -> Value {
            context?.perform(mode: mode, operation) ?? operation()
        }

        self.init(
            values: {
                withContext(mode: .render) {
                    path.wrappedValue.map(AnyNavigationValue.init)
                }
            },
            topValue: {
                withContext(mode: .render) {
                    path.wrappedValue.last.map(AnyNavigationValue.init)
                }
            },
            append: { value in
                withContext {
                    guard let element = value.base as? Data.Element else {
                        return false
                    }

                    var pathValue = path.wrappedValue
                    pathValue.append(element)
                    path.wrappedValue = pathValue
                    return true
                }
            },
            removeLast: {
                withContext {
                    var pathValue = path.wrappedValue
                    guard !pathValue.isEmpty else {
                        return false
                    }

                    pathValue.removeLast()
                    path.wrappedValue = pathValue
                    return true
                }
            },
            count: {
                withContext {
                    path.wrappedValue.count
                }
            }
        )
    }
}

struct NavigationDirectDestination {

    let id: Int

    let token: Int

    let destination: NavigationDestination
}

struct NavigationPresentedDestination {

    let slot: [Int]

    let identity: AnyHashable

    let destination: NavigationDestination

    let dismiss: () -> Void

    let token: Int

    func withToken(_ token: Int) -> NavigationPresentedDestination {
        NavigationPresentedDestination(
            slot: slot,
            identity: identity,
            destination: destination,
            dismiss: dismiss,
            token: token
        )
    }

    func renderPath(in stackPath: [Int]) -> [Int] {
        let suffix = slot.starts(with: stackPath)
            ? Array(slot.dropFirst(stackPath.count))
            : slot
        return [3] + suffix
    }
}

enum NavigationDismissTarget: Equatable {

    case direct(id: Int, token: Int)

    case presented(slot: [Int], identity: AnyHashable, token: Int)

    case value(index: Int, value: AnyNavigationValue, token: Int)
}

struct NavigationDestination {

    private let block: (RenderProposal?, [Int], StateRuntime?, DismissAction) -> RenderedBlock?

    private let element: (RenderProposal?, [Int], StateRuntime?, DismissAction) -> RenderedElement?

    init<Content: View>(
        environment: EnvironmentValues,
        contextPath: [Int]?,
        @ViewBuilder destination: @escaping () -> Content
    ) {
        self.block = { proposal, path, runtime, dismiss in
            let content = EnvironmentRenderContext.withValues(environment) {
                Self.makeDestination(
                    destination,
                    contextPath: contextPath,
                    runtime: runtime
                )
            }
            var destinationEnvironment = environment
            destinationEnvironment.dismiss = dismiss
            return EnvironmentRenderContext.withValues(destinationEnvironment) {
                ViewResolver.block(
                    from: content,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        }
        self.element = { proposal, path, runtime, dismiss in
            let content = EnvironmentRenderContext.withValues(environment) {
                Self.makeDestination(
                    destination,
                    contextPath: contextPath,
                    runtime: runtime
                )
            }
            var destinationEnvironment = environment
            destinationEnvironment.dismiss = dismiss
            return EnvironmentRenderContext.withValues(destinationEnvironment) {
                ViewResolver.element(
                    from: content,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?,
        dismiss: DismissAction
    ) -> RenderedBlock? {
        block(proposal, path, runtime, dismiss)
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?,
        dismiss: DismissAction
    ) -> RenderedElement? {
        element(proposal, path, runtime, dismiss)
    }

    private static func makeDestination<Content: View>(
        _ destination: () -> Content,
        contextPath: [Int]?,
        runtime: StateRuntime?
    ) -> Content {
        guard let runtime, let contextPath else {
            return destination()
        }

        return runtime.withView(at: contextPath, mode: .render) {
            destination()
        }
    }
}

enum NavigationLinkActivation {

    case destination((EnvironmentValues) -> NavigationDestination)

    case value(AnyNavigationValue?)

    var isEnabled: Bool {
        switch self {
        case .destination:
            true
        case .value(let value):
            value != nil
        }
    }
}

struct NavigationDestinationView<Content: View, Value: Hashable, Destination: View>: View,
    NavigationRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let data: Value.Type

    let destination: (Value) -> Destination

    let contextPath: [Int]?

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        registerDestination()
        return ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        registerDestination()
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    private func registerDestination() {
        NavigationDestinationCollectionContext.current?.register(
            data,
            contextPath: contextPath,
            destination: destination
        )
    }
}

struct NavigationPresentedDestinationView<Content: View, Destination: View>: View,
    NavigationRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let isPresented: Binding<Bool>

    let destination: () -> Destination

    let contextPath: [Int]?

    let actionContext: StateActionContext?

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        registerDestination(at: path)
        return ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        registerDestination(at: path)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    private func registerDestination(at path: [Int]) {
        guard readIsPresented() else {
            return
        }

        let environment = EnvironmentRenderContext.current
        NavigationDestinationCollectionContext.current?.registerPresented(
            NavigationPresentedDestination(
                slot: path,
                identity: AnyHashable(true),
                destination: NavigationDestination(
                    environment: environment,
                    contextPath: contextPath,
                    destination: destination
                ),
                dismiss: {
                    writeIsPresented(false)
                },
                token: 0
            )
        )
    }

    private func readIsPresented() -> Bool {
        actionContext?.perform(mode: .render) {
            isPresented.wrappedValue
        } ?? isPresented.wrappedValue
    }

    private func writeIsPresented(_ newValue: Bool) {
        actionContext?.perform {
            isPresented.wrappedValue = newValue
        } ?? {
            isPresented.wrappedValue = newValue
        }()
    }
}

struct NavigationItemDestinationView<Content: View, Item: Hashable, Destination: View>: View,
    NavigationRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let item: Binding<Item?>

    let destination: (Item) -> Destination

    let contextPath: [Int]?

    let actionContext: StateActionContext?

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        registerDestination(at: path)
        return ViewResolver.block(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        registerDestination(at: path)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    private func registerDestination(at path: [Int]) {
        guard let value = readItem() else {
            return
        }

        let environment = EnvironmentRenderContext.current
        NavigationDestinationCollectionContext.current?.registerPresented(
            NavigationPresentedDestination(
                slot: path,
                identity: AnyHashable(value),
                destination: NavigationDestination(
                    environment: environment,
                    contextPath: contextPath
                ) {
                    destination(value)
                },
                dismiss: {
                    writeItem(nil)
                },
                token: 0
            )
        )
    }

    private func readItem() -> Item? {
        actionContext?.perform(mode: .render) {
            item.wrappedValue
        } ?? item.wrappedValue
    }

    private func writeItem(_ newValue: Item?) {
        actionContext?.perform {
            item.wrappedValue = newValue
        } ?? {
            item.wrappedValue = newValue
        }()
    }
}

protocol NavigationRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement?
}

extension NavigationStack: NavigationRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: root)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        render(
            in: proposal,
            path: path,
            runtime: runtime,
            renderRoot: {
                ViewResolver.block(from: root, in: proposal, path: path + [0], runtime: runtime)
            },
            renderDestination: {
                $0.renderedBlock(in: proposal, path: path + $1, runtime: runtime, dismiss: $2)
            }
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        render(
            in: proposal,
            path: path,
            runtime: runtime,
            renderRoot: {
                ViewResolver.element(from: root, in: proposal, path: path + [0], runtime: runtime)
            },
            renderDestination: {
                $0.renderedElement(in: proposal, path: path + $1, runtime: runtime, dismiss: $2)
            }
        )
    }

    private func render<Result>(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?,
        renderRoot: () -> Result,
        renderDestination: (NavigationDestination, [Int], DismissAction) -> Result
    ) -> Result {
        let accessor = makePathAccessor(runtime, path)
        runtime?.registerNavigationStack(at: path, accessor: accessor)
        registerBackHandler(in: runtime, path: path)
        return EnvironmentRenderContext.withValues(
            navigationEnvironment(in: runtime, path: path)
        ) {
            let destinations = collectDestinations(
                in: proposal,
                path: path,
                runtime: runtime
            )
            runtime?.updateNavigationDestinationTypes(
                destinations.typeIDs,
                at: path
            )

            return NavigationStackContext.withStack(path: path, runtime: runtime) {
                let presentedDestination = destinations.presentedDestination
                runtime?.updateNavigationPresentedDestination(
                    presentedDestination,
                    at: path
                )

                if let directDestination = runtime?.topDirectNavigationDestination(at: path) {
                    let target = NavigationDismissTarget.direct(
                        id: directDestination.id,
                        token: directDestination.token
                    )
                    return renderDestination(
                        directDestination.destination,
                        [1, directDestination.id],
                        dismissAction(for: target, runtime: runtime, path: path)
                    )
                }

                if let presentedDestination =
                    runtime?.topPresentedNavigationDestination(at: path) ?? presentedDestination
                {
                    let target = NavigationDismissTarget.presented(
                        slot: presentedDestination.slot,
                        identity: presentedDestination.identity,
                        token: presentedDestination.token
                    )
                    return renderDestination(
                        presentedDestination.destination,
                        presentedDestination.renderPath(in: path),
                        dismissAction(for: target, runtime: runtime, path: path)
                    )
                }

                let values = accessor.values()
                runtime?.updateNavigationValues(values, at: path)
                if let value = values.last,
                   let destination = destinations.destination(for: value) {
                    let index = values.count - 1
                    let token = runtime?.navigationValueDismissToken(
                        at: path,
                        index: index,
                        value: value
                    ) ?? 0
                    let target = NavigationDismissTarget.value(
                        index: index,
                        value: value,
                        token: token
                    )
                    return renderDestination(
                        destination,
                        [2, index],
                        dismissAction(for: target, runtime: runtime, path: path)
                    )
                }

                return renderRoot()
            }
        }
    }

    private func navigationEnvironment(
        in runtime: StateRuntime?,
        path: [Int]
    ) -> EnvironmentValues {
        var environment = EnvironmentRenderContext.current
        environment.pop = PopAction {
            [weak runtime] in

            _ = runtime?.popNavigationStack(at: path)
        }
        environment.push = PushAction(
            value: {
                [weak runtime] value in

                _ = runtime?.pushNavigationValue(value, at: path)
            },
            destination: {
                [weak runtime] destination in

                runtime?.pushDirectNavigationDestination(
                    destination,
                    at: path
                )
            }
        )
        return environment
    }

    private func dismissAction(
        for target: NavigationDismissTarget,
        runtime: StateRuntime?,
        path: [Int]
    ) -> DismissAction {
        DismissAction {
            [weak runtime] in

            _ = runtime?.dismissNavigationStack(at: path, target: target)
        }
    }

    private func registerBackHandler(in runtime: StateRuntime?, path: [Int]) {
        guard let runtime else {
            return
        }

        runtime.registerGlobalKeyPressHandler(
            KeyPressHandler(
                actionPath: path,
                matches: {
                    ($0.key == .escape)
                        && [.down, .repeat].contains($0.phase)
                },
                action: { _ in
                    runtime.popNavigationStack(at: path) ? .handled : .ignored
                }
            ),
            at: path
        )
    }

    private func collectDestinations(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> NavigationDestinationCollection {
        let collection = NavigationDestinationCollection()
        NavigationDestinationCollectionContext.withCollection(collection) {
            NavigationStackContext.withStack(path: path, runtime: runtime) {
                let render = {
                    _ = ViewResolver.block(
                        from: root,
                        in: proposal,
                        path: path + [0],
                        runtime: runtime
                    )
                }

                runtime?.withoutRenderRegistrations(render) ?? render()
            }
        }
        return collection
    }
}

extension NavigationLink: NavigationRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: label)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard var block = ViewResolver.block(
            from: label,
            in: proposal,
            path: path + [0],
            runtime: runtime
        ) else {
            return nil
        }

        registerActivation(in: runtime, path: path)
        if isActive(in: runtime) {
            block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
            block.hitRegions.append(RenderedHitRegion(path: path, frame: block.bounds))
        }
        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map {
            .block($0)
        }
    }

    private func registerActivation(in runtime: StateRuntime?, path: [Int]) {
        guard let runtime,
              isActive(in: runtime),
              let stackPath = NavigationStackContext.current?.path else {
            return
        }

        let environment = EnvironmentRenderContext.current
        runtime.registerFocusable(true, at: path)
        runtime.registerKeyPressHandler(
            KeyPressHandler(
                actionPath: path,
                matches: {
                    $0.key == .return && [.down, .repeat].contains($0.phase)
                },
                action: { _ in
                    activate(
                        in: runtime,
                        stackPath: stackPath,
                        environment: environment
                    )
                }
            ),
            at: path
        )
        runtime.registerTapGestureHandler(
            TapGestureHandler(
                actionPath: path,
                count: 1,
                action: {
                    _ = activate(
                        in: runtime,
                        stackPath: stackPath,
                        environment: environment
                    )
                }
            ),
            at: path
        )
    }

    private func isActive(in runtime: StateRuntime?) -> Bool {
        runtime != nil && NavigationStackContext.current != nil && activation.isEnabled
    }

    private func activate(
        in runtime: StateRuntime,
        stackPath: [Int],
        environment: EnvironmentValues
    ) -> KeyPress.Result {
        switch activation {
        case .destination(let destination):
            runtime.pushDirectNavigationDestination(
                destination(environment),
                at: stackPath
            )
            return .handled
        case .value(let value):
            guard let value,
                  runtime.pushNavigationValue(value, at: stackPath) else {
                return .ignored
            }

            return .handled
        }
    }
}

final class NavigationRuntime {

    private var stacks: [[Int]: NavigationStackState] = [:]

    func managedPathAccessor(at path: [Int]) -> NavigationPathAccessor {
        let state = state(at: path)
        return NavigationPathAccessor(
            values: {
                state.managedPath.values
            },
            topValue: {
                state.managedPath.lastValue
            },
            append: { value in
                state.managedPath.append(value)
                return true
            },
            removeLast: {
                guard !state.managedPath.isEmpty else {
                    return false
                }

                state.managedPath.removeLast()
                return true
            },
            count: {
                state.managedPath.count
            }
        )
    }

    func registerStack(at path: [Int], accessor: NavigationPathAccessor) {
        state(at: path).pathAccessor = accessor
    }

    func updateDestinationTypes(_ destinationTypes: Set<ObjectIdentifier>, at path: [Int]) {
        state(at: path).destinationTypeIDs = destinationTypes
    }

    func updateValues(_ values: [AnyNavigationValue], at path: [Int]) -> [[Int]] {
        state(at: path).updateValues(values, stackPath: path)
    }

    func valueDismissToken(at path: [Int], index: Int, value: AnyNavigationValue) -> Int? {
        state(at: path).valueDismissToken(index: index, value: value)
    }

    func updatePresentedDestination(
        _ destination: NavigationPresentedDestination?,
        at path: [Int]
    ) -> [[Int]] {
        state(at: path).updatePresentedDestination(destination, stackPath: path)
    }

    func pushValue(_ value: AnyNavigationValue, at path: [Int]) -> Bool {
        let state = state(at: path)
        guard state.pathAccessor?.append(value) == true else {
            return false
        }

        return true
    }

    func pushDirectDestination(_ destination: NavigationDestination, at path: [Int]) {
        let state = state(at: path)
        state.directDestinations.append(
            NavigationDirectDestination(
                id: state.directDestinations.count,
                token: state.nextDismissToken(),
                destination: destination
            )
        )
    }

    func topDirectDestination(at path: [Int]) -> NavigationDirectDestination? {
        state(at: path).directDestinations.last
    }

    func topPresentedDestination(at path: [Int]) -> NavigationPresentedDestination? {
        state(at: path).presentedDestination
    }

    func pop(at path: [Int]) -> [[Int]]? {
        let state = state(at: path)
        if let destination = state.directDestinations.popLast() {
            return [path + [1, destination.id]]
        }

        if let destination = state.presentedDestination {
            state.presentedDestination = nil
            destination.dismiss()
            return [path + destination.renderPath(in: path)]
        }

        guard state.pathAccessor?.removeLast() == true else {
            return nil
        }

        let removedIndex = max(state.pathAccessor?.count() ?? 0, 0)
        return [path + [2, removedIndex]]
    }

    func dismiss(at path: [Int], target: NavigationDismissTarget) -> [[Int]]? {
        let state = state(at: path)
        switch target {
        case .direct(let id, let token):
            guard let destination = state.directDestinations.last,
                  destination.id == id,
                  destination.token == token else {
                return nil
            }

            _ = state.directDestinations.popLast()
            return [path + [1, destination.id]]
        case .presented(let slot, let identity, let token):
            guard let destination = state.presentedDestination,
                  destination.slot == slot,
                  destination.identity == identity,
                  destination.token == token else {
                return nil
            }

            state.presentedDestination = nil
            destination.dismiss()
            return [path + destination.renderPath(in: path)]
        case .value(let index, let value, let token):
            guard state.valueDismissToken(index: index, value: value) == token,
                  state.pathAccessor?.count() == index + 1,
                  state.pathAccessor?.topValue() == value,
                  state.pathAccessor?.removeLast() == true else {
                return nil
            }

            return [path + [2, index]]
        }
    }

    func removeStateSubtree(at path: [Int]) {
        stacks = stacks.filter {
            !$0.key.starts(with: path)
        }
    }

    private func state(at path: [Int]) -> NavigationStackState {
        if let state = stacks[path] {
            return state
        }

        let state = NavigationStackState()
        stacks[path] = state
        return state
    }
}

private final class NavigationStackState {

    var managedPath = NavigationPath()

    var pathAccessor: NavigationPathAccessor?

    var destinationTypeIDs: Set<ObjectIdentifier> = []

    var directDestinations: [NavigationDirectDestination] = []

    var presentedDestination: NavigationPresentedDestination?

    private var valueDestinationValues: [AnyNavigationValue] = []

    private var valueDestinationTokens: [Int] = []

    private var dismissToken = 0

    func nextDismissToken() -> Int {
        dismissToken += 1
        return dismissToken
    }

    func updatePresentedDestination(
        _ destination: NavigationPresentedDestination?,
        stackPath: [Int]
    ) -> [[Int]] {
        let next = tokenizedPresentedDestination(destination)
        defer {
            presentedDestination = next
        }

        guard let current = presentedDestination else {
            return []
        }

        guard let next,
              current.slot == next.slot,
              current.identity == next.identity else {
            return [stackPath + current.renderPath(in: stackPath)]
        }

        return []
    }

    private func tokenizedPresentedDestination(
        _ destination: NavigationPresentedDestination?
    ) -> NavigationPresentedDestination? {
        guard let destination else {
            return nil
        }

        if let current = presentedDestination,
           current.slot == destination.slot,
           current.identity == destination.identity {
            return destination.withToken(current.token)
        }

        return destination.withToken(nextDismissToken())
    }

    func updateValues(_ values: [AnyNavigationValue], stackPath: [Int]) -> [[Int]] {
        let commonCount = min(values.count, valueDestinationValues.count)
        let firstChangedIndex = (0..<commonCount).first {
            values[$0] != valueDestinationValues[$0]
        }
        let retainedCount = firstChangedIndex ?? commonCount

        let removedPaths = valueDestinationValues.indices
            .filter {
                $0 >= retainedCount
            }
            .map {
                stackPath + [2, $0]
            }

        if retainedCount < valueDestinationValues.count {
            valueDestinationValues.removeSubrange(retainedCount...)
            valueDestinationTokens.removeSubrange(retainedCount...)
        }

        while valueDestinationValues.count < values.count {
            valueDestinationValues.append(values[valueDestinationValues.count])
            valueDestinationTokens.append(nextDismissToken())
        }

        return removedPaths
    }

    func valueDismissToken(index: Int, value: AnyNavigationValue) -> Int? {
        guard valueDestinationValues.indices.contains(index),
              valueDestinationValues[index] == value else {
            return nil
        }

        return valueDestinationTokens[index]
    }
}

final class NavigationDestinationCollection {

    private var destinations: [ObjectIdentifier: (AnyNavigationValue) -> NavigationDestination?] = [:]

    private var presentedDestinations: [NavigationPresentedDestination] = []

    var typeIDs: Set<ObjectIdentifier> {
        Set(destinations.keys)
    }

    var presentedDestination: NavigationPresentedDestination? {
        presentedDestinations.last
    }

    func register<Value, Destination>(
        _ data: Value.Type,
        contextPath: [Int]?,
        @ViewBuilder destination: @escaping (Value) -> Destination
    ) where Value: Hashable, Destination: View {
        let environment = EnvironmentRenderContext.current
        destinations[ObjectIdentifier(data)] = { value in
            guard let typedValue = value.base as? Value else {
                return nil
            }

            return NavigationDestination(environment: environment, contextPath: contextPath) {
                destination(typedValue)
            }
        }
    }

    func destination(for value: AnyNavigationValue) -> NavigationDestination? {
        destinations[value.typeID]?(value)
    }

    func registerPresented(_ destination: NavigationPresentedDestination) {
        presentedDestinations.append(destination)
    }
}

enum NavigationDestinationCollectionContext {

    @TaskLocal
    private static var taskCurrent: NavigationDestinationCollection?

    static var current: NavigationDestinationCollection? {
        taskCurrent
    }

    static func withCollection<Value>(
        _ collection: NavigationDestinationCollection,
        perform operation: () -> Value
    ) -> Value {
        $taskCurrent.withValue(collection) {
            operation()
        }
    }
}

struct NavigationStackActivationContext {

    let path: [Int]

    let runtime: StateRuntime?
}

enum NavigationStackContext {

    @TaskLocal
    private static var taskCurrent: NavigationStackActivationContext?

    static var current: NavigationStackActivationContext? {
        taskCurrent
    }

    static func withStack<Value>(
        path: [Int],
        runtime: StateRuntime?,
        perform operation: () -> Value
    ) -> Value {
        $taskCurrent.withValue(
            NavigationStackActivationContext(path: path, runtime: runtime)
        ) {
            operation()
        }
    }
}
