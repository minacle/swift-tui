public import Foundation
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

/// An action that opens a URL.
///
/// SwiftTUI only invokes the installed handler. The default action discards
/// URLs and does not call a platform URL opener.
public nonisolated struct OpenURLAction: @unchecked Sendable {

    /// The result of an open URL action.
    public nonisolated struct Result: Equatable, Sendable {

        private enum Storage: Equatable, Sendable {

            case handled

            case discarded

            case systemAction(URL?)
        }

        private let storage: Storage

        /// The handler opened the URL.
        public static let handled = Result(storage: .handled)

        /// The handler discarded the URL.
        public static let discarded = Result(storage: .discarded)

        /// The handler asks the system to open the original URL.
        public static let systemAction = Result(storage: .systemAction(nil))

        /// The handler asks the system to open the specified URL.
        ///
        /// SwiftTUI does not provide a default system opener, so this result is
        /// only accepted when a custom handler treats it as handled.
        public static func systemAction(_ url: URL) -> Result {
            Result(storage: .systemAction(url))
        }

        var accepted: Bool {
            storage == .handled
        }
    }

    private let handler: (URL) -> Result

    /// Creates an action that opens a URL.
    ///
    /// - Parameter handler: The closure to run for the given URL.
    public init(handler: @escaping (URL) -> Result) {
        self.handler = handler
    }

    /// Opens a URL by invoking the installed handler.
    ///
    /// - Parameter url: The URL to open.
    public func callAsFunction(_ url: URL) {
        _ = result(for: url)
    }

    /// Opens a URL by invoking the installed handler and reporting acceptance.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - completion: A closure that receives whether the handler accepted the URL.
    public func callAsFunction(_ url: URL, completion: @escaping (Bool) -> Void) {
        completion(result(for: url).accepted)
    }

    func result(for url: URL) -> Result {
        handler(url)
    }
}

/// An action that copies text to the terminal clipboard.
///
/// Read this action from `Environment(\.copy)` and call it with a string or
/// substring to publish the text through the clipboard service installed by
/// the running app.
public nonisolated struct CopyAction {

    private let action: (String) -> Void

    /// Creates a copy action.
    ///
    /// - Parameter action: The closure to run with copied text.
    public init(_ action: @escaping (String) -> Void) {
        self.action = action
    }

    /// Copies text by invoking the installed clipboard service.
    ///
    /// - Parameter text: The string or substring to copy.
    public func callAsFunction<S>(_ text: S) where S: StringProtocol {
        action(String(text))
    }
}

/// An action that reads text from the terminal clipboard.
///
/// Read this action from `Environment(\.paste)`. The action returns `nil`
/// when the clipboard service is unavailable or doesn't contain readable
/// UTF-8 text.
public nonisolated struct PasteAction {

    private let action: () -> String?

    /// Creates a paste action.
    ///
    /// - Parameter action: The closure that reads clipboard text.
    public init(_ action: @escaping () -> String?) {
        self.action = action
    }

    /// Reads text from the installed clipboard service.
    ///
    /// - Returns: Clipboard text, or `nil` when no text is available.
    public func callAsFunction() -> String? {
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
            guard let storedValue = storage[ObjectIdentifier(key)],
                  let value = storedValue as? Key.Value else {
                return Key.defaultValue
            }

            return value
        }
        set {
            storage[ObjectIdentifier(key)] = newValue as Any
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

    /// A Boolean value that indicates whether this environment allows user interaction.
    nonisolated var isEnabled: Bool {
        get {
            self[IsEnabledKey.self]
        }
        set {
            self[IsEnabledKey.self] = newValue
        }
    }

    /// A Boolean value that indicates whether the nearest focusable ancestor has focus.
    internal(set) nonisolated var isFocused: Bool {
        get {
            self[IsFocusedKey.self]
        }
        set {
            self[IsFocusedKey.self] = newValue
        }
    }

    /// A Boolean value that indicates whether this view is currently presented.
    internal(set) nonisolated var isPresented: Bool {
        get {
            self[IsPresentedKey.self]
        }
        set {
            self[IsPresentedKey.self] = newValue
        }
    }

    /// A Boolean value that indicates whether scrollable views allow scrolling.
    nonisolated var isScrollEnabled: Bool {
        get {
            self[IsScrollEnabledKey.self]
        }
        set {
            self[IsScrollEnabledKey.self] = newValue
        }
    }

    /// An action that copies text to the terminal clipboard.
    ///
    /// The default action discards text until the root app runner installs a
    /// terminal clipboard service.
    nonisolated var copy: CopyAction {
        get {
            self[CopyActionKey.self]
        }
        set {
            self[CopyActionKey.self] = newValue
        }
    }

    /// An action that reads text from the terminal clipboard.
    ///
    /// The default action returns `nil` until the root app runner installs a
    /// terminal clipboard service.
    nonisolated var paste: PasteAction {
        get {
            self[PasteActionKey.self]
        }
        set {
            self[PasteActionKey.self] = newValue
        }
    }

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

    /// An action that dismisses the current presentation.
    ///
    /// The default action does nothing outside a dismissible presentation.
    internal(set) var dismiss: DismissAction {
        get {
            self[DismissActionKey.self]
        }
        set {
            self[DismissActionKey.self] = newValue
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

    /// An action that opens a URL.
    ///
    /// The default action discards URLs and performs no system side effects.
    var openURL: OpenURLAction {
        get {
            self[OpenURLActionKey.self]
        }
        set {
            self[OpenURLActionKey.self] = newValue
        }
    }
}

/// A property wrapper that reads a value from a view's environment.
@propertyWrapper
public struct Environment<Value> {

    private let storage: EnvironmentStorage<Value>

    /// The current environment value at the wrapped key path.
    public var wrappedValue: Value {
        storage.value
    }

    /// A bindable projection of the environment value.
    public var projectedValue: EnvironmentBindable<Value> {
        EnvironmentBindable(getValue: {
            storage.value
        })
    }

    /// Creates an environment reader for a key path.
    ///
    /// - Parameter keyPath: A key path into ``EnvironmentValues``.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.storage = EnvironmentStorage {
            $0[keyPath: keyPath]
        }
    }

    /// Creates an environment reader for an observable object type.
    ///
    /// - Parameter objectType: The observable object type to read from the
    ///   current environment.
    public init(_ objectType: Value.Type) where Value: AnyObject & Observable {
        self.storage = EnvironmentStorage {
            values in

            guard let object = values.observableObject(for: objectType) else {
                fatalError(missingObservableObjectMessage(for: objectType))
            }

            return object
        }
    }

    /// Creates an environment reader for an optional observable object type.
    ///
    /// - Parameter objectType: The observable object type to read from the
    ///   current environment.
    public init<T>(_ objectType: T.Type) where Value == T?, T: AnyObject & Observable {
        self.storage = EnvironmentStorage {
            values in

            values.observableObject(for: objectType)
        }
    }
}

/// A dynamic-member projection that creates bindings to observable environment objects.
@dynamicMemberLookup
public struct EnvironmentBindable<Value> {

    private let getValue: () -> Value

    /// Creates a projection around an environment value.
    ///
    /// - Parameter wrappedValue: The value read from the current environment.
    public init(_ wrappedValue: Value) {
        self.getValue = {
            wrappedValue
        }
    }

    init(getValue: @escaping () -> Value) {
        self.getValue = getValue
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
                getValue()[keyPath: keyPath]
            },
            set: { newValue in
                let value = getValue()
                value[keyPath: keyPath] = newValue
            }
        )
    }
}

