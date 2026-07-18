import Foundation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Lazy Stack Materialization")
struct LazyStackMaterializationTests {

    @Test
    func `a vertical lazy stack creates only its viewport and adjacent rows`() {
        let probe = LazyRowProbe()
        let runtime = StateRuntime()
        let view = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<1_000) { index in
                    ProbedLazyRow(index: index, probe: probe)
                }
            }
        }
        .frame(width: 3, height: 3)

        let block = runtime.block(from: view)
        let created = Set(probe.createdIndices)

        #expect(block?.trimmedLines == ["0", "1", "2"])
        #expect(created.contains(0))
        #expect(created.count <= 5)
        #expect(!created.contains(10))
    }

    @Test
    func `a horizontal lazy stack creates only its viewport and adjacent columns`() {
        let probe = LazyRowProbe()
        let runtime = StateRuntime()
        let view = ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(0..<1_000) { index in
                    ProbedLazyRow(index: index, probe: probe)
                }
            }
        }
        .frame(width: 3, height: 1)

        let block = runtime.block(from: view)
        let created = Set(probe.createdIndices)

        #expect(block?.lines == ["012"])
        #expect(created.contains(0))
        #expect(created.count <= 5)
        #expect(!created.contains(10))
    }

    @Test
    func `a flexible vertical ScrollView materializes only the lazy viewport window in a VStack`() {
        let probe = LazyRowProbe()
        let runtime = StateRuntime()
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("H")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<1_000) { index in
                        ProbedLazyRow(index: index, probe: probe)
                    }
                }
            }
        }
        .frame(width: 3, height: 4)

        let block = runtime.block(from: view)
        let created = Set(probe.createdIndices)

        #expect(block?.trimmedLines == ["H", "0", "1", "2"])
        #expect(created.contains(0))
        #expect(created.count <= 5)
        #expect(!created.contains(10))
    }

    @Test
    func `a flexible horizontal ScrollView materializes only the lazy viewport window in an HStack`() {
        let probe = LazyRowProbe()
        let runtime = StateRuntime()
        let view = HStack(alignment: .top, spacing: 0) {
            Text("H")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(0..<1_000) { index in
                        ProbedLazyRow(index: index, probe: probe)
                    }
                }
            }
        }
        .frame(width: 4, height: 1)

        let block = runtime.block(from: view)
        let created = Set(probe.createdIndices)

        #expect(block?.lines == ["H012"])
        #expect(created.contains(0))
        #expect(created.count <= 5)
        #expect(!created.contains(10))
    }

    @Test
    func `a flexible lazy viewport materializes the same window for one hundred and one thousand rows`() {
        let shortProbe = LazyRowProbe()
        let longProbe = LazyRowProbe()
        let shortRuntime = StateRuntime()
        let longRuntime = StateRuntime()
        let shortView = FlexibleLazyRows(count: 100, probe: shortProbe)
        let longView = FlexibleLazyRows(count: 1_000, probe: longProbe)

        _ = shortRuntime.block(from: shortView)
        _ = longRuntime.block(from: longView)

        #expect(Set(shortProbe.createdIndices).count == Set(longProbe.createdIndices).count)
        #expect(Set(longProbe.createdIndices).count <= 5)
    }

    @Test
    func `multiple flexible lazy ScrollViews share the VStack remainder after fixed content and spacing`() {
        let firstProbe = LazyRowProbe()
        let secondProbe = LazyRowProbe()
        let runtime = StateRuntime()
        let view = VStack(alignment: .leading) {
            Text("H")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<1_000) { index in
                        ProbedLazyRow(index: index, probe: firstProbe)
                    }
                }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<1_000) { index in
                        ProbedLazyRow(index: index, probe: secondProbe)
                    }
                }
            }
        }
        .frame(width: 3, height: 9)

        let block = runtime.block(from: view)

        #expect(block?.trimmedLines == ["H", "", "0", "1", "2", "", "0", "1", "2"])
        #expect(block?.scrollRegions.map(\.frame) == [
            RenderedRect(x: 0, y: 2, width: 3, height: 3),
            RenderedRect(x: 0, y: 6, width: 3, height: 3),
        ])
        #expect(Set(firstProbe.createdIndices).count <= 10)
        #expect(Set(secondProbe.createdIndices).count <= 10)
    }

    @Test
    func `a zero viewport creates no lazy rows while an unbounded ScrollView resolves every row eagerly`() {
        let zeroProbe = LazyRowProbe()
        let unboundedProbe = LazyRowProbe()
        let zeroRuntime = StateRuntime()
        let unboundedRuntime = StateRuntime()
        let zeroView = ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<10) { index in
                    ProbedLazyRow(index: index, probe: zeroProbe)
                }
            }
        }
        .frame(width: 2, height: 0)
        let unboundedView = ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<10) { index in
                    ProbedLazyRow(index: index, probe: unboundedProbe)
                }
            }
        }

        let zeroBlock = zeroRuntime.block(from: zeroView)
        let unboundedBlock = unboundedRuntime.block(
            from: unboundedView,
            in: RenderProposal(columns: 2)
        )

        #expect(zeroBlock?.height == 0)
        #expect(zeroProbe.createdIndices.isEmpty)
        #expect(unboundedBlock?.trimmedLines == (0..<10).map(String.init))
        #expect(Set(unboundedProbe.createdIndices) == Set(0..<10))
    }

    @Test
    func `ScrollViewReader jumps to a distant ForEach ID without creating intermediate rows`() {
        let probe = LazyRowProbe()
        let runtime = StateRuntime()
        let view = LazyReaderView(probe: probe)

        #expect(runtime.block(from: view)?.trimmedLines == ["go", "0", "1", "2"])
        probe.createdIndices = []
        dispatchButtonClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())

        let block = runtime.block(from: view)
        let created = Set(probe.createdIndices)

        #expect(block?.trimmedLines == ["go", "900", "901", "902"])
        #expect(created.contains(900))
        #expect(created.allSatisfy { (899...903).contains($0) })
    }

    @Test
    func `an offscreen ForEach row keeps state while lifecycle follows visibility`() {
        var position = ScrollPosition(y: 0)
        let probe = LazyStateProbe()
        let runtime = StateRuntime()
        let view = ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<1_000) { index in
                    StatefulLazyRow(index: index, probe: probe)
                }
            }
        }
        .scrollPosition(
            Binding(
                get: {position},
                set: {position = $0}
            )
        )
        .frame(width: 2, height: 2)

        _ = runtime.block(from: view)
        let initialToken = probe.tokens[0]
        #expect(initialToken != nil)
        #expect(probe.appearedIndices.contains(0))

        position = ScrollPosition(y: 900)
        _ = runtime.block(from: view)
        #expect(probe.disappearedIndices.contains(0))

        position = ScrollPosition(y: 0)
        _ = runtime.block(from: view)
        #expect(probe.tokens[0] == initialToken)
        #expect(probe.appearedIndices.filter { $0 == 0 }.count == 2)
    }

    @Test
    func `a bottom edge follows lazy content changes without invoking its binding setter`() {
        var position = ScrollPosition(edge: .bottom)
        var setterCallCount = 0
        let runtime = StateRuntime()
        let binding = Binding(
            get: {position},
            set: {
                setterCallCount += 1
                position = $0
            }
        )

        let initial = ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<3) { index in
                    Text("\(index)")
                }
            }
        }
        .scrollPosition(binding)
        .frame(width: 1, height: 2)
        let expanded = ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<4) { index in
                    Text("\(index)")
                }
            }
        }
        .scrollPosition(binding)
        .frame(width: 1, height: 2)

        #expect(runtime.block(from: initial)?.lines == ["1", "2"])
        #expect(runtime.block(from: expanded)?.lines == ["2", "3"])
        #expect(position.edge == .bottom)
        #expect(setterCallCount == 0)
    }

    @Test
    func `ScrollViewReader uses ForEach identity in an eager stack without an explicit ID`() {
        let runtime = StateRuntime()
        let view = EagerForEachReaderView()

        #expect(runtime.block(from: view)?.trimmedLines == ["go", "0", "1"])
        dispatchButtonClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.trimmedLines == ["go", "2", "3"])
    }

    @Test
    func `a ForEach of sections constructs only the section intersecting the viewport`() {
        let probe = LazySectionProbe()
        let runtime = StateRuntime()
        let view = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<100) { section in
                    Section {
                        ForEach(0..<5) { row in
                            ProbedLazyRow(index: section * 10 + row, probe: probe.rows)
                        }
                    } header: {
                        ProbedSectionHeader(section: section, probe: probe)
                    } footer: {
                        Text("F\(section)")
                    }
                }
            }
        }
        .frame(width: 3, height: 3)

        _ = runtime.block(from: view)

        #expect(Set(probe.constructedSections) == [0])
        #expect(Set(probe.rows.createdIndices).allSatisfy { (0...3).contains($0) })
    }
}

