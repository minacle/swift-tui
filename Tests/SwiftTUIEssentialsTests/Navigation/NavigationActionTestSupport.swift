import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

struct NavigationPushDirectDestinationView: View {

    var body: some View {
        NavigationStack {
            NavigationPushDirectDestinationButton()
        }
    }
}

struct NavigationPushDirectDestinationButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    Text("Detail")
                }
                return .handled
            }
    }
}

struct NavigationPushDirectStateMutationView: View {

    @State var status = "empty"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                NavigationPushDirectStateMutationButton(status: $status)
                Text(status)
            }
        }
    }
}

struct NavigationPushDirectStateMutationButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    let status: Binding<String>

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationStateMutationDestination(status: status)
                }
                return .handled
            }
    }
}

struct NavigationPushDirectStateResetView: View {

    var body: some View {
        NavigationStack {
            NavigationPushDirectStateResetButton()
        }
    }
}

struct NavigationPushDirectStateResetButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationPoppableStatefulDestination()
                }
                return .handled
            }
    }
}

struct NavigationPoppableStatefulDestination: View {

    @Environment(\.pop) private var pop

    @State var count = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Value count \(count)")
                .onTapGesture {
                    count += 1
                }

            Text("Back")
                .onTapGesture {
                    pop()
                }
        }
    }
}

struct NavigationPopValueView: View {

    @Environment(\.pop) private var pop

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .onTapGesture {
                    pop()
                }
                .navigationDestination(for: Int.self) { value in
                    NavigationPopValueDestination(value: value)
                }
        }
    }
}

struct NavigationPopValueDestination: View {

    @Environment(\.pop) private var pop

    let value: Int

    var body: some View {
        Text("Value \(value)")
            .onTapGesture {
                pop()
            }
    }
}
