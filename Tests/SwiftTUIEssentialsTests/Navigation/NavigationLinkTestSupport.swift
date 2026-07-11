import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

struct FocusedDirectNavigationLinkView: View {

    @FocusState var isFocused: Bool = true

    private let title: String = "Open"

    var body: some View {
        NavigationStack {
            NavigationLink(title) {
                Text("Detail")
            }
            .focused($isFocused)
        }
    }
}

struct FocusedValueNavigationLinkView: View {

    @FocusState var isFocused: Bool = true

    let path: Binding<[Int]>

    private let title: String = "One"

    var body: some View {
        NavigationStack(path: path) {
            NavigationLink(title, value: 1)
                .focused($isFocused)
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

struct ValueNavigationPathView: View {

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

struct HeterogeneousNavigationPathView: View {

    let path: Binding<NavigationPath>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(for: Int.self) { value in
                    Text("Int \(value)")
                }
                .navigationDestination(for: String.self) { value in
                    Text("String \(value)")
                }
        }
    }
}

struct NilValueNavigationLinkView: View {

    @FocusState var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            NavigationLink("Missing", value: Optional<Int>.none)
                .focused($isFocused)
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

struct NavigationStateMutationView: View {

    @State var status = "empty"

    @FocusState var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink("Open") {
                    NavigationStateMutationDestination(status: $status)
                }
                .focused($isFocused)

                Text(status)
            }
        }
    }
}

struct NavigationStateMutationDestination: View {

    let status: Binding<String>

    var body: some View {
        Text("Destination \(status.wrappedValue)")
            .onTapGesture {
                status.wrappedValue = "updated"
            }
    }
}

struct NavigationDestinationStateResetView: View {

    @FocusState var isFocused: Bool = true

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            NavigationLink("Open", value: 1)
                .focused($isFocused)
                .navigationDestination(for: Int.self) { value in
                    NavigationStatefulDestination(value: value)
                }
        }
    }
}

struct NavigationStatefulDestination: View {

    let value: Int

    @State var count = 0

    var body: some View {
        Text("Value \(value) count \(count)")
            .onTapGesture {
                count += 1
            }
    }
}

struct NavigationPushValueView: View {

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            NavigationPushValueButton()
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

struct NavigationPushValueButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push(1)
                return .handled
            }
    }
}

enum NavigationPushDestination: Codable, Hashable, Sendable {

    case detail
}

struct NavigationPushChildRootDestinationView: View {

    let path: Binding<[NavigationPushDestination]>

    var body: some View {
        NavigationStack(path: path) {
            NavigationPushChildButton()
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("Detail")
                    }
                }
        }
    }
}

struct NavigationPushChildButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Button {
            push(NavigationPushDestination.detail)
        } label: {
            Text("Push")
        }
        .focused($isFocused)
    }
}

@Observable
final class NavigationPushObservablePathModel {

    var path: [NavigationPushDestination] = []
}

struct NavigationPushObservableObjectPathView: View {

    @State private var model = NavigationPushObservablePathModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            NavigationPushChildButton()
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("Detail")
                    }
                }
        }
    }
}

struct NavigationPushInitializedObservableObjectPathRootView: View {

    @State private var route = true

    var body: some View {
        Group {
            if route {
                NavigationPushInitializedObservableObjectPathView(
                    model: NavigationPushObservablePathModel()
                )
            }
        }
    }
}

struct NavigationPushInitializedObservableObjectPathView: View {

    @State private var model: NavigationPushObservablePathModel

    init(model: NavigationPushObservablePathModel) {
        self._model = State(wrappedValue: model)
    }

    var body: some View {
        NavigationStack(path: navigationPath) {
            NavigationPushChildButton()
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("Detail")
                    }
                }
        }
    }

    private var navigationPath: Binding<[NavigationPushDestination]> {
        Binding(
            get: {
                model.path
            },
            set: {
                model.path = $0
            }
        )
    }
}
