import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Focus Management")
struct FocusManagementTests {

    @Test
    func `FocusState defaults Boolean values to false and optional values to nil`() {
        struct Probe {

            @FocusState var isFocused: Bool

            @FocusState var field: FocusField?
        }

        let probe = Probe()

        #expect(probe.isFocused == false)
        #expect(probe.field == nil)
    }

    @Test
    func `FocusState preserves explicitly initialized wrapped values`() {
        struct Probe {

            @FocusState var isFocused = true

            @FocusState var field: FocusField? = .first
        }

        let probe = Probe()

        #expect(probe.isFocused == true)
        #expect(probe.field == .first)
    }

    @Test
    func `isFocused defaults to false in environment values and descendants`() {
        #expect(!EnvironmentValues().isFocused)
        #expect(ViewResolver.text(from: IsFocusedEnvironmentMarkerText()) == "unfocused")
    }

    @Test
    func `a focus binding propagates its current state through isFocused after rerender`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()
        let view = FocusedEnvironmentMarkerView(probe: probe)

        #expect(runtime.block(from: view)?.text == "unfocused")

        probe.binding?.wrappedValue = true
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "focused")

        probe.binding?.wrappedValue = false
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "focused")
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "unfocused")
    }

    @Test
    func `a nested unfocused focusable view reports isFocused false despite a focused ancestor`() {
        let runtime = StateRuntime()

        #expect(runtime.block(from: NestedFocusableEnvironmentMarkerView())?.text == "unfocused")
    }

    @Test
    func `moving focus to a nested focused child clears the outer isFocused value`() {
        let runtime = StateRuntime()
        let outerProbe = FocusBindingProbe<Bool>()
        let childProbe = FocusBindingProbe<Bool>()
        let view = NestedFocusOwnerEnvironmentMarkerView(
            outerProbe: outerProbe,
            childProbe: childProbe
        )

        let initialBlock = renderFocusUntilStable(runtime, view: view)
        #expect(
            initialBlock?.lines
                == ["focused  ", "unfocused"]
        )

        childProbe.binding?.wrappedValue = true
        #expect(
            renderFocusUntilStable(runtime, view: view)?.lines
                == ["unfocused", "focused  "]
        )
        #expect(outerProbe.binding?.wrappedValue == false)
        #expect(childProbe.binding?.wrappedValue == true)
    }

    @Test
    func `a button label observes isFocused after the button receives pointer focus`() {
        let runtime = StateRuntime()
        let view = FocusableEnvironmentButton()

        #expect(runtime.block(from: view)?.text == "unfocused")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "focused")
    }

    @Test
    func `a text field label observes isFocused after the field receives pointer focus`() {
        let runtime = StateRuntime()
        let view = FocusableEnvironmentTextField()

        #expect(runtime.block(from: view)?.text == "unfocused")

        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "focused")
    }

    @Test
    func `a handled immediate pointer event prevents deferred pointer focus`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()
        let view = ClickableFocusedTextView(probe: probe)
            .onPointerPress { .handled }

        _ = runtime.block(from: view)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: .zero, phase: .down)
            ) == .handled
        )

        #expect(probe.binding?.wrappedValue == false)
    }

    @Test
    func `a navigation link label observes isFocused after the link receives pointer focus`() {
        let runtime = StateRuntime()
        let view = FocusableEnvironmentNavigationLink()

        #expect(runtime.block(from: view)?.text == "unfocused")
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "focused")
    }

    @Test
    func `mutating a focus binding invalidates and rerenders the root view`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()

        #expect(runtime.block(from: BoolFocusableThenFocusedView(probe: probe))?.text == "A")

        probe.binding?.wrappedValue = true

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: BoolFocusableThenFocusedView(probe: probe))?.text == "A")
        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `focusable followed by focused registers a Boolean focus candidate`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()

        _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

        probe.binding?.wrappedValue = true
        _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `focused followed by focusable also registers a Boolean focus candidate`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()

        _ = runtime.block(from: BoolFocusedThenFocusableView(probe: probe))

        probe.binding?.wrappedValue = true
        _ = runtime.block(from: BoolFocusedThenFocusableView(probe: probe))

        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `focused registers a Boolean focus candidate without an explicit focusable modifier`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()

        _ = runtime.block(from: BoolFocusedOnlyView(probe: probe))

        probe.binding?.wrappedValue = true
        _ = runtime.block(from: BoolFocusedOnlyView(probe: probe))

        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `an equality-based focused modifier registers an optional focus candidate without an explicit focusable modifier`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<FocusField?>()

        _ = runtime.block(from: OptionalFocusedOnlyView(probe: probe))

        probe.binding?.wrappedValue = .first
        _ = runtime.block(from: OptionalFocusedOnlyView(probe: probe))

        #expect(probe.binding?.wrappedValue == .first)
    }

    @Test
    func `setting a Boolean focus binding to false clears active focus`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()

        _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

        probe.binding?.wrappedValue = true
        _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

        #expect(probe.binding?.wrappedValue == true)

        probe.binding?.wrappedValue = false
        _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

        #expect(probe.binding?.wrappedValue == false)
    }

    @Test
    func `an optional focus binding selects either candidate and clears focus with nil`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<FocusField?>()

        #expect(runtime.block(from: OptionalFocusView(probe: probe))?.lines == ["First ", "Second"])

        probe.binding?.wrappedValue = .first
        _ = runtime.block(from: OptionalFocusView(probe: probe))

        #expect(probe.binding?.wrappedValue == .first)

        probe.binding?.wrappedValue = .second
        _ = runtime.block(from: OptionalFocusView(probe: probe))

        #expect(probe.binding?.wrappedValue == .second)

        probe.binding?.wrappedValue = nil
        _ = runtime.block(from: OptionalFocusView(probe: probe))

        #expect(probe.binding?.wrappedValue == nil)
    }

    @Test
    func `focusable false rejects programmatic focus requests`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()

        _ = runtime.block(from: DisabledFocusableView(probe: probe))

        probe.binding?.wrappedValue = true
        _ = runtime.block(from: DisabledFocusableView(probe: probe))

        #expect(probe.binding?.wrappedValue == false)
    }

    @Test
    func `duplicate focus values select the first rendered candidate`() {
        let runtime = StateRuntime()
        let fieldProbe = FocusBindingProbe<FocusField?>()
        let firstProbe = FocusBindingProbe<Bool>()
        let secondProbe = FocusBindingProbe<Bool>()

        _ = runtime.block(
            from: DuplicateFocusValueView(
                fieldProbe: fieldProbe,
                firstProbe: firstProbe,
                secondProbe: secondProbe
            )
        )

        fieldProbe.binding?.wrappedValue = .first
        _ = runtime.block(
            from: DuplicateFocusValueView(
                fieldProbe: fieldProbe,
                firstProbe: firstProbe,
                secondProbe: secondProbe
            )
        )

        #expect(fieldProbe.binding?.wrappedValue == .first)
        #expect(firstProbe.binding?.wrappedValue == true)
        #expect(secondProbe.binding?.wrappedValue == false)
    }

    @Test
    func `focus modifiers leave rendered output unchanged`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()

        let block = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

        #expect(block?.text == "A")
    }

    @Test
    func `pointer-down on a focusable view sets its Boolean focus binding`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()
        let view = ClickableFocusedTextView(probe: probe)

        _ = runtime.block(from: view)

        #expect(probe.binding?.wrappedValue == false)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `a focused modifier enables pointer focus without an explicit focusable modifier`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()
        let view = ClickableFocusedOnlyTextView(probe: probe)

        _ = runtime.block(from: view)

        #expect(probe.binding?.wrappedValue == false)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `padding does not expand the pointer-focus region inside a frame`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()
        let view = PaddedFramedClickFocusView(probe: probe)

        #expect(runtime.block(from: view)?.lines == ["top", " A "])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 1), phase: .down)
            ) == .ignored
        )
        #expect(probe.binding?.wrappedValue == false)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 1), phase: .down)
            ) == .ignored
        )
        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `pointer-focus hit testing follows content after scrolling`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()
        let view = ScrolledClickFocusView(probe: probe)

        #expect(runtime.block(from: view)?.lines == ["B"])

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(probe.binding?.wrappedValue == true)
    }

    @Test
    func `focusable false ignores pointer focus requests`() {
        let runtime = StateRuntime()
        let probe = FocusBindingProbe<Bool>()
        let view = DisabledClickFocusView(probe: probe)

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(probe.binding?.wrappedValue == false)
    }

    @Test
    func `pointer focus on press coexists with tap recognition on release`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<Bool>()
        let tapProbe = TapGestureProbe()
        let view = ClickFocusTapGestureView(
            focusProbe: focusProbe,
            tapProbe: tapProbe
        )
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(focusProbe.binding?.wrappedValue == true)
        #expect(tapProbe.events.isEmpty)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date
            ) == .ignored
        )
        #expect(tapProbe.events == ["tap"])
    }
}

