import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Container Values")
struct ContainerValuesTests {

    @Test
    func `a copied collection can change without mutating its source`() {
        var source = ContainerValues()
        source.rank = 1
        var copy = source

        copy.rank = 2

        #expect(source.rank == 1)
        #expect(copy.rank == 2)
    }

    @Test
    func `an optional custom value preserves nil instead of restoring its default`() {
        var values = ContainerValues()

        values.optionalCount = nil

        #expect(values.optionalCount == nil)
    }

    @Test
    func `custom values use defaults and remain independent between sibling subviews`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            Text("A")
                .containerValue(\.rank, 4)
            Text("B")
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots.map(\.rank) == [4, 0])
    }

    @Test
    func `nested key paths preserve independently assigned fields`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            Text("A")
                .containerValue(\.metadata.leading, 2)
                .containerValue(\.metadata.trailing, 3)
                .containerValue(\.rank, 1)
                .containerValue(\.rank, 5)
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots[0].rank == 5)
        #expect(probe.snapshots[0].metadata == ContainerMetadata(leading: 2, trailing: 3))
    }

    @Test
    func `custom values pass through a view body AnyView padding and frame`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            AnyView(
                ContainerValueWrapper {
                    Text("A")
                        .containerValue(\.rank, 6)
                        .containerValue(\.metadata.leading, 2)
                }
            )
            .padding()
            .frame(width: 3, height: 3)
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots[0].rank == 6)
        #expect(probe.snapshots[0].metadata.leading == 2)
    }

    @Test
    func `container values stop at stack and custom layout boundaries`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            HStack {
                Text("A")
                    .containerValue(\.rank, 1)
            }
            ContainerBoundaryLayout {
                Text("B")
                    .containerValue(\.rank, 2)
            }
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots.map(\.rank) == [0, 0])
    }

    @Test
    func `a value set on a container is visible to its parent layout`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            HStack {
                Text("A")
                    .containerValue(\.rank, 1)
            }
            .containerValue(\.rank, 7)
            ContainerBoundaryLayout {
                Text("B")
                    .containerValue(\.rank, 2)
            }
            .containerValue(\.rank, 8)
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots.map(\.rank) == [7, 8])
    }

    @Test
    func `tag lookup matches both the tag type and value`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            Text("A")
                .tag(1)
        }

        _ = ViewResolver.block(from: view)

        let snapshot = probe.snapshots[0]
        #expect(snapshot.intTag == 1)
        #expect(snapshot.stringTag == nil)
        #expect(snapshot.hasIntOne)
        #expect(!snapshot.hasIntTwo)
        #expect(!snapshot.hasStringOne)
    }

    @Test
    func `tag includes the matching optional type by default`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            Text("A")
                .tag(7)
        }

        _ = ViewResolver.block(from: view)

        let optionalTag = probe.snapshots[0].optionalIntTag
        #expect(optionalTag != nil)
        #expect(optionalTag! == 7)
    }

    @Test
    func `tag can omit the matching optional type`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            Text("A")
                .tag(7, includeOptional: false)
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots[0].intTag == 7)
        #expect(probe.snapshots[0].optionalIntTag == nil)
    }

    @Test
    func `an optional nil tag remains distinct from an absent tag`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            Text("A")
                .tag(nil as Int?, includeOptional: false)
        }

        _ = ViewResolver.block(from: view)

        let optionalTag = probe.snapshots[0].optionalIntTag
        #expect(optionalTag != nil)
        #expect(optionalTag! == nil)
        #expect(probe.snapshots[0].hasOptionalIntNil)
    }

    @Test
    func `different tag types coexist and the outer tag replaces the same type`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            Text("A")
                .tag(1)
                .tag("one")
                .tag(2)
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots[0].intTag == 2)
        #expect(probe.snapshots[0].stringTag == "one")
        #expect(probe.snapshots[0].optionalIntTag! == 2)
        #expect(probe.snapshots[0].optionalStringTag! == "one")
    }

    @Test
    func `tags stop at a layout container boundary`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            HStack {
                Text("A")
                    .tag(1)
            }
            HStack {
                Text("B")
                    .tag(2)
            }
            .tag(3)
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots[0].intTag == nil)
        #expect(probe.snapshots[1].intTag == 3)
    }

    @Test
    func `ForEach element IDs are not exposed as container value tags`() {
        let probe = ContainerValuesProbe()
        let view = ContainerValuesProbeLayout(probe: probe) {
            ForEach([1, 2], id: \.self) {
                Text("\($0)")
            }
        }

        _ = ViewResolver.block(from: view)

        #expect(probe.snapshots.count == 2)
        #expect(probe.snapshots.allSatisfy { $0.intTag == nil })
        #expect(probe.snapshots.allSatisfy { $0.optionalIntTag == nil })
    }
}

