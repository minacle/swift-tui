import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Text Content, Attributes, and Links")
struct TextContentAndLinkTests {

    @Test
    func `a plain Text value exposes its original content`() {
        let text = Text("Hello")

        #expect(text.content == "Hello")
    }

    @Test
    func `Text initializers preserve content from StringProtocol values, verbatim strings, LocalizedStringKey, and AttributedString values`() {
        let string = "Hello"
        let substring = string[string.startIndex..<string.index(string.startIndex, offsetBy: 4)]
        var attributed = AttributedString("Styled")
    #if canImport(Darwin)
        attributed.inlinePresentationIntent = .stronglyEmphasized
    #endif

        #expect(Text(string).content == "Hello")
        #expect(Text(substring).content == "Hell")
        #expect(Text(verbatim: "Literal").content == "Literal")
        #expect(Text(LocalizedStringKey("Key")).content == "Key")
        #expect(Text(attributed).content == "Styled")
    }

    @Test
    func `attributed bold, italic, and strikethrough intents become matching rendered styles`() {
        var attributed = AttributedString("Bold Italic Strike")
        attributed[attributed.range(of: "Bold")!].inlinePresentationIntent = .stronglyEmphasized
        attributed[attributed.range(of: "Italic")!].inlinePresentationIntent = .emphasized
        attributed[attributed.range(of: "Strike")!].inlinePresentationIntent = .strikethrough

        let block = ViewResolver.block(from: Text(attributed))

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

        let block = ViewResolver.block(from: Text(attributed).foregroundStyle(.red).italic())

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

    @Test
    func `attributed foreground and background colors produce separate styled runs`() {
        var attributed = AttributedString("Red Blue")
        attributed[attributed.range(of: "Red")!].foregroundColor = .color16(.red)
        attributed[attributed.range(of: "Blue")!].backgroundColor = .trueColor(
            red: 1,
            green: 2,
            blue: 3
        )

        let block = ViewResolver.block(from: Text(attributed))

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
    func `attributed colors take precedence over inherited text colors`() {
        var attributed = AttributedString("Styled")
        attributed.foregroundColor = .color16(.green)
        attributed.backgroundColor = .color256(196)

        let block = ViewResolver.block(
            from: Text(attributed)
                .foregroundStyle(.red)
                ._backgroundStyle(.blue)
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "Styled",
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.green),
                    backgroundStyle: AnyColor(Color256(rawValue: 196))
                )
            ),
        ])
    }

    @Test
    func `wrapping preserves styles attached to attributed runs`() {
        var attributed = AttributedString("Alpha Beta")
        attributed[attributed.range(of: "Beta")!].inlinePresentationIntent = .stronglyEmphasized

        let block = ViewResolver.block(from: Text(attributed), in: RenderProposal(columns: 5))

        #expect(block?.runs == [
            RenderedRun(text: "Alpha", row: 0),
            RenderedRun(text: "Beta", row: 1, style: TextStyle(isBold: true)),
        ])
        #expect(block?.lines == ["Alpha", "Beta "])
    }

    @Test
    func `attributed alignment positions text within the proposed width`() {
        var left = AttributedString("A")
        left.alignment = .left
        var center = AttributedString("A")
        center.alignment = .center
        var right = AttributedString("A")
        right.alignment = .right

        let leftBlock = ViewResolver.block(from: Text(left), in: RenderProposal(columns: 5))
        let centerBlock = ViewResolver.block(from: Text(center), in: RenderProposal(columns: 5))
        let rightBlock = ViewResolver.block(from: Text(right), in: RenderProposal(columns: 5))

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
        attributed.alignment = .left

        let block = ViewResolver.block(
            from: Text(attributed).multilineTextAlignment(.trailing),
            in: RenderProposal(columns: 5)
        )

        #expect(block?.runs == [RenderedRun(text: "A")])
        #expect(block?.lines == ["A    "])
    }

    @Test
    func `wrapped attributed lines retain their alignment`() {
        var attributed = AttributedString("AB CD")
        attributed.alignment = .center

        let block = ViewResolver.block(from: Text(attributed), in: RenderProposal(columns: 4))

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
        let view = Text(attributed)
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

        let block = ViewResolver.block(from: Text(attributed).tint(.green))

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
        attributed.foregroundColor = .color16(.red)

        let block = ViewResolver.block(from: Text(attributed).tint(.green))

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

        #expect(runtime.block(from: Text(attributed))?.text == "Visit")
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .down),
                at: date
            ) == .handled
        )
        #expect(
            runtime.dispatch(
                PointerEvent(button: .left, column: 1, row: 1, phase: .up),
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
