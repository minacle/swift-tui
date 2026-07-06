import Foundation
public import Observation

/// A two-way connection to a value owned by a source of truth.
///
/// `Binding` lets controls and child views read and write state that is stored
/// elsewhere. The getter and setter are evaluated when `wrappedValue` is read or
/// assigned.
@dynamicMemberLookup
@propertyWrapper
public struct Binding<Value> {

    private let getValue: () -> Value

    private let setValue: (Value) -> Void

    /// The current value exposed through this binding.
    public var wrappedValue: Value {
        get {
            getValue()
        }
        nonmutating set {
            setValue(newValue)
        }
    }

    /// The projected binding value.
    public var projectedValue: Binding<Value> {
        self
    }

    /// Creates a binding from explicit getter and setter closures.
    ///
    /// - Parameters:
    ///   - get: A closure that returns the current value.
    ///   - set: A closure that stores a new value.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getValue = get
        self.setValue = set
    }

    /// Creates a binding from an existing projected binding value.
    ///
    /// - Parameter projectedValue: The binding to use.
    public init(projectedValue: Binding<Value>) {
        self = projectedValue
    }

    /// Creates a binding that always reads the same value and ignores writes.
    ///
    /// - Parameter value: The value returned by the binding.
    /// - Returns: A read-only constant binding.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(
            get: { value },
            set: { _ in }
        )
    }

    /// Creates a binding to a writable property of the bound value.
    ///
    /// - Parameter keyPath: A writable key path into `Value`.
    /// - Returns: A binding that reads and writes the selected property.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        Binding<Subject>(
            get: {
                wrappedValue[keyPath: keyPath]
            },
            set: { newValue in
                var value = wrappedValue
                value[keyPath: keyPath] = newValue
                wrappedValue = value
            }
        )
    }
}

/// A property wrapper type that can read and write a value managed by SwiftTUI.
///
/// Use `@State` for local mutable view state. SwiftTUI keeps the stored value
/// alive across render passes at the view's identity path and invalidates the
/// terminal output when the value changes.
@propertyWrapper
public struct State<Value> {

    private let storage: StateStorage<Value>

    /// The current state value.
    public var wrappedValue: Value {
        get {
            cell.value
        }
        nonmutating set {
            cell.value = newValue
        }
    }

    /// A binding to this state value.
    public var projectedValue: Binding<Value> {
        let cell = cell
        return Binding(
            get: {
                cell.value
            },
            set: { newValue in
                cell.value = newValue
            }
        )
    }

    /// Creates state with an initial value.
    ///
    /// - Parameter value: The value used the first time SwiftTUI materializes
    ///   this state location.
    public init(wrappedValue value: @autoclosure @escaping () -> Value) {
        self.storage = StateStorage(createInitialValue: value)
    }

    /// Creates state with an initial value.
    ///
    /// - Parameter value: The value used the first time SwiftTUI materializes
    ///   this state location.
    public init(initialValue value: @autoclosure @escaping () -> Value) {
        self.init(wrappedValue: value())
    }

    private var cell: StateCell<Value> {
        guard let context = StateRenderContext.current else {
            return storage.fallback
        }

        return context.cell(for: storage)
    }
}

public extension State where Value: ExpressibleByNilLiteral {

    /// Creates optional state initialized to `nil`.
    init() {
        self.init(wrappedValue: nil)
    }
}

protocol DynamicStateProperty {

    @MainActor
    func materialize()
}

extension State: DynamicStateProperty {

    func materialize() {
        _ = cell
    }
}

/// A property wrapper type that creates bindings to properties of an observable object.
///
/// Use `@Bindable` around an `Observable` reference to form bindings to its
/// writable properties with dynamic-member syntax.
@dynamicMemberLookup
@propertyWrapper
public struct Bindable<Value: Observable> {

    /// The observable object whose properties can be bound.
    public var wrappedValue: Value

    /// The projected bindable value.
    public var projectedValue: Bindable<Value> {
        self
    }

    /// Creates a bindable wrapper around an observable object.
    ///
    /// - Parameter wrappedValue: The observable object to expose.
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// Creates a bindable wrapper around an observable object.
    ///
    /// - Parameter wrappedValue: The observable object to expose.
    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// Creates a binding to a writable property of the observable object.
    ///
    /// - Parameter keyPath: A reference-writable key path into the object.
    /// - Returns: A binding that reads and writes the selected property.
    public subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
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

/// A property wrapper type that can read and write the current focus location.
///
/// Use `@FocusState` with `Bool` or optional hashable values, then attach the
/// projected binding with `focused(...)` modifiers. SwiftTUI updates focus state
/// when focusable regions are rendered and when user input changes focus.
@propertyWrapper
public struct FocusState<Value: Hashable> {

    private let storage: FocusStateStorage<Value>

    /// The current focus value.
    public var wrappedValue: Value {
        get {
            cell.value
        }
        nonmutating set {
            cell.setValue(newValue)
        }
    }

    /// A binding that can be attached to focusable views.
    public var projectedValue: Binding {
        Binding(cell: cell)
    }

    /// Creates focus state with the default value for `Bool` or optional values.
    ///
    /// - Important: `FocusState` supports only `Bool` and optional hashable
    ///   value types.
    public init() {
        guard let value = FocusInitialValue<Value>.value else {
            fatalError("FocusState only supports Bool and Optional values.")
        }

        self.storage = FocusStateStorage(initialValue: value)
    }

    /// Creates focus state with an explicit initial value.
    ///
    /// - Parameter value: The initial focus value.
    /// - Important: `FocusState` supports only `Bool` and optional hashable
    ///   value types.
    public init(wrappedValue value: Value) {
        guard FocusInitialValue<Value>.value != nil else {
            fatalError("FocusState only supports Bool and Optional values.")
        }

        self.storage = FocusStateStorage(initialValue: value)
    }

    private var cell: FocusCell<Value> {
        guard let context = StateRenderContext.current else {
            return storage.fallback
        }

        return context.focusCell(for: storage)
    }
}

extension FocusState: DynamicStateProperty {

    func materialize() {
        _ = cell
    }
}

public extension FocusState {

    /// A property wrapper type that can read and write a focus state value.
    @propertyWrapper
    struct Binding {

        fileprivate let cell: FocusCell<Value>

