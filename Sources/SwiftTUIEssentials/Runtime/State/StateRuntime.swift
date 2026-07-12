import Foundation
import Observation
import Terminal

final class StateRuntime {

    private let now: () -> Date

    private var cells: [StateKey: Any] = [:]

    private var renderKeysByStorageID: [ObjectIdentifier: StateKey] = [:]

    private var actionKeysByStorageID: [ObjectIdentifier: StateKey] = [:]

    private let focus = FocusRuntime()

    private let input = InputRuntime()

    private let lifecycle = LifecycleRuntime()

    private let tasks = ViewTaskRuntime()

    private let change = ChangeRuntime()

    let navigation = NavigationRuntime()

    private var editableTextSingleLineStates: [[Int]: EditableTextSingleLineState] = [:]

    private var editableTextMultilineStates: [[Int]: EditableTextMultilineState] = [:]

    private var textSelectionStates: [[Int]: TextSelectionState] = [:]

    private var activeTextSelectionPath: [Int]?

    private var forEachIdentityStates: [ForEachIdentityKey: ForEachIdentityState] = [:]

    private var explicitIDStates: [ExplicitIDIdentityKey: ExplicitIDIdentityState] = [:]

    private var scrollViewStates: [[Int]: ScrollViewState] = [:]

    private var scrollViewRenderOrder: [[Int]] = []

    private var layoutCaches: [[Int]: Any] = [:]

    private var layoutMeasurementStores: [[Int]: LayoutMeasurementStore] = [:]

    private var activeLayoutPaths: Set<[Int]> = []

    private var layoutGeneration = 0

    private var terminationHandler: TerminationHandler?

    private var openURLHandlers: [OpenURLHandler] = []

    private var invalidated = false

    private var isObservingRender = false

    private var focusGeneration = 0

    private var suppressRenderRegistrations = false

    private var suppressInteractiveRenderRegistrations = false

