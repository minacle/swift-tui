import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

@Suite("Button Behavior")
struct ButtonBehaviorTests {

    @Test
    func `rendering a button label does not perform its action`() {
        var didRun = false
        let title = ["Sa", "ve"].joined()
        let custom = Button(action: { didRun = true }) {
            Text("Run")
        }
        let titled = Button(title) {
            didRun = true
        }

        #expect(ViewResolver.text(from: custom) == "Run")
        #expect(ViewResolver.text(from: titled) == "Save")
        #expect(!didRun)
    }

    @Test
    func `a button performs its action when pointer-up occurs within the region where pointer-down began`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Button("Run") {
            tapProbe.record("run")
        }

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(tapProbe.events.isEmpty)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date
            ) == .ignored
        )
        #expect(tapProbe.events == ["run"])
    }

    @Test
    func `button activation and an outer tap both recognize the pointer sequence`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Button("Run") {
            tapProbe.record("button")
        }
        .onTapGesture {
            tapProbe.record("outer")
        }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(tapProbe.events == ["button", "outer"])
    }

    @Test
    func `button activation and an outer long press both recognize the pointer sequence`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let view = Button("Run") {
            tapProbe.record("button")
        }
        .onLongPressGesture(
            minimumDuration: 0,
            perform: {
                tapProbe.record("long")
            },
            onPressingChanged: {
                tapProbe.record($0 ? "pressing" : "ended")
            }
        )

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(tapProbe.events == ["pressing", "long"])
        #expect(runtime.nextLongPressDeadline == nil)

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date.addingTimeInterval(0.1)
            ) == .ignored
        )
        #expect(tapProbe.events == ["pressing", "long", "button", "ended"])
    }

    @Test
    func `a button ignores clicks outside its hit region`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Button("Run") {
            tapProbe.record("run")
        }

        _ = runtime.block(from: view)

        dispatchClick(to: runtime, column: 4, row: 1, expecting: .ignored)

        #expect(tapProbe.events.isEmpty)
    }

    @Test
    func `a focused button performs its action for Return and ignores unrelated keys`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = FocusedButtonView(tapProbe: tapProbe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: "x", characters: "x")) == .ignored)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        #expect(tapProbe.events == ["go"])
    }

    @Test
    func `button Return activation continues to key resolution after its action`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = ResolvedButtonView(tapProbe: tapProbe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled
        )
        #expect(tapProbe.events == ["button", "resolve"])
    }

    @Test
    func `a handled immediate key event prevents deferred Button activation`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = HandledButtonView(tapProbe: tapProbe)

        _ = runtime.block(from: view)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled
        )
        #expect(tapProbe.events == ["event"])
    }

    @Test
    func `a disabled button rejects pointer and Return activation and cannot remain focused`() {
        let runtime = StateRuntime()
        let focusProbe = FocusBindingProbe<Bool>()
        let tapProbe = TapGestureProbe()
        let view = DisabledFocusedButtonView(
            focusProbe: focusProbe,
            tapProbe: tapProbe
        )

        #expect(runtime.block(from: view)?.text == "Run")
        #expect(focusProbe.binding?.wrappedValue == false)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
        dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
        #expect(tapProbe.events.isEmpty)
    }

    @Test
    func `clicking a stateful button invalidates and rerenders its updated label`() {
        let runtime = StateRuntime()
        let view = ButtonStateMutationView()

        #expect(runtime.block(from: view)?.text == "0")

        dispatchClick(to: runtime, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "1")
    }

    @Test
    func `button actions use the environment captured during rendering for pointer and keyboard activation`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = ButtonEnvironmentActionView(tapProbe: tapProbe)
            .environment(\.testMarker, "button")

        _ = runtime.block(from: view)
        dispatchClick(to: runtime, column: 1, row: 1)

        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)

        #expect(tapProbe.events == ["button", "button"])
    }

    @Test
    func `automatic and fitted buttons keep their intrinsic width in a horizontal stack`() {
        let automatic = HStack(spacing: 0) {
            Button("A") {}
            Text("B")
        }
        let fitted = HStack(spacing: 0) {
            Button("A") {}
                .buttonSizing(.fitted)
            Text("B")
        }

        #expect(ViewResolver.block(from: automatic, in: RenderProposal(columns: 5))?.lines == ["AB"])
        #expect(ViewResolver.block(from: fitted, in: RenderProposal(columns: 5))?.lines == ["AB"])
    }

    @Test
    func `a flexible button expands to the proposed width`() {
        let view = Button("Open") {}
            .buttonSizing(.flexible)

        #expect(ViewResolver.block(from: view, in: RenderProposal(columns: 8))?.lines == ["Open    "])
    }

    @Test
    func `a flexible button receives the remaining width in a horizontal stack`() {
        let view = HStack(spacing: 0) {
            Button("A") {}
                .buttonSizing(.flexible)
            Text("B")
        }

        #expect(ViewResolver.block(from: view, in: RenderProposal(columns: 5))?.lines == ["A   B"])
    }

    @Test
    func `the expanded blank area of a flexible button participates in hit testing`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = Button("A") {
            tapProbe.record("tap")
        }
        .buttonSizing(.flexible)

        #expect(runtime.block(from: view, in: RenderProposal(columns: 5))?.lines == ["A    "])

        dispatchClick(to: runtime, column: 5, row: 1)

        #expect(tapProbe.events == ["tap"])
    }
}

private struct FocusedButtonView: View {

    @FocusState var isFocused: Bool = true

    let tapProbe: TapGestureProbe

    var body: some View {
        Button("Go") {
            tapProbe.record("go")
        }
        .focused($isFocused)
    }
}

private struct DisabledFocusedButtonView: View {

    @FocusState var isFocused: Bool = true

    let focusProbe: FocusBindingProbe<Bool>

    let tapProbe: TapGestureProbe

    var body: some View {
        CapturedFocusedButton(
            focus: $isFocused,
            focusProbe: focusProbe,
            tapProbe: tapProbe
        )
        .disabled(true)
    }
}

private struct ResolvedButtonView: View {

    @FocusState var isFocused: Bool = true

    let tapProbe: TapGestureProbe

    var body: some View {
        Button("Resolve") {
            tapProbe.record("button")
        }
        .focused($isFocused)
        .environment(\.resolveKey[.return]) { _ in
            tapProbe.record("resolve")
            return .handled
        }
    }
}

private struct HandledButtonView: View {

    @FocusState var isFocused: Bool = true

    let tapProbe: TapGestureProbe

    var body: some View {
        Button("Handled") {
            tapProbe.record("button")
        }
        .focused($isFocused)
        .onKeyPress(.return) {
            tapProbe.record("event")
            return .handled
        }
    }
}

private struct CapturedFocusedButton: View {

    let focus: FocusState<Bool>.Binding

    let tapProbe: TapGestureProbe

    init(
        focus: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        tapProbe: TapGestureProbe
    ) {
        self.focus = focus
        self.tapProbe = tapProbe
        focusProbe.capture(focus)
    }

    var body: some View {
        Button("Run") {
            tapProbe.record("run")
        }
        .focused(focus)
    }
}

private struct ButtonStateMutationView: View {

    @State var count = 0

    var body: some View {
        Button(action: {
            count += 1
        }) {
            Text("\(count)")
        }
    }
}

private struct ButtonEnvironmentActionView: View {

    @FocusState var isFocused: Bool = true

    @Environment(\.testMarker) private var marker

    let tapProbe: TapGestureProbe

    var body: some View {
        Button("Read") {
            tapProbe.record(marker)
        }
        .focused($isFocused)
    }
}