private struct NestedFocusOwnerEnvironmentMarkerView: View {

    @FocusState private var isOuterFocused = true

    @FocusState private var isChildFocused: Bool

    let outerProbe: FocusBindingProbe<Bool>

    let childProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedNestedFocusOwnerEnvironmentMarkers(
            outerFocus: $isOuterFocused,
            childFocus: $isChildFocused,
            outerProbe: outerProbe,
            childProbe: childProbe
        )
    }
}

private struct CapturedNestedFocusOwnerEnvironmentMarkers: View {

    let outerFocus: FocusState<Bool>.Binding

    let childFocus: FocusState<Bool>.Binding

    init(
        outerFocus: FocusState<Bool>.Binding,
        childFocus: FocusState<Bool>.Binding,
        outerProbe: FocusBindingProbe<Bool>,
        childProbe: FocusBindingProbe<Bool>
    ) {
        self.outerFocus = outerFocus
        self.childFocus = childFocus
        outerProbe.capture(outerFocus)
        childProbe.capture(childFocus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IsFocusedEnvironmentMarkerText()
            IsFocusedEnvironmentMarkerText()
                .focused(childFocus)
        }
        .focused(outerFocus)
    }
}

private func renderFocusUntilStable<Content: View>(
    _ runtime: StateRuntime,
    view: Content
) -> RenderedBlock? {
    var block: RenderedBlock?
    for _ in 0..<8 {
        block = runtime.block(from: view)
        if !runtime.consumeInvalidation() {
            break
        }
    }
    return block
}