        /// The current focus value.
        public var wrappedValue: Value {
            get {
                cell.value
            }
            nonmutating set {
                cell.setValue(newValue)
            }
        }

        /// The projected focus binding value.
        public var projectedValue: Binding {
            self
        }

        fileprivate init(cell: FocusCell<Value>) {
            self.cell = cell
        }
    }
}

final class StateRuntime {

    private var cells: [StateKey: Any] = [:]

    private var renderKeysByStorageID: [ObjectIdentifier: StateKey] = [:]

    private var actionKeysByStorageID: [ObjectIdentifier: StateKey] = [:]

    private let focus = FocusRuntime()

    private let input = InputRuntime()

    private let lifecycle = LifecycleRuntime()

    private let tasks = ViewTaskRuntime()

    private let change = ChangeRuntime()

    let navigation = NavigationRuntime()

    private var textFieldStates: [[Int]: TextFieldState] = [:]

    private var textEditorStates: [[Int]: TextEditorState] = [:]

    private var forEachIdentityStates: [ForEachIdentityKey: ForEachIdentityState] = [:]

    private var explicitIDStates: [ExplicitIDIdentityKey: ExplicitIDIdentityState] = [:]

    private var scrollViewStates: [[Int]: ScrollViewState] = [:]

    private var scrollViewRenderOrder: [[Int]] = []

    private var terminationHandler: TerminationHandler?

    private var invalidated = false

    private var isObservingRender = false

    private var focusGeneration = 0

    private var suppressRenderRegistrations = false

    private var suppressInteractiveRenderRegistrations = false

    private var pendingRemovedStateSubtrees: [[Int]] = []

    var isSuppressingRenderRegistrations: Bool {
        suppressRenderRegistrations
    }

    var isSuppressingInteractiveRenderRegistrations: Bool {
        suppressRenderRegistrations || suppressInteractiveRenderRegistrations
    }

    func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        focus.beginRender(requests: currentFocusRequests())
        input.beginRender()
        lifecycle.beginRender()
        tasks.beginRender()
        change.beginRender()
        scrollViewRenderOrder = []
        terminationHandler = nil
        defer {
            if focus.finishRender(requests: currentFocusRequests()) {
                invalidated = true
            }
            lifecycle.finishRender(perform: performLifecycleHandler)
            change.finishRender(perform: performChangeHandler)
            tasks.finishRender(start: startTask)
            removePendingStateSubtrees()
        }

        let block = observeRender {
            ViewResolver.block(
                from: view,
                in: ViewResolver.rootProposal(for: view, proposal: proposal),
                path: [],
                runtime: self
            )
        }
        input.updateHitRegions(block?.hitRegions ?? [])
        input.updateScrollRegions(block?.scrollRegions ?? [])
        input.updateFocusRegions(block?.focusRegions ?? [])
        return block
    }

    func observeRender<Value>(_ operation: () -> Value) -> Value {
        let wasObservingRender = isObservingRender
        isObservingRender = true
        defer {
            isObservingRender = wasObservingRender
        }

        return withObservationTracking {
            operation()
        } onChange: {
            MainActor.assumeIsolated {
                self.invalidated = true
            }
        }
    }

