import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Destination Presentation")
struct DestinationPresentationTests {

    @Test
    func `a Boolean-bound navigation destination appears when true and clears its binding on Escape`() {
        var isPresented = false
        let runtime = StateRuntime()
        let view = NavigationPresentedBoolView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Root")

        isPresented = true
        #expect(runtime.block(from: view)?.text == "Presented")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `isPresented is false at the root and true inside a presented navigation destination`() {
        var isPresented = false
        let runtime = StateRuntime()
        let view = NavigationIsPresentedEnvironmentView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            )
        )

        #expect(!EnvironmentValues().isPresented)
        #expect(runtime.block(from: view)?.text == "root")

        isPresented = true
        #expect(runtime.block(from: view)?.text == "presented")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "root")
    }

    @Test
    func `a global key handler can present a Boolean-bound navigation destination`() {
        let runtime = StateRuntime()
        let view = NavigationPresentedBoolStateGlobalKeyView()

        #expect(runtime.block(from: view)?.text == "Root")

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Presented")
    }

    @Test
    func `a character global key handler can present a destination after an onAppear update`() {
        let runtime = StateRuntime()
        let view = NavigationPresentedBoolStateCharacterGlobalKeyOnAppearView()

        #expect(runtime.block(from: view)?.text == "Root")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root appeared")

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Presented")
    }

    @Test
    func `a direct destination can present a Boolean-bound destination from within itself`() {
        let runtime = StateRuntime()
        let view = NavigationPresentedBoolStateDirectDestinationView()

        #expect(runtime.block(from: view)?.text == "Open")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Presented")
    }

    @Test
    func `Escape closes a Boolean-presented destination before its underlying direct destination`() {
        let runtime = StateRuntime()
        let view = NavigationPresentedBoolStateDirectDestinationView()

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Presented")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `a Button in a destination presented from a direct destination remains tappable`() {
        let runtime = StateRuntime()
        let probe = KeyPressProbe()
        let view = NavigationPresentedBoolStateDirectDestinationInputView(probe: probe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Activate")

        dispatchButtonClick(to: runtime, column: 1, row: 1)
        #expect(probe.events == ["activated"])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Activated")
    }

    @Test
    func `a focused Button in a destination presented from a direct destination activates and consumes Return`() {
        let runtime = StateRuntime()
        let probe = KeyPressProbe()
        let view = NavigationPresentedBoolStateDirectDestinationInputView(probe: probe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Activate")

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(probe.events == ["activated"])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Activated")
    }

    @Test
    func `an item-bound navigation destination appears for a value and clears the item on Escape`() {
        var item: Int? = nil
        let runtime = StateRuntime()
        let view = NavigationPresentedItemView(
            item: Binding(
                get: {
                    item
                },
                set: {
                    item = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Root")

        item = 7
        #expect(runtime.block(from: view)?.text == "Item 7")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(item == nil)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `changing the item bound to a navigation destination creates fresh local state`() {
        var item: Int? = 1
        let runtime = StateRuntime()
        let view = NavigationPresentedItemStateResetView(
            item: Binding(
                get: {
                    item
                },
                set: {
                    item = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Value 1 count 0")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Value 1 count 1")

        item = 2
        #expect(runtime.block(from: view)?.text == "Value 2 count 0")
    }

    @Test
    func `a dismiss action captured above a NavigationStack cannot close its presented destination`() {
        var isPresented = true
        let runtime = StateRuntime()
        let view = NavigationParentCapturedDismissActionView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Close")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(isPresented)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Close")
    }

    @Test
    func `the dismiss action clears a Boolean-bound presented destination`() {
        var isPresented = true
        let runtime = StateRuntime()
        let view = NavigationPresentedDismissActionView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Close")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `the dismiss action clears an item-bound presented destination`() {
        var item: Int? = 7
        let runtime = StateRuntime()
        let view = NavigationItemDismissActionView(
            item: Binding(
                get: {
                    item
                },
                set: {
                    item = $0
                }
            )
        )

        #expect(runtime.block(from: view)?.text == "Item 7")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(item == nil)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `a stale dismiss action cannot close a newly re-presented Boolean destination`() {
        var isPresented = true
        let probe = DismissActionProbe()
        let runtime = StateRuntime()
        let view = NavigationCapturedPresentedDismissActionView(
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

        #expect(runtime.block(from: view)?.text == "Close")
        let staleDismiss = probe.dismiss

        staleDismiss?()
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")

        isPresented = true
        #expect(runtime.block(from: view)?.text == "Close")
        let currentDismiss = probe.dismiss

        staleDismiss?()
        #expect(isPresented)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Close")

        currentDismiss?()
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Root")
    }

    @Test
    func `a dismiss action from a direct destination cannot close a covering presented destination`() {
        var isPresented = false
        let directProbe = NavigationActionProbe()
        let presentedProbe = NavigationActionProbe()
        let runtime = StateRuntime()
        let view = NavigationPushDirectWithPresentedActionView(
            isPresented: Binding(
                get: {
                    isPresented
                },
                set: {
                    isPresented = $0
                }
            ),
            directProbe: directProbe,
            presentedProbe: presentedProbe
        )

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")
        let coveredDismiss = directProbe.dismiss

        isPresented = true
        #expect(runtime.block(from: view)?.text == "A")
        let currentDismiss = presentedProbe.dismiss
        _ = runtime.consumeInvalidation()

        coveredDismiss?()
        #expect(isPresented)
        #expect(!runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")

        currentDismiss?()
        #expect(!isPresented)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "A")
    }
}
