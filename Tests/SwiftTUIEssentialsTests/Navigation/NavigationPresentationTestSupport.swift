import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

struct NavigationPresentedBoolView: View {

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    Text("Presented")
                }
        }
    }
}

struct NavigationIsPresentedEnvironmentView: View {

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            IsPresentedEnvironmentMarkerText(rootLabel: "root")
                .navigationDestination(isPresented: isPresented) {
                    IsPresentedEnvironmentMarkerText(rootLabel: "root")
                }
        }
    }
}

struct NavigationPresentedBoolStateGlobalKeyView: View {

    @State
    private var isPresented = false

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: $isPresented) {
                    Text("Presented")
                }
                .onGlobalKeyPress("a") {
                    isPresented = true
                    return .handled
                }
        }
    }
}

struct NavigationPresentedBoolStateCharacterGlobalKeyOnAppearView: View {

    @State
    private var didAppear = false

    @State
    private var isPresented = false

    var body: some View {
        NavigationStack {
            Text(didAppear ? "Root appeared" : "Root")
                .navigationDestination(isPresented: $isPresented) {
                    Text("Presented")
                }
                .onAppear {
                    didAppear = true
                }
                .onGlobalKeyPress(characters: .init(charactersIn: "a")) {
                    _ in

                    isPresented = true
                    return .handled
                }
        }
    }
}

struct NavigationPresentedBoolStateDirectDestinationView: View {

    @FocusState
    private var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            NavigationLink("Open") {
                NavigationPresentedBoolStateDirectDestinationDetailView()
            }
            .focusable()
            .focused($isFocused)
        }
    }
}

struct NavigationPresentedBoolStateDirectDestinationDetailView: View {

    @State
    private var isPresented = false

    var body: some View {
        Text("Detail")
            .navigationDestination(isPresented: $isPresented) {
                Text("Presented")
            }
            .onGlobalKeyPress(characters: .init(charactersIn: "a")) {
                _ in

                isPresented = true
                return .handled
            }
    }
}

struct NavigationPresentedBoolStateDirectDestinationInputView: View {

    let probe: KeyPressProbe

    @FocusState
    private var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            NavigationLink("Open") {
                NavigationPresentedBoolStateDirectDestinationInputDetailView(probe: probe)
            }
            .focusable()
            .focused($isFocused)
        }
    }
}

struct NavigationPresentedBoolStateDirectDestinationInputDetailView: View {

    let probe: KeyPressProbe

    @State
    private var isPresented = false

    var body: some View {
        Text("Detail")
            .navigationDestination(isPresented: $isPresented) {
                NavigationPresentedBoolStateDirectDestinationInputPresentedView(probe: probe)
            }
            .onGlobalKeyPress(characters: .init(charactersIn: "a")) {
                _ in

                isPresented = true
                return .handled
            }
    }
}

struct NavigationPresentedBoolStateDirectDestinationInputPresentedView: View {

    let probe: KeyPressProbe

    @FocusState
    private var isFocused: Bool = true

    @State
    private var wasActivated = false

    var body: some View {
        Button(wasActivated ? "Activated" : "Activate") {
            probe.record("activated")
            wasActivated = true
        }
        .focused($isFocused)
    }
}

struct NavigationPresentedItemView: View {

    let item: Binding<Int?>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(item: item) { value in
                    Text("Item \(value)")
                }
        }
    }
}

struct NavigationPresentedItemStateResetView: View {

    let item: Binding<Int?>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(item: item) { value in
                    NavigationStatefulDestination(value: value)
                }
        }
    }
}

struct NavigationPresentedPopActionView: View {

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationPresentedPopDestination()
                }
        }
    }
}

struct NavigationPresentedPopDestination: View {

    @Environment(\.pop) private var pop

    var body: some View {
        Text("Back")
            .onTapGesture {
                pop()
            }
    }
}

struct NavigationParentCapturedDismissActionView: View {

    @Environment(\.dismiss) private var dismiss

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationPassedDismissActionDestination(dismiss: dismiss)
                }
        }
    }
}

struct NavigationPassedDismissActionDestination: View {

    let dismiss: DismissAction

    var body: some View {
        Text("Close")
            .onTapGesture {
                dismiss()
            }
    }
}

struct NavigationPresentedDismissActionView: View {

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationDismissActionDestination(label: "Close")
                }
        }
    }
}

struct NavigationItemDismissActionView: View {

    let item: Binding<Int?>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(item: item) { value in
                    NavigationDismissActionDestination(label: "Item \(value)")
                }
        }
    }
}

struct NavigationDismissValueView: View {

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(for: Int.self) { value in
                    NavigationDismissActionDestination(label: "Value \(value)")
                }
        }
    }
}

