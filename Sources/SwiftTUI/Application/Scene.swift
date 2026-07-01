/// A top-level description of terminal content.
@MainActor
@preconcurrency
public protocol Scene {}

public protocol _LimitedAvailabilitySceneMarker {}

protocol RootScene: Scene {

    associatedtype Root: View

    var root: Root { get }
}

protocol SceneRootResolving {

    var resolvedRootScene: (any RootScene)? { get }
}

enum SceneResolver {

    static func rootScene<Content: Scene>(from scene: Content) -> (any RootScene)? {
        if let root = scene as? any RootScene {
            return root
        }

        if let resolving = scene as? any SceneRootResolving {
            return resolving.resolvedRootScene
        }

        return nil
    }
}

/// The single terminal window used by a SwiftTUI app.
public nonisolated struct WindowGroup<Content: View>: RootScene {

    let root: Content

    @MainActor
    public init(@ViewBuilder content: () -> Content) {
        self.root = content()
    }
}

extension WindowGroup: SceneRootResolving {

    var resolvedRootScene: (any RootScene)? {
        self
    }
}

/// A scene builder result that marks content from an availability-limited branch.
public nonisolated struct LimitedAvailabilityScene<Content: Scene>: Scene, _LimitedAvailabilitySceneMarker {

    let scene: Content

    public init(_ scene: Content) {
        self.scene = scene
    }
}

extension LimitedAvailabilityScene: SceneRootResolving {

    var resolvedRootScene: (any RootScene)? {
        SceneResolver.rootScene(from: scene)
    }
}

/// A scene builder result that includes availability-limited content when available.
public nonisolated struct OptionalScene<Content>: Scene where Content: Scene & _LimitedAvailabilitySceneMarker {

    let scene: Content?

    public init(_ scene: Content?) {
        self.scene = scene
    }
}

extension OptionalScene: SceneRootResolving {

    var resolvedRootScene: (any RootScene)? {
        guard let scene else {
            return nil
        }

        return SceneResolver.rootScene(from: scene)
    }
}

/// A result builder for app scenes.
@resultBuilder
public enum SceneBuilder {

    public static func buildBlock<Content: Scene>(_ content: Content) -> Content {
        content
    }

    public static func buildExpression<Content: Scene>(_ content: Content) -> Content {
        content
    }

    public static func buildLimitedAvailability<Content: Scene>(
        _ scene: Content
    ) -> LimitedAvailabilityScene<Content> {
        LimitedAvailabilityScene(scene)
    }

    public static func buildOptional<Content>(
        _ scene: Content?
    ) -> OptionalScene<Content> where Content: Scene & _LimitedAvailabilitySceneMarker {
        OptionalScene(scene)
    }
}
