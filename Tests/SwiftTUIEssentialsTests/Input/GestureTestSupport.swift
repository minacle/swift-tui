import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

struct DeferredParentStateMutationView: View {

    @State private var isOpen = false

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParentCallbackKeyPressChildView {
                isOpen = true
                message = "updated"
            }
            if isOpen {
                Text(message.isEmpty ? "empty" : message)
            }
            else {
                Text("idle")
            }
        }
    }
}

struct DeferredParentStateMutationWithExistingStringCellView: View {

    @State private var isOpen = false

    @State private var placeholder = ""

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParentCallbackKeyPressChildView {
                isOpen = true
                message = "updated"
            }
            if isOpen {
                Text(message.isEmpty ? "empty" : message)
            }
            else {
                Text(placeholder.isEmpty ? "empty" : placeholder)
            }
        }
    }
}

struct TapGestureStateMutationView: View {

    @State var count = 0

    var body: some View {
        Text(String(count))
            .onTapGesture {
                count += 1
            }
    }
}

struct PointerPressStateMutationView: View {

    @State var count = 0

    var body: some View {
        Text(String(count))
            .onPointerPress {
                count += 1
                return .handled
            }
    }
}

struct LongPressGestureStateMutationView: View {

    @State private var count = 0

    @State private var isPressing = false

    var body: some View {
        Text("\(count):\(isPressing)")
            .onLongPressGesture(
                minimumDuration: 0.1,
                perform: {
                    count += 1
                },
                onPressingChanged: {
                    isPressing = $0
                }
            )
    }
}

struct HoverGestureStateMutationView: View {

    @State private var isHovering = false

    @State private var count = 0

    var body: some View {
        Text("\(isHovering):\(count)")
            .onHover {
                isHovering = $0
            }
            .onContinuousHover { phase in
                if case .active = phase {
                    count += 1
                }
            }
    }
}

struct ParentCallbackDirectStateMutationTapView: View {

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParentCallbackTapChildView {
                message = "updated"
            }
            Text(message.isEmpty ? "empty" : message)
        }
    }
}

struct ParentCallbackDirectStateMutationLongPressView: View {

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParentCallbackLongPressChildView {
                message = "updated"
            }
            Text(message.isEmpty ? "empty" : message)
        }
    }
}

struct ParentCallbackDirectStateMutationHoverView: View {

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParentCallbackHoverChildView {
                message = "updated"
            }
            Text(message.isEmpty ? "empty" : message)
        }
    }
}

struct ParentCallbackTapChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Tap")
            .onTapGesture {
                action()
            }
    }
}

struct ParentCallbackLongPressChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Press")
            .onLongPressGesture(minimumDuration: 0.1) {
                action()
            }
    }
}

struct ParentCallbackHoverChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Hover")
            .onHover { isHovering in
                if isHovering {
                    action()
                }
            }
    }
}

struct StackTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                Text("A")
                    .onTapGesture {
                        tapProbe.record("left")
                    }
                Text("B")
                    .onTapGesture {
                        tapProbe.record("right")
                    }
            }
            Text("C")
                .onTapGesture {
                    tapProbe.record("bottom")
                }
        }
    }
}

struct NestedTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(spacing: 0) {
            Text("A")
                .onTapGesture {
                    tapProbe.record("child")
                }
        }
        .onTapGesture {
            tapProbe.record("parent")
        }
    }
}

struct CountedTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        Text("A")
            .onTapGesture(count: 3) {
                tapProbe.record("three")
            }
            .onTapGesture(count: 2) {
                tapProbe.record("two")
            }
            .onTapGesture(count: 1) {
                tapProbe.record("one")
            }
    }
}
