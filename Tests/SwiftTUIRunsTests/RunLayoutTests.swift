import Terminal
import Testing
@testable import SwiftTUIRuns

@Suite("Run Layout")
struct RunLayoutTests {

    @Test
    func `metrics report emergency width mandatory-line width and unwrapped rows`() {
        let metrics = RunGroup("A界\nBC").measure()

        #expect(metrics.minimumContentColumns == 2)
        #expect(metrics.maximumContentColumns == 3)
        #expect(metrics.unwrappedRows == 2)
    }

    @Test
    func `wrapping crosses input run boundaries without creating an artificial break`() {
        let group = RunGroup {
            Run("hel")
            Run("lo world")
        }

        #expect(group.layout(fittingColumns: 7).lines.map { $0.runs.map(\.content).joined() } == [
            "hello",
            "world",
        ])
    }

    @Test
    func `layout splits attributes and source ranges at row boundaries`() {
        let group = RunGroup {
            Run("ab").bold()
            Run("cd").italic()
        }
        let layout = group.layout(fittingColumns: 3)

        #expect(layout.size == Size(columns: 3, rows: 2))
        #expect(layout.lines[0].runs.map(\.content) == ["ab", "c"])
        #expect(layout.lines[0].runs[0].attributes.isBold == true)
        #expect(layout.lines[0].runs[1].attributes.isItalic == true)
        #expect(layout.lines[0].sourceRange == RunIndex(characterOffset: 0)..<RunIndex(characterOffset: 3))
        #expect(layout.lines[1].runs.map(\.content) == ["d"])
        #expect(layout.lines[1].sourceRange == RunIndex(characterOffset: 3)..<RunIndex(characterOffset: 4))
    }

    @Test
    func `a grapheme spanning run boundaries keeps later character attributes aligned`() {
        let group = RunGroup {
            Run("e").bold()
            Run("\u{0301}").italic()
            Run("X").underline()
        }
        let layout = group.layout()

        #expect(layout.lines[0].runs.map(\.content) == ["e\u{0301}", "X"])
        #expect(layout.lines[0].runs[0].attributes.isBold == true)
        #expect(layout.lines[0].runs[1].attributes.isUnderline == true)
    }

    @Test
    func `empty consecutive and trailing mandatory lines remain in the layout`() {
        let emptyLayout = RunGroup("").layout()
        let layout = RunGroup("\n\n").layout()

        #expect(emptyLayout.size == Size(columns: 0, rows: 1))
        #expect(emptyLayout.lines.count == 1)
        #expect(layout.size == Size(columns: 0, rows: 3))
        #expect(layout.lines.count == 3)
        #expect(layout.lines.allSatisfy { $0.runs.isEmpty && $0.columns == 0 })
        #expect(layout.lines.map(\.sourceRange) == [
            RunIndex(characterOffset: 0)..<RunIndex(characterOffset: 0),
            RunIndex(characterOffset: 1)..<RunIndex(characterOffset: 1),
            RunIndex(characterOffset: 2)..<RunIndex(characterOffset: 2),
        ])
    }

    @Test
    func `point and index map wide and wrapped insertion positions in both directions`() {
        let layout = RunGroup("A界B").layout(fittingColumns: 3)

        #expect(layout.point(at: RunIndex(characterOffset: 0)) == Point(column: 0, row: 0))
        #expect(layout.point(at: RunIndex(characterOffset: 2)) == Point(column: 0, row: 1))
        #expect(layout.index(at: Point(column: 2, row: 0)) == RunIndex(characterOffset: 1))
        #expect(layout.index(at: Point(column: 99, row: 99)) == RunIndex(characterOffset: 3))
    }

    @Test
    func `a combining grapheme remains one indexed character with its displayed width`() {
        let layout = RunGroup("e\u{0301}").layout()

        #expect(layout.size == Size(columns: 1, rows: 1))
        #expect(layout.lines[0].sourceRange == RunIndex(characterOffset: 0)..<RunIndex(characterOffset: 1))
        #expect(layout.point(at: RunIndex(characterOffset: 1)) == Point(column: 1, row: 0))
    }

    @Test
    func `line range columns clamp to visible source and cross attribute boundaries`() {
        let layout = RunGroup {
            Run("x\n")
            Run("A").bold()
            Run("界").italic()
            Run("B").underline()
        }
        .layout()
        let line = layout.lines[1]

        #expect(
            line.columns(
                in: RunIndex(characterOffset: 0)..<RunIndex(characterOffset: 4)
            ) == 3
        )
        #expect(
            line.columns(
                in: RunIndex(characterOffset: 4)..<RunIndex(characterOffset: 99)
            ) == 1
        )
        #expect(
            line.columns(
                in: RunIndex(characterOffset: 0)..<RunIndex(characterOffset: 1)
            ) == 0
        )
    }

    @Test
    func `line prefix and suffix ranges fit whole graphemes and adjacent zero-width content`() {
        let line = RunGroup("A\u{200B}界").layout().lines[0]

        #expect(
            line.prefixRange(fittingColumns: 1)
                == RunIndex(characterOffset: 0)..<RunIndex(characterOffset: 2)
        )
        #expect(
            line.suffixRange(fittingColumns: 2)
                == RunIndex(characterOffset: 1)..<RunIndex(characterOffset: 3)
        )
        #expect(
            line.prefixRange(fittingColumns: 0)
                == RunIndex(characterOffset: 0)..<RunIndex(characterOffset: 0)
        )
        #expect(
            line.suffixRange(fittingColumns: -1)
                == RunIndex(characterOffset: 3)..<RunIndex(characterOffset: 3)
        )
        #expect(line.prefixRange(fittingColumns: 3) == line.sourceRange)
        #expect(line.suffixRange(fittingColumns: 3) == line.sourceRange)
    }

    @Test
    func `line character boundaries reject columns inside wide graphemes or outside the line`() {
        let line = RunGroup("A界").layout().lines[0]
        let emptyLine = RunGroup("").layout().lines[0]

        #expect(line.isCharacterBoundary(atColumn: 0))
        #expect(line.isCharacterBoundary(atColumn: 1))
        #expect(!line.isCharacterBoundary(atColumn: 2))
        #expect(line.isCharacterBoundary(atColumn: 3))
        #expect(!line.isCharacterBoundary(atColumn: -1))
        #expect(!line.isCharacterBoundary(atColumn: 4))
        #expect(emptyLine.isCharacterBoundary(atColumn: 0))
        #expect(!emptyLine.isCharacterBoundary(atColumn: 1))
        #expect(emptyLine.prefixRange(fittingColumns: 1).isEmpty)
        #expect(emptyLine.suffixRange(fittingColumns: 1).isEmpty)
    }

    @Test
    func `nonpositive fitting widths produce an empty layout`() {
        let layout = RunGroup("content").layout(fittingColumns: 0)

        #expect(layout.size == Size())
        #expect(layout.lines.isEmpty)
        #expect(layout.index(at: Point(column: 8, row: 2)) == RunIndex(characterOffset: 0))
    }
}
