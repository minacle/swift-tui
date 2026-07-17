import Foundation
import SwiftTUI

@main
struct AppRunnerTestHost: App {

    private let scenario: AppRunnerTestScenario

    init() {
        scenario = AppRunnerTestScenario(
            rawValue: ProcessInfo.processInfo.environment["SWIFT_TUI_TEST_SCENARIO"] ?? ""
        ) ?? .idleTask

        if scenario == .terminalRestoration {
            FileHandle.standardOutput.write(Data("host-ready".utf8))
            _ = FileHandle.standardInput.readData(ofLength: 1)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRunnerTestView(scenario: scenario)
        }
    }
}

private enum AppRunnerTestScenario: String {

    case idleTask = "idle-task"

    case cancellableTask = "cancellable-task"

    case longPress = "long-press"

    case repeatedInput = "repeated-input"

    case resize

    case terminalRestoration = "terminal-restoration"
}

private struct AppRunnerTestView: View {

    let scenario: AppRunnerTestScenario

    @ViewBuilder
    var body: some View {
        switch scenario {
        case .idleTask, .terminalRestoration:
            IdleTaskView()
        case .cancellableTask:
            CancellableTaskView()
        case .longPress:
            LongPressView()
        case .repeatedInput:
            RepeatedInputView()
        case .resize:
            ResizeView()
        }
    }
}

private struct IdleTaskView: View {

    @Environment(\.terminate)
    private var terminate

    @State
    private var phase = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("idle")
            if phase >= 1 {
                Text("started")
            }
            if phase >= 2 {
                Text("resumed")
            }
        }
        .frame(width: 10, height: 3, alignment: .topLeading)
        .task {
            phase = 1
            await Task.yield()
            phase = 2
            terminate()
        }
    }
}

private struct CancellableTaskView: View {

    @Environment(\.terminate)
    private var terminate

    @FocusState
    private var isFocused = false

    @State
    private var requestID: Int?

    @State
    private var status = "ready"

    var body: some View {
        Text(status == "ready" && isFocused ? "focused" : status)
            .frame(width: 10, height: 1, alignment: .topLeading)
            .focusable()
            .focused($isFocused)
            .task(id: requestID) {
                guard requestID != nil else {
                    return
                }

                status = "running"
                do {
                    try await Task.sleep(for: .seconds(60))
                }
                catch is CancellationError {
                    status = "stopped"
                    await Task.yield()
                    terminate()
                }
                catch {
                    status = "failed"
                    terminate()
                }
            }
            .onKeyPress(.return) {
                requestID = 1
                return .handled
            }
            .onKeyPress(.escape) {
                requestID = nil
                return .handled
            }
    }
}

private struct RepeatedInputView: View {

    @Environment(\.terminate)
    private var terminate

    @FocusState
    private var isFocused = false

    @State
    private var count = 0

    var body: some View {
        let renderedCount = count
        recordRepeatedInput("render:\(renderedCount):focused:\(isFocused)")
        return Text("count:\(count)")
            .frame(width: 10, height: 1, alignment: .topLeading)
            .focusable()
            .focused($isFocused)
            .task {
                isFocused = true
            }
            .onKeyPress("a") {
                count += 1
                recordRepeatedInput("handled:\(count)")
                if count == 3 {
                    terminate()
                }
                return .handled
            }
    }
}

private struct LongPressView: View {

    @Environment(\.terminate)
    private var terminate

    @State
    private var status = "waiting"

    var body: some View {
        Text(status)
            .frame(width: 10, height: 1, alignment: .topLeading)
            .onLongPressGesture(minimumDuration: 0.05) {
                status = "completed"
                terminate()
            }
    }
}

private func recordRepeatedInput(_ message: String) {
    FileHandle.standardError.write(Data("[repeated-input]\(message)\n".utf8))
}

private struct ResizeView: View {

    @Environment(\.terminate)
    private var terminate

    var body: some View {
        GeometryReader { geometry in
            Text("\(geometry.columns)x\(geometry.rows)")
        }
        .onTerminate {
            terminate()
        }
    }
}