    func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal? = nil
    ) -> RenderedElement? {
        focus.beginRender(requests: currentFocusRequests())
        input.beginRender()
        lifecycle.beginRender()
        tasks.beginRender()
        change.beginRender()
        scrollViewRenderOrder = []
        terminationHandler = nil
        defer {
            if focus.finishRender(requests: currentFocusRequests()) {
                invalidated = true
            }
            lifecycle.finishRender(perform: performLifecycleHandler)
            change.finishRender(perform: performChangeHandler)
            tasks.finishRender(start: startTask)
            removePendingStateSubtrees()
        }

        return observeRender {
            ViewResolver.element(from: view, in: proposal, path: [], runtime: self)
        }
    }

    func consumeInvalidation() -> Bool {
        defer {
            invalidated = false
        }

        return invalidated
    }

    fileprivate func cell<Value>(
        for key: StateKey,
        initialValue: @autoclosure () -> Value
    ) -> StateCell<Value> {
        if let cell = cells[key] as? StateCell<Value> {
            return cell
        }

        let cell = StateCell(value: initialValue()) {
            [weak self] in

            self?.invalidated = true
        }
        cells[key] = cell
        return cell
    }

    fileprivate func focusCell<Value: Hashable>(
        for key: StateKey,
        initialValue: @autoclosure () -> Value
    ) -> FocusCell<Value> {
        if let cell = cells[key] as? FocusCell<Value> {
            return cell
        }

        let cell = FocusCell(
            value: initialValue(),
            invalidate: {
                [weak self] in

                self?.invalidated = true
            },
            nextGeneration: {
                [weak self] in

                guard let self else {
                    return 0
                }

                focusGeneration += 1
                return focusGeneration
            }
        )
        cells[key] = cell
        return cell
    }

    fileprivate func renderedKey(
        for storageID: ObjectIdentifier,
        kind: StateKey.Kind,
        valueType: ObjectIdentifier
    ) -> StateKey? {
        guard let key = renderKeysByStorageID[storageID],
              key.kind == kind,
              key.valueType == valueType else {
            return nil
        }

        return key
    }

    fileprivate func actionKey(
        for storageID: ObjectIdentifier,
        kind: StateKey.Kind,
        valueType: ObjectIdentifier,
        path: [Int]
    ) -> StateKey {
        if let key = actionKeysByStorageID[storageID],
           key.kind == kind,
           key.valueType == valueType {
            return key
        }

        let key = StateKey(
            kind: kind,
            path: path,
            slot: -1,
            valueType: valueType,
            storageID: storageID
        )
        actionKeysByStorageID[storageID] = key
        return key
    }

    fileprivate func bindRenderKey(
        _ key: StateKey,
        to storageID: ObjectIdentifier
    ) {
        renderKeysByStorageID[storageID] = key
    }

    fileprivate func stateCell<Value>(
        forRenderKey key: StateKey,
        storageID: ObjectIdentifier,
        initialValue: @autoclosure () -> Value
    ) -> StateCell<Value> {
        guard let actionKey = actionKeysByStorageID.removeValue(forKey: storageID),
              actionKey != key,
              let actionCell = cells.removeValue(forKey: actionKey) as? StateCell<Value> else {
            return cell(for: key, initialValue: initialValue())
        }

        if let renderCell = cells[key] as? StateCell<Value> {
            renderCell.value = actionCell.value
            return renderCell
        }

        cells[key] = actionCell
        return actionCell
    }

    fileprivate func focusCell<Value: Hashable>(
        forRenderKey key: StateKey,
        storageID: ObjectIdentifier,
        initialValue: @autoclosure () -> Value
    ) -> FocusCell<Value> {
        guard let actionKey = actionKeysByStorageID.removeValue(forKey: storageID),
              actionKey != key,
              let actionCell = cells.removeValue(forKey: actionKey) as? FocusCell<Value> else {
            return focusCell(for: key, initialValue: initialValue())
        }

        if let renderCell = cells[key] as? FocusCell<Value> {
            renderCell.setValue(
                actionCell.value,
                invalidates: false,
                recordsRequest: false
            )
            return renderCell
        }

        cells[key] = actionCell
        return actionCell
    }

    func registerFocusable(_ isFocusable: Bool, at path: [Int]) {
        guard !isSuppressingInteractiveRenderRegistrations else {
            return
        }

        focus.registerFocusable(
            isFocusable && EnvironmentRenderContext.current.isEnabled,
            at: path
        )
    }

    func registerFocusAttachment(_ attachment: any FocusAttachment, at path: [Int]) {
        guard !isSuppressingInteractiveRenderRegistrations else {
            return
        }

        focus.registerAttachment(attachment, at: path)
    }

    func registerKeyPressHandler(_ handler: KeyPressHandler, at path: [Int]) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringKeyPressHandler(handler),
            at: path
        )
    }

    func registerGlobalKeyPressHandler(_ handler: KeyPressHandler, at path: [Int]) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.registerGlobal(
            environmentRestoringKeyPressHandler(handler),
            at: path
        )
    }

    func registerTapGestureHandler(_ handler: TapGestureHandler, at path: [Int]) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringTapGestureHandler(handler),
            at: path
        )
    }

    func registerTerminationHandler(_ handler: TerminationHandler) {
        guard !suppressRenderRegistrations else {
            return
        }

        terminationHandler = handler
    }

    func registerLifecycleHandler(_ handler: LifecycleHandler, at path: [Int]) {
        guard !suppressRenderRegistrations else {
            return
        }

        lifecycle.register(handler, at: path)
    }

    func registerTaskHandler(_ handler: ViewTaskHandler, at path: [Int]) {
        guard !suppressRenderRegistrations else {
            return
        }

        tasks.register(handler, at: path)
    }

    func registerChangeHandler(_ handler: ChangeHandler, at path: [Int]) {
        guard !suppressRenderRegistrations else {
            return
        }

        change.register(handler, at: path)
    }

    func managedNavigationPathAccessor(at path: [Int]) -> NavigationPathAccessor {
        navigation.managedPathAccessor(at: path)
    }

    func registerNavigationStack(at path: [Int], accessor: NavigationPathAccessor) {
        navigation.registerStack(at: path, accessor: accessor)
    }

    func updateNavigationDestinationTypes(
        _ destinationTypes: Set<ObjectIdentifier>,
        at path: [Int]
    ) {
        navigation.updateDestinationTypes(destinationTypes, at: path)
    }

    func updateNavigationValues(_ values: [AnyNavigationValue], at path: [Int]) {
        let removedPaths = navigation.updateValues(values, at: path)
        for removedPath in removedPaths {
            removeStateSubtree(at: removedPath)
        }
    }

    func pushNavigationValue(_ value: AnyNavigationValue, at path: [Int]) -> Bool {
        guard navigation.pushValue(value, at: path) else {
            return false
        }

        invalidated = true
        return true
    }

    func pushDirectNavigationDestination(
        _ destination: NavigationDestination,
        at path: [Int]
    ) {
        navigation.pushDirectDestination(destination, at: path)
        invalidated = true
    }

    func topDirectNavigationDestination(at path: [Int]) -> NavigationDirectDestination? {
        navigation.topDirectDestination(at: path)
    }

    func popNavigationStack(at path: [Int]) -> Bool {
        guard let removedPaths = navigation.pop(at: path) else {
            return false
        }

        for removedPath in removedPaths {
            removeStateSubtree(at: removedPath)
        }
        invalidated = true
        return true
    }

    func scrollPoint(at path: [Int]) -> ScrollPoint? {
        scrollViewStates[path]?.point
    }

    func registerScrollView(
        at path: [Int],
        axes: Axis.Set,
        point: ScrollPoint,
        maximumPoint: ScrollPoint,
        viewportSize: GeometrySize,
        identifiedRegions: [RenderedIdentifiedRegion],
        binding: Binding<ScrollPosition>?
    ) {
        guard !isSuppressingInteractiveRenderRegistrations else {
            return
        }

        scrollViewRenderOrder.removeAll {
            $0 == path
        }
        scrollViewRenderOrder.append(path)
        scrollViewStates[path] = ScrollViewState(
            axes: axes,
            point: point,
            maximumPoint: maximumPoint,
            viewportSize: viewportSize,
            identifiedRegions: identifiedRegions,
            binding: binding
        )
    }

    func isFocused(at path: [Int]) -> Bool {
        focus.activePath == path
    }

    func textFieldState(at path: [Int], initialText: String) -> TextFieldState {
        if let cursor = textFieldStates[path] {
            return cursor
        }

        let cursor = TextFieldState(initialText: initialText) {
            [weak self] in

            self?.invalidated = true
        }
        textFieldStates[path] = cursor
        return cursor
    }

    func textEditorState(at path: [Int], initialText: String) -> TextEditorState {
        if let state = textEditorStates[path] {
            return state
        }

        let state = TextEditorState(initialText: initialText) {
            [weak self] in

            self?.invalidated = true
        }
        textEditorStates[path] = state
        return state
    }

    func forEachChildIndex(at path: [Int], id: AnyHashable) -> Int {
        let key = ForEachIdentityKey(path: path)
        var state = forEachIdentityStates[key] ?? ForEachIdentityState()

        if let index = state.indicesByID[id] {
            return index
        }

        let index = state.nextIndex
        state.indicesByID[id] = index
        state.nextIndex += 1
        forEachIdentityStates[key] = state
        return index
    }

    func finishForEachRender(at path: [Int], activeIDs: [AnyHashable]) {
        let key = ForEachIdentityKey(path: path)
        guard var state = forEachIdentityStates[key] else {
            return
        }

        let activeIDs = Set(activeIDs)
        let removedPaths = state.indicesByID.compactMap { id, index -> [Int]? in
            activeIDs.contains(id) ? nil : path + [index]
        }
        state.indicesByID = state.indicesByID.filter {
            activeIDs.contains($0.key)
        }
        forEachIdentityStates[key] = state

        pendingRemovedStateSubtrees.append(contentsOf: removedPaths)
    }

    func explicitIDChildIndex(at path: [Int], id: AnyHashable) -> Int {
        let key = ExplicitIDIdentityKey(path: path)
        var state = explicitIDStates[key] ?? ExplicitIDIdentityState()

        if let index = state.indicesByID[id] {
            return index
        }

        let index = state.nextIndex
        state.indicesByID[id] = index
        state.nextIndex += 1
        explicitIDStates[key] = state
        return index
    }

    func finishExplicitIDRender(at path: [Int], activeID: AnyHashable) {
        let key = ExplicitIDIdentityKey(path: path)
        guard var state = explicitIDStates[key] else {
            return
        }

        let removedPaths = state.indicesByID.compactMap { id, index -> [Int]? in
            id == activeID ? nil : path + [index]
        }
        state.indicesByID = state.indicesByID.filter {
            $0.key == activeID
        }
        explicitIDStates[key] = state

        pendingRemovedStateSubtrees.append(contentsOf: removedPaths)
    }

    func dispatch(_ keyPress: KeyPress) -> KeyPress.Result {
        if let activePath = focus.activePath,
           input.dispatch(keyPress, from: activePath, perform: performKeyPress) == .handled {
            return .handled
        }

        return input.dispatchGlobal(keyPress, perform: performKeyPress)
    }

    func dispatch(_ mouseEvent: MouseEvent, at date: Date = Date()) -> KeyPress.Result {
        input.dispatch(
            mouseEvent,
            at: date,
            perform: { path, operation in
                withView(at: path, perform: operation)
            },
            focus: { path in
                let result = focus.requestFocus(at: path)
                if result.changed {
                    invalidated = true
                }
                return result.handled
            },
            scroll: { path, mouseEvent in
                dispatchScroll(mouseEvent, at: path)
            }
        )
    }

    var nextTapDeadline: Date? {
        input.nextTapDeadline
    }

    func dispatchExpiredTapActions(at date: Date = Date()) -> KeyPress.Result {
        input.dispatchExpiredTapActions(at: date) { path, operation in
            withView(at: path, perform: operation)
        }
    }

    func dispatchTerminate() {
        guard let terminationHandler else {
            return
        }

        EnvironmentRenderContext.withValues(terminationHandler.environment) {
            withView(at: terminationHandler.actionPath) {
                terminationHandler.action()
            }
        }
    }

    func updateRenderedFrame(_ frame: TextFrame) {
        input.updateRootFrame(frame)
    }

    func materializeDynamicProperties(in value: Any) {
        for child in Mirror(reflecting: value).children {
            guard let property = child.value as? any DynamicStateProperty else {
                continue
            }

            property.materialize()
        }
    }

    private func performKeyPress(
        at path: [Int],
        operation: () -> KeyPress.Result
    ) -> KeyPress.Result {
        withView(at: path, perform: operation)
    }

    private func performLifecycleHandler(_ handler: LifecycleHandler) {
        EnvironmentRenderContext.withValues(handler.environment) {
            withView(at: handler.actionPath) {
                handler.action()
            }
        }
    }

    private func performChangeHandler(_ handler: ChangeHandler) {
        EnvironmentRenderContext.withValues(handler.environment) {
            withView(at: handler.actionPath) {
                handler.perform()
            }
        }
    }

    private func startTask(
        identity: LifecycleIdentity,
        handler: ViewTaskHandler
    ) -> Task<Void, Never> {
        let operation: @MainActor () async -> Void = {
            [weak self] in

            guard let self else {
                return
            }

            await EnvironmentRenderContext.withValues(handler.environment) {
                await self.withView(at: handler.actionPath) {
                    await handler.action()
                }
            }

            completeTask(identity, id: handler.id)
        }

        if let executorPreference = handler.executorPreference {
            return Task.detached(
                executorPreference: executorPreference,
                priority: handler.priority
            ) {
                await operation()
            }
        }

        return Task.detached(priority: handler.priority) {
            await operation()
        }
    }

    private func completeTask(_ identity: LifecycleIdentity, id: ViewTaskID?) {
        tasks.complete(identity, id: id)
    }

    private func environmentRestoringKeyPressHandler(
        _ handler: KeyPressHandler
    ) -> KeyPressHandler {
        let environment = EnvironmentRenderContext.current
        return KeyPressHandler(
            actionPath: handler.actionPath,
            matches: handler.matches,
            action: { keyPress in
                EnvironmentRenderContext.withValues(environment) {
                    handler.action(keyPress)
                }
            }
        )
    }

    private func environmentRestoringTapGestureHandler(
        _ handler: TapGestureHandler
    ) -> TapGestureHandler {
        let environment = EnvironmentRenderContext.current
        return TapGestureHandler(
            actionPath: handler.actionPath,
            count: handler.count,
            action: {
                EnvironmentRenderContext.withValues(environment) {
                    handler.action()
                }
            }
        )
    }

    func withView<Value>(
        at path: [Int],
        mode: StateRenderContextMode = .action,
        perform operation: () -> Value
    ) -> Value {
        let context = StateRenderContext(runtime: self, path: path, mode: mode)
        return StateRenderContext.withCurrent(context) {
            if mode == .render, !isObservingRender {
                return observeRender(operation)
            }

            return operation()
        }
    }

    func withView<Value>(
        at path: [Int],
        mode: StateRenderContextMode = .action,
        perform operation: () async -> Value
    ) async -> Value {
        let context = StateRenderContext(runtime: self, path: path, mode: mode)
        return await StateRenderContext.withCurrent(context, perform: operation)
    }

    func withoutRenderRegistrations<Value>(_ operation: () -> Value) -> Value {
        let previous = suppressRenderRegistrations
        suppressRenderRegistrations = true
        defer {
            suppressRenderRegistrations = previous
        }

        return operation()
    }

    func withoutInteractiveRenderRegistrations<Value>(_ operation: () -> Value) -> Value {
        let previous = suppressInteractiveRenderRegistrations
        suppressInteractiveRenderRegistrations = true
        defer {
            suppressInteractiveRenderRegistrations = previous
        }

        return operation()
    }

    private func removeStateSubtree(at path: [Int]) {
        let removedRenderKeys = Set(
            cells.keys.filter {
                $0.storageID == nil && $0.path.starts(with: path)
            }
        )

        for key in removedRenderKeys {
            cells.removeValue(forKey: key)
        }
        renderKeysByStorageID = renderKeysByStorageID.filter {
            !removedRenderKeys.contains($0.value)
        }
        textFieldStates = textFieldStates.filter {
            !$0.key.starts(with: path)
        }
        textEditorStates = textEditorStates.filter {
            !$0.key.starts(with: path)
        }
        forEachIdentityStates = forEachIdentityStates.filter {
            !$0.key.path.starts(with: path)
        }
        explicitIDStates = explicitIDStates.filter {
            !$0.key.path.starts(with: path)
        }
        scrollViewStates = scrollViewStates.filter {
            !$0.key.starts(with: path)
        }
        scrollViewRenderOrder.removeAll {
            $0.starts(with: path)
        }
        navigation.removeStateSubtree(at: path)
    }

    private func removePendingStateSubtrees() {
        for path in pendingRemovedStateSubtrees {
            removeStateSubtree(at: path)
        }

        pendingRemovedStateSubtrees = []
    }

    func scrollTo(
        id: AnyHashable,
        anchor: UnitPoint?,
        under readerPath: [Int]
    ) {
        for path in scrollViewRenderOrder where path.starts(with: readerPath) {
            guard var state = scrollViewStates[path],
                  let region = state.identifiedRegions.first(where: { $0.id == id }) else {
                continue
            }

            let currentPoint = state.binding?.wrappedValue.point ?? state.point
            let nextPoint = scrollPoint(
                from: currentPoint,
                toReveal: region.frame,
                anchor: anchor,
                axes: state.axes,
                viewportSize: state.viewportSize,
                maximumPoint: state.maximumPoint
            )
            guard nextPoint != currentPoint else {
                return
            }

            state.point = nextPoint
            scrollViewStates[path] = state
            state.binding?.wrappedValue = ScrollPosition(point: nextPoint)
            invalidated = true
            return
        }
    }

    private func scrollPoint(
        from currentPoint: ScrollPoint,
        toReveal target: RenderedRect,
        anchor: UnitPoint?,
        axes: Axis.Set,
        viewportSize: GeometrySize,
        maximumPoint: ScrollPoint
    ) -> ScrollPoint {
        ScrollPoint(
            x: axes.contains(.horizontal)
                ? clamped(
                    resolvedScrollOffset(
                        current: currentPoint.x,
                        targetOrigin: target.x,
                        targetLength: target.width,
                        viewportLength: viewportSize.columns,
                        anchorValue: anchor?.x
                    ),
                    upperBound: maximumPoint.x
                )
                : currentPoint.x,
            y: axes.contains(.vertical)
                ? clamped(
                    resolvedScrollOffset(
                        current: currentPoint.y,
                        targetOrigin: target.y,
                        targetLength: target.height,
                        viewportLength: viewportSize.rows,
                        anchorValue: anchor?.y
                    ),
                    upperBound: maximumPoint.y
                )
                : currentPoint.y
        )
    }

    private func resolvedScrollOffset(
        current: Int,
        targetOrigin: Int,
        targetLength: Int,
        viewportLength: Int,
        anchorValue: Double?
    ) -> Int {
        guard let anchorValue else {
            if targetOrigin < current {
                return targetOrigin
            }

            let targetEnd = targetOrigin + targetLength
            let viewportEnd = current + viewportLength
            if targetEnd > viewportEnd {
                return targetEnd - viewportLength
            }

            return current
        }

        let aligned = Double(targetOrigin)
            + Double(targetLength) * anchorValue
            - Double(viewportLength) * anchorValue
        return Int(aligned.rounded(.down))
    }

    private func dispatchScroll(
        _ mouseEvent: MouseEvent,
        at path: [Int]
    ) -> KeyPress.Result {
        guard var state = scrollViewStates[path],
              let delta = scrollDelta(for: mouseEvent, axes: state.axes) else {
            return .ignored
        }

        let currentPoint = state.binding?.wrappedValue.point ?? state.point
        let nextPoint = ScrollPoint(
            x: clamped(
                currentPoint.x + delta.x,
                upperBound: state.maximumPoint.x
            ),
            y: clamped(
                currentPoint.y + delta.y,
                upperBound: state.maximumPoint.y
            )
        )
        guard nextPoint != currentPoint else {
            return .ignored
        }

        state.point = nextPoint
        scrollViewStates[path] = state
        state.binding?.wrappedValue = ScrollPosition(point: nextPoint)
        invalidated = true
        return .handled
    }

    private func scrollDelta(
        for mouseEvent: MouseEvent,
        axes: Axis.Set
    ) -> (x: Int, y: Int)? {
        switch mouseEvent.button {
        case .wheelUp:
            if axes.contains(.horizontal)
                && (mouseEvent.modifiers.contains(.shift) || !axes.contains(.vertical)) {
                return (x: -1, y: 0)
            }
            guard axes.contains(.vertical) else {
                return nil
            }
            return (x: 0, y: -1)
        case .wheelDown:
            if axes.contains(.horizontal)
                && (mouseEvent.modifiers.contains(.shift) || !axes.contains(.vertical)) {
                return (x: 1, y: 0)
            }
            guard axes.contains(.vertical) else {
                return nil
            }
            return (x: 0, y: 1)
        case .wheelLeft:
            guard axes.contains(.horizontal) else {
                return nil
            }
            return (x: -1, y: 0)
        case .wheelRight:
            guard axes.contains(.horizontal) else {
                return nil
            }
            return (x: 1, y: 0)
        default:
            return nil
        }
    }

    private func clamped(_ value: Int, upperBound: Int) -> Int {
        min(max(value, 0), upperBound)
    }

    private func currentFocusRequests() -> [FocusRequestRecord] {
        cells.compactMap { key, cell -> FocusRequestRecord? in
            guard let source = cell as? any FocusRequestSource,
                  let request = source.currentRequest() else {
                return nil
            }

            return FocusRequestRecord(
                request: request,
                sourcePath: key.path,
                generation: source.requestGeneration
            )
        }
    }
}

