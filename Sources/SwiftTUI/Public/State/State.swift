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

        let cell: FocusCell<Value>

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
