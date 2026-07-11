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

extension WindowGroup: RootScene {
}

extension WindowGroup: SceneRootResolving {

    var resolvedRootScene: (any RootScene)? {
        self
    }
}

extension LimitedAvailabilityScene: SceneRootResolving {

    var resolvedRootScene: (any RootScene)? {
        SceneResolver.rootScene(from: scene)
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
