/// A top-level description of terminal content.
///
/// Scenes are the root containers that an ``App`` returns from its `body`.
/// SwiftTUI currently renders a single root terminal scene.
@MainActor
@preconcurrency
public protocol Scene {}

/// A marker protocol for scene-builder results created from limited-availability branches.
public protocol _LimitedAvailabilitySceneMarker {}

/// The single terminal window used by a SwiftTUI app.
///
/// A `WindowGroup` supplies the root view hierarchy for the terminal session.
public nonisolated struct WindowGroup<Content: View>: Scene {

    let root: Content

    /// Creates a terminal window group with the given root view content.
    ///
    /// - Parameter content: A view builder that produces the root terminal view.
    @MainActor
    public init(@ViewBuilder content: () -> Content) {
        self.root = content()
    }
}

/// A scene builder result that marks content from an availability-limited branch.
///
/// SwiftTUI uses this type internally as the public result of
/// ``SceneBuilder/buildLimitedAvailability(_:)``.
public nonisolated struct LimitedAvailabilityScene<Content: Scene>: Scene, _LimitedAvailabilitySceneMarker {

    let scene: Content

    /// Creates a limited-availability scene wrapper.
    ///
    /// - Parameter scene: The scene produced by an availability-limited branch.
    public init(_ scene: Content) {
        self.scene = scene
    }
}

/// A scene builder result that includes availability-limited content when available.
///
/// SwiftTUI uses this type for optional scene-builder branches that contain
/// limited-availability scene content.
public nonisolated struct OptionalScene<Content>: Scene where Content: Scene & _LimitedAvailabilitySceneMarker {

    let scene: Content?

    /// Creates an optional scene wrapper.
    ///
    /// - Parameter scene: The scene to render, or `nil` to render no scene.
    public init(_ scene: Content?) {
        self.scene = scene
    }
}

/// A result builder for app scenes.
@resultBuilder
public enum SceneBuilder {

    /// Returns the single scene in a scene-builder block.
    ///
    /// - Parameter content: The scene expression in the block.
    /// - Returns: The scene to use as the app's scene body.
    public static func buildBlock<Content: Scene>(_ content: Content) -> Content {
        content
    }

    /// Returns a scene expression unchanged.
    ///
    /// - Parameter content: The scene expression.
    /// - Returns: The same scene expression.
    public static func buildExpression<Content: Scene>(_ content: Content) -> Content {
        content
    }

    /// Wraps a scene produced by an availability-limited branch.
    ///
    /// - Parameter scene: The scene from the limited-availability branch.
    /// - Returns: A public wrapper used by optional scene-builder support.
    public static func buildLimitedAvailability<Content: Scene>(
        _ scene: Content
    ) -> LimitedAvailabilityScene<Content> {
        LimitedAvailabilityScene(scene)
    }

    /// Builds an optional limited-availability scene.
    ///
    /// - Parameter scene: The optional scene branch result.
    /// - Returns: An optional scene wrapper.
    public static func buildOptional<Content>(
        _ scene: Content?
    ) -> OptionalScene<Content> where Content: Scene & _LimitedAvailabilitySceneMarker {
        OptionalScene(scene)
    }
}
