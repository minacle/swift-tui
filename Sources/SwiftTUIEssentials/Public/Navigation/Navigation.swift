import Foundation

/// A key used to create localized text.
///
/// SwiftTUI stores the key as a plain string and renders it verbatim. This type
/// doesn't perform table lookup, locale selection, interpolation, or fallback
/// localization.
@available(
    *,
    deprecated,
    message: "Localize with String.init(localized:...) and pass the resulting String."
)
public nonisolated struct LocalizedStringKey: Equatable, Hashable, Sendable,
    ExpressibleByStringLiteral
{

    /// The mutable, unlocalized string rendered by SwiftTUI.
    public var key: String

    /// Creates a key from the unlocalized string SwiftTUI will render.
    ///
    /// - Parameter key: The string to store and render verbatim.
    public init(_ key: String) {
        self.key = key
    }

    /// Creates a key from a string literal that SwiftTUI renders verbatim.
    ///
    /// - Parameter value: The literal to store.
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public extension Text {

    /// Creates text from a localized string key.
    ///
    /// - Parameter key: The localized string key whose stored string is rendered.
    @available(
        *,
        deprecated,
        message: "Localize with String.init(localized:...) and pass the resulting String."
    )
    init(_ key: LocalizedStringKey) {
        self.init(content: key.key)
    }
}

/// An action that pops the current navigation stack.
///
/// Read this action with `Environment(\.pop)` inside a navigation stack. Each
/// call removes at most one active presentation or path value. A stack-provided
/// action is scoped by its rendered path, not by a permanent stack-instance
/// token; retaining it can affect a stack later recreated at the same path.
/// Prefer reading the current environment action where it is used.
public nonisolated struct PopAction {

    private let action: @MainActor () -> Void

    /// Creates a pop action backed by a main-actor closure.
    ///
    /// The default closure is inert. The action retains the closure, but a
    /// stack-provided closure doesn't keep its navigation runtime alive and is
    /// inert after that runtime is deallocated.
    ///
    /// - Parameter action: The main-actor closure to invoke synchronously.
    public init(_ action: @escaping @MainActor () -> Void = {}) {
        self.action = action
    }

    /// Invokes the stored closure on the main actor.
    ///
    /// A stack-provided action removes the current top presentation or value
    /// when its owning stack is still active. This method doesn't report
    /// whether anything was removed.
    @MainActor public func callAsFunction() {
        action()
    }
}

/// An action that dismisses the current presentation.
///
/// Read this action with `Environment(\.dismiss)` inside a presented view. A
/// destination-provided action dismisses only the presentation scope from
/// which it was captured. The default action, an action whose runtime was
/// deallocated, and an action whose scope no longer matches the current
/// destination do nothing.
///
/// The type uses unchecked sendability for a main-actor closure. That
/// conformance doesn't make captured state safe for concurrent access; invoke
/// the action through its main-actor call operation.
public nonisolated struct DismissAction: @unchecked Sendable {

    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void = {}) {
        self.action = action
    }

    /// Invokes the stored dismissal closure on the main actor.
    ///
    /// This method doesn't report whether the presentation still existed or
    /// was dismissed.
    @MainActor public func callAsFunction() {
        action()
    }
}

