import Testing
@testable import SwiftTUIEssentials

@Suite("Pinned Lazy Stack Sections")
struct PinnedSectionTests {

    @Test
    func `a vertical section header stays at the top until its section ends`() {
        let view = ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 0,
                pinnedViews: [.sectionHeaders]
            ) {
                Section {
                    ForEach(0..<4) { index in
                        Text("R\(index)")
                    }
                } header: {
                    Text("H")
                } footer: {
                    Text("F")
                }
            }
        }
        .scrollPosition(.constant(ScrollPosition(y: 2)))
        .frame(width: 2, height: 3)

        #expect(ViewResolver.block(from: view)?.trimmedLines == ["H1", "R2", "R3"])
    }

    @Test
    func `a vertical section footer stays at the bottom while its section intersects the viewport`() {
        let view = ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 0,
                pinnedViews: [.sectionFooters]
            ) {
                Section {
                    ForEach(0..<4) { index in
                        Text("R\(index)")
                    }
                } header: {
                    Text("H")
                } footer: {
                    Text("F")
                }
            }
        }
        .frame(width: 2, height: 3)

        #expect(ViewResolver.block(from: view)?.trimmedLines == ["H", "R0", "F1"])
    }

    @Test
    func `horizontal section supplementary views pin to leading and trailing edges`() {
        let view = ScrollView(.horizontal) {
            LazyHStack(
                alignment: .top,
                spacing: 0,
                pinnedViews: [.sectionHeaders, .sectionFooters]
            ) {
                Section {
                    ForEach(0..<4) { index in
                        Text("\(index)")
                    }
                } header: {
                    Text("H")
                } footer: {
                    Text("F")
                }
            }
        }
        .scrollPosition(.constant(ScrollPosition(x: 2)))
        .frame(width: 3, height: 1)

        #expect(ViewResolver.block(from: view)?.lines == ["H2F"])
    }

    @Test
    func `an adjacent section bounds the preceding pinned header`() {
        let view = ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 0,
                pinnedViews: [.sectionHeaders]
            ) {
                Section {
                    Text("A")
                    Text("B")
                } header: {
                    Text("H0")
                }
                Section {
                    Text("C")
                    Text("D")
                } header: {
                    Text("H1")
                }
            }
        }
        .scrollPosition(.constant(ScrollPosition(y: 2)))
        .frame(width: 2, height: 2)

        #expect(ViewResolver.block(from: view)?.lines == ["H0", "H1"])
    }

    @Test
    func `a pinned header moves its hit and focus regions with its rendered cells`() {
        let runtime = StateRuntime()
        let view = ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 0,
                pinnedViews: [.sectionHeaders]
            ) {
                Section {
                    Text("A")
                    Text("B")
                    Text("C")
                } header: {
                    Text("H")
                        .onTapGesture {}
                        .focusable()
                }
            }
        }
        .scrollPosition(.constant(ScrollPosition(y: 2)))
        .frame(width: 1, height: 2)

        let block = runtime.block(from: view)

        #expect(block?.hitRegions.map(\.frame) == [RenderedRect(width: 1, height: 1)])
        #expect(block?.focusRegions.map(\.frame) == [RenderedRect(width: 1, height: 1)])
    }
}
