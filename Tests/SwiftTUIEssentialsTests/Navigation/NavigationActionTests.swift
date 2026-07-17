import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Navigation Actions")
struct NavigationActionTests {

    @Test
    func `a value destination can mutate state owned by its NavigationStack parent`() {
        let runtime = StateRuntime()
        let view = NavigationStateMutationView()

        #expect(runtime.block(from: view)?.lines == ["Open ", "empty"])
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Destination empty")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Destination updated")
    }

    @Test
    func `popping and reopening a value destination creates fresh local state`() {
        var path: [Int] = []
        let runtime = StateRuntime()
        let view = NavigationDestinationStateResetView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Open")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Value 1 count 0")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Value 1 count 1")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Open")

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Value 1 count 0")
    }

    @Test
    func `NavigationRuntime appends a pushed value before its destination type is registered`() {
        var path: [NavigationPushDestination] = []
        let runtime = NavigationRuntime()
        runtime.registerStack(
            at: [],
            accessor: NavigationPathAccessor(
                Binding(
                    get: {
                        path
                    },
                    set: {
                        path = $0
                    }
                )
            )
        )

        #expect(runtime.pushValue(AnyNavigationValue(NavigationPushDestination.detail), at: []))
        #expect(path == [.detail])
    }

    @Test
    func `the direct push action presents its destination`() {
        let runtime = StateRuntime()
        let view = NavigationPushDirectDestinationView()

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `a directly pushed destination can mutate state owned by its parent`() {
        let runtime = StateRuntime()
        let view = NavigationPushDirectStateMutationView()

        #expect(runtime.block(from: view)?.lines == ["Push ", "empty"])
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Destination empty")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Destination updated")
    }

    @Test
    func `popping and reopening a directly pushed destination creates fresh local state`() {
        let runtime = StateRuntime()
        let view = NavigationPushDirectStateResetView()

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.trimmedLines == ["Value count 0", "Back"])

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.trimmedLines == ["Value count 1", "Back"])

        dispatchClick(to: runtime, column: 1, row: 2)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Push")

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.trimmedLines == ["Value count 0", "Back"])
    }

    @Test
    func `the pop action dismisses a Boolean-bound presented destination`() {
        var isPresented = true
        let runtime = StateRuntime()
        let view = NavigationPresentedPopActionView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Back")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `the dismiss action closes a directly pushed destination`() {
        let runtime = StateRuntime()
        let view = NavigationPushDirectDismissActionView()

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Close")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Push")
    }

    @Test
    func `the dismiss action at a NavigationStack root has no effect`() {
        let runtime = StateRuntime()
        let view = NavigationRootDismissActionView()

        #expect(runtime.block(from: view)?.text == "Dismiss")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Dismiss")
    }

    @Test
    func `a stale dismiss action cannot close a newly pushed direct destination`() {
        let probe = NavigationActionProbe()
        let runtime = StateRuntime()
        let view = NavigationPushCapturedDirectActionView(probe: probe)

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")
        let expiredDismiss = probe.dismiss

        expiredDismiss?()
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Push")

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")
        let currentDismiss = probe.dismiss
        _ = runtime.consumeInvalidation()

        expiredDismiss?()
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")

        currentDismiss?()
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Push")
    }

    @Test
    func `a stale dismiss action cannot remove a newly repushed value destination`() {
        var path: [Int] = []
        let probe = NavigationActionProbe()
        let runtime = StateRuntime()
        let view = NavigationCapturedValueDismissActionView(
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            ),
            probe: probe
        )

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(path == [1])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")
        let expiredDismiss = probe.dismiss

        expiredDismiss?()
        #expect(path.isEmpty)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Push")

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(path == [1])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")
        let currentDismiss = probe.dismiss
        _ = runtime.consumeInvalidation()

        expiredDismiss?()
        #expect(path == [1])
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")

        currentDismiss?()
        #expect(path.isEmpty)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Push")
    }

    @Test
    func `a captured stack-level pop action can close a re-presented destination after its sibling dismiss action expires`() {
        var isPresented = true
        let probe = NavigationActionProbe()
        let runtime = StateRuntime()
        let view = NavigationCapturedPresentedNavigationActionsView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            ),
            probe: probe
        )

        #expect(runtime.block(from: view)?.text == "A")
        let staleDismiss = probe.dismiss
        let stalePop = probe.pop

        staleDismiss?()
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")

        isPresented = true
        #expect(runtime.block(from: view)?.text == "A")

        staleDismiss?()
        #expect(isPresented)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")

        stalePop?()
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `a captured stack-level value push remains valid after its sibling dismiss action expires`() {
        var isPresented = true
        var path: [Int] = []
        let probe = NavigationActionProbe()
        let runtime = StateRuntime()
        let view = NavigationCapturedPresentedNavigationPathActionsView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            ),
            path: Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            ),
            probe: probe
        )

        #expect(runtime.block(from: view)?.text == "A")
        let staleDismiss = probe.dismiss
        let stalePush = probe.push

        staleDismiss?()
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")

        isPresented = true
        #expect(runtime.block(from: view)?.text == "A")

        staleDismiss?()
        #expect(isPresented)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")

        stalePush?(1)
        #expect(path == [1])
        #expect(runtime.consumeInvalidation())

        isPresented = false
        #expect(runtime.block(from: view)?.text == "Value 1")
    }

    @Test
    func `a captured stack-level direct push remains valid after its sibling dismiss action expires`() {
        var isPresented = true
        let probe = NavigationActionProbe()
        let runtime = StateRuntime()
        let view = NavigationCapturedPresentedNavigationActionsView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            ),
            probe: probe
        )

        #expect(runtime.block(from: view)?.text == "A")
        let staleDismiss = probe.dismiss
        let stalePush = probe.push

        staleDismiss?()
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")

        isPresented = true
        #expect(runtime.block(from: view)?.text == "A")

        staleDismiss?()
        #expect(isPresented)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")

        stalePush? {
            Text("Direct")
        }
        #expect(runtime.consumeInvalidation())

        isPresented = false
        #expect(runtime.block(from: view)?.text == "Direct")
    }

    @Test
    func `default navigation environment actions can be invoked outside a NavigationStack`() {
        let probe = NavigationActionProbe()
        let view = CapturedNavigationActionsView(probe: probe)

        _ = ViewResolver.text(from: view)
        probe.push?(1)
        probe.push? {
            Text("Detail")
        }
        probe.pop?()
        probe.dismiss?()
    }

    @Test
    func `the dismiss action removes the current value from a bound navigation path`() {
        var path = [1]
        let runtime = StateRuntime()
        let view = NavigationDismissValueView(
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
    }
}
