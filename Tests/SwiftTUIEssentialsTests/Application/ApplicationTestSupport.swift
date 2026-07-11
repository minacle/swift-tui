import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

struct TerminateStatusView: View {

    @State var status = "running"

    var body: some View {
        Text(status)
            .onTerminate {
                status = "interrupted"
            }
    }
}

@Observable
final class ObservableTerminateNavigationModel {

    var path: [NavigationPushDestination] = []
}

struct ObservableTerminateNavigationView: View {

    @State private var model = ObservableTerminateNavigationModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            Text("main")
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("confirm quit")
                    }
                }
        }
        .onTerminate {
            model.path.append(.detail)
        }
    }
}

struct EnvironmentBackedTerminateView: View {

    @Environment(\.terminate) private var terminate

    var body: some View {
        Text("A")
            .onTerminate {
                terminate()
            }
    }
}

struct CapturedTerminateActionView: View {

    @Environment(\.terminate) private var terminate

    let probe: TerminateActionProbe

    var body: some View {
        CapturedTerminateAction(action: terminate, probe: probe)
    }
}

struct CapturedTerminateAction: View {

    init(action: TerminateAction, probe: TerminateActionProbe) {
        probe.capture(action)
    }

    var body: some View {
        Text("A")
    }
}

struct CapturedClipboardActionsView: View {

    @Environment(\.copy) private var copy

    @Environment(\.paste) private var paste

    let probe: ClipboardActionProbe

    var body: some View {
        CapturedClipboardActions(copy: copy, paste: paste, probe: probe)
    }
}

struct CapturedClipboardActions: View {

    init(copy: CopyAction, paste: PasteAction, probe: ClipboardActionProbe) {
        probe.capture(copy: copy, paste: paste)
    }

    var body: some View {
        Text("A")
    }
}

struct ForEachStateView: View {

    let items: [ForEachTestItem]

    let probe: LabeledBindingProbe

    var body: some View {
        ForEach(items, id: \.id) { item in
            LabeledChildCounterView(label: item.id, probe: probe)
        }
    }
}

struct ForEachTapView: View {

    let items: [ForEachTestItem]

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.id) { item in
                Text(item.label)
                    .onTapGesture {
                        tapProbe.record(item.id)
                    }
            }
        }
    }
}

struct ForEachButtonView: View {

    let items: [ForEachTestItem]

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.id) { item in
                Button(action: {
                    tapProbe.record(item.id)
                }) {
                    Text(item.label)
                }
            }
        }
    }
}
