import Foundation

struct AppRunner<Application: App> {

    var app: Application

    func run() throws {
        guard let root = SceneResolver.rootScene(from: app.body) else {
            return
        }

        try run(root, session: TerminalSession())
    }

    func run(session: TerminalSession) throws {
        guard let root = SceneResolver.rootScene(from: app.body) else {
            return
        }

        try run(root, session: session)
    }

    private func run(
        _ root: any RootScene,
        session: TerminalSession
    ) throws {
        let runtime = StateRuntime(onInvalidation: {
            MainRunLoopWakeup.signal()
        })
        let termination = TerminationController {
            MainRunLoopWakeup.signal()
        }
        let runLoopKeepAlive = Timer(
            fire: .distantFuture,
            interval: 0,
            repeats: false
        ) { _ in }
        RunLoop.main.add(runLoopKeepAlive, forMode: .default)

        try session.start()
        defer {
            runLoopKeepAlive.invalidate()
            session.stopReading()
            runtime.endInputSession()
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
            if termination.isRequested {
                return
            }

            session.requestInput()
            waitForEvent(until: nextDeadline(using: runtime))

            if let input = session.takeInput(),
               dispatch(input, using: runtime) {
                dispatchPendingInput(
                    using: runtime,
                    session: session
                )
            }

            runtime.dispatchExpiredRecognitionActions()
            runtime.dispatchExpiredScrollIndicatorFlashes()

            let currentViewport = session.currentTerminalSize()
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
        case .focusIn:
            return false
        case .focusOut:
            runtime.dispatchSceneInactive()
            return true
        case .none:
            return false
        }
    }

    private func dispatchPendingInput(using runtime: StateRuntime, session: TerminalSession) {
        while dispatch(session.readPendingInput(), using: runtime) {}
    }

    private func render(
        _ root: any RootScene,
        using runtime: StateRuntime,
        termination: TerminationController,
        session: TerminalSession,
        previousRender: RenderedTerminalViewport? = nil
    ) -> RenderedTerminalViewport {
        while true {
            let viewport = session.currentTerminalSize()
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
                previousRender: previousRender,
                session: session
            )
            return RenderedTerminalViewport(viewport: viewport, block: block)
        }
    }

    private func render(
        _ block: RenderedBlock,
        in viewport: TerminalViewportSize,
        previousRender: RenderedTerminalViewport?,
        session: TerminalSession
    ) {
        session.write(TerminalScreenRenderer.redraw(
            from: previousRender?.block,
            previousViewport: previousRender?.viewport,
            to: block,
            in: viewport
        ))
    }

    private func nextDeadline(using runtime: StateRuntime) -> Date? {
        [
            runtime.nextTapDeadline,
            runtime.nextLongPressDeadline,
            runtime.nextRecognitionDeadline,
            runtime.nextScrollIndicatorFlashDeadline,
        ].compactMap(\.self).min()
    }

    /// Services one main-run-loop source or waits until the next runtime
    /// deadline so MainActor task continuations can run while terminal input
    /// remains blocked on the dedicated I/O worker.
    private func waitForEvent(until deadline: Date?) {
        _ = RunLoop.main.run(
            mode: .default,
            before: deadline ?? .distantFuture
        )
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

    private let onRequest: () -> Void

    init(onRequest: @escaping () -> Void = {}) {
        self.onRequest = onRequest
    }

    lazy var action = TerminateAction {
        [weak self] in

        guard let self, !isRequested else {
            return
        }

        isRequested = true
        onRequest()
    }
}
