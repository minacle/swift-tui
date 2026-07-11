import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

final class BindingProbe<Value> {

    var binding: Binding<Value>?

    func capture(_ binding: Binding<Value>) {
        self.binding = binding
    }
}

final class LabeledBindingProbe {

    var bindings: [String: Binding<Int>] = [:]

    func capture(_ binding: Binding<Int>, label: String) {
        bindings[label] = binding
    }
}

final class LabeledStringBindingProbe {

    var bindings: [String: Binding<String>] = [:]

    func capture(_ binding: Binding<String>, label: String) {
        bindings[label] = binding
    }
}

final class ObjectProbe<ObjectType: AnyObject> {

    var object: ObjectType?

    func capture(_ object: ObjectType) {
        self.object = object
    }
}

final class ObjectCreationProbe {

    private(set) var createdIDs: [Int] = []

    func nextID() -> Int {
        let id = createdIDs.count + 1
        createdIDs.append(id)
        return id
    }
}

@Observable
final class TestObservableModel {

    let id: Int

    var count: Int

    var unreadCount: Int

    var token: String

    init(count: Int = 0, token: String = "", creationProbe: ObjectCreationProbe? = nil) {
        self.id = creationProbe?.nextID() ?? 0
        self.count = count
        self.unreadCount = 0
        self.token = token
    }
}

final class FocusBindingProbe<Value: Hashable> {

    var binding: FocusState<Value>.Binding?

    func capture(_ binding: FocusState<Value>.Binding) {
        self.binding = binding
    }
}

final class KeyPressProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

final class TapGestureProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

struct PointerPressEvent: Equatable {

    var name: String

    var button: PointerButton

    var location: Point

    var modifiers: EventModifiers

    var phase: PointerPress.Phases
}

final class PointerPressProbe {

    var names: [String] = []

    var events: [PointerPressEvent] = []

    func record(_ name: String) {
        names.append(name)
    }

    func record(_ name: String, _ pointerPress: PointerPress) {
        names.append(name)
        events.append(
            PointerPressEvent(
                name: name,
                button: pointerPress.button,
                location: pointerPress.location,
                modifiers: pointerPress.modifiers,
                phase: pointerPress.phase
            )
        )
    }
}

final class HoverProbe {

    var events: [String] = []

    var phases: [HoverPhase] = []

    func record(_ event: String) {
        events.append(event)
    }

    func record(_ phase: HoverPhase) {
        phases.append(phase)
    }
}

struct TapLocationEvent: Equatable {

    var name: String

    var location: Point
}

final class TapLocationProbe {

    var events: [TapLocationEvent] = []

    func record(_ name: String, _ location: Point) {
        events.append(TapLocationEvent(name: name, location: location))
    }
}

final class LifecycleProbe {

    var events: [String] = []
}

@MainActor
final class AsyncTaskProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func waitForCount(_ count: Int) async {
        for _ in 0..<100 {
            if events.count >= count {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

final class TerminateActionProbe {

    var action: TerminateAction?

    func capture(_ action: TerminateAction) {
        self.action = action
    }
}

final class ClipboardActionProbe {

    var copy: CopyAction?

    var paste: PasteAction?

    func capture(copy: CopyAction, paste: PasteAction) {
        self.copy = copy
        self.paste = paste
    }
}

final class TerminalIOProbe {

    private var input: [UInt8]

    private var inputOffset = 0

    private(set) var output: [String] = []

    private(set) var timeouts: [TimeInterval?] = []

    init(input: [UInt8]) {
        self.input = input
    }

    func terminalIO() -> TerminalIO {
        TerminalIO(readByte: readByte(timeout:), write: write(_:))
    }

    private func readByte(timeout: TimeInterval?) -> UInt8? {
        timeouts.append(timeout)
        guard inputOffset < input.count else {
            return nil
        }

        defer {
            inputOffset += 1
        }
        return input[inputOffset]
    }

    private func write(_ value: String) {
        output.append(value)
    }
}

func osc52ClipboardResponse(
    _ text: String,
    terminator: String = "\u{001B}\\"
) -> [UInt8] {
    let payload = Data(text.utf8).base64EncodedString()
    return Array("\u{001B}]52;c;\(payload)\(terminator)".utf8)
}