private final class StateStorage<Value> {

    let createInitialValue: () -> Value

    private var fallbackCell: StateCell<Value>?

    var fallback: StateCell<Value> {
        if let fallbackCell {
            return fallbackCell
        }

        let cell = StateCell(value: createInitialValue(), invalidate: {})
        fallbackCell = cell
        return cell
    }

    var key: StateKey?

    init(createInitialValue: @escaping () -> Value) {
        self.createInitialValue = createInitialValue
    }

    #if !compiler(>=6.4)
    // Swift 6.3.3's release optimizer crashes in this synthesized deinit.
    @_optimize(none)
    deinit {}
    #endif
}

private final class FocusStateStorage<Value: Hashable> {

    let initialValue: Value

    let fallback: FocusCell<Value>

    var key: StateKey?

    init(initialValue: Value) {
        self.initialValue = initialValue
        self.fallback = FocusCell(
            value: initialValue,
            invalidate: {},
            nextGeneration: {
                0
            }
        )
    }

    #if !compiler(>=6.4)
    // Swift 6.3.3's release optimizer crashes in this synthesized deinit.
    @_optimize(none)
    deinit {}
    #endif
}

private final class StateCell<Value> {

    private let invalidate: () -> Void

    var value: Value {
        didSet {
            invalidate()
        }
    }

