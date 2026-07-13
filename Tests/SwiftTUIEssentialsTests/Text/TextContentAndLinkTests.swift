import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Text Content, Attributes, and Links")
struct TextContentAndLinkTests {

    @Test
    func `a plain Text value exposes its original content`() {
        let text = Text("Hello")

        #expect(text.content == "Hello")
    }

    @Test
    func `Text renders nested RunGroup attributes with explicit child overrides`() {
        let text = Text(
            RunGroup {
                Run("A")
                RunGroup {
                    Run("B").bold(false)
                    Run("C")
                }
                .bold()
            }
            .foregroundColor(Color16.red)
        )

        #expect(ViewResolver.block(from: text)?.runs == [
            RenderedRun(
                text: "AB",
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(
                text: "C",
                column: 2,
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    isBold: true
                )
            ),
        ])
    }

    @Test
    func `Text keeps styles aligned after a grapheme crosses Run boundaries`() {
        let text = Text(
            RunGroup {
                Run("e").bold()
                Run("\u{0301}").italic()
                Run("X").underline()
            }
        )

        #expect(ViewResolver.block(from: text)?.runs == [
            RenderedRun(text: "e\u{0301}", style: TextStyle(isBold: true)),
            RenderedRun(text: "X", column: 1, style: TextStyle(isUnderline: true)),
        ])
    }

    @Test
    func `Text initializers preserve content from StringProtocol and AttributedString values`() {
        let string = ["Hel", "lo"].joined()
        let substring = string[string.startIndex..<string.index(string.startIndex, offsetBy: 4)]
        var attributed = AttributedString("Styled")
#if canImport(Darwin)
        attributed.inlinePresentationIntent = .stronglyEmphasized
#endif

        #expect(Text(string).content == "Hello")
        #expect(Text(substring).content == "Hell")
        #expect(Text(attributedContent: attributed).content == "Styled")
    }

#if canImport(Darwin)
    @Test
    func `attributed bold, italic, and strikethrough intents become matching rendered styles`() {
        var attributed = AttributedString("Bold Italic Strike")
        attributed[attributed.range(of: "Bold")!].inlinePresentationIntent = .stronglyEmphasized
        attributed[attributed.range(of: "Italic")!].inlinePresentationIntent = .emphasized
        attributed[attributed.range(of: "Strike")!].inlinePresentationIntent = .strikethrough

        let block = ViewResolver.block(from: Text(attributedContent: attributed))

        #expect(block?.runs == [
            RenderedRun(text: "Bold", style: TextStyle(isBold: true)),
            RenderedRun(text: " ", column: 4),
            RenderedRun(text: "Italic", column: 5, style: TextStyle(isItalic: true)),
            RenderedRun(text: " ", column: 11),
            RenderedRun(text: "Strike", column: 12, style: TextStyle(isStrikethrough: true)),
        ])
    }

    @Test
    func `attributed run styles merge with inherited foreground and italic styles`() {
        var attributed = AttributedString("Bold plain")
        attributed[attributed.range(of: "Bold")!].inlinePresentationIntent = .stronglyEmphasized

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed).foregroundStyle(.red).italic()
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "Bold",
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    isBold: true,
                    isItalic: true
                )
            ),
            RenderedRun(
                text: " plain",
                column: 4,
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.red),
                    isItalic: true
                )
            ),
        ])
    }
#endif

    @Test
    func `attributed foreground and background colors produce separate styled runs`() {
        var attributed = AttributedString("Red Blue")
        attributed.setSwiftTUIForegroundColor(
            .color16(.red),
            in: attributed.range(of: "Red")!
        )
        attributed.setSwiftTUIBackgroundColor(
            .trueColor(red: 1, green: 2, blue: 3),
            in: attributed.range(of: "Blue")!
        )

        let block = ViewResolver.block(from: Text(attributedContent: attributed))

        #expect(block?.runs == [
            RenderedRun(
                text: "Red",
                style: TextStyle(foregroundStyle: AnyColor(Color16.red))
            ),
            RenderedRun(text: " ", column: 3),
            RenderedRun(
                text: "Blue",
                column: 4,
                style: TextStyle(
                    backgroundStyle: AnyColor(TrueColor(red: 1, green: 2, blue: 3))
                )
            ),
        ])
    }

    @Test
    func `an attributed foreground color overrides inherited foregroundStyle`() {
        var attributed = AttributedString("Styled")
        attributed.setSwiftTUIForegroundColor(.color16(.green))

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed)
                .foregroundStyle(.red)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "Styled",
                style: TextStyle(foregroundStyle: AnyColor(Color16.green))
            ),
        ])
    }

