/// A top-level description of terminal content.
///
/// Scenes are the root containers that an ``App`` returns from its `body`.
/// SwiftTUI currently renders a single root terminal scene.
@MainActor
@preconcurrency
public protocol Scene {}

/// Marks a scene-builder result created from a limited-availability branch.
///
/// ``SceneBuilder`` uses this protocol to constrain its optional-branch result.
/// Application code normally receives the conformance through
/// ``LimitedAvailabilityScene`` rather than declaring a conformance directly.
public protocol _LimitedAvailabilitySceneMarker {}

/// The single terminal window used by a SwiftTUI app.
///
/// A `WindowGroup` supplies the root view hierarchy for the terminal session.
/// Despite its name, this type represents one terminal viewport; SwiftTUI does
/// not create multiple platform windows from a group.
public nonisolated struct WindowGroup<Content: View>: Scene {

    let root: Content

    /// Creates the root terminal scene from view-builder content.
    ///
    /// SwiftTUI evaluates `content` during app construction and retains the
    /// resulting view hierarchy for the terminal session.
    ///
    /// - Parameter content: A view builder that produces the root terminal
    ///   view hierarchy.
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

    /// Wraps a scene produced by an availability-limited branch.
    ///
    /// - Parameter scene: The scene produced by an availability-limited branch.
    public init(_ scene: Content) {
        self.scene = scene
    }
}

/// A scene builder result that includes availability-limited content when available.
///
/// SwiftTUI uses this type for optional scene-builder branches that contain
/// limited-availability scene content. A `nil` value resolves to no root scene,
/// so the app returns without starting a terminal session.
public nonisolated struct OptionalScene<Content>: Scene where Content: Scene & _LimitedAvailabilitySceneMarker {

    let scene: Content?

    /// Creates an optional scene wrapper.
    ///
    /// - Parameter scene: The scene to render, or `nil` to render no scene.
    public init(_ scene: Content?) {
        self.scene = scene
    }
}

/// Builds the root scene hierarchy declared by an ``App``.
///
/// The builder supports one scene expression and optional control flow created
/// by limited-availability checks. It doesn't combine multiple independent
/// window groups.
@resultBuilder
public enum SceneBuilder {

    /// Builds a scene block containing one scene expression.
    ///
    /// - Parameter content: The scene expression in the block.
    /// - Returns: The scene to use as the app's scene body.
    public static func buildBlock<Content: Scene>(_ content: Content) -> Content {
        content
    }

    /// Converts a scene expression into builder content without wrapping it.
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

    /// Builds optional content from a limited-availability scene branch.
    ///
    /// - Parameter scene: The branch result, or `nil` when the branch isn't
    ///   present.
    /// - Returns: A wrapper that resolves the scene when present and otherwise
    ///   resolves no root scene.
    public static func buildOptional<Content>(
        _ scene: Content?
    ) -> OptionalScene<Content> where Content: Scene & _LimitedAvailabilitySceneMarker {
        OptionalScene(scene)
    }
}
