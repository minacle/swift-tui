import Testing
@testable import SwiftTUIEssentials

@Suite("View Rendering")
struct ViewRendererTests {

    @Test
    func `an intrinsic render reports content-local size lines and plain text`() {
        let output = ViewRenderer.render(Text("Hello"))

        #expect(output.size == Size(columns: 5, rows: 1))
        #expect(output.lines == ["Hello"])
        #expect(output.text == "Hello")
    }

    @Test
    func `a finite column proposal wraps text without padding to the proposed rows`() {
        let output = ViewRenderer.render(
            Text("ABCDEF"),
            proposedSize: ProposedViewSize(columns: 5, rows: 10)
        )

        #expect(output.size == Size(columns: 5, rows: 2))
        #expect(output.lines == ["ABCDE", "F    "])
        #expect(output.text == "ABCDE\nF    ")
    }

    @Test
    func `an empty view produces zero size and empty output`() {
        let output = ViewRenderer.render(EmptyView())

        #expect(output.size == .zero)
        #expect(output.lines.isEmpty)
        #expect(output.text.isEmpty)
        #expect(output.ansiText.isEmpty)
    }

    @Test
    func `plain text omits styling while ANSI text wraps every supported style in SGR`() {
        let output = ViewRenderer.render(
            Text("A")
                .bold()
                .dim()
                .italic()
                .underline()
                .strikethrough()
                .foregroundStyle(.brightCyan)
                .background(.blue)
        )

        #expect(output.text == "A")
        #expect(
            output.ansiText
                == "\u{001B}[1m\u{001B}[2m\u{001B}[3m\u{001B}[4m\u{001B}[9m"
                + "\u{001B}[96m\u{001B}[44m"
                + "A"
                + "\u{001B}[22m\u{001B}[23m\u{001B}[24m\u{001B}[29m"
                + "\u{001B}[39m\u{001B}[49m"
        )
    }

    @Test
    func `ANSI output materializes layout gaps and rows without screen or cursor controls`() {
        let output = ViewRenderer.render(
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text("A")
                    Text("B")
                }
                Text("C")
            }
        )

        #expect(output.lines == ["A   B", "", "C    "])
        #expect(output.ansiText == "A   B\n\nC    ")
        #expect(!output.ansiText.contains("\u{001B}[2J"))
        #expect(!output.ansiText.contains("\u{001B}[?25"))
        #expect(!output.ansiText.contains("\u{001B}]"))
    }

    @Test
    func `a framed view preserves trailing spaces and empty rows without a final line feed`() {
        let output = ViewRenderer.render(
            Text("A").frame(width: 3, height: 3)
        )

        #expect(output.size == Size(columns: 3, rows: 3))
        #expect(output.lines == ["   ", " A ", "   "])
        #expect(output.text == "   \n A \n   ")
        #expect(output.ansiText == output.text)
        #expect(!output.text.hasSuffix("\n"))
        #expect(!output.ansiText.hasSuffix("\n"))
    }

    @Test
    func `a one-shot render does not run onAppear or initial onChange actions`() {
        var actions: [String] = []
        let view = Text("A")
            .onAppear {
                actions.append("appear")
            }
            .onChange(of: 1, initial: true) {
                actions.append("change")
            }

        _ = ViewRenderer.render(view)

        #expect(actions.isEmpty)
    }

    @Test
    func `a one-shot render does not start view tasks`() async {
        let probe = ViewTaskStartProbe()
        let view = Text("A")
            .task {
                probe.started = true
            }

        _ = ViewRenderer.render(view)
        await Task.yield()

        #expect(!probe.started)
    }

    @Test
    func `State supplies its wrapper-local fallback value during a one-shot render`() {
        let output = ViewRenderer.render(StateFallbackView())

        #expect(output.text == "fallback")
    }

    @Test
    func `ProposedViewSize max reaches a custom root Layout without normalization`() {
        let output = ViewRenderer.render(
            MaximumProposalLayout() {
                Text("A")
            },
            proposedSize: .max
        )

        #expect(output.size == Size(columns: 1, rows: 1))
        #expect(output.text == "A")
    }

    @Test
    func `rendered text preserves embedded terminal control characters`() {
        let text = "\u{001B}[31munsafe\u{001B}[0m"
        let output = ViewRenderer.render(Text(text))

        #expect(output.text == text)
        #expect(output.ansiText == text)
    }
}

private final class ViewTaskStartProbe {

    var started = false
}

private struct StateFallbackView: View {

    @State private var value = "fallback"

    var body: some View {
        Text(value)
    }
}

private struct MaximumProposalLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> Size {
        Size(
            columns: proposal.columns == Int.max ? 1 : 0,
            rows: proposal.rows == Int.max ? 1 : 0
        )
    }

    func placeSubviews(
        in bounds: Rect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(at: bounds.origin, proposal: .unspecified)
    }
}
