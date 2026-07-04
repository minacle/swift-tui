import Foundation
public import Observation

/// An action that terminates the running SwiftTUI app.
///
/// Read this action from `Environment(\.terminate)` and call it to request a
/// graceful exit from the app's terminal event loop.
public nonisolated struct TerminateAction {

    private let action: () -> Void

    /// Creates a terminate action.
    ///
    /// - Parameter action: The closure to run when the action is called.
    public init(_ action: @escaping () -> Void = {}) {
        self.action = action
    }

    /// Requests termination by invoking the stored action.
    public func callAsFunction() {
        action()
    }
}

/// A key for accessing values in the environment.
public protocol EnvironmentKey {

    /// The value type stored for this environment key.
    associatedtype Value

    /// The default value for the environment key.
    nonisolated static var defaultValue: Value { get }
}

/// A collection of environment values propagated through a view hierarchy.
///
/// Environment values are copied and transformed as SwiftTUI resolves the view
/// tree for rendering and event handling.
public nonisolated struct EnvironmentValues {

    private var storage: [ObjectIdentifier: Any] = [:]

    private var observableObjects: [ObjectIdentifier: AnyObject] = [:]

    /// Creates an environment value collection with default values.
    public init() {}

    /// Accesses the value associated with an environment key.
    ///
    /// - Parameter key: The key type that identifies the value.
    public nonisolated subscript<Key: EnvironmentKey>(_ key: Key.Type) -> Key.Value {
        get {
            storage[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    nonisolated func observableObject<Value>(
        for valueType: Value.Type
    ) -> Value? where Value: AnyObject & Observable {
        observableObjects[ObjectIdentifier(valueType)] as? Value
    }

    nonisolated mutating func setObservableObject<Value>(
        _ value: Value
    ) where Value: AnyObject & Observable {
        observableObjects[ObjectIdentifier(Value.self)] = value
    }
}

public extension EnvironmentValues {

    /// An action that pops the current navigation stack.
    ///
    /// The default action does nothing outside a navigation stack.
    var pop: PopAction {
        get {
            self[PopActionKey.self]
        }
        set {
            self[PopActionKey.self] = newValue
        }
    }

    /// An action that pushes a value or destination onto the current navigation stack.
    ///
    /// The default action does nothing outside a navigation stack.
    var push: PushAction {
        get {
            self[PushActionKey.self]
        }
        set {
            self[PushActionKey.self] = newValue
        }
    }

    /// An action that terminates the running SwiftTUI app.
    ///
    /// The default action does nothing until the root app runner installs one.
    var terminate: TerminateAction {
        get {
            self[TerminateActionKey.self]
        }
        set {
            self[TerminateActionKey.self] = newValue
        }
    }
}

/// A property wrapper that reads a value from a view's environment.
@propertyWrapper
public struct Environment<Value> {

    private let readValue: (EnvironmentValues) -> Value

    /// The current environment value at the wrapped key path.
    public var wrappedValue: Value {
        readValue(EnvironmentRenderContext.current)
    }

    /// A bindable projection of the environment value.
    public var projectedValue: EnvironmentBindable<Value> {
        EnvironmentBindable(wrappedValue)
    }

    /// Creates an environment reader for a key path.
    ///
    /// - Parameter keyPath: A key path into ``EnvironmentValues``.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.readValue = {
            $0[keyPath: keyPath]
        }
    }

    /// Creates an environment reader for an observable object type.
    ///
    /// - Parameter objectType: The observable object type to read from the
    ///   current environment.
    public init(_ objectType: Value.Type) where Value: AnyObject & Observable {
        self.readValue = {
            values in

            guard let object = values.observableObject(for: objectType) else {
                fatalError(missingObservableObjectMessage(for: objectType))
            }

            return object
        }
    }
}

/// A dynamic-member projection that creates bindings to observable environment objects.
@dynamicMemberLookup
public struct EnvironmentBindable<Value> {

    private let wrappedValue: Value

    /// Creates a projection around an environment value.
    ///
    /// - Parameter wrappedValue: The value read from the current environment.
    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// Creates a binding to a writable property of an observable environment object.
    ///
    /// - Parameter keyPath: A reference-writable key path into the object.
    /// - Returns: A binding that reads and writes the selected property.
    public subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>
    ) -> Binding<Subject> where Value: AnyObject & Observable {
        Binding(
            get: {
                wrappedValue[keyPath: keyPath]
            },
            set: { newValue in
                wrappedValue[keyPath: keyPath] = newValue
            }
        )
    }
}

func missingObservableObjectMessage<Value>(
    for objectType: Value.Type
) -> String where Value: AnyObject & Observable {
    "No observable object of type \(String(reflecting: objectType)) found. " +
        "A View.environment(_:) for \(String(reflecting: objectType)) " +
        "may be missing as an ancestor of this view."
}