struct NavigationPushDirectDismissActionView: View {

    var body: some View {
        NavigationStack {
            NavigationPushDirectDismissActionButton()
        }
    }
}

struct NavigationPushDirectDismissActionButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationDismissActionDestination(label: "Close")
                }
                return .handled
            }
    }
}

struct NavigationPushCapturedDirectActionView: View {

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack {
            NavigationPushCapturedDirectActionButton(probe: probe)
        }
    }
}

struct NavigationPushCapturedDirectActionButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    let probe: NavigationActionProbe

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    CapturedNavigationActionsView(probe: probe)
                }
                return .handled
            }
    }
}

struct NavigationCapturedValueDismissActionView: View {

    let path: Binding<[Int]>

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack(path: path) {
            NavigationPushValueButton()
                .navigationDestination(for: Int.self) { _ in
                    CapturedNavigationActionsView(probe: probe)
                }
        }
    }
}

struct NavigationPushDirectWithPresentedActionView: View {

    let isPresented: Binding<Bool>

    let directProbe: NavigationActionProbe

    let presentedProbe: NavigationActionProbe

    var body: some View {
        NavigationStack {
            NavigationPushDirectWithPresentedActionButton(
                isPresented: isPresented,
                directProbe: directProbe,
                presentedProbe: presentedProbe
            )
        }
    }
}

struct NavigationPushDirectWithPresentedActionButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    let isPresented: Binding<Bool>

    let directProbe: NavigationActionProbe

    let presentedProbe: NavigationActionProbe

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationDirectWithPresentedActionDestination(
                        isPresented: isPresented,
                        directProbe: directProbe,
                        presentedProbe: presentedProbe
                    )
                }
                return .handled
            }
    }
}

struct NavigationDirectWithPresentedActionDestination: View {

    let isPresented: Binding<Bool>

    let directProbe: NavigationActionProbe

    let presentedProbe: NavigationActionProbe

    var body: some View {
        CapturedNavigationActionsView(probe: directProbe)
            .navigationDestination(isPresented: isPresented) {
                CapturedNavigationActionsView(probe: presentedProbe)
            }
    }
}

struct NavigationRootDismissActionView: View {

    var body: some View {
        NavigationStack {
            NavigationDismissActionDestination(label: "Dismiss")
        }
    }
}

struct NavigationCapturedPresentedDismissActionView: View {

    let isPresented: Binding<Bool>

    let probe: DismissActionProbe

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationCapturedDismissActionDestination(probe: probe)
                }
        }
    }
}

struct NavigationCapturedPresentedNavigationActionsView: View {

    let isPresented: Binding<Bool>

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    CapturedNavigationActionsView(probe: probe)
                }
        }
    }
}

struct NavigationCapturedPresentedNavigationPathActionsView: View {

    let isPresented: Binding<Bool>

    let path: Binding<[Int]>

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    CapturedNavigationActionsView(probe: probe)
                }
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

struct NavigationCapturedDismissActionDestination: View {

    @Environment(\.dismiss) private var dismiss

    let probe: DismissActionProbe

    var body: some View {
        CapturedDismissAction(dismiss: dismiss, probe: probe)
    }
}

struct CapturedDismissAction: View {

    init(dismiss: DismissAction, probe: DismissActionProbe) {
        probe.capture(dismiss)
    }

    var body: some View {
        NavigationDismissActionDestination(label: "Close")
    }
}

struct NavigationDismissActionDestination: View {

    @Environment(\.dismiss) private var dismiss

    let label: String

    var body: some View {
        Text(label)
            .onTapGesture {
                dismiss()
            }
    }
}

final class DismissActionProbe {

    var dismiss: DismissAction?

    func capture(_ dismiss: DismissAction) {
        self.dismiss = dismiss
    }
}

final class NavigationActionProbe {

    var push: PushAction?

    var pop: PopAction?

    var dismiss: DismissAction?

    func capture(push: PushAction, pop: PopAction, dismiss: DismissAction) {
        self.push = push
        self.pop = pop
        self.dismiss = dismiss
    }
}

struct CapturedNavigationActionsView: View {

    @Environment(\.push) private var push

    @Environment(\.pop) private var pop

    @Environment(\.dismiss) private var dismiss

    let probe: NavigationActionProbe

    var body: some View {
        CapturedNavigationActions(push: push, pop: pop, dismiss: dismiss, probe: probe)
    }
}

struct CapturedNavigationActions: View {

    init(push: PushAction, pop: PopAction, dismiss: DismissAction, probe: NavigationActionProbe) {
        probe.capture(push: push, pop: pop, dismiss: dismiss)
    }

    var body: some View {
        Text("A")
    }
}