    init(value: Value, invalidate: @escaping () -> Void) {
        self.value = value
        self.invalidate = invalidate
    }

    #if !compiler(>=6.4)
    // Swift 6.3.3's release optimizer crashes in this synthesized deinit.
    @_optimize(none)
    deinit {}
    #endif
}

private final class FocusCell<Value: Hashable> {

    private let invalidate: () -> Void

    private let nextGeneration: () -> Int

    private(set) var value: Value

    private(set) var generation = 0

    init(
        value: Value,
        invalidate: @escaping () -> Void,
        nextGeneration: @escaping () -> Int
    ) {
        self.value = value
        self.invalidate = invalidate
        self.nextGeneration = nextGeneration
    }

    #if !compiler(>=6.4)
    // Swift 6.3.3's release optimizer crashes in this synthesized deinit.
    @_optimize(none)
    deinit {}
    #endif

    @discardableResult
    func setValue(
        _ newValue: Value,
        invalidates: Bool = true,
        recordsRequest: Bool = true
    ) -> Bool {
        guard value != newValue else {
            return false
        }

        value = newValue

        if recordsRequest {
            generation = nextGeneration()
        }

        if invalidates {
            invalidate()
        }

        return true
    }
}

private enum FocusInitialValue<Value: Hashable> {

    static var value: Value? {
        if Value.self == Bool.self {
            return false as? Value
        }

        return (Value.self as? any OptionalFocusValue.Type)?.nilValue as? Value
    }
}

