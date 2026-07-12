import Foundation

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
            renderedViewport: render(
                root,
                using: runtime,
                termination: termination,
                session: session
            )
        )

        while true {
            if viewportTracker.needsRedraw(for: TerminalControl.currentTerminalSize()) {
                viewportTracker.update(
                    renderedViewport: render(
                        root,
                        using: runtime,
                        termination: termination,
                        session: session
                    )
                )
            }

            if dispatch(
                session.readInput(timeout: inputTimeout(using: runtime)),
                using: runtime
            ) {
                dispatchPendingInput(using: runtime, session: session)
            }

            _ = runtime.dispatchExpiredTapActions()
            _ = runtime.dispatchExpiredLongPressActions()
            runtime.dispatchExpiredScrollIndicatorFlashes()

            let currentViewport = TerminalControl.currentTerminalSize()
            if runtime.consumeInvalidation()
                || viewportTracker.needsRedraw(for: currentViewport) {
                viewportTracker.update(
                    renderedViewport: render(
                        root,
                        using: runtime,
                        termination: termination,
                        session: session,
                        previousRender: viewportTracker.renderedViewport
                    )
                )
            }

            if termination.isRequested {
                return
            }
        }
    }

    @discardableResult
    private func dispatch(_ input: TerminalInput, using runtime: StateRuntime) -> Bool {
        switch input {
        case .quit:
            runtime.dispatchTerminate()
            return false
        case .keyPress(let keyPress):
            _ = runtime.dispatch(keyPress)
            return true
        case .pointerPress(let pointerPress):
            _ = runtime.dispatch(pointerPress)
            return true
        case .pointerMotion(let pointerMotion):
            _ = runtime.dispatch(pointerMotion)
            return true
        case .pointerScroll(let pointerScroll):
            _ = runtime.dispatch(pointerScroll)
            return true
        case .none:
            return false
        }
    }

    private func dispatchPendingInput(using runtime: StateRuntime, session: TerminalSession) {
        while dispatch(session.readInput(timeout: 0), using: runtime) {}
    }

    private func render(
        _ root: any RootScene,
        using runtime: StateRuntime,
        termination: TerminationController,
        session: TerminalSession,
        previousRender: RenderedTerminalViewport? = nil
    ) -> RenderedTerminalViewport {
        while true {
            let viewport = TerminalControl.currentTerminalSize()
            guard let block = root.renderedBlock(
                in: RenderProposal(viewport),
                using: runtime,
                termination: termination,
                session: session
            ) else {
                return RenderedTerminalViewport(viewport: viewport, block: nil)
            }

            runtime.updateRenderedFrame(TerminalScreenRenderer.frame(for: block, in: viewport))
            guard !runtime.consumeInvalidation() else {
                continue
            }

            render(
                block,
                in: viewport,
                previousRender: previousRender
            )
            return RenderedTerminalViewport(viewport: viewport, block: block)
        }
    }

    private func render(
        _ block: RenderedBlock,
        in viewport: TerminalViewportSize,
        previousRender: RenderedTerminalViewport?
    ) {
        TerminalControl.write(TerminalScreenRenderer.redraw(
            from: previousRender?.block,
            previousViewport: previousRender?.viewport,
            to: block,
            in: viewport
        ))
    }

    private func inputTimeout(using runtime: StateRuntime) -> TimeInterval? {
        [
            runtime.nextTapDeadline,
            runtime.nextLongPressDeadline,
            runtime.nextScrollIndicatorFlashDeadline,
        ].compactMap(\.self).min().map {
            max($0.timeIntervalSinceNow, 0)
        }
    }
}

struct TerminalViewportTracker {

    private(set) var renderedViewport: RenderedTerminalViewport

    init(renderedViewport: TerminalViewportSize) {
        self.renderedViewport = RenderedTerminalViewport(
            viewport: renderedViewport,
            block: nil
        )
    }

    init(renderedViewport: RenderedTerminalViewport) {
        self.renderedViewport = renderedViewport
    }

    func needsRedraw(for currentViewport: TerminalViewportSize) -> Bool {
        currentViewport != renderedViewport.viewport
    }

    mutating func update(renderedViewport: RenderedTerminalViewport) {
        self.renderedViewport = renderedViewport
    }

    mutating func update(renderedViewport: TerminalViewportSize) {
        self.renderedViewport = RenderedTerminalViewport(
            viewport: renderedViewport,
            block: renderedViewport == self.renderedViewport.viewport ? self.renderedViewport.block : nil
        )
    }
}

struct RenderedTerminalViewport: Equatable, Sendable {

    var viewport: TerminalViewportSize

    var block: RenderedBlock?
}

extension RootScene {

    fileprivate func renderedBlock(
        in proposal: RenderProposal,
        using runtime: StateRuntime,
        termination: TerminationController,
        session: TerminalSession
    ) -> RenderedBlock? {
        let action = termination.action
        return runtime.block(
            from: root
                .onTerminate {
                    action()
                }
                .environment(\.terminate, action)
                .environment(\.copy, CopyAction(session.copy(_:)))
                .environment(\.paste, PasteAction(session.paste)),
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
