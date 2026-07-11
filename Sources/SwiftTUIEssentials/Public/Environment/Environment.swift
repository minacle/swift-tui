public import Foundation
public import Observation

/// An action that terminates the running SwiftTUI app.
///
/// Read this action from `Environment(\.terminate)` and call it to request a
/// graceful exit from the app's terminal event loop. The app runner's action
/// records the request synchronously. The runner observes it near the end of
/// the current loop iteration, after any pending input, gesture deadlines, and
/// required redraw for that iteration. A directly initialized action can
/// instead run any closure supplied by the caller.
public nonisolated struct TerminateAction {

    private let action: () -> Void

    /// Creates an action that synchronously invokes a closure.
    ///
    /// The default closure does nothing, so a standalone action doesn't imply
    /// that an application runner exists or that termination succeeded.
    ///
    /// - Parameter action: The closure to run on each invocation.
    public init(_ action: @escaping () -> Void = {}) {
        self.action = action
    }

    /// Synchronously invokes the action's stored closure.
    ///
    /// When this value comes from ``EnvironmentValues/terminate``, the closure
    /// normally requests app termination. Custom and default values can have
    /// different behavior.
    public func callAsFunction() {
        action()
    }
}

/// An action that opens a URL.
///
/// SwiftTUI passes the URL unchanged to the installed handler. The action
/// doesn't validate the URL, resolve redirects, or invoke a platform URL
/// opener. The default environment action returns ``Result/discarded``.
///
/// The type uses unchecked sendability to carry an arbitrary handler. This
/// conformance doesn't make a captured closure or its state safe for concurrent
/// access; callers remain responsible for the handler's isolation.
public nonisolated struct OpenURLAction: @unchecked Sendable {

    /// Describes how an installed URL handler responded to a request.
    ///
    /// SwiftTUI treats only ``handled`` as accepted. It doesn't perform the
    /// fallback represented by either `systemAction` value.
    public nonisolated struct Result: Equatable, Sendable {

        private enum Storage: Equatable, Sendable {

            case handled

            case discarded

            case systemAction(URL?)
        }

        private let storage: Storage

        /// The handler accepted and handled the URL request.
        public static let handled = Result(storage: .handled)

        /// The handler declined the URL request without a fallback.
        public static let discarded = Result(storage: .discarded)

        /// The handler requests a system fallback for the original URL.
        ///
        /// SwiftTUI records this result as not accepted and doesn't invoke a
        /// system URL opener.
        public static let systemAction = Result(storage: .systemAction(nil))

        /// Returns a result that requests a system fallback for another URL.
        ///
        /// SwiftTUI doesn't validate or open the supplied URL and records this
        /// result as not accepted.
        ///
        /// - Parameter url: The URL a separate system-opening layer could use.
        /// - Returns: A system-action result carrying `url`.
        public static func systemAction(_ url: URL) -> Result {
            Result(storage: .systemAction(url))
        }

        var accepted: Bool {
            storage == .handled
        }
    }

    private let handler: (URL) -> Result

    /// Creates an action backed by a URL handler.
    ///
    /// The closure is retained for the lifetime of this action and runs
    /// synchronously when the action is called.
    ///
    /// - Parameter handler: The closure that receives each unmodified URL and
    ///   returns its disposition.
    public init(handler: @escaping (URL) -> Result) {
        self.handler = handler
    }

    /// Invokes the installed handler and discards its result.
    ///
    /// - Parameter url: The unvalidated URL to pass to the handler.
    public func callAsFunction(_ url: URL) {
        _ = result(for: url)
    }

    /// Invokes the installed handler and reports whether it returned
    /// ``Result/handled``.
    ///
    /// - Parameters:
    ///   - url: The unvalidated URL to pass to the handler.
    ///   - completion: A closure invoked synchronously with `true` only for
    ///     ``Result/handled``. Both system-action results and ``Result/discarded``
    ///     produce `false`.
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
/// the running app. The action forwards text verbatim: it performs no
/// redaction, confirmation, or success reporting. The app runner's terminal
/// service can expose the value to the host clipboard through OSC 52, so don't
/// pass secrets unless that transfer is intended.
public nonisolated struct CopyAction {

    private let action: (String) -> Void

    /// Creates a copy action backed by a retained closure.
    ///
    /// - Parameter action: The closure to invoke synchronously with copied text.
    public init(_ action: @escaping (String) -> Void) {
        self.action = action
    }

    /// Forwards text to the installed clipboard closure.
    ///
    /// This method doesn't report whether a terminal or clipboard accepted the
    /// value.
    ///
    /// - Parameter text: The string or substring to convert to `String` and
    ///   forward without validation.
    public func callAsFunction<S>(_ text: S) where S: StringProtocol {
        action(String(text))
    }
}

/// An action that reads text from the terminal clipboard.
///
/// Read this action from `Environment(\.paste)`. The action returns `nil`
/// when the clipboard service is unavailable or doesn't contain readable
/// UTF-8 text. Treat returned text as untrusted input; this wrapper doesn't
/// validate, sanitize, or limit clipboard contents.
public nonisolated struct PasteAction {

    private let action: () -> String?

    /// Creates a paste action backed by a retained closure.
    ///
    /// - Parameter action: The closure invoked synchronously to read clipboard
    ///   text.
    public init(_ action: @escaping () -> String?) {
        self.action = action
    }

    /// Invokes the installed clipboard-reading closure.
    ///
    /// - Returns: Clipboard text, or `nil` when no text is available.
    public func callAsFunction() -> String? {
        action()
    }
}

/// A type-level key for storing a value in ``EnvironmentValues``.
///
/// Define a distinct key type for each value. When no override is present,
/// ``EnvironmentValues`` reads ``defaultValue`` without storing it.
public protocol EnvironmentKey {

    /// The type of value associated with this key.
    associatedtype Value

    /// The value returned when an environment contains no explicit override
    /// for this key.
    nonisolated static var defaultValue: Value { get }
}

/// A collection of environment values propagated through a view hierarchy.
///
/// Environment values are copied and transformed as SwiftTUI resolves the view
/// tree for rendering and event handling. Value-key overrides have value
/// semantics, while observable objects are stored and propagated by reference.
public nonisolated struct EnvironmentValues {

    private var storage: [ObjectIdentifier: Any] = [:]

    private var observableObjects: [ObjectIdentifier: AnyObject] = [:]

    /// Creates an environment with no explicit overrides or observable objects.
    ///
    /// Reading a key from this value returns that key's declared default.
    public init() {}

    /// Reads or replaces the value associated with an environment key type.
    ///
    /// - Parameter key: The key type that uniquely identifies the value.
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

    /// Indicates whether descendants can register user-interaction handlers.
    ///
    /// The default is `true`. ``View/disabled(_:)`` combines its value with the
    /// inherited setting, so a descendant can't re-enable interaction beneath
    /// a disabled ancestor by applying `disabled(false)`.
    nonisolated var isEnabled: Bool {
        get {
            self[IsEnabledKey.self]
        }
        set {
            self[IsEnabledKey.self] = newValue
        }
    }

    /// Indicates whether the nearest focusable view for this environment has
    /// focus.
    ///
    /// SwiftTUI maintains this read-only value while resolving a focused view.
    /// It defaults to `false` outside that scope.
    internal(set) nonisolated var isFocused: Bool {
        get {
            self[IsFocusedKey.self]
        }
        set {
            self[IsFocusedKey.self] = newValue
        }
    }

    /// Indicates whether the current navigation destination is presented.
    ///
    /// SwiftTUI sets this read-only value inside an active navigation
    /// destination, including value-, Boolean-, item-, and explicitly pushed
    /// destinations. It defaults to `false` elsewhere.
    internal(set) nonisolated var isPresented: Bool {
        get {
            self[IsPresentedKey.self]
        }
        set {
            self[IsPresentedKey.self] = newValue
        }
    }

    /// Indicates whether scrollable descendants accept scrolling input.
    ///
    /// The default is `true`. This setting controls interaction; it doesn't
    /// remove the scroll view or change its current scroll position.
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
///
/// SwiftTUI materializes the wrapper with the active environment snapshot. The
/// storage belongs to the wrapper instance, not to each rendered identity: if
/// the same view value is rendered in multiple environments, the most recent
/// materialization replaces the earlier snapshot. Read or capture the value
/// while constructing the relevant body instead of relying on an escaped action
/// to recover an earlier identity's wrapper snapshot.
@propertyWrapper
public struct Environment<Value> {

    private let storage: EnvironmentStorage<Value>

    /// The value read from this wrapper instance's most recently materialized
    /// environment snapshot.
    public var wrappedValue: Value {
        storage.value
    }

    /// A dynamic-member projection for binding writable properties of an
    /// observable environment object.
    ///
    /// The projection reads this wrapper instance's most recently materialized
    /// object on every access; it doesn't copy properties into independent or
    /// per-identity storage.
    public var projectedValue: EnvironmentBindable<Value> {
        EnvironmentBindable(getValue: {
            storage.value
        })
    }

    /// Creates a wrapper that reads an environment key path.
    ///
    /// - Parameter keyPath: A key path into ``EnvironmentValues``.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.storage = EnvironmentStorage {
            $0[keyPath: keyPath]
        }
    }

    /// Creates a wrapper that requires an observable object of the given type.
    ///
    /// SwiftTUI looks up objects by their exact concrete type. Reading
    /// ``wrappedValue`` traps if no matching ancestor installed one with
    /// ``View/environment(_:)``.
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

    /// Creates a wrapper for an optional observable object of the given type.
    ///
    /// SwiftTUI looks up objects by their exact concrete type and returns `nil`
    /// when no matching ancestor installed one.
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

/// A dynamic-member projection that creates bindings to observable object
/// properties.
///
/// Bindings created from this value read the current object reference on every
/// access and write directly through its reference-writable key path. The
/// projection doesn't retain a snapshot of individual property values.
@dynamicMemberLookup
public struct EnvironmentBindable<Value> {

    private let getValue: () -> Value

    /// Creates a projection around a fixed observable object reference.
    ///
    /// Unlike ``Environment/projectedValue``, this initializer always returns
    /// the supplied reference and doesn't track later environment replacement.
    ///
    /// - Parameter wrappedValue: The observable object reference to expose.
    public init(_ wrappedValue: Value) {
        self.getValue = {
            wrappedValue
        }
    }

    init(getValue: @escaping () -> Value) {
        self.getValue = getValue
    }

    /// Creates a binding to a writable property of the current observable object.
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
    ///   interact with this view. Passing `false` preserves the inherited
    ///   setting; it doesn't override a disabled ancestor.
    /// - Returns: A view whose descendants register interaction only while the
    ///   inherited environment and this modifier are both enabled.
    nonisolated func disabled(_ disabled: Bool) -> some View {
        TransformedEnvironmentView(
            content: self,
            keyPath: \.isEnabled,
            transform: {
                $0 = $0 && !disabled
            }
        )
    }

    /// Overrides an environment value for this view's descendant hierarchy.
    ///
    /// A closer nested override for the same key path takes precedence. The
    /// value is scoped to view resolution and registered callbacks from this
    /// subtree; it doesn't mutate an ancestor's environment value.
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

    /// Installs an observable object for this view's descendant hierarchy.
    ///
    /// Objects are keyed by exact concrete type. A closer modifier for the same
    /// type takes precedence, and the modified hierarchy retains the object
    /// reference while the view value is retained.
    ///
    /// - Parameter object: The observable object to expose to descendant views.
    /// - Returns: A view with the observable object in its environment.
    func environment<Value>(
        _ object: Value
    ) -> some View where Value: AnyObject & Observable {
        TypedEnvironmentObjectView(content: self, object: object)
    }

    /// Transforms an inherited environment value for this view's descendants.
    ///
    /// SwiftTUI invokes `transform` while resolving the subtree, potentially
    /// more than once across measurement and rendering. Use it only to mutate
    /// the supplied value; don't rely on the closure for unrelated side
    /// effects.
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

    /// Handles a termination request delivered to this rendered view hierarchy.
    ///
    /// The action is registered with the currently rendered view hierarchy and
    /// runs with the runtime environment and state path captured during
    /// rendering. An `@Environment` wrapper reused across rendered identities
    /// still exposes that wrapper instance's most recent materialization.
    /// The runtime retains only one termination handler: a later registration
    /// in render order replaces an earlier one, so multiple `onTerminate`
    /// modifiers don't compose.
    ///
    /// The handler doesn't terminate the app automatically. Call the
    /// ``EnvironmentValues/terminate`` action to exit, or update state without
    /// calling it to present a confirmation flow.
    ///
    /// - Parameter action: The action to run for a termination request.
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
    /// The callback receives the URL unchanged. SwiftTUI restores the runtime
    /// environment and state path captured during rendering, but a reused
    /// `@Environment` wrapper still exposes its most recent materialization.
    /// Incoming dispatch invokes every rendered `onOpenURL` registration; the
    /// callback has no result with which to stop later handlers. This modifier
    /// doesn't replace ``EnvironmentValues/openURL`` and therefore doesn't
    /// control activation of attributed-text links.
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
