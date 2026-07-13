/// Options that select which gestures remain eligible under a gesture attachment.
///
/// The mask is relative to modifier nesting. Existing modifiers and view
/// content inside the receiver count as subviews of the new attachment, while
/// modifiers applied later outside it aren't affected.
public nonisolated struct GestureMask: OptionSet, Sendable {

    /// The bit pattern backing this option set.
    public let rawValue: Int

    /// Creates a gesture mask from a bit pattern.
    ///
    /// Unknown bits are preserved but don't select additional gesture scopes.
    ///
    /// - Parameter rawValue: The bit pattern to store.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Disables the attachment and gestures nested inside its receiver.
    public static let none = GestureMask([])

    /// Enables only the gesture introduced by the current modifier.
    public static let gesture = GestureMask(rawValue: 1 << 0)

    /// Enables existing receiver gestures and descendant gestures, but not the current one.
    public static let subviews = GestureMask(rawValue: 1 << 1)

    /// Enables the current gesture and all gestures inside its receiver.
    public static let all: GestureMask = [.gesture, .subviews]
}

/// Options that select which input events remain eligible under an event attachment.
///
/// Input-event masks don't affect gestures or hover observation.
public nonisolated struct InputEventMask: OptionSet, Sendable {

    /// The bit pattern backing this option set.
    public let rawValue: Int

    /// Creates an input-event mask from a bit pattern.
    ///
    /// Unknown bits are preserved but don't select additional event scopes.
    ///
    /// - Parameter rawValue: The bit pattern to store.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Disables the attachment and input events nested inside its receiver.
    public static let none = InputEventMask([])

    /// Enables only the input event introduced by the current modifier.
    public static let inputEvent = InputEventMask(rawValue: 1 << 0)

    /// Enables existing receiver events and descendant events, but not the current one.
    public static let subviews = InputEventMask(rawValue: 1 << 1)

    /// Enables the current event and all input events inside its receiver.
    public static let all: InputEventMask = [.inputEvent, .subviews]
}

extension View {

    /// Attaches a gesture in the normal-priority recognition tier.
    ///
    /// - Parameters:
    ///   - gesture: The gesture graph to attach.
    ///   - mask: The gesture scopes eligible under this modifier.
    /// - Returns: A view with a normal-priority gesture attachment.
    public func gesture<G: Gesture>(
        _ gesture: G,
        including mask: GestureMask = .all
    ) -> some View {
        GestureAttachmentView(
            content: self,
            gesture: gesture,
            tier: .normal,
            mask: mask,
            isSimultaneous: false
        )
    }

    /// Conditionally attaches a gesture in the normal-priority tier.
    ///
    /// Disabling the attachment is equivalent to an attachment mask of
    /// ``GestureMask/subviews``: gestures already inside the receiver remain
    /// eligible.
    ///
    /// - Parameters:
    ///   - gesture: The gesture graph to attach.
    ///   - isEnabled: Whether the current attachment is eligible.
    /// - Returns: A view with a conditionally enabled gesture attachment.
    public func gesture<G: Gesture>(
        _ gesture: G,
        isEnabled: Bool
    ) -> some View {
        self.gesture(gesture, including: isEnabled ? .all : .subviews)
    }

    /// Attaches a gesture in the high-priority recognition tier.
    ///
    /// - Parameters:
    ///   - gesture: The gesture graph to attach.
    ///   - mask: The gesture scopes eligible under this modifier.
    /// - Returns: A view with a high-priority gesture attachment.
    public func highPriorityGesture<G: Gesture>(
        _ gesture: G,
        including mask: GestureMask = .all
    ) -> some View {
        GestureAttachmentView(
            content: self,
            gesture: gesture,
            tier: .high,
            mask: mask,
            isSimultaneous: false
        )
    }

    /// Conditionally attaches a gesture in the high-priority tier.
    ///
    /// - Parameters:
    ///   - gesture: The gesture graph to attach.
    ///   - isEnabled: Whether the current attachment is eligible.
    /// - Returns: A view with a conditionally enabled high-priority gesture.
    public func highPriorityGesture<G: Gesture>(
        _ gesture: G,
        isEnabled: Bool
    ) -> some View {
        highPriorityGesture(gesture, including: isEnabled ? .all : .subviews)
    }

