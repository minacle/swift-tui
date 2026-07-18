/// A parent container's proposed terminal-cell dimensions for a child.
///
/// A `nil` dimension is unspecified and asks the child for its intrinsic size
/// on that axis. A concrete value is a layout proposal rather than permission
/// to allocate an unbounded render buffer.
nonisolated struct RenderProposal: Equatable, Hashable, Sendable {

    var columns: Int?

    var rows: Int?

    init(columns: Int? = nil, rows: Int? = nil) {
        self.columns = columns
        self.rows = rows
    }

    init(_ viewport: TerminalViewportSize) {
        self.init(columns: viewport.columns, rows: viewport.rows)
    }
}

/// A resolved child contribution consumed by container layout.
nonisolated enum RenderedElement: Equatable, Sendable {

    case block(RenderedBlock)

    case spacer(minLength: Int)
}

/// Internal layout behavior propagated from a view to its parent container.
nonisolated struct LayoutTraits: Sendable {

    var flexibleAxes: Axis.Set = []

    /// Axes that should keep a finite parent bound during flexible measurement.
    ///
    /// Built-in stacks normally ask flexible children for an unbounded natural
    /// size before distributing their remainder. A child opts into this set
    /// when that probe would destroy bounded behavior, such as viewport-driven
    /// lazy materialization.
    var preferredFiniteMeasurementAxes: Axis.Set = []

    var fillsStackMinorAxis = false

    var maximumColumns: Int? = nil

    var maximumRows: Int? = nil

    var priority: Double = 0

    var zIndex: Double = 0

    var gridCellColumns = 1

    var gridCellAnchor: UnitPoint?

    var gridCellUnsizedAxes: Axis.Set = []

    var gridColumnAlignment: HorizontalAlignment?

    private var layoutValues = LayoutValueStorage()

    private var containerValueStorage = ContainerValueStorage()

    init(
        flexibleAxes: Axis.Set = [],
        fillsStackMinorAxis: Bool = false,
        priority: Double = 0,
        zIndex: Double = 0
    ) {
        self.flexibleAxes = flexibleAxes
        self.fillsStackMinorAxis = fillsStackMinorAxis
        self.priority = priority
        self.zIndex = zIndex
    }

    func removingFlexibleAxes(_ axes: Axis.Set) -> LayoutTraits {
        var traits = self
        traits.flexibleAxes.subtract(axes)
        return traits
    }

    func settingMaximumSize(columns: Int?, rows: Int?) -> LayoutTraits {
        var traits = self
        if let columns {
            traits.maximumColumns = traits.maximumColumns.map { min($0, columns) } ?? columns
        }
        if let rows {
            traits.maximumRows = traits.maximumRows.map { min($0, rows) } ?? rows
        }
        return traits
    }

    func settingPriority(_ value: Double) -> LayoutTraits {
        var traits = self
        traits.priority = value
        return traits
    }

    func settingZIndex(_ value: Double) -> LayoutTraits {
        var traits = self
        traits.zIndex = value
        return traits
    }

    func settingGridCellColumns(_ count: Int) -> LayoutTraits {
        var traits = self
        traits.gridCellColumns = max(count, 1)
        return traits
    }

    func settingGridCellAnchor(_ anchor: UnitPoint) -> LayoutTraits {
        var traits = self
        traits.gridCellAnchor = anchor
        return traits
    }

    func settingGridCellUnsizedAxes(_ axes: Axis.Set) -> LayoutTraits {
        var traits = self
        traits.gridCellUnsizedAxes = axes
        return traits
    }

    func settingGridColumnAlignment(_ alignment: HorizontalAlignment) -> LayoutTraits {
        var traits = self
        traits.gridColumnAlignment = alignment
        return traits
    }

    func settingLayoutValue<K: LayoutValueKey>(
        key: K.Type,
        value: K.Value
    ) -> LayoutTraits {
        var traits = self
        traits.layoutValues.set(value, for: key)
        return traits
    }

    func layoutValue<K: LayoutValueKey>(for key: K.Type) -> K.Value {
        layoutValues.value(for: key)
    }

    var containerValues: ContainerValues {
        ContainerValues(storage: containerValueStorage)
    }

    func settingContainerValue<Value>(
        _ keyPath: WritableKeyPath<ContainerValues, Value>,
        value: Value
    ) -> LayoutTraits {
        var traits = self
        var values = traits.containerValues
        values[keyPath: keyPath] = value
        traits.containerValueStorage = values.storage
        return traits
    }

    func settingTag<Value: Hashable>(
        _ tag: Value,
        includeOptional: Bool
    ) -> LayoutTraits {
        var traits = self
        traits.containerValueStorage.setTag(
            tag,
            includeOptional: includeOptional
        )
        return traits
    }
}

private nonisolated struct LayoutValueStorage: @unchecked Sendable {

    private var values: [ObjectIdentifier: Any] = [:]

    func value<K: LayoutValueKey>(for key: K.Type) -> K.Value {
        values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue
    }

    mutating func set<K: LayoutValueKey>(_ value: K.Value, for key: K.Type) {
        values[ObjectIdentifier(key)] = value
    }
}