private nonisolated struct ContainerMetadata: Equatable, Sendable {

    var leading = 0

    var trailing = 0
}

private nonisolated enum RankContainerValueKey: ContainerValueKey {

    static let defaultValue = 0
}

private nonisolated enum MetadataContainerValueKey: ContainerValueKey {

    static let defaultValue = ContainerMetadata()
}

private nonisolated enum OptionalCountContainerValueKey: ContainerValueKey {

    static let defaultValue: Int? = 9
}

private extension ContainerValues {

    nonisolated var rank: Int {
        get {
            self[RankContainerValueKey.self]
        }
        set {
            self[RankContainerValueKey.self] = newValue
        }
    }

    nonisolated var metadata: ContainerMetadata {
        get {
            self[MetadataContainerValueKey.self]
        }
        set {
            self[MetadataContainerValueKey.self] = newValue
        }
    }

    nonisolated var optionalCount: Int? {
        get {
            self[OptionalCountContainerValueKey.self]
        }
        set {
            self[OptionalCountContainerValueKey.self] = newValue
        }
    }
}

private nonisolated struct ContainerValuesSnapshot: Sendable {

    let rank: Int

    let metadata: ContainerMetadata

    let intTag: Int?

    let optionalIntTag: Int??

    let stringTag: String?

    let optionalStringTag: String??

    let hasIntOne: Bool

    let hasIntTwo: Bool

    let hasStringOne: Bool

    let hasOptionalIntNil: Bool

    init(_ values: ContainerValues) {
        rank = values.rank
        metadata = values.metadata
        intTag = values.tag(for: Int.self)
        optionalIntTag = values.tag(for: Optional<Int>.self)
        stringTag = values.tag(for: String.self)
        optionalStringTag = values.tag(for: Optional<String>.self)
        hasIntOne = values.hasTag(1)
        hasIntTwo = values.hasTag(2)
        hasStringOne = values.hasTag("one")
        hasOptionalIntNil = values.hasTag(nil as Int?)
    }
}

private nonisolated final class ContainerValuesProbe: @unchecked Sendable {

    var snapshots: [ContainerValuesSnapshot] = []
}

private nonisolated struct ContainerValuesProbeLayout: Layout {

    let probe: ContainerValuesProbe

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        probe.snapshots = subviews.map {
            ContainerValuesSnapshot($0.containerValues)
        }
        let sizes = subviews.map {
            $0.sizeThatFits(.unspecified)
        }
        return Size(
            columns: sizes.reduce(0) { $0 + $1.columns },
            rows: sizes.map(\.rows).max() ?? 0
        )
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var column = bounds.origin.column
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            subview.place(
                at: Point(column: column, row: bounds.origin.row),
                proposal: ProposedViewSize(size)
            )
            column += size.columns
        }
    }
}

private nonisolated struct ContainerBoundaryLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        subviews[0].sizeThatFits(proposal)
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews[0].place(
            at: bounds.origin,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}

private struct ContainerValueWrapper<Content: View>: View {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}
