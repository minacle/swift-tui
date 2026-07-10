import Foundation
import Observation
import Testing
@testable import SwiftTUI

struct IdentifiedTaskView: View {

    let id: Int

    let probe: AsyncTaskProbe

    var body: some View {
        Text("\(id)")
            .task(id: id) {
                probe.record("start \(id)")
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                }
                catch {
                    probe.record("cancel \(id)")
                }
            }
    }
}

struct ExplicitIDCounterHost: View {

    let id: Int

    var body: some View {
        ExplicitIDCounter()
            .id(id)
    }
}

struct ExplicitIDCounter: View {

    @State private var count = 0

    var body: some View {
        Text("\(count)")
            .onTapGesture {
                count += 1
            }
    }
}

struct ExplicitIDScrollHost: View {

    let id: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .frame(width: 1, height: 2)
        .id(id)
    }
}

struct ReaderScrollToBottomView: View {

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading) {
                Button("go") {
                    proxy.scrollTo("bottom")
                }
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("A")
                            .id("top")
                        Text("B")
                        Text("C")
                        Text("D")
                            .id("bottom")
                    }
                }
                .frame(width: 1, height: 2)
            }
        }
    }
}

struct ReaderAnchorScrollView: View {

    let anchor: UnitPoint

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading) {
                Button("go") {
                    proxy.scrollTo("target", anchor: anchor)
                }
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("A")
                        Text("B")
                        Text("C")
                            .id("target")
                        Text("D")
                    }
                }
                .frame(width: 1, height: 2)
            }
        }
    }
}

struct ReaderBindingScrollView: View {

    let position: Binding<ScrollPosition>

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading) {
                Button("go") {
                    proxy.scrollTo("target")
                }
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("A")
                        Text("B")
                        Text("C")
                            .id("target")
                        Text("D")
                    }
                }
                .scrollPosition(position)
                .frame(width: 1, height: 2)
            }
        }
    }
}

struct ReaderHorizontalScrollView: View {

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading) {
                Button("go") {
                    proxy.scrollTo("target")
                }
                ScrollView(.horizontal) {
                    HStack {
                        Text("A")
                        Text("B")
                        Text("C")
                            .id("target")
                        Text("D")
                    }
                }
                .frame(width: 2, height: 1)
            }
        }
    }
}

struct ReaderTwoAxisScrollView: View {

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading) {
                Button("go") {
                    proxy.scrollTo("target", anchor: .bottomTrailing)
                }
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading) {
                        Text("ABC")
                        Text("DEF")
                        Text("GHI")
                            .id("target")
                    }
                }
                .frame(width: 2, height: 2)
            }
        }
    }
}

struct ReaderMissingIDView: View {

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading) {
                Button("go") {
                    proxy.scrollTo("missing")
                }
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("A")
                        Text("B")
                        Text("C")
                    }
                }
                .frame(width: 1, height: 2)
            }
        }
    }
}

struct ReaderOutOfScopeView: View {

    var body: some View {
        VStack(alignment: .leading) {
            ScrollViewReader { proxy in
                Button("go") {
                    proxy.scrollTo("target")
                }
            }
            Text("X")
                .id("target")
            ScrollView {
                VStack(alignment: .leading) {
                    Text("A")
                    Text("B")
                    Text("C")
                        .id("target")
                }
            }
            .frame(width: 1, height: 2)
        }
    }
}