    /// Attaches a gesture in the view-defined and simultaneous tier.
    ///
    /// This attachment shares a tier with SwiftTUI's `onTapGesture` and other
    /// view-defined recognition modifiers. It doesn't make the gesture a child
    /// of a ``SimultaneousGesture``; use `simultaneously(with:)` for explicit
    /// composition inside one gesture graph.
    ///
    /// - Parameters:
    ///   - gesture: The gesture graph to attach.
    ///   - mask: The gesture scopes eligible under this modifier.
    /// - Returns: A view with a simultaneous-tier gesture attachment.
    public func simultaneousGesture<G: Gesture>(
        _ gesture: G,
        including mask: GestureMask = .all
    ) -> some View {
        GestureAttachmentView(
            content: self,
            gesture: gesture,
            tier: .viewDefined,
            mask: mask,
            isSimultaneous: true
        )
    }

    /// Conditionally attaches a gesture in the view-defined and simultaneous tier.
    ///
    /// - Parameters:
    ///   - gesture: The gesture graph to attach.
    ///   - isEnabled: Whether the current attachment is eligible.
    /// - Returns: A view with a conditionally enabled simultaneous-tier gesture.
    public func simultaneousGesture<G: Gesture>(
        _ gesture: G,
        isEnabled: Bool
    ) -> some View {
        simultaneousGesture(gesture, including: isEnabled ? .all : .subviews)
    }

    /// Attaches an input event in the normal-priority recognition tier.
    ///
    /// - Parameters:
    ///   - event: The input-event graph to attach.
    ///   - mask: The input-event scopes eligible under this modifier.
    /// - Returns: A view with a normal-priority input-event attachment.
    public func inputEvent<E: InputEvent>(
        _ event: E,
        including mask: InputEventMask = .all
    ) -> some View {
        InputEventAttachmentView(
            content: self,
            event: event,
            tier: .normal,
            mask: mask
        )
    }

    /// Conditionally attaches an input event in the normal-priority tier.
    ///
    /// Disabling the current attachment keeps events already inside the
    /// receiver eligible.
    ///
    /// - Parameters:
    ///   - event: The input-event graph to attach.
    ///   - isEnabled: Whether the current attachment is eligible.
    /// - Returns: A view with a conditionally enabled input-event attachment.
    public func inputEvent<E: InputEvent>(
        _ event: E,
        isEnabled: Bool
    ) -> some View {
        inputEvent(event, including: isEnabled ? .all : .subviews)
    }

    /// Attaches an input event in the high-priority recognition tier.
    ///
    /// - Parameters:
    ///   - event: The input-event graph to attach.
    ///   - mask: The input-event scopes eligible under this modifier.
    /// - Returns: A view with a high-priority input-event attachment.
    public func highPriorityInputEvent<E: InputEvent>(
        _ event: E,
        including mask: InputEventMask = .all
    ) -> some View {
        InputEventAttachmentView(
            content: self,
            event: event,
            tier: .high,
            mask: mask
        )
    }

    /// Conditionally attaches an input event in the high-priority tier.
    ///
    /// - Parameters:
    ///   - event: The input-event graph to attach.
    ///   - isEnabled: Whether the current attachment is eligible.
    /// - Returns: A view with a conditionally enabled high-priority event.
    public func highPriorityInputEvent<E: InputEvent>(
        _ event: E,
        isEnabled: Bool
    ) -> some View {
        highPriorityInputEvent(event, including: isEnabled ? .all : .subviews)
    }

    /// Attaches an input event in the view-defined and simultaneous tier.
    ///
    /// Explicit simultaneous siblings inside one event graph continue to run
    /// before their aggregated handled result affects outside consumers.
    ///
    /// - Parameters:
    ///   - event: The input-event graph to attach.
    ///   - mask: The input-event scopes eligible under this modifier.
    /// - Returns: A view with a simultaneous-tier input-event attachment.
    public func simultaneousInputEvent<E: InputEvent>(
        _ event: E,
        including mask: InputEventMask = .all
    ) -> some View {
        InputEventAttachmentView(
            content: self,
            event: event,
            tier: .viewDefined,
            mask: mask
        )
    }

    /// Conditionally attaches an input event in the view-defined and simultaneous tier.
    ///
    /// - Parameters:
    ///   - event: The input-event graph to attach.
    ///   - isEnabled: Whether the current attachment is eligible.
    /// - Returns: A view with a conditionally enabled simultaneous-tier event.
    public func simultaneousInputEvent<E: InputEvent>(
        _ event: E,
        isEnabled: Bool
    ) -> some View {
        simultaneousInputEvent(event, including: isEnabled ? .all : .subviews)
    }
}