    private var pendingRemovedStateSubtrees: [[Int]] = []

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

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
        beginLayoutRender()
        focus.beginRender(requests: currentFocusRequests())
        input.beginRender()
        lifecycle.beginRender()
        tasks.beginRender()
        change.beginRender()
        scrollViewRenderOrder = []
        terminationHandler = nil
        openURLHandlers = []
        defer {
            input.finishRender { path, operation in
                withView(at: path, perform: operation)
            }
            if focus.finishRender(requests: currentFocusRequests()) {
                invalidated = true
            }
            lifecycle.finishRender(perform: performLifecycleHandler)
            change.finishRender(perform: performChangeHandler)
            tasks.finishRender(start: startTask)
            removePendingStateSubtrees()
            finishLayoutRender()
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
        input.updateCoordinateSpaceRegions(block?.coordinateSpaceRegions ?? [])
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
        beginLayoutRender()
        focus.beginRender(requests: currentFocusRequests())
        input.beginRender()
        lifecycle.beginRender()
        tasks.beginRender()
        change.beginRender()
        scrollViewRenderOrder = []
        terminationHandler = nil
        openURLHandlers = []
        defer {
            input.finishRender { path, operation in
                withView(at: path, perform: operation)
            }
            if focus.finishRender(requests: currentFocusRequests()) {
                invalidated = true
            }
            lifecycle.finishRender(perform: performLifecycleHandler)
            change.finishRender(perform: performChangeHandler)
            tasks.finishRender(start: startTask)
            removePendingStateSubtrees()
            finishLayoutRender()
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

    func layoutMeasurementStore(at path: [Int]) -> LayoutMeasurementStore {
        if let store = layoutMeasurementStores[path] {
            return store
        }

        let store = LayoutMeasurementStore()
        layoutMeasurementStores[path] = store
        return store
    }

    func withLayoutCache<L: Layout, Value>(
        for layout: L,
        subviews: L.Subviews,
        at path: [Int],
        perform operation: (inout L.Cache) -> Value
    ) -> Value {
        activeLayoutPaths.insert(path)

        if let box = layoutCaches[path] as? LayoutCacheBox<L> {
            if box.generation != layoutGeneration {
                layout.updateCache(&box.cache, subviews: subviews)
                box.generation = layoutGeneration
            }
            return operation(&box.cache)
        }

        let box = LayoutCacheBox<L>(
            cache: layout.makeCache(subviews: subviews),
            generation: layoutGeneration
        )
        layoutCaches[path] = box
        return operation(&box.cache)
    }

    private func beginLayoutRender() {
        layoutGeneration &+= 1
        activeLayoutPaths = []
        layoutMeasurementStores = [:]
    }

    private func finishLayoutRender() {
        layoutCaches = layoutCaches.filter {
            activeLayoutPaths.contains($0.key)
        }
        layoutMeasurementStores = [:]
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

    func registerPointerPressHandler(_ handler: PointerPressHandler, at path: [Int]) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringPointerPressHandler(handler),
            at: path
        )
    }

    func registerLongPressGestureHandler(
        _ handler: LongPressGestureHandler,
        at path: [Int]
    ) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringLongPressGestureHandler(handler),
            at: path
        )
    }

    func registerHoverGestureHandler(
        _ handler: HoverGestureHandler,
        at path: [Int]
    ) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringHoverGestureHandler(handler),
            at: path
        )
    }

    func registerPointerDownPositionHandler(
        _ handler: PointerDownPositionHandler,
        at path: [Int]
    ) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringPointerDownPositionHandler(handler),
            at: path
        )
    }

    func registerPointerDragHandler(
        _ handler: PointerDragHandler,
        at path: [Int]
    ) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringPointerDragHandler(handler),
            at: path
        )
    }

    func registerLinkHandler(_ handler: LinkHandler, at path: [Int]) {
        guard !isSuppressingInteractiveRenderRegistrations,
              EnvironmentRenderContext.current.isEnabled else {
            return
        }

        input.register(
            environmentRestoringLinkHandler(handler),
            at: path
        )
    }

    func registerTerminationHandler(_ handler: TerminationHandler) {
        guard !suppressRenderRegistrations else {
            return
        }

        terminationHandler = handler
    }

    func registerOpenURLHandler(_ handler: OpenURLHandler) {
        guard !suppressRenderRegistrations else {
            return
        }

        openURLHandlers.append(handler)
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

    func navigationValueDismissScope(
        at path: [Int],
        index: Int,
        value: AnyNavigationValue
    ) -> NavigationActionScope? {
        navigation.valueDismissScope(at: path, index: index, value: value)
    }

    func updateNavigationPresentedDestination(
        _ destination: NavigationPresentedDestination?,
        at path: [Int]
    ) {
        let removedPaths = navigation.updatePresentedDestination(destination, at: path)
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

    func topPresentedNavigationDestination(at path: [Int]) -> NavigationPresentedDestination? {
        navigation.topPresentedDestination(at: path)
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

    func dismissNavigationStack(at path: [Int], scope: NavigationActionScope) -> Bool {
        guard let removedPaths = navigation.dismiss(at: path, scope: scope) else {
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
        viewportSize: Size,
        identifiedRegions: [RenderedIdentifiedRegion],
        binding: Binding<ScrollPosition>?,
        flashGeneration: Int?,
        at date: Date? = nil
    ) {
        guard !isSuppressingInteractiveRenderRegistrations else {
            return
        }

        scrollViewRenderOrder.removeAll {
            $0 == path
        }
        scrollViewRenderOrder.append(path)
        let date = date ?? now()
        let previous = scrollViewStates[path]
        let requestsFlash = previous != nil && (
            previous?.point != point
                || flashGeneration.map { $0 != previous?.flashGeneration } == true
        )
        scrollViewStates[path] = ScrollViewState(
            axes: axes,
            point: point,
            maximumPoint: maximumPoint,
            viewportSize: viewportSize,
            identifiedRegions: identifiedRegions,
            binding: binding,
            flashGeneration: flashGeneration,
            flashDeadline: requestsFlash
                ? date.addingTimeInterval(0.5)
                : previous?.flashDeadline,
            isIndicatorInteracting: previous?.isIndicatorInteracting ?? false
        )
        if requestsFlash {
            invalidated = true
        }
    }

    func scrollIndicatorIsTemporarilyVisible(
        at path: [Int],
        date: Date? = nil
    ) -> Bool {
        guard let state = scrollViewStates[path] else {
            return false
        }
        return state.isIndicatorInteracting
            || state.flashDeadline.map { $0 > (date ?? now()) } == true
    }

    func scrollIndicatorScroll(to offset: Int, axis: Axis, at path: [Int]) {
        guard scrollViewRenderOrder.contains(path),
              var state = scrollViewStates[path] else {
            return
        }
        let current = state.binding?.wrappedValue.point ?? state.point
        let next = ScrollPoint(
            x: axis == .horizontal
                ? clamped(offset, upperBound: state.maximumPoint.x)
                : current.x,
            y: axis == .vertical
                ? clamped(offset, upperBound: state.maximumPoint.y)
                : current.y
        )
        guard next != current else {
            return
        }
        state.point = next
        state.flashDeadline = now().addingTimeInterval(0.5)
        scrollViewStates[path] = state
        state.binding?.wrappedValue = ScrollPosition(point: next)
        invalidated = true
    }

    func setScrollIndicatorInteraction(_ active: Bool, at path: [Int]) {
        guard scrollViewRenderOrder.contains(path),
              var state = scrollViewStates[path],
              state.isIndicatorInteracting != active else {
            return
        }
        state.isIndicatorInteracting = active
        if !active {
            state.flashDeadline = now().addingTimeInterval(0.5)
        }
        scrollViewStates[path] = state
        invalidated = true
    }

    func isFocused(at path: [Int]) -> Bool {
        focus.activePath == path
    }

    func editableTextSingleLineState(
        at path: [Int],
        initialText: String
    ) -> EditableTextSingleLineState {
        if let state = editableTextSingleLineStates[path] {
            return state
        }

        let state = EditableTextSingleLineState(initialText: initialText) {
            [weak self] in

            self?.invalidated = true
        }
        editableTextSingleLineStates[path] = state
        return state
    }

    func editableTextMultilineState(
        at path: [Int],
        initialText: String
    ) -> EditableTextMultilineState {
        if let state = editableTextMultilineStates[path] {
            return state
        }

        let state = EditableTextMultilineState(initialText: initialText) {
            [weak self] in

            self?.invalidated = true
        }
        editableTextMultilineStates[path] = state
        return state
    }

    func textSelectionState(at path: [Int], initialOffset: Int = 0) -> TextSelectionState {
        if let state = textSelectionStates[path] {
            return state
        }

        let state = TextSelectionState(offset: initialOffset) {
            [weak self] in

            self?.invalidated = true
        }
        textSelectionStates[path] = state
        return state
    }

    func beginTextSelection(at path: [Int], offset: Int, upperBound: Int) {
        if let activeTextSelectionPath, activeTextSelectionPath != path {
            textSelectionStates[activeTextSelectionPath]?.clearSelection(upperBound: .max)
        }
        activeTextSelectionPath = path
        textSelectionState(at: path).begin(at: offset, upperBound: upperBound)
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

    func dispatch(_ pointerEvent: PointerEvent, at date: Date = Date()) -> KeyPress.Result {
        input.dispatch(
            pointerEvent,
            at: date,
            perform: { path, operation in
                withView(at: path, perform: operation)
            },
            performLink: { path, operation in
                withView(at: path, perform: operation)
            },
            focus: { path in
                let result = focus.requestFocus(at: path)
                if result.changed {
                    invalidated = true
                }
                return result.handled
            },
            scroll: { path, pointerEvent in
                dispatchScroll(pointerEvent, at: path)
            }
        )
    }

    var nextTapDeadline: Date? {
        input.nextTapDeadline
    }

    var nextLongPressDeadline: Date? {
        input.nextLongPressDeadline
    }

    var nextScrollIndicatorFlashDeadline: Date? {
        scrollViewRenderOrder.compactMap {
            guard let state = scrollViewStates[$0], !state.isIndicatorInteracting else {
                return nil
            }
            return state.flashDeadline
        }.min()
    }

    func dispatchExpiredTapActions(at date: Date = Date()) -> KeyPress.Result {
        input.dispatchExpiredTapActions(at: date) { path, operation in
            withView(at: path, perform: operation)
        }
    }

    func dispatchExpiredLongPressActions(at date: Date = Date()) -> KeyPress.Result {
        input.dispatchExpiredLongPressActions(at: date) { path, operation in
            withView(at: path, perform: operation)
        }
    }

    func dispatchExpiredScrollIndicatorFlashes(at date: Date = Date()) {
        var expired = false
        for path in scrollViewStates.keys {
            guard var state = scrollViewStates[path],
                  !state.isIndicatorInteracting,
                  state.flashDeadline.map({ $0 <= date }) == true else {
                continue
            }
            state.flashDeadline = nil
            scrollViewStates[path] = state
            expired = true
        }
        if expired {
            invalidated = true
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

    func dispatchOpenURL(_ url: URL) -> KeyPress.Result {
        var handled = false
        for handler in openURLHandlers {
            EnvironmentRenderContext.withValues(handler.environment) {
                withView(at: handler.actionPath) {
                    handler.action(url)
                    handled = true
                }
            }
        }
        return handled ? .handled : .ignored
    }

    func updateRenderedFrame(_ frame: TextFrame) {
        input.updateRootFrame(frame)
    }

    func materializeDynamicProperties(in value: Any) {
        materializeDynamicEnvironmentProperties(in: value)

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
            action: handler.action.restoringEnvironment(environment)
        )
    }

    private func environmentRestoringPointerPressHandler(
        _ handler: PointerPressHandler
    ) -> PointerPressHandler {
        let environment = EnvironmentRenderContext.current
        return PointerPressHandler(
            actionPath: handler.actionPath,
            coordinateSpace: handler.coordinateSpace,
            matches: handler.matches,
            action: { pointerPress in
                EnvironmentRenderContext.withValues(environment) {
                    handler.action(pointerPress)
                }
            }
        )
    }

    private func environmentRestoringLongPressGestureHandler(
        _ handler: LongPressGestureHandler
    ) -> LongPressGestureHandler {
        let environment = EnvironmentRenderContext.current
        return LongPressGestureHandler(
            actionPath: handler.actionPath,
            minimumDuration: handler.minimumDuration,
            maximumDistance: handler.maximumDistance,
            action: {
                EnvironmentRenderContext.withValues(environment) {
                    handler.action()
                }
            },
            onPressingChanged: handler.onPressingChanged.map { action in
                {
                    isPressing in

                    EnvironmentRenderContext.withValues(environment) {
                        action(isPressing)
                    }
                }
            }
        )
    }

    private func environmentRestoringHoverGestureHandler(
        _ handler: HoverGestureHandler
    ) -> HoverGestureHandler {
        let environment = EnvironmentRenderContext.current
        return HoverGestureHandler(
            actionPath: handler.actionPath,
            action: handler.action.restoringEnvironment(environment)
        )
    }

    private func environmentRestoringPointerDownPositionHandler(
        _ handler: PointerDownPositionHandler
    ) -> PointerDownPositionHandler {
        let environment = EnvironmentRenderContext.current
        return PointerDownPositionHandler(
            actionPath: handler.actionPath,
            requiresFocus: handler.requiresFocus,
            shouldDeferBegin: { point in
                EnvironmentRenderContext.withValues(environment) {
                    handler.shouldDeferBegin(point)
                }
            },
            began: { point in
                EnvironmentRenderContext.withValues(environment) {
                    handler.began(point)
                }
            },
            changed: { point in
                EnvironmentRenderContext.withValues(environment) {
                    handler.changed(point)
                }
            }
        )
    }

    private func environmentRestoringPointerDragHandler(
        _ handler: PointerDragHandler
    ) -> PointerDragHandler {
        let environment = EnvironmentRenderContext.current
        return PointerDragHandler(
            actionPath: handler.actionPath,
            button: handler.button,
            coordinateSpace: handler.coordinateSpace,
            action: { drag in
                EnvironmentRenderContext.withValues(environment) {
                    handler.action(drag)
                }
            }
        )
    }

    private func environmentRestoringLinkHandler(
        _ handler: LinkHandler
    ) -> LinkHandler {
        let environment = EnvironmentRenderContext.current
        return LinkHandler(
            actionPath: handler.actionPath,
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
        editableTextSingleLineStates = editableTextSingleLineStates.filter {
            !$0.key.starts(with: path)
        }
        editableTextMultilineStates = editableTextMultilineStates.filter {
            !$0.key.starts(with: path)
        }
        textSelectionStates = textSelectionStates.filter {
            !$0.key.starts(with: path)
        }
        if activeTextSelectionPath?.starts(with: path) == true {
            activeTextSelectionPath = nil
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
        layoutCaches = layoutCaches.filter {
            !$0.key.starts(with: path)
        }
        layoutMeasurementStores = layoutMeasurementStores.filter {
            !$0.key.starts(with: path)
        }
        activeLayoutPaths = activeLayoutPaths.filter {
            !$0.starts(with: path)
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
            state.flashDeadline = now().addingTimeInterval(0.5)
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
        viewportSize: Size,
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
        _ pointerEvent: PointerEvent,
        at path: [Int]
    ) -> KeyPress.Result {
        guard var state = scrollViewStates[path],
              let delta = scrollDelta(for: pointerEvent, axes: state.axes) else {
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
        state.flashDeadline = now().addingTimeInterval(0.5)
        scrollViewStates[path] = state
        state.binding?.wrappedValue = ScrollPosition(point: nextPoint)
        invalidated = true
        return .handled
    }

    private func scrollDelta(
        for pointerEvent: PointerEvent,
        axes: Axis.Set
    ) -> (x: Int, y: Int)? {
        switch pointerEvent.button {
        case .wheelUp:
            if axes.contains(.horizontal)
                && (pointerEvent.modifiers.contains(.shift) || !axes.contains(.vertical)) {
                return (x: -1, y: 0)
            }
            guard axes.contains(.vertical) else {
                return nil
            }
            return (x: 0, y: -1)
        case .wheelDown:
            if axes.contains(.horizontal)
                && (pointerEvent.modifiers.contains(.shift) || !axes.contains(.vertical)) {
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

private final class LayoutCacheBox<L: Layout> {

    var cache: L.Cache

    var generation: Int

    init(cache: L.Cache, generation: Int) {
        self.cache = cache
        self.generation = generation
    }
}

final class StateStorage<Value> {

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

    fileprivate var key: StateKey?

    init(createInitialValue: @escaping () -> Value) {
        self.createInitialValue = createInitialValue
    }

    #if !compiler(>=6.4)
    // Swift 6.3.3's release optimizer crashes in this synthesized deinit.
    @_optimize(none)
    deinit {}
    #endif
}

final class FocusStateStorage<Value: Hashable> {

    let initialValue: Value

    let fallback: FocusCell<Value>

    fileprivate var key: StateKey?

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

final class StateCell<Value> {

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

final class FocusCell<Value: Hashable> {

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

enum FocusInitialValue<Value: Hashable> {

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

extension TapGestureAction {

    fileprivate func restoringEnvironment(_ environment: EnvironmentValues) -> TapGestureAction {
        switch self {
        case .plain(let action):
            return .plain {
                EnvironmentRenderContext.withValues(environment) {
                    action()
                }
            }
        case .location(let coordinateSpace, let action):
            return .location(coordinateSpace) { location in
                EnvironmentRenderContext.withValues(environment) {
                    action(location)
                }
            }
        }
    }
}

extension HoverGestureAction {

    fileprivate func restoringEnvironment(_ environment: EnvironmentValues) -> HoverGestureAction {
        switch self {
        case .state(let action):
            return .state { isHovering in
                EnvironmentRenderContext.withValues(environment) {
                    action(isHovering)
                }
            }
        case .phase(let coordinateSpace, let action):
            return .phase(coordinateSpace) { phase in
                EnvironmentRenderContext.withValues(environment) {
                    action(phase)
                }
            }
        }
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

    var viewportSize: Size

    var identifiedRegions: [RenderedIdentifiedRegion]

    var binding: Binding<ScrollPosition>?

    var flashGeneration: Int?

    var flashDeadline: Date?

    var isIndicatorInteracting: Bool
}

struct TerminationHandler {

    var actionPath: [Int]

    var environment: EnvironmentValues

    var action: () -> Void
}

struct OpenURLHandler {

    var actionPath: [Int]

    var environment: EnvironmentValues

    var action: (URL) -> Void
}

enum StateRenderContextMode {

    case render

    case action
}

nonisolated final class StateRenderContext: @unchecked Sendable {

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
