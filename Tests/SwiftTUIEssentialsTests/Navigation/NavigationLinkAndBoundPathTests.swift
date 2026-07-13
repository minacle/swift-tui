import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Navigation Links and Bound Paths")
struct NavigationLinkAndBoundPathTests {

    @Test
    func `a focused direct NavigationLink opens with Return or tap and closes with Escape`() {
        let runtime = StateRuntime()
        let view = FocusedDirectNavigationLinkView()

        #expect(runtime.block(from: view)?.text == "Open")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Open")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `a disabled focused NavigationLink ignores Return and tap activation`() {
        let runtime = StateRuntime()
        let view = FocusedDirectNavigationLinkView()
            .disabled(true)

        #expect(runtime.block(from: view)?.text == "Open")
        _ = runtime.consumeInvalidation()
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
        #expect(runtime.consumeInvalidation() == false)
        #expect(runtime.block(from: view)?.text == "Open")
    }

    @Test
    func `a value NavigationLink appends its value to the bound path and renders its destination`() {
        var path: [Int] = []
        let runtime = StateRuntime()
        let view = FocusedValueNavigationLinkView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "One")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(path == [1])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Value 1")
    }

    @Test
    func `a NavigationStack renders programmatic bound-path changes and removes one value per Escape`() {
        var path = [1, 2]
        let runtime = StateRuntime()
        let view = ValueNavigationPathView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Value 2")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(path == [1])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Value 1")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(path.isEmpty)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `NavigationPath routes heterogeneous values to their matching destinations`() {
        var path = NavigationPath()
        path.append(1)
        path.append("two")

        let runtime = StateRuntime()
        let view = HeterogeneousNavigationPathView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "String two")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Int 1")
    }

    @Test
    func `a NavigationLink with a nil optional value does not activate by Return or a completed tap`() {
        let runtime = StateRuntime()
        let view = NilValueNavigationLinkView()

        #expect(runtime.block(from: view)?.text == "Missing")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(!runtime.consumeInvalidation())
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date
            ) == .ignored
        )
        #expect(runtime.block(from: view)?.text == "Missing")
    }

    @Test
    func `the value push action appends to a bound path and renders the destination`() {
        var path: [Int] = []
        let runtime = StateRuntime()
        let view = NavigationPushValueView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(path == [1])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Value 1")
    }

    @Test
    func `a value push action from a child destination appends its enum value to the root bound path`() {
        var path: [NavigationPushDestination] = []
        let runtime = StateRuntime()
        let view = NavigationPushChildRootDestinationView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(path == [.detail])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `the value push action updates a NavigationStack path stored in an observable object`() {
        let runtime = StateRuntime()
        let view = NavigationPushObservableObjectPathView()

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `a NavigationStack retains an initialized observable path model when pushing a value`() {
        let runtime = StateRuntime()
        let view = NavigationPushInitializedObservableObjectPathRootView()

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `the pop action removes a value from the bound navigation path and does nothing at the root`() {
        var path = [1]
        let runtime = StateRuntime()
        let view = NavigationPopValueView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Value 1")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(path.isEmpty)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(path.isEmpty)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

}