nonisolated struct ContainerValueStorage: @unchecked Sendable {

    private var values: [ObjectIdentifier: StoredContainerValue] = [:]

    private var tags: [ObjectIdentifier: StoredContainerValue] = [:]

    func value<Key: ContainerValueKey>(for key: Key.Type) -> Key.Value {
        guard let stored = values[ObjectIdentifier(key)],
              let value = stored.value as? Key.Value else {
            return Key.defaultValue
        }
        return value
    }

    mutating func set<Key: ContainerValueKey>(
        _ value: Key.Value,
        for key: Key.Type
    ) {
        values[ObjectIdentifier(key)] = StoredContainerValue(value)
    }

    func tag<Value: Hashable>(for type: Value.Type) -> Value? {
        guard let stored = tags[ObjectIdentifier(type)] else {
            return nil
        }
        return stored.value as? Value
    }

    func hasTag<Value: Hashable>(_ tag: Value) -> Bool {
        self.tag(for: Value.self).map { $0 == tag } ?? false
    }

    mutating func setTag<Value: Hashable>(
        _ tag: Value,
        includeOptional: Bool
    ) {
        setTag(tag, for: Value.self)
        if includeOptional {
            let optionalTag: Value? = tag
            setTag(optionalTag, for: Optional<Value>.self)
        }
    }

    private mutating func setTag<Value: Hashable>(
        _ tag: Value,
        for type: Value.Type
    ) {
        tags[ObjectIdentifier(type)] = StoredContainerValue(tag)
    }
}

private nonisolated struct StoredContainerValue {

    let value: Any

    init<Value>(_ value: Value) {
        self.value = value
    }
}

protocol LayoutTraitRenderable {

    var layoutTraits: LayoutTraits { get }
}

/// A lazily rendered child passed from view resolution into container layout.
///
/// The render closure may be invoked for measurement and again for placement.
/// Callers pass `true` while probing a flexible child so registrations and
/// observable UI mutations can be suppressed during the measurement render.
nonisolated struct StackChild {

    var traits: LayoutTraits

    var isSpacer: Bool = false

    var isEmptyView: Bool = false

    var suppressesVerticalFlexInParentStack: Bool = false

    var render: (RenderProposal?, Bool) -> RenderedElement?
}

/// Identifies renders performed only to measure layout.
///
/// Code that publishes selection, scrolling, focus, or other observable state
/// must remain side-effect free while this context is active.
enum LayoutMeasurementContext {

    @TaskLocal
    private static var taskIsMeasuring = false

    @TaskLocal
    private static var taskRenderPass: LayoutMeasurementRenderPass?

    static var isMeasuring: Bool {
        taskIsMeasuring
    }

    static func withMeasurement<Value>(_ operation: () -> Value) -> Value {
        $taskIsMeasuring.withValue(true) {
            return operation()
        }
    }

    /// Reuses the current pass-local measurement cache or creates one for a
    /// top-level render resolution.
    static func withRenderPass<Value>(_ operation: () -> Value) -> Value {
        guard taskRenderPass == nil else {
            return operation()
        }

        return $taskRenderPass.withValue(
            LayoutMeasurementRenderPass(),
            operation: operation
        )
    }

    /// Reuses an element rendered for measurement with the same view identity,
    /// proposal, alignment query, and stack axis in the current render pass.
    static func cachedElement(
        type: Any.Type,
        path: [Int],
        proposal: RenderProposal?,
        alignmentKeys: Set<AlignmentKey>,
        stackAxis: Axis?,
        render: () -> RenderedElement?
    ) -> RenderedElement? {
        guard isMeasuring, let taskRenderPass else {
            return render()
        }

        return taskRenderPass.element(
            type: type,
            path: path,
            proposal: proposal,
            alignmentKeys: alignmentKeys,
            stackAxis: stackAxis,
            render: render
        )
    }
}

/// Stores side-effect-free measurement renders for one synchronous resolution
/// tree so nested layouts do not repeatedly evaluate the same view proposal.
/// The task-local value is `Sendable` only to cross the task-local API; render
/// resolution accesses its mutable storage synchronously from the owning task.
private nonisolated final class LayoutMeasurementRenderPass: @unchecked Sendable {

    private enum StackAxisKey: Hashable {

        case none

        case horizontal

        case vertical

        init(_ axis: Axis?) {
            self = switch axis {
            case .horizontal:
                .horizontal
            case .vertical:
                .vertical
            case nil:
                .none
            }
        }
    }

    private struct Key: Hashable {

        var type: ObjectIdentifier

        var path: [Int]

        var proposal: RenderProposal?

        var alignmentKeys: Set<AlignmentKey>

        var stackAxis: StackAxisKey
    }

    private struct Resolution {

        var element: RenderedElement?
    }

    private var resolutions: [Key: Resolution] = [:]

    func element(
        type: Any.Type,
        path: [Int],
        proposal: RenderProposal?,
        alignmentKeys: Set<AlignmentKey>,
        stackAxis: Axis?,
        render: () -> RenderedElement?
    ) -> RenderedElement? {
        let key = Key(
            type: ObjectIdentifier(type),
            path: path,
            proposal: proposal,
            alignmentKeys: alignmentKeys,
            stackAxis: StackAxisKey(stackAxis)
        )
        if let resolution = resolutions[key] {
            return resolution.element
        }

        let element = render()
        resolutions[key] = Resolution(element: element)
        return element
    }
}

/// Propagates the active stack axis while resolving layout traits.
enum StackAxisContext {

    @TaskLocal
    static var axis: Axis?

    static func withAxis<Value>(
        _ axis: Axis?,
        operation: () -> Value
    ) -> Value {
        $axis.withValue(axis, operation: operation)
    }
}

/// Tracks alignment guides requested by the current container measurement.
nonisolated enum ExplicitAlignmentQueryContext {

    @TaskLocal
    static var keys: Set<AlignmentKey> = []

    static func withKeys<Value>(
        _ additionalKeys: Set<AlignmentKey>,
        operation: () -> Value
    ) -> Value {
        $keys.withValue(keys.union(additionalKeys), operation: operation)
    }
}