nonisolated struct EnvironmentValueView<Content: View, Value>: View,
    EnvironmentModifierRenderable, LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let keyPath: WritableKeyPath<EnvironmentValues, Value>

    let value: Value

    var layoutTraits: LayoutTraits {
        render(
            path: keyPath,
            transform: { $0 = value }
        ) {
            ViewResolver.layoutTraits(from: content)
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        render(
            path: keyPath,
            transform: { $0 = value }
        ) {
            ViewResolver.block(from: content, in: proposal, path: path, runtime: runtime)
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        render(
            path: keyPath,
            transform: { $0 = value }
        ) {
            ViewResolver.element(from: content, in: proposal, path: path, runtime: runtime)
        }
    }
}

nonisolated struct TransformedEnvironmentView<Content: View, Value>: View,
    EnvironmentModifierRenderable, LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let keyPath: WritableKeyPath<EnvironmentValues, Value>

    let transform: (inout Value) -> Void

    var layoutTraits: LayoutTraits {
        render(
            path: keyPath,
            transform: transform
        ) {
            ViewResolver.layoutTraits(from: content)
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        render(
            path: keyPath,
            transform: transform
        ) {
            ViewResolver.block(from: content, in: proposal, path: path, runtime: runtime)
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        render(
            path: keyPath,
            transform: transform
        ) {
            ViewResolver.element(from: content, in: proposal, path: path, runtime: runtime)
        }
    }
}

nonisolated struct TypedEnvironmentObjectView<Content: View, Value>: View,
    EnvironmentModifierRenderable, LayoutTraitRenderable
    where Value: AnyObject & Observable
{

    typealias Body = Never

    let content: Content

    let object: Value

    var layoutTraits: LayoutTraits {
        render(object) {
            ViewResolver.layoutTraits(from: content)
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        render(object) {
            ViewResolver.block(from: content, in: proposal, path: path, runtime: runtime)
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        render(object) {
            ViewResolver.element(from: content, in: proposal, path: path, runtime: runtime)
        }
    }
}

struct OnTerminateView<Content: View>: View, TerminationModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let actionPath: [Int]?

    let action: () -> Void

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        register(in: runtime, renderedPath: path)
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
        register(in: runtime, renderedPath: path)
        return ViewResolver.element(
            from: content,
            in: proposal,
            path: path,
            runtime: runtime
        )
    }

    private func register(in runtime: StateRuntime?, renderedPath: [Int]) {
        runtime?.registerTerminationHandler(
            TerminationHandler(
                actionPath: actionPath ?? renderedPath,
                environment: EnvironmentRenderContext.current,
                action: action
            )
        )
    }
}

protocol EnvironmentModifierRenderable {

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

protocol TerminationModifierRenderable {

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

extension EnvironmentModifierRenderable {

    func render<Value, Result>(
        path keyPath: WritableKeyPath<EnvironmentValues, Value>,
        transform: (inout Value) -> Void,
        perform operation: () -> Result
    ) -> Result {
        var values = EnvironmentRenderContext.current
        transform(&values[keyPath: keyPath])
        return EnvironmentRenderContext.withValues(values, perform: operation)
    }

    func render<Value, Result>(
        _ object: Value,
        perform operation: () -> Result
    ) -> Result where Value: AnyObject & Observable {
        var values = EnvironmentRenderContext.current
        values.setObservableObject(object)
        return EnvironmentRenderContext.withValues(values, perform: operation)
    }
}

public extension View {

    /// Sets the environment value of the specified key path to the given value.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path into ``EnvironmentValues``.
    ///   - value: The value to expose to descendant views.
    /// - Returns: A view with the updated environment value.
    func environment<Value>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value>,
        _ value: Value
    ) -> some View {
        EnvironmentValueView(
            content: self,
            keyPath: keyPath,
            value: value
        )
    }

    /// Sets an observable object in the environment by its type.
    ///
    /// - Parameter object: The observable object to expose to descendant views.
    /// - Returns: A view with the observable object in its environment.
    func environment<Value>(
        _ object: Value
    ) -> some View where Value: AnyObject & Observable {
        TypedEnvironmentObjectView(content: self, object: object)
    }

    /// Transforms the environment value of the specified key path.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path into ``EnvironmentValues``.
    ///   - transform: A closure that mutates the environment value before
    ///     descendant views are resolved.
    /// - Returns: A view with the transformed environment value.
    func transformEnvironment<Value>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value>,
        transform: @escaping (inout Value) -> Void
    ) -> some View {
        TransformedEnvironmentView(
            content: self,
            keyPath: keyPath,
            transform: transform
        )
    }

    /// Performs an action when the user requests app termination.
    ///
    /// The action is registered with the currently rendered view hierarchy and
    /// runs when SwiftTUI dispatches a termination request.
    ///
    /// - Parameter action: The action to run before termination completes.
    /// - Returns: A view with a termination handler attached.
    func onTerminate(perform action: @escaping () -> Void) -> some View {
        OnTerminateView(
            content: self,
            actionPath: StateContext.currentPath,
            action: action
        )
    }
}

enum EnvironmentRenderContext {

    private struct TaskValues: @unchecked Sendable {

        var values: EnvironmentValues
    }

    @TaskLocal
    private static var taskValues = TaskValues(values: EnvironmentValues())

    static var current: EnvironmentValues {
        taskValues.values
    }

    static func withValues<Value>(
        _ values: EnvironmentValues,
        perform operation: () -> Value
    ) -> Value {
        $taskValues.withValue(TaskValues(values: values)) {
            return operation()
        }
    }

    static func withValues<Value>(
        _ values: EnvironmentValues,
        perform operation: () async -> Value
    ) async -> Value {
        await $taskValues.withValue(TaskValues(values: values)) {
            await operation()
        }
    }
}

private struct PopActionKey: EnvironmentKey {

    nonisolated static var defaultValue: PopAction {
        PopAction()
    }
}

private struct PushActionKey: EnvironmentKey {

    nonisolated static var defaultValue: PushAction {
        PushAction()
    }
}

private struct TerminateActionKey: EnvironmentKey {

    nonisolated static var defaultValue: TerminateAction {
        TerminateAction()
    }
}
