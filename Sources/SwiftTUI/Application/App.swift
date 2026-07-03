import Foundation

/// The entry point for a SwiftTUI application.
///
/// Declare one type that conforms to `App` and annotate it with `@main`.
/// SwiftTUI creates the app value, resolves its root scene, starts a terminal
/// session, and runs the render/input loop until termination is requested.
@MainActor
@preconcurrency
public protocol App {

    /// The scene type produced by this app.
    associatedtype Body: Scene

    /// The scene hierarchy that SwiftTUI renders into the terminal.
    @SceneBuilder
    var body: Body { get }

    /// Creates the app instance that `main()` runs.
    init()
}

public extension App {

    /// Starts the SwiftTUI terminal event loop for this app.
    ///
    /// This method is normally invoked by Swift's `@main` entry point. It
    /// configures the terminal session, repeatedly renders the root scene into
    /// the current viewport, dispatches keyboard and mouse input, and prints a
    /// startup error if the terminal session cannot be created.
    static func main() {
        do {
            try AppRunner(app: Self()).run()
        } catch {
            TerminalControl.write("SwiftTUI failed to start: \(error)\n")
        }
    }
}

struct AppRunner<Application: App> {

    var app: Application

    func run() throws {
        guard let root = SceneResolver.rootScene(from: app.body) else {
            return
        }

        let runtime = StateRuntime()
        let termination = TerminationController()

        let session = try TerminalSession()
        try session.start()
        defer {
            session.stop()
        }

        var viewportTracker = TerminalViewportTracker(
            renderedViewport: render(root, using: runtime, termination: termination)
        )

        while true {
            if viewportTracker.needsRedraw(for: TerminalControl.currentTerminalSize()) {
                viewportTracker.update(
                    renderedViewport: render(root, using: runtime, termination: termination)
                )
            }

            switch TerminalControl.readInput(timeout: inputTimeout(using: runtime)) {
            case .quit:
                runtime.dispatchTerminate()
            case .keyPress(let keyPress):
                _ = runtime.dispatch(keyPress)
            case .mouse(let mouseEvent):
                _ = runtime.dispatch(mouseEvent)
            case .none:
                break
            }

            _ = runtime.dispatchExpiredTapActions()

            if runtime.consumeInvalidation()
                || viewportTracker.needsRedraw(for: TerminalControl.currentTerminalSize()) {
                viewportTracker.update(
                    renderedViewport: render(root, using: runtime, termination: termination)
                )
            }

            if termination.isRequested {
                return
            }
        }
    }

    private func render(
        _ root: any RootScene,
        using runtime: StateRuntime,
        termination: TerminationController
    ) -> TerminalViewportSize {
        while true {
            let viewport = TerminalControl.currentTerminalSize()
            guard let block = root.renderedBlock(
                in: RenderProposal(viewport),
                using: runtime,
                termination: termination
            ) else {
                return viewport
            }

            runtime.updateRenderedFrame(TextRenderer.frame(for: block, in: viewport))
            guard !runtime.consumeInvalidation() else {
                continue
            }

            render(block, in: viewport)
            return viewport
        }
    }

    private func render(_ block: RenderedBlock, in viewport: TerminalViewportSize) {
        TerminalControl.write(TextRenderer.screen(for: block, in: viewport))
    }

    private func inputTimeout(using runtime: StateRuntime) -> TimeInterval? {
        runtime.nextTapDeadline.map {
            max($0.timeIntervalSinceNow, 0)
        }
    }
}

struct TerminalViewportTracker {

    private(set) var renderedViewport: TerminalViewportSize

    func needsRedraw(for currentViewport: TerminalViewportSize) -> Bool {
        currentViewport != renderedViewport
    }

    mutating func update(renderedViewport: TerminalViewportSize) {
        self.renderedViewport = renderedViewport
    }
}

private extension RootScene {

    func renderedBlock(
        in proposal: RenderProposal,
        using runtime: StateRuntime,
        termination: TerminationController
    ) -> RenderedBlock? {
        let action = termination.action
        return runtime.block(
            from: root
                .onTerminate {
                    action()
                }
                .environment(\.terminate, action),
            in: proposal
        )
    }
}

final class TerminationController {

    private(set) var isRequested = false

    lazy var action = TerminateAction {
        [weak self] in

        self?.isRequested = true
    }
}