/// An action that pushes a value or destination onto the current navigation stack.
///
/// Read this action with `Environment(\.push)` inside a navigation stack. The
/// default action and an action whose runtime was deallocated are inert. A
/// stack-provided action is scoped by rendered path, so retaining it can affect
/// a stack later recreated at the same path. Calls don't report whether a push
/// succeeded; prefer reading the current environment action at the use site.
public nonisolated struct PushAction {

    private let pushValue: @MainActor (AnyNavigationValue) -> Void

    private let pushDestination: @MainActor (NavigationDestination) -> Void

    /// Creates a push action that ignores values and destination builders.
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

    /// Requests that the owning stack append a hashable, codable value.
    ///
    /// The stack resolves the value through a matching `navigationDestination`
    /// modifier registered for the value's concrete type. `PushAction` doesn't
    /// serialize or persist the value despite the `Codable` constraint.
    ///
    /// - Parameter value: The value to append when the action still belongs to
    ///   an active navigation stack.
    @MainActor public func callAsFunction<Value>(_ value: Value)
        where Value: Decodable, Value: Encodable, Value: Hashable
    {
        pushValue(AnyNavigationValue(value))
    }

    /// Requests that the owning stack present an explicitly built destination.
    ///
    /// SwiftTUI retains the escaping builder with the pushed destination and
    /// evaluates it during rendering in the environment and state context
    /// captured at the call site.
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
/// Values appended through this API must be hashable and codable. SwiftTUI
/// keeps each value in memory and matches a destination by concrete type;
/// `NavigationPath` doesn't encode, decode, save, or restore its elements
/// automatically.
public struct NavigationPath: Equatable {

    private var elements: [AnyNavigationValue]

    /// Creates an in-memory path with no values.
    public init() {
        self.elements = []
    }

    /// Indicates whether the path contains no values.
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

    /// Appends a hashable, codable value to the end of the path.
    ///
    /// SwiftTUI retains the value without serializing it.
    ///
    /// - Parameter value: The value whose concrete type and hashable value are
    ///   used for destination matching and equality.
    /// - Complexity: Amortized O(1).
    public mutating func append<Value>(_ value: Value)
        where Value: Decodable, Value: Encodable, Value: Hashable
    {
        elements.append(AnyNavigationValue(value))
    }

    /// Removes a number of values from the end of the path.
    ///
    /// - Parameter count: The number of values to remove. The default is `1`.
    /// - Precondition: `count >= 0 && count <= self.count`.
    /// - Complexity: O(`count`).
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
/// It can manage its own path or use a caller-provided path binding. Return and
/// tap activation push destinations, while Escape, ``PopAction``, and
/// ``DismissAction`` remove the active layer when their captured scope permits.
public struct NavigationStack<Data, Root: View>: View {

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let root: Root

    let makePathAccessor: (StateRuntime?, [Int]) -> NavigationPathAccessor

    /// Creates a navigation stack with path state owned by SwiftTUI.
    ///
    /// The managed path persists at the stack's rendered identity and isn't
    /// exposed as a binding.
    ///
    /// - Parameter root: A view builder evaluated immediately to create the
    ///   root hierarchy.
    public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {
        self.root = root()
        self.makePathAccessor = { runtime, path in
            runtime?.managedNavigationPathAccessor(at: path) ?? .empty
        }
    }

    /// Creates a navigation stack controlled by a heterogeneous path binding.
    ///
    /// - Parameters:
    ///   - path: A binding read during rendering and updated for pushes, pops,
    ///     Escape, and applicable dismiss actions.
    ///   - root: A view builder evaluated immediately to create the root view.
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

    /// Creates a navigation stack controlled by a homogeneous collection binding.
    ///
    /// - Parameters:
    ///   - path: A binding to a mutable, range-replaceable, random-access
    ///     collection. SwiftTUI reads it during rendering and updates it for
    ///     compatible pushes and removals.
    ///   - root: A view builder evaluated immediately to create the root view.
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
/// pushing either an explicit destination or a value. An active link responds
/// to Return key-down or repeat events and to a completed single primary-button
/// tap. It is inactive outside a ``NavigationStack``, while disabled, or when
/// its optional value is `nil`.
public struct NavigationLink<Label: View, Destination: View>: View {

    /// The body type for this directly rendered primitive view.
    public typealias Body = Never

    let label: Label

    let activation: NavigationLinkActivation

    /// Creates a link that presents an explicit destination view.
    ///
    /// The destination builder escapes and is evaluated only after activation,
    /// using the environment and state context captured by that activation.
    ///
    /// - Parameters:
    ///   - destination: A view builder that creates the destination to push.
    ///   - label: A view builder evaluated immediately to create the rendered,
    ///     focusable label.
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

    /// Creates a navigation link with a plain string label.
    ///
    /// SwiftTUI renders `title` unchanged and doesn't perform localization.
    /// Localize it with `String.init(localized:...)` before calling this
    /// initializer when needed. Sanitize untrusted strings before rendering
    /// them because terminal control characters remain unchanged.
    ///
    /// - Parameters:
    ///   - title: The string to render as the link label.
    ///   - destination: A view builder that creates the destination to push.
    init(
        _ title: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.init(title: title, destination: destination)
    }

    /// Builds the text-label form shared by plain and deprecated initializers.
    internal init(
        title: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.init(destination: destination) {
            Text(title)
        }
    }

    /// Creates a navigation link that presents a destination view, with a text label.
    ///
    /// - Parameters:
    ///   - titleKey: The text used as the link label.
    ///   - destination: A view builder that creates the destination to push.
    @available(
        *,
        deprecated,
        message: "Localize with String.init(localized:...) and pass the resulting String."
    )
    init(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.init(title: titleKey.key, destination: destination)
    }
}

public extension NavigationLink where Destination == Never {

    /// Creates a link that pushes a value for destination lookup.
    ///
    /// - Parameters:
    ///   - value: The value to append to the containing stack's path, or `nil`
    ///     to render a noninteractive, nonfocusable label.
    ///   - label: A view builder evaluated immediately to create the label.
    init<Value>(
        value: Value?,
        @ViewBuilder label: () -> Label
    ) where Value: Decodable, Value: Encodable, Value: Hashable {
        self.label = label()
        self.activation = .value(value.map(AnyNavigationValue.init))
    }
}

public extension NavigationLink where Label == Text, Destination == Never {

    /// Creates a value link with a plain string label.
    ///
    /// SwiftTUI renders `title` unchanged and doesn't perform localization.
    /// Localize it with `String.init(localized:...)` before calling this
    /// initializer when needed. Sanitize untrusted strings before rendering
    /// them because terminal control characters remain unchanged.
    ///
    /// - Parameters:
    ///   - title: The string to render as the link label.
    ///   - value: The value to append to the navigation path, or `nil` to make
    ///     the link inactive.
    init<Value>(
        _ title: String,
        value: Value?
    ) where Value: Decodable, Value: Encodable, Value: Hashable {
        self.init(title: title, value: value)
    }

    /// Builds the value-link form shared by plain and deprecated initializers.
    internal init<Value>(
        title: String,
        value: Value?
    ) where Value: Decodable, Value: Encodable, Value: Hashable {
        self.init(value: value) {
            Text(title)
        }
    }

    /// Creates a navigation link that presents the view corresponding to a
    /// value, with a text label.
    ///
    /// - Parameters:
    ///   - titleKey: The text used as the link label.
    ///   - value: The value to append to the navigation path, or `nil` to make
    ///     the link inactive.
    @available(
        *,
        deprecated,
        message: "Localize with String.init(localized:...) and pass the resulting String."
    )
    init<Value>(
        _ titleKey: LocalizedStringKey,
        value: Value?
    ) where Value: Decodable, Value: Encodable, Value: Hashable {
        self.init(title: titleKey.key, value: value)
    }
}

public extension View {

    /// Registers a value destination with the nearest containing navigation stack.
    ///
    /// The stack selects this builder when the top path value has the same
    /// concrete type as `data`. The builder can run repeatedly while that value
    /// is rendered, so don't use it for unrelated side effects.
    ///
    /// - Parameters:
    ///   - data: The value type this destination handles.
    ///   - destination: A view builder that creates a destination for a value.
    /// - Returns: A view that registers the destination while a containing
    ///   navigation stack collects this subtree.
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

    /// Presents a destination in the containing stack while a binding is `true`.
    ///
    /// Escape or the destination's ``DismissAction`` writes `false` to the
    /// binding. Programmatically writing `false` removes the destination on the
    /// next render.
    ///
    /// - Parameters:
    ///   - isPresented: A binding that indicates whether the destination is presented.
    ///   - destination: An escaping builder evaluated while the destination is
    ///     rendered.
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

    /// Presents a destination in the containing stack while an item is non-`nil`.
    ///
    /// Escape or the destination's ``DismissAction`` writes `nil` to the
    /// binding. Changing the non-`nil` item changes presentation identity only
    /// when the new value isn't equal under `AnyHashable` equality.
    ///
    /// - Parameters:
    ///   - item: A binding to the data to present, or `nil` when no destination is presented.
    ///   - destination: An escaping builder evaluated with the current non-`nil`
    ///     item while the destination is rendered.
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

    let scope: NavigationActionScope

    let destination: NavigationDestination
}

struct NavigationPresentedDestination {

    let slot: [Int]

    let identity: AnyHashable

    let destination: NavigationDestination

    let dismiss: () -> Void

    let scope: NavigationActionScope?

    func withScope(_ scope: NavigationActionScope) -> NavigationPresentedDestination {
        NavigationPresentedDestination(
            slot: slot,
            identity: identity,
            destination: destination,
            dismiss: dismiss,
            scope: scope
        )
    }

    func renderPath(in stackPath: [Int]) -> [Int] {
        let suffix = slot.starts(with: stackPath)
            ? Array(slot.dropFirst(stackPath.count))
            : slot
        return [3] + suffix
    }
}

struct NavigationActionScope: Equatable {

    let id: Int
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
            destinationEnvironment.isPresented = true
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
            destinationEnvironment.isPresented = true
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
                scope: nil
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
                scope: nil
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
                let rootPresentedDestination = destinations.presentedDestination

                if let directDestination = runtime?.topDirectNavigationDestination(at: path) {
                    let dismiss = dismissAction(
                        for: directDestination.scope,
                        runtime: runtime,
                        path: path
                    )
                    let destinations = collectDestinations(path: path, runtime: runtime) {
                        _ = renderDestination(
                            directDestination.destination,
                            [1, directDestination.id],
                            dismiss
                        )
                    }
                    let presentedDestination =
                        destinations.presentedDestination ?? rootPresentedDestination
                    runtime?.updateNavigationPresentedDestination(
                        presentedDestination,
                        at: path
                    )
                    if let presentedDestination =
                        runtime?.topPresentedNavigationDestination(at: path) ?? presentedDestination
                    {
                        return renderDestination(
                            presentedDestination.destination,
                            presentedDestination.renderPath(in: path),
                            dismissAction(
                                for: presentedDestination.scope,
                                runtime: runtime,
                                path: path
                            )
                        )
                    }

                    return renderDestination(
                        directDestination.destination,
                        [1, directDestination.id],
                        dismiss
                    )
                }

                let presentedDestination = rootPresentedDestination
                runtime?.updateNavigationPresentedDestination(
                    presentedDestination,
                    at: path
                )
                if let presentedDestination =
                    runtime?.topPresentedNavigationDestination(at: path) ?? presentedDestination
                {
                    return renderDestination(
                        presentedDestination.destination,
                        presentedDestination.renderPath(in: path),
                        dismissAction(
                            for: presentedDestination.scope,
                            runtime: runtime,
                            path: path
                        )
                    )
                }

                let values = accessor.values()
                runtime?.updateNavigationValues(values, at: path)
                if let value = values.last,
                   let destination = destinations.destination(for: value) {
                    let index = values.count - 1
                    let scope = runtime?.navigationValueDismissScope(
                        at: path,
                        index: index,
                        value: value
                    )
                    return renderDestination(
                        destination,
                        [2, index],
                        dismissAction(for: scope, runtime: runtime, path: path)
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
        for scope: NavigationActionScope?,
        runtime: StateRuntime?,
        path: [Int]
    ) -> DismissAction {
        guard let scope else {
            return DismissAction()
        }

        return DismissAction {
            [weak runtime] in

            _ = runtime?.dismissNavigationStack(at: path, scope: scope)
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
        collectDestinations(path: path, runtime: runtime) {
            _ = ViewResolver.block(
                from: root,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        }
    }

    private func collectDestinations(
        path: [Int],
        runtime: StateRuntime?,
        render: () -> Void
    ) -> NavigationDestinationCollection {
        let collection = NavigationDestinationCollection()
        NavigationDestinationCollectionContext.withCollection(collection) {
            NavigationStackContext.withStack(path: path, runtime: runtime) {
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
        var environment = EnvironmentRenderContext.current
        environment.isFocused = runtime?.isFocused(at: path) == true
        guard var block = EnvironmentRenderContext.withValues(environment, perform: {
            ViewResolver.block(
                from: label,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        }) else {
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
                action: .plain {
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

    func valueDismissScope(
        at path: [Int],
        index: Int,
        value: AnyNavigationValue
    ) -> NavigationActionScope? {
        state(at: path).valueDismissScope(index: index, value: value)
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
                scope: state.nextActionScope(),
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
        if let destination = state.presentedDestination {
            state.presentedDestination = nil
            destination.dismiss()
            return [path + destination.renderPath(in: path)]
        }

        if let destination = state.directDestinations.popLast() {
            return [path + [1, destination.id]]
        }

        guard state.pathAccessor?.removeLast() == true else {
            return nil
        }

        let removedIndex = max(state.pathAccessor?.count() ?? 0, 0)
        return [path + [2, removedIndex]]
    }

    func dismiss(at path: [Int], scope: NavigationActionScope) -> [[Int]]? {
        let state = state(at: path)

        if let destination = state.presentedDestination {
            guard destination.scope == scope else {
                return nil
            }

            state.presentedDestination = nil
            destination.dismiss()
            return [path + destination.renderPath(in: path)]
        }

        if let destination = state.directDestinations.last {
            guard destination.scope == scope else {
                return nil
            }

            _ = state.directDestinations.popLast()
            return [path + [1, destination.id]]
        }

        guard let removedIndex = state.removeTopValue(ifScope: scope) else {
            return nil
        }

        return [path + [2, removedIndex]]
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

    private var valueDestinationScopes: [NavigationActionScope] = []

    private var nextActionScopeID = 0

    func nextActionScope() -> NavigationActionScope {
        nextActionScopeID += 1
        return NavigationActionScope(id: nextActionScopeID)
    }

    func updatePresentedDestination(
        _ destination: NavigationPresentedDestination?,
        stackPath: [Int]
    ) -> [[Int]] {
        let next = scopedPresentedDestination(destination)
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

    private func scopedPresentedDestination(
        _ destination: NavigationPresentedDestination?
    ) -> NavigationPresentedDestination? {
        guard let destination else {
            return nil
        }

        if let current = presentedDestination,
           current.slot == destination.slot,
           current.identity == destination.identity {
            return destination.withScope(current.scope ?? nextActionScope())
        }

        return destination.withScope(nextActionScope())
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
            valueDestinationScopes.removeSubrange(retainedCount...)
        }

        while valueDestinationValues.count < values.count {
            valueDestinationValues.append(values[valueDestinationValues.count])
            valueDestinationScopes.append(nextActionScope())
        }

        return removedPaths
    }

    func valueDismissScope(index: Int, value: AnyNavigationValue) -> NavigationActionScope? {
        guard valueDestinationValues.indices.contains(index),
              valueDestinationValues[index] == value else {
            return nil
        }

        return valueDestinationScopes[index]
    }

    func removeTopValue(ifScope scope: NavigationActionScope) -> Int? {
        guard let count = pathAccessor?.count(),
              count > 0 else {
            return nil
        }

        let index = count - 1
        guard valueDestinationValues.indices.contains(index),
              valueDestinationScopes[index] == scope,
              pathAccessor?.topValue() == valueDestinationValues[index],
              pathAccessor?.removeLast() == true else {
            return nil
        }

        return index
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