private protocol OptionalFocusValue {

    static var nilValue: Any { get }
}

extension Optional: OptionalFocusValue {

    fileprivate static var nilValue: Any {
        Self.none as Any
    }
}

private struct StateKey: Hashable {

    enum Kind: Hashable {

        case state

        case focus
    }

    var kind: Kind

    var path: [Int]

    var slot: Int

    var valueType: ObjectIdentifier

    var storageID: ObjectIdentifier?
}

private struct ForEachIdentityKey: Hashable {

    var path: [Int]
}

private struct ForEachIdentityState {

    var indicesByID: [AnyHashable: Int] = [:]

    var nextIndex = 0
}

private struct ExplicitIDIdentityKey: Hashable {

    var path: [Int]
}

private struct ExplicitIDIdentityState {

    var indicesByID: [AnyHashable: Int] = [:]

    var nextIndex = 0
}

private struct ScrollViewState {

    var axes: Axis.Set

    var point: ScrollPoint

    var maximumPoint: ScrollPoint

    var viewportSize: GeometrySize

    var identifiedRegions: [RenderedIdentifiedRegion]

    var binding: Binding<ScrollPosition>?
}

struct TerminationHandler {

    var actionPath: [Int]

    var environment: EnvironmentValues

    var action: () -> Void
}

enum StateRenderContextMode {

    case render

    case action
}

private nonisolated final class StateRenderContext: @unchecked Sendable {

    @TaskLocal
    private static var taskCurrent: StateRenderContext?

    let runtime: StateRuntime

    let path: [Int]

    let mode: StateRenderContextMode

    private var nextSlot = 0

    nonisolated static var current: StateRenderContext? {
        taskCurrent
    }

    static func withCurrent<Value>(
        _ context: StateRenderContext,
        perform operation: () -> Value
    ) -> Value {
        $taskCurrent.withValue(context) {
            operation()
        }
    }

    static func withCurrent<Value>(
        _ context: StateRenderContext,
        perform operation: () async -> Value
    ) async -> Value {
        await $taskCurrent.withValue(context) {
            await operation()
        }
    }

    init(runtime: StateRuntime, path: [Int], mode: StateRenderContextMode) {
        self.runtime = runtime
        self.path = path
        self.mode = mode
    }

    @MainActor
    func cell<Value>(for storage: StateStorage<Value>) -> StateCell<Value> {
        let valueType = ObjectIdentifier(Value.self)
        let storageID = ObjectIdentifier(storage)

        if mode == .action {
            let key = actionResolvedKey(
                storageID: storageID,
                kind: .state,
                valueType: valueType
            )
            storage.key = key
            return runtime.cell(for: key, initialValue: storage.createInitialValue())
        }

        let key = renderResolvedKey(
            storedKey: storage.key,
            storageID: storageID,
            kind: .state,
            valueType: valueType
        )
        storage.key = key
        return runtime.stateCell(
            forRenderKey: key,
            storageID: storageID,
            initialValue: storage.createInitialValue()
        )
    }

    @MainActor
    func focusCell<Value: Hashable>(
        for storage: FocusStateStorage<Value>
    ) -> FocusCell<Value> {
        let valueType = ObjectIdentifier(Value.self)
        let storageID = ObjectIdentifier(storage)

        if mode == .action {
            let key = actionResolvedKey(
                storageID: storageID,
                kind: .focus,
                valueType: valueType
            )
            storage.key = key
            return runtime.focusCell(for: key, initialValue: storage.initialValue)
        }

        let key = renderResolvedKey(
            storedKey: storage.key,
            storageID: storageID,
            kind: .focus,
            valueType: valueType
        )
        storage.key = key
        return runtime.focusCell(
            forRenderKey: key,
            storageID: storageID,
            initialValue: storage.initialValue
        )
    }

    @MainActor
    private func renderResolvedKey(
        storedKey: StateKey?,
        storageID: ObjectIdentifier,
        kind: StateKey.Kind,
        valueType: ObjectIdentifier
    ) -> StateKey {
        let key: StateKey
        if let storedKey,
           storedKey.storageID == nil,
           storedKey.path == path {
            key = storedKey
            nextSlot = max(nextSlot, storedKey.slot + 1)
        }
        else {
            key = renderKey(kind: kind, valueType: valueType)
        }

        runtime.bindRenderKey(key, to: storageID)
        return key
    }

    @MainActor
    private func actionResolvedKey(
        storageID: ObjectIdentifier,
        kind: StateKey.Kind,
        valueType: ObjectIdentifier
    ) -> StateKey {
        if let renderedKey = runtime.renderedKey(
            for: storageID,
            kind: kind,
            valueType: valueType
        ) {
            return renderedKey
        }

        return runtime.actionKey(
            for: storageID,
            kind: kind,
            valueType: valueType,
            path: path
        )
    }

    @MainActor
    private func renderKey(
        kind: StateKey.Kind,
        valueType: ObjectIdentifier
    ) -> StateKey {
        let key = StateKey(
            kind: kind,
            path: path,
            slot: nextSlot,
            valueType: valueType,
            storageID: nil
        )
        nextSlot += 1
        return key
    }
}