final class EnvironmentStorage<Value> {

    private let readValue: (EnvironmentValues) -> Value

    private var values = EnvironmentValues()

    var value: Value {
        readValue(values)
    }

    init(_ readValue: @escaping (EnvironmentValues) -> Value) {
        self.readValue = readValue
    }

    #if swift(<6.4)
    // Work around an optimizer crash in the Swift 6.3 synthesized deinitializer.
    @inline(never)
    deinit {
    }
    #endif

    func materialize(environment: EnvironmentValues) {
        values = environment
    }
}

protocol DynamicEnvironmentProperty {

    func materialize(environment: EnvironmentValues)
}

extension Environment: DynamicEnvironmentProperty {

    func materialize(environment: EnvironmentValues) {
        storage.materialize(environment: environment)
    }
}

func materializeDynamicEnvironmentProperties(
    in value: Any,
    environment: EnvironmentValues = EnvironmentRenderContext.current
) {
    for child in Mirror(reflecting: value).children {
        guard let property = child.value as? any DynamicEnvironmentProperty else {
            continue
        }

        property.materialize(environment: environment)
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

struct OnOpenURLView<Content: View>: View, OpenURLModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let actionPath: [Int]?

    let action: (URL) -> Void

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
        runtime?.registerOpenURLHandler(
            OpenURLHandler(
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

protocol OpenURLModifierRenderable {

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

    /// Adds a condition that controls whether users can interact with this view.
    ///
    /// - Parameter disabled: A Boolean value that determines whether users can
    ///   interact with this view.
    /// - Returns: A view that controls whether users can interact with this view.
    nonisolated func disabled(_ disabled: Bool) -> some View {
        TransformedEnvironmentView(
            content: self,
            keyPath: \.isEnabled,
            transform: {
                $0 = $0 && !disabled
            }
        )
    }

    /// Sets the environment value of the specified key path to the given value.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path into ``EnvironmentValues``.
    ///   - value: The value to expose to descendant views.
    /// - Returns: A view with the updated environment value.
    nonisolated func environment<Value>(
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

    /// Performs an action when SwiftTUI dispatches an incoming URL to this view.
    ///
    /// - Parameter action: The action to run with the incoming URL.
    /// - Returns: A view with an incoming URL handler attached.
    func onOpenURL(perform action: @escaping (URL) -> Void) -> some View {
        OnOpenURLView(
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

private struct IsEnabledKey: EnvironmentKey {

    nonisolated static var defaultValue: Bool {
        true
    }
}

private struct IsFocusedKey: EnvironmentKey {

    nonisolated static let defaultValue = false
}

private struct IsPresentedKey: EnvironmentKey {

    nonisolated static let defaultValue = false
}

private struct IsScrollEnabledKey: EnvironmentKey {

    nonisolated static let defaultValue = true
}

private struct CopyActionKey: EnvironmentKey {

    nonisolated static var defaultValue: CopyAction {
        CopyAction { _ in }
    }
}

private struct PasteActionKey: EnvironmentKey {

    nonisolated static var defaultValue: PasteAction {
        PasteAction { nil }
    }
}

private struct OpenURLActionKey: EnvironmentKey {

    nonisolated static let defaultValue = OpenURLAction { _ in
        .discarded
    }
}

private struct PopActionKey: EnvironmentKey {

    nonisolated static var defaultValue: PopAction {
        PopAction()
    }
}

private struct DismissActionKey: EnvironmentKey {

    nonisolated static var defaultValue: DismissAction {
        DismissAction()
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
