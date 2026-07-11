import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Scene Resolution")
struct SceneResolutionTests {

    @Test
    func `a window group exposes the view produced by its content builder`() {
        let scene = WindowGroup {
            Text("Hello, SwiftTUI")
        }

        #expect(ViewResolver.text(from: scene.root) == "Hello, SwiftTUI")
    }

    @Test
    func `the scene resolver returns the root view of a window group`() {
        let scene = WindowGroup {
            Text("Hello, SwiftTUI")
        }

        let root = SceneResolver.rootScene(from: scene)

        #expect(root != nil)
        if let root {
            #expect(ViewResolver.text(from: root.root) == "Hello, SwiftTUI")
        }
    }

    @Test
    func `a limited-availability scene resolves the root view of its window group`() {
        let scene = SceneBuilder.buildLimitedAvailability(
            WindowGroup {
                Text("Limited scene")
            }
        )
        let root = SceneResolver.rootScene(from: scene)

        #expect(root != nil)
        if let root {
            #expect(ViewResolver.text(from: root.root) == "Limited scene")
        }
    }

    @Test
    func `an absent optional scene resolves no root scene`() {
        let scene: LimitedAvailabilityScene<WindowGroup<Text>>? = nil

        #expect(SceneResolver.rootScene(from: SceneBuilder.buildOptional(scene)) == nil)
    }
}