nonisolated enum StateContext {

    static var currentPath: [Int]? {
        StateRenderContext.current?.path
    }

    @MainActor
    static func captureActionContext() -> StateActionContext? {
        StateActionContext(StateRenderContext.current)
    }
}

final class StateActionContext {

    private weak var runtime: StateRuntime?

    private let path: [Int]

    init(runtime: StateRuntime, path: [Int]) {
        self.runtime = runtime
        self.path = path
    }

    fileprivate init?(_ context: StateRenderContext?) {
        guard let context else {
            return nil
        }

        self.runtime = context.runtime
        self.path = context.path
    }

    func perform<Value>(
        mode: StateRenderContextMode = .action,
        _ operation: () -> Value
    ) -> Value {
        guard let runtime else {
            return operation()
        }

        return runtime.withView(at: path, mode: mode, perform: operation)
    }

    func scrollTo(id: AnyHashable, anchor: UnitPoint?) {
        guard StateRenderContext.current?.mode != .render else {
            preconditionFailure(
                "ScrollViewProxy may not be used during ScrollViewReader content rendering."
            )
        }

        guard let runtime else {
            return
        }

        runtime.scrollTo(id: id, anchor: anchor, under: path)
    }
}

struct FocusRequest: Equatable {

    var bindingID: ObjectIdentifier

    var value: AnyHashable
}

struct FocusRequestRecord {

    var request: FocusRequest

    var sourcePath: [Int]?

    var generation: Int
}

private protocol FocusRequestSource: AnyObject {

    var requestGeneration: Int { get }

    func currentRequest() -> FocusRequest?
}

private protocol FocusRequestValue {

    var focusRequestValue: AnyHashable? { get }
}

extension Bool: FocusRequestValue {

    var focusRequestValue: AnyHashable? {
        self ? AnyHashable(true) : nil
    }
}

extension Optional: FocusRequestValue where Wrapped: Hashable {

    var focusRequestValue: AnyHashable? {
        map {
            AnyHashable($0)
        }
    }
}

extension FocusCell: FocusRequestSource {

    var requestGeneration: Int {
        generation
    }

    func currentRequest() -> FocusRequest? {
        guard let value = (value as? any FocusRequestValue)?.focusRequestValue else {
            return nil
        }

        return FocusRequest(
            bindingID: ObjectIdentifier(self),
            value: value
        )
    }
}

protocol FocusAttachment {

    var bindingID: ObjectIdentifier { get }

    var generation: Int { get }

    func currentRequest() -> FocusRequest?

    func matches(_ request: FocusRequest) -> Bool

    func matchesValue(_ value: AnyHashable) -> Bool

    @discardableResult
    func setActive() -> Bool

    @discardableResult
    func clear() -> Bool
}

private struct BoolFocusAttachment: FocusAttachment {

    let binding: FocusState<Bool>.Binding

    var bindingID: ObjectIdentifier {
        ObjectIdentifier(binding.cell)
    }

    var generation: Int {
        binding.cell.generation
    }

    func currentRequest() -> FocusRequest? {
        guard binding.wrappedValue else {
            return nil
        }

        return FocusRequest(bindingID: bindingID, value: AnyHashable(true))
    }

    func matches(_ request: FocusRequest) -> Bool {
        request.bindingID == bindingID && request.value == AnyHashable(true)
    }

    func matchesValue(_ value: AnyHashable) -> Bool {
        value == AnyHashable(true)
    }

    func setActive() -> Bool {
        binding.cell.setValue(true, invalidates: false, recordsRequest: false)
    }

    func clear() -> Bool {
        binding.cell.setValue(false, invalidates: false, recordsRequest: false)
    }
}

private struct OptionalFocusAttachment<Value: Hashable>: FocusAttachment {

    let binding: FocusState<Value?>.Binding

    let value: Value

    var bindingID: ObjectIdentifier {
        ObjectIdentifier(binding.cell)
    }

    var generation: Int {
        binding.cell.generation
    }

    func currentRequest() -> FocusRequest? {
        guard let value = binding.wrappedValue else {
            return nil
        }

        return FocusRequest(bindingID: bindingID, value: AnyHashable(value))
    }

    func matches(_ request: FocusRequest) -> Bool {
        request.bindingID == bindingID && request.value == AnyHashable(value)
    }

    func matchesValue(_ value: AnyHashable) -> Bool {
        value == AnyHashable(self.value)
    }

    func setActive() -> Bool {
        binding.cell.setValue(value, invalidates: false, recordsRequest: false)
    }

