import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Application Termination")
struct ApplicationTerminationTests {

    @Test
    func `calling a terminate action invokes its stored closure`() {
        var didTerminate = false
        let action = TerminateAction {
            didTerminate = true
        }

        action()

        #expect(didTerminate)
    }

    @Test
    func `a terminate action captured from the environment remains callable`() {
        var didTerminate = false
        let probe = TerminateActionProbe()
        let view = CapturedTerminateActionView(probe: probe)
            .environment(\.terminate, TerminateAction {
                didTerminate = true
            })

        _ = ViewResolver.text(from: view)
        probe.action?()

        #expect(didTerminate)
    }

    @Test
    func `dispatching termination invokes an on-terminate handler that requests application termination`() {
        let runtime = StateRuntime()
        let termination = TerminationController()
        let action = termination.action
        let view = Text("A")
            .onTerminate {
                action()
            }
            .environment(\.terminate, action)

        _ = runtime.block(from: view)
        runtime.dispatchTerminate()

        #expect(termination.isRequested)
    }

    @Test
    func `an on-terminate handler can invoke a terminate action captured during rendering`() {
        let runtime = StateRuntime()
        let termination = TerminationController()
        let action = termination.action
        let view = EnvironmentBackedTerminateView()
            .environment(\.terminate, action)

        _ = runtime.block(from: view)
        runtime.dispatchTerminate()

        #expect(termination.isRequested)
    }

    @Test
    func `an on-terminate handler can update view state without requesting application termination`() {
        let runtime = StateRuntime()
        let termination = TerminationController()
        let action = termination.action
        let view = TerminateStatusView()
            .onTerminate {
                action()
            }
            .environment(\.terminate, action)

        #expect(runtime.block(from: view)?.text == "running")

        runtime.dispatchTerminate()

        #expect(!termination.isRequested)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "interrupted")
    }

    @Test
    func `mutating an observable navigation path during termination invalidates the view immediately`() {
        let runtime = StateRuntime()
        let view = ObservableTerminateNavigationView()

        #expect(runtime.block(from: view)?.text == "main")

        runtime.dispatchTerminate()

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "confirm quit")
    }
}
