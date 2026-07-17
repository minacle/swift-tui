import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Navigation Links and Bound Paths")
struct NavigationLinkAndBoundPathTests {

    @Test
    func `a focused direct NavigationLink consumes Return or pointer-up when it opens and closes with Escape`() {
        let runtime = StateRuntime()
        let view = FocusedDirectNavigationLinkView()

        #expect(runtime.block(from: view)?.text == "Open")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")

        #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Open")

        dispatchNavigationLinkClick(to: runtime, column: 1, row: 1)
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
    func `a value NavigationLink consumes Return while appending its value and rendering its destination`() {
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

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
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
    func `NavigationLink pointer activation consumes pointer-up after an outer long press`() {
        var path: [Int] = []
        let runtime = StateRuntime()
        let probe = TapGestureProbe()
        let view = GestureNavigationLinkView(
            path: Binding(
                get: { path },
                set: { path = $0 }
            ),
            probe: probe
        )
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 0, row: 0),
                    phase: .down
                ),
                at: date
            ) == .ignored
        )
        #expect(probe.events == ["long"])
        #expect(path.isEmpty)

        #expect(
            runtime.dispatch(
                PointerPress(
                    button: .left,
                    location: Point(column: 0, row: 0),
                    phase: .up
                ),
                at: date.addingTimeInterval(0.1)
            ) == .handled
        )
        #expect(probe.events == ["long"])
        #expect(path == [1])
    }

    @Test
    func `NavigationLink pointer activation consumes pointer-up before an outer tap`() {
        var path: [Int] = []
        let runtime = StateRuntime()
        let probe = TapGestureProbe()
        let view = TapNavigationLinkView(
            path: Binding(
                get: { path },
                set: { path = $0 }
            ),
            probe: probe
        )

        _ = runtime.block(from: view)
        dispatchNavigationLinkClick(to: runtime, column: 1, row: 1)

        #expect(probe.events.isEmpty)
        #expect(path == [1])
    }

    @Test
    func `NavigationLink Return activation consumes the key before resolution`() {
        let runtime = StateRuntime()
        let probe = TapGestureProbe()
        let view = ResolvedNavigationLinkView(probe: probe)

        #expect(runtime.block(from: view)?.text == "Open")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(
            runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled
        )
        #expect(probe.events.isEmpty)
        #expect(runtime.block(from: view)?.text == "Detail")
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
    func `a value push action from a child destination appends its enum value and consumes Return`() {
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

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(path == [.detail])
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `the value push action updates an observable NavigationStack path and consumes Return`() {
        let runtime = StateRuntime()
        let view = NavigationPushObservableObjectPathView()

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "Detail")
    }

    @Test
    func `a NavigationStack retains its initialized path model when a Button consumes Return to push`() {
        let runtime = StateRuntime()
        let view = NavigationPushInitializedObservableObjectPathRootView()

        #expect(runtime.block(from: view)?.text == "Push")
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: view)

        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
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

private func dispatchNavigationLinkClick(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    at date: Date = Date(timeIntervalSinceReferenceDate: 1_000)
) {
    #expect(
        runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: column - 1, row: row - 1),
                phase: .down
            ),
            at: date
        ) == .ignored
    )
    #expect(
        runtime.dispatch(
            PointerPress(
                button: .left,
                location: Point(column: column - 1, row: row - 1),
                phase: .up
            ),
            at: date
        ) == .handled
    )
}

private struct GestureNavigationLinkView: View {

    let path: Binding<[Int]>

    let probe: TapGestureProbe

    var body: some View {
        NavigationStack(path: path) {
            NavigationLink("Open", value: 1)
                .onLongPressGesture(minimumDuration: 0) {
                    probe.record("long")
                }
                .navigationDestination(for: Int.self) { _ in
                    Text("Detail")
                }
        }
    }
}

private struct TapNavigationLinkView: View {

    let path: Binding<[Int]>

    let probe: TapGestureProbe

    var body: some View {
        NavigationStack(path: path) {
            NavigationLink("Open", value: 1)
                .onTapGesture {
                    probe.record("tap")
                }
                .navigationDestination(for: Int.self) { _ in
                    Text("Detail")
                }
        }
    }
}

private struct ResolvedNavigationLinkView: View {

    @FocusState var isFocused: Bool = true

    let probe: TapGestureProbe

    var body: some View {
        NavigationStack {
            NavigationLink("Open") {
                Text("Detail")
            }
            .focused($isFocused)
            .environment(\.resolveKey[.return]) { _ in
                probe.record("resolve")
                return .handled
            }
        }
    }
}