#if canImport(Darwin)
    @Test
    func `wrapping preserves styles attached to attributed runs`() {
        var attributed = AttributedString("Alpha Beta")
        attributed[attributed.range(of: "Beta")!].inlinePresentationIntent = .stronglyEmphasized

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed),
            in: RenderProposal(columns: 5)
        )

        #expect(block?.runs == [
            RenderedRun(text: "Alpha", row: 0),
            RenderedRun(text: "Beta", row: 1, style: TextStyle(isBold: true)),
        ])
        #expect(block?.lines == ["Alpha", "Beta "])
    }
#endif

    @Test
    func `attributed alignment positions text within the proposed width`() {
        var left = AttributedString("A")
        left.setSwiftTUIAlignment(.left)
        var center = AttributedString("A")
        center.setSwiftTUIAlignment(.center)
        var right = AttributedString("A")
        right.setSwiftTUIAlignment(.right)

        let leftBlock = ViewResolver.block(
            from: Text(attributedContent: left),
            in: RenderProposal(columns: 5)
        )
        let centerBlock = ViewResolver.block(
            from: Text(attributedContent: center),
            in: RenderProposal(columns: 5)
        )
        let rightBlock = ViewResolver.block(
            from: Text(attributedContent: right),
            in: RenderProposal(columns: 5)
        )

        #expect(leftBlock?.runs == [RenderedRun(text: "A")])
        #expect(leftBlock?.lines == ["A    "])
        #expect(centerBlock?.runs == [RenderedRun(text: "A", column: 2)])
        #expect(centerBlock?.lines == ["  A  "])
        #expect(rightBlock?.runs == [RenderedRun(text: "A", column: 4)])
        #expect(rightBlock?.lines == ["    A"])
    }

    @Test
    func `an attributed string's alignment takes precedence over multilineTextAlignment`() {
        var attributed = AttributedString("A")
        attributed.setSwiftTUIAlignment(.left)

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed).multilineTextAlignment(.trailing),
            in: RenderProposal(columns: 5)
        )

        #expect(block?.runs == [RenderedRun(text: "A")])
        #expect(block?.lines == ["A    "])
    }

    @Test
    func `wrapped attributed lines retain their alignment`() {
        var attributed = AttributedString("AB CD")
        attributed.setSwiftTUIAlignment(.center)

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed),
            in: RenderProposal(columns: 4)
        )

        #expect(block?.runs == [
            RenderedRun(text: "AB", column: 1),
            RenderedRun(text: "CD", row: 1, column: 1),
        ])
        #expect(block?.lines == [" AB ", " CD "])
    }

    @Test
    func `an attributed link uses the default tint without an underline and opens when clicked`() {
        var attributed = AttributedString("Visit")
        let url = URL(string: "https://example.com")!
        attributed.link = url
        var opened: [URL] = []
        let runtime = StateRuntime()
        let view = Text(attributedContent: attributed)
            .environment(\.openURL, OpenURLAction { opened.append($0); return .handled })

        let block = runtime.block(from: view)

        #expect(block?.runs == [
            RenderedRun(
                text: "Visit",
                style: TextStyle(foregroundStyle: AnyColor(Color16.blue)),
                link: url
            ),
        ])
        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(opened == [url])
    }

    @Test
    func `an attributed link uses the view tint as its foreground color`() {
        var attributed = AttributedString("Visit")
        let url = URL(string: "https://example.com")!
        attributed.link = url

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed).tint(.green)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "Visit",
                style: TextStyle(foregroundStyle: AnyColor(Color16.green)),
                link: url
            ),
        ])
    }

    @Test
    func `an attributed link's explicit foreground color overrides the view tint`() {
        var attributed = AttributedString("Visit")
        let url = URL(string: "https://example.com")!
        attributed.link = url
        attributed.setSwiftTUIForegroundColor(.color16(.red))

        let block = ViewResolver.block(
            from: Text(attributedContent: attributed).tint(.green)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "Visit",
                style: TextStyle(foregroundStyle: AnyColor(Color16.red)),
                link: url
            ),
        ])
    }

    @Test
    func `clicking a link with the default openURL action does not open it`() {
        var attributed = AttributedString("Visit")
        attributed.link = URL(string: "https://example.com")!
        let runtime = StateRuntime()

        #expect(runtime.block(from: Text(attributedContent: attributed))?.text == "Visit")
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down),
                at: date
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .up),
                at: date
            ) == .ignored
        )
    }

    @Test
    func `onOpenURL receives and handles a dispatched URL`() {
        let url = URL(string: "swift-tui://open")!
        var received: [URL] = []
        let runtime = StateRuntime()
        let view = Text("A")
            .onOpenURL {
                received.append($0)
            }

        #expect(runtime.block(from: view)?.text == "A")
        #expect(runtime.dispatchOpenURL(url) == .handled)
        #expect(received == [url])
    }
}
