/// A type-level key for a view that a descendant container can request.
///
/// Define a distinct key for each semantic attachment point. The context is
/// supplied by the consuming container when it requests the installed view.
public protocol ViewAttachmentKey {

    /// The information the consuming container passes to the attachment builder.
    associatedtype Context = Void
}

/// View factories installed for descendant containers.
///
/// Read this value with `Environment(\.viewAttachments)` and request a view
/// using its ``ViewAttachmentKey``. A missing key returns `nil`. When nested
/// modifiers install the same key, the closest modifier wins.
///
/// ```swift
/// enum AccessoryKey: ViewAttachmentKey {
///     typealias Context = String
/// }
///
/// struct AccessoryHost: View {
///     @Environment(\.viewAttachments) private var attachments
///
///     var body: some View {
///         attachments.view(for: AccessoryKey.self, context: "Ready")
///     }
/// }
///
/// AccessoryHost()
///     .viewAttachment(AccessoryKey.self) { Text($0) }
/// ```
public nonisolated struct ViewAttachments {

    private var storage: [ObjectIdentifier: Any] = [:]

    /// Creates an empty attachment collection.
    public init() {}

    /// Creates the view installed for a key using context from the consumer.
    ///
    /// The stored builder runs only when this method is called. SwiftTUI can
    /// call it repeatedly during measurement and rendering, so the builder
    /// must remain free of unrelated side effects.
    ///
    /// - Parameters:
    ///   - key: The semantic attachment point to request.
    ///   - context: Information supplied by the consuming container.
    /// - Returns: The installed type-erased view, or `nil` when no view is
    ///   installed for `key`.
    @MainActor
    public func view<Key: ViewAttachmentKey>(
        for key: Key.Type,
        context: Key.Context
    ) -> AnyView? {
        guard let entry = storage[ObjectIdentifier(key)] as? ViewAttachmentEntry<Key.Context> else {
            return nil
        }

        return entry.content(context)
    }

    /// Creates the view installed for a key that requires no context.
    ///
    /// - Parameter key: The semantic attachment point to request.
    /// - Returns: The installed type-erased view, or `nil` when no view is
    ///   installed for `key`.
    @MainActor
    public func view<Key: ViewAttachmentKey>(for key: Key.Type) -> AnyView?
    where Key.Context == Void {
        view(for: key, context: ())
    }

    mutating func set<Key: ViewAttachmentKey, Attachment: View>(
        _ key: Key.Type,
        content: @escaping @MainActor (Key.Context) -> Attachment
    ) {
        storage[ObjectIdentifier(key)] = ViewAttachmentEntry<Key.Context> {
            AnyView(content($0))
        }
    }

    func contains<Key: ViewAttachmentKey>(_ key: Key.Type) -> Bool {
        storage[ObjectIdentifier(key)] is ViewAttachmentEntry<Key.Context>
    }
}

private nonisolated struct ViewAttachmentEntry<Context> {

    let content: @MainActor (Context) -> AnyView
}

extension EnvironmentValues {

    /// The view factories installed for descendant containers.
    ///
    /// Consumers request a factory by its ``ViewAttachmentKey``. The default
    /// value is empty, and each `viewAttachment(_:content:)` modifier replaces
    /// the inherited factory only for its key.
    public internal(set) nonisolated var viewAttachments: ViewAttachments {
        get {
            self[ViewAttachmentsKey.self]
        }
        set {
            self[ViewAttachmentsKey.self] = newValue
        }
    }
}

private struct ViewAttachmentsKey: EnvironmentKey {

    nonisolated static var defaultValue: ViewAttachments {
        ViewAttachments()
    }
}

extension View {

    /// Installs a lazily created view for a descendant container.
    ///
    /// The consuming container chooses whether, when, and where to request and
    /// place the view. Applying another attachment for the same key closer to a
    /// consumer replaces this builder; builders for other keys remain intact.
    /// The builder is evaluated in the consumer's environment and can run more
    /// than once during measurement and rendering.
    ///
    /// - Parameters:
    ///   - key: The semantic attachment point to install.
    ///   - content: A builder that receives context from the consumer.
    /// - Returns: A view that exposes the attachment to its descendants.
    public func viewAttachment<Key: ViewAttachmentKey, Attachment: View>(
        _ key: Key.Type,
        @ViewBuilder content: @escaping @MainActor (Key.Context) -> Attachment
    ) -> some View {
        transformEnvironment(\.viewAttachments) {
            $0.set(key, content: content)
        }
    }

    /// Installs a lazily created view that requires no consumer context.
    ///
    /// - Parameters:
    ///   - key: The semantic attachment point to install.
    ///   - content: A builder evaluated when a descendant requests the view.
    /// - Returns: A view that exposes the attachment to its descendants.
    public func viewAttachment<Key: ViewAttachmentKey, Attachment: View>(
        _ key: Key.Type,
        @ViewBuilder content: @escaping @MainActor () -> Attachment
    ) -> some View where Key.Context == Void {
        viewAttachment(key) {
            _ in

            content()
        }
    }
}
