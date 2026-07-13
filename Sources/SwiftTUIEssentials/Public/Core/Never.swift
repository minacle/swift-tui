/// Supplies the uninhabited associated types and body shared by SwiftTUI's
/// declarative protocols.
extension Never {

    /// The uninhabited value produced by an uninhabited declaration.
    public typealias Value = Never

    /// The uninhabited body used to terminate declarative composition.
    public typealias Body = Never

    /// Eliminates the uninhabited receiver as the common declarative body.
    ///
    /// A `Never` value cannot be constructed, so a valid program cannot invoke
    /// this getter. The concrete member serves as the shared `body` witness for
    /// ``View``, ``InputEvent``, ``Gesture``, and ``Shortcut``.
    public var body: Never {
        switch self {}
    }
}