    func clear() -> Bool {
        binding.cell.setValue(nil, invalidates: false, recordsRequest: false)
    }
}

extension FocusState.Binding where Value == Bool {

    func focusAttachment() -> any FocusAttachment {
        BoolFocusAttachment(binding: self)
    }
}

extension FocusState.Binding {

    func focusAttachment<Wrapped>(
        equals value: Wrapped
    ) -> any FocusAttachment where Value == Wrapped?, Wrapped: Hashable {
        OptionalFocusAttachment(binding: self, value: value)
    }
}

private final class FocusRuntime {

    private struct Candidate {

        var path: [Int]

        var attachments: [any FocusAttachment]
    }

    struct RequestResult {

        var handled: Bool

        var changed: Bool
    }

    private var pathsInRenderOrder: [[Int]] = []

    private var focusablePaths: Set<[Int]> = []

    private var disabledPaths: Set<[Int]> = []

    private var attachmentsByPath: [[Int]: [any FocusAttachment]] = [:]

    private var allAttachments: [any FocusAttachment] = []

    private var candidates: [Candidate] = []

    private var requestsForCurrentRender: [FocusRequestRecord] = []

    private var updatedActivePathDuringRender = false

    private(set) var activePath: [Int]?

    func beginRender(requests: [FocusRequestRecord]) {
        pathsInRenderOrder = []
        focusablePaths = []
        disabledPaths = []
        attachmentsByPath = [:]
        allAttachments = []
        updatedActivePathDuringRender = false
        requestsForCurrentRender = requests.sorted {
            $0.generation > $1.generation
        }
    }

    func registerFocusable(_ isFocusable: Bool, at path: [Int]) {
        registerPath(path)

        if isFocusable {
            focusablePaths.insert(path)
            updateActivePathDuringRender(at: path)
        }
        else {
            focusablePaths.remove(path)
            disabledPaths.insert(path)
        }
    }

    func registerAttachment(_ attachment: any FocusAttachment, at path: [Int]) {
        registerPath(path)
        attachmentsByPath[path, default: []].append(attachment)
        allAttachments.append(attachment)
        updateActivePathDuringRender(at: path)
    }

    func finishRender(requests extraRequests: [FocusRequestRecord]) -> Bool {
        candidates = pathsInRenderOrder.compactMap { path -> Candidate? in
            guard focusablePaths.contains(path),
                  !disabledPaths.contains(path) else {
                return nil
            }

            return Candidate(path: path, attachments: attachmentsByPath[path] ?? [])
        }

        let previousActivePath = activePath
        let activeCandidate = activeCandidate(
            from: candidates,
            extraRequests: extraRequests
        )
        activePath = activeCandidate?.path
        let attachmentsChanged = syncAttachments(for: activeCandidate)
        return activePath != previousActivePath || attachmentsChanged
    }

    private func activeCandidate(
        from candidates: [Candidate],
        extraRequests: [FocusRequestRecord]
    ) -> Candidate? {
        let renderedRequests = currentRenderedRequests()
        let requests = (renderedRequests + extraRequests).sorted {
            $0.generation > $1.generation
        }

        for request in requests {
            if let candidate = candidate(matching: request, in: candidates) {
                return candidate
            }
        }

        guard renderedRequests.isEmpty else {
            return nil
        }

        if updatedActivePathDuringRender,
           let activePath,
           let candidate = candidates.first(where: { $0.path == activePath }) {
            return candidate
        }

        guard let activePath,
              let candidate = candidates.first(where: { $0.path == activePath }),
              candidate.attachments.isEmpty else {
            return nil
        }

        return candidate
    }

    func requestFocus(at path: [Int]) -> RequestResult {
        guard let candidate = candidates.first(where: { $0.path == path }) else {
            return RequestResult(handled: false, changed: false)
        }

        let previousActivePath = activePath
        activePath = candidate.path
        let attachmentsChanged = syncAttachments(for: candidate)
        return RequestResult(
            handled: true,
            changed: activePath != previousActivePath || attachmentsChanged
        )
    }

    private func currentRenderedRequests() -> [FocusRequestRecord] {
        allAttachments
            .compactMap { attachment -> FocusRequestRecord? in
                attachment.currentRequest().map {
                    FocusRequestRecord(
                        request: $0,
                        sourcePath: nil,
                        generation: attachment.generation
                    )
                }
            }
    }

    private func candidate(
        matching record: FocusRequestRecord,
        in candidates: [Candidate]
    ) -> Candidate? {
        if let candidate = candidates.first(where: { candidate in
            candidate.attachments.contains {
                $0.matches(record.request)
            }
        }) {
            return candidate
        }

        guard let sourcePath = record.sourcePath else {
            return nil
        }

        return candidates.first { candidate in
            candidate.path.starts(with: sourcePath)
                && candidate.attachments.contains {
                    $0.matchesValue(record.request.value)
                }
        }
    }

    private func updateActivePathDuringRender(at path: [Int]) {
        guard focusablePaths.contains(path),
              !disabledPaths.contains(path),
              let attachments = attachmentsByPath[path] else {
            return
        }

        for request in requestsForCurrentRender
            where attachments.contains(where: { attachment in
                attachment.matches(request.request)
                    || (request.sourcePath.map { path.starts(with: $0) } == true
                        && attachment.matchesValue(request.request.value))
            }) {
            activePath = path
            updatedActivePathDuringRender = true
            return
        }
    }

    private func syncAttachments(for activeCandidate: Candidate?) -> Bool {
        var changed = false
        var activeBindingIDs = Set<ObjectIdentifier>()
        if let activeCandidate {
            for attachment in activeCandidate.attachments
                where !activeBindingIDs.contains(attachment.bindingID) {
                activeBindingIDs.insert(attachment.bindingID)
                changed = attachment.setActive() || changed
            }
        }

        var clearedBindingIDs = Set<ObjectIdentifier>()
        for attachment in allAttachments
            where !activeBindingIDs.contains(attachment.bindingID)
                && !clearedBindingIDs.contains(attachment.bindingID) {
            clearedBindingIDs.insert(attachment.bindingID)
            changed = attachment.clear() || changed
        }

        return changed
    }

    private func registerPath(_ path: [Int]) {
        guard !pathsInRenderOrder.contains(path) else {
            return
        }

        pathsInRenderOrder.append(path)
    }
}