@MainActor
private final class LazyRowProbe {

    var createdIndices: [Int] = []
}

@MainActor
private struct ProbedLazyRow: View {

    let index: Int

    let probe: LazyRowProbe

    var body: some View {
        probe.createdIndices.append(index)
        return Text("\(index)")
    }
}

@MainActor
private struct FlexibleLazyRows: View {

    let count: Int

    let probe: LazyRowProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("H")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<count) { index in
                        ProbedLazyRow(index: index, probe: probe)
                    }
                }
            }
        }
        .frame(width: 3, height: 4)
    }
}

@MainActor
private struct LazyReaderView: View {

    let probe: LazyRowProbe

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Button("go") {
                    proxy.scrollTo(900, anchor: .top)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<1_000) { index in
                            ProbedLazyRow(index: index, probe: probe)
                        }
                    }
                }
                .frame(width: 3, height: 3)
            }
        }
    }
}

@MainActor
private struct EagerForEachReaderView: View {

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Button("go") {
                    proxy.scrollTo(3, anchor: .top)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<4) { index in
                            Text("\(index)")
                        }
                    }
                }
                .frame(width: 1, height: 2)
            }
        }
    }
}

@MainActor
private final class LazySectionProbe {

    let rows = LazyRowProbe()

    var constructedSections: [Int] = []
}

@MainActor
private struct ProbedSectionHeader: View {

    let section: Int

    let probe: LazySectionProbe

    init(section: Int, probe: LazySectionProbe) {
        self.section = section
        self.probe = probe
        probe.constructedSections.append(section)
    }

    var body: some View {
        Text("H\(section)")
    }
}

@MainActor
private final class LazyStateProbe {

    var appearedIndices: [Int] = []

    var disappearedIndices: [Int] = []

    var tokens: [Int: UUID] = [:]
}

@MainActor
private struct StatefulLazyRow: View {

    @State
    private var token = UUID()

    let index: Int

    let probe: LazyStateProbe

    var body: some View {
        probe.tokens[index] = token
        return Text("\(index)")
            .onAppear {
                probe.appearedIndices.append(index)
            }
            .onDisappear {
                probe.disappearedIndices.append(index)
            }
    }
}
