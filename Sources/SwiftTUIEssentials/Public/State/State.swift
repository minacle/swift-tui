import Foundation
public import Observation

/// A view property that SwiftTUI materializes before evaluating a view's body.
///
/// Conforming property wrappers can bind their storage to the current rendered
/// identity. This protocol is a marker for public API composition; SwiftTUI's
/// built-in wrappers provide the runtime behavior.
public protocol DynamicProperty {}

/// A two-way connection to a value owned by a source of truth.
///
/// `Binding` lets controls and child views read and write state that is stored
/// elsewhere. The getter and setter are evaluated when `wrappedValue` is read or
/// assigned; a binding doesn't allocate storage or schedule rendering by
/// itself. Whether a write persists or invalidates a view is determined by the
/// supplied setter.
@dynamicMemberLookup
@propertyWrapper
public struct Binding<Value> {

    private let getValue: () -> Value

    private let setValue: (Value) -> Void

    /// Reads from or writes to the binding's source of truth.
    ///
    /// Every access synchronously invokes the corresponding closure.
    public var wrappedValue: Value {
        get {
            getValue()
        }
        nonmutating set {
            setValue(newValue)
        }
    }

    /// The binding itself, for passing a binding through property-wrapper
    /// projection syntax.
    public var projectedValue: Binding<Value> {
        self
    }

    /// Creates a binding from retained getter and setter closures.
    ///
    /// - Parameters:
    ///   - get: The closure invoked synchronously for each read.
    ///   - set: The closure invoked synchronously for each assignment. SwiftTUI
    ///     doesn't otherwise store the assigned value.
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

    /// Creates a binding that always reads the same captured value and ignores
    /// writes.
    ///
    /// - Parameter value: The value returned by the binding.
    /// - Returns: A binding whose setter has no effect.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(
            get: { value },
            set: { _ in }
        )
    }

    /// Creates a binding to a writable property of the current bound value.
    ///
    /// Each write reads the complete current root value, changes the selected
    /// property, and assigns that root value through this binding's setter.
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
/// terminal output after every assignment. Removing that identity discards its
/// state; recreating it evaluates the retained initial-value expression again.
/// Outside a SwiftTUI render or captured action context, the wrapper uses
/// wrapper-local fallback storage whose writes don't invalidate a renderer.
@propertyWrapper
public struct State<Value>: DynamicProperty {

    private let storage: StateStorage<Value>

    /// The value stored at this state's current rendered identity.
    ///
    /// Assigning a value requests another render even when the new value would
    /// compare equal to the old value. Outside a render or captured action
    /// context, this property instead accesses fallback storage and requests no
    /// render.
    public var wrappedValue: Value {
        get {
            cell.value
        }
        nonmutating set {
            cell.value = newValue
        }
    }

    /// A binding that reads and writes the same current state cell.
    ///
    /// Outside a render or captured action context, the binding targets this
    /// wrapper's fallback cell and doesn't invalidate a renderer.
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

    /// Creates state with a lazily evaluated initial value.
    ///
    /// - Parameter value: The value used the first time SwiftTUI materializes
    ///   a new state identity. The wrapper retains the expression for its
    ///   storage lifetime so another newly materialized identity can evaluate
    ///   it again.
    public init(wrappedValue value: @autoclosure @escaping () -> Value) {
        self.storage = StateStorage(createInitialValue: value)
    }

    /// Creates state with a lazily evaluated initial value.
    ///
    /// - Parameter value: The value used the first time SwiftTUI materializes
    ///   a new state identity. The wrapper retains the expression for its
    ///   storage lifetime so another newly materialized identity can evaluate
    ///   it again.
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

extension State where Value: ExpressibleByNilLiteral {

    /// Creates state whose initial value is `nil`.
    public init() {
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
/// writable properties with dynamic-member syntax. The wrapper retains and
/// mutates the same object; it doesn't copy the object's property values.
@dynamicMemberLookup
@propertyWrapper
public struct Bindable<Value: Observable>: DynamicProperty {

    /// The observable object reference exposed by this wrapper.
    public var wrappedValue: Value

    /// The wrapper itself, used for dynamic-member binding syntax.
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

    /// Creates a binding that reads and writes a property on the retained
    /// observable object.
    ///
    /// Observation invalidates a rendered view when that view previously read
    /// the changed property; this binding doesn't force invalidation for
    /// otherwise unobserved properties.
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
/// when focusable regions are rendered and when user input changes focus. A
/// programmatic assignment requests the matching rendered focus region;
/// `false` or `nil` clears that request. Outside a render or captured action
/// context, the wrapper uses local fallback storage and can't request focus from
/// a runtime.
@propertyWrapper
public struct FocusState<Value: Hashable>: DynamicProperty {

    private let storage: FocusStateStorage<Value>

    /// The focus value synchronized with rendered focus attachments.
    ///
    /// Assigning a different value records a focus request and invalidates the
    /// current runtime. Assigning the existing value has no effect. Outside a
    /// render or captured action context, this accesses fallback storage only.
    public var wrappedValue: Value {
        get {
            cell.value
        }
        nonmutating set {
            cell.setValue(newValue)
        }
    }

    /// A binding for attaching this state to focusable views.
    ///
    /// Use `focused(_:)` with `Bool`, or `focused(_:equals:)` with an optional
    /// hashable value.
    public var projectedValue: Binding {
        Binding(cell: cell)
    }

    /// Creates focus state with `false` for `Bool` or `nil` for an optional
    /// value.
    ///
    /// - Precondition: `Value` is `Bool` or an optional hashable type. Other
    ///   `Hashable` types trap at initialization.
    public init() {
        guard let value = FocusInitialValue<Value>.value else {
            fatalError("FocusState only supports Bool and Optional values.")
        }

        self.storage = FocusStateStorage(initialValue: value)
    }

    /// Creates focus state with an explicit initial request value.
    ///
    /// A `true` Boolean or non-`nil` optional requests its matching attachment
    /// when that attachment is rendered.
    ///
    /// - Parameter value: The initial focus value.
    /// - Precondition: `Value` is `Bool` or an optional hashable type. Other
    ///   `Hashable` types trap at initialization.
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

extension FocusState {

    /// A projected property wrapper that connects a ``FocusState`` value to a
    /// focusable view.
    @propertyWrapper
    public struct Binding {

        let cell: FocusCell<Value>

        /// The current focus value shared with the source ``FocusState``.
        ///
        /// Assigning a different focused value records a programmatic focus
        /// request and invalidates the owning rendered hierarchy. Assigning the
        /// already stored value has no effect.
        public var wrappedValue: Value {
            get {
                cell.value
            }
            nonmutating set {
                cell.setValue(newValue)
            }
        }

        /// The focus binding itself, for property-wrapper projection syntax.
        public var projectedValue: Binding {
            self
        }

        fileprivate init(cell: FocusCell<Value>) {
            self.cell = cell
        }
    }
}
