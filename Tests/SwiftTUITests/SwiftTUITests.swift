import Foundation
import Observation
import Testing
@testable import SwiftTUI

nonisolated struct CustomShapeStyle: Color, ShapeStyle {

    let background = "48;5;24"

    let foreground = "38;5;42"
}

@Test func anyColorConvenienceFactoriesCreateTypeErasedColors() {
    let defaultColor: AnyColor = .default

    #expect(defaultColor == AnyColor(DefaultColor.default))
    #expect(AnyColor.color16(.red) == AnyColor(Color16.red))
    #expect(AnyColor.color256(196) == AnyColor(Color256(rawValue: 196)))
    #expect(AnyColor.color256(Color256(rawValue: 42)) == AnyColor(Color256(rawValue: 42)))
    #expect(
        AnyColor.trueColor(red: 1, green: 2, blue: 3)
            == AnyColor(TrueColor(red: 1, green: 2, blue: 3))
    )
    #expect(
        AnyColor.trueColor(TrueColor(red: 4, green: 5, blue: 6))
            == AnyColor(TrueColor(red: 4, green: 5, blue: 6))
    )
}

@Test func styleModifiersAcceptAnyColorConvenienceFactories() {
    let block = ViewResolver.block(
        from: Text("A")
            .foregroundStyle(.color256(196))
            .background(.trueColor(red: 1, green: 2, blue: 3))
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "A",
            style: TextStyle(
                foregroundStyle: AnyColor(Color256(rawValue: 196)),
                backgroundStyle: AnyColor(TrueColor(red: 1, green: 2, blue: 3))
            )
        ),
    ])
}

@Test func textPreservesContent() {
    let text = Text("Hello")

    #expect(text.content == "Hello")
}

@Test func textInitializersAcceptStringProtocolVerbatimLocalizedAndAttributedContent() {
    let string = "Hello"
    let substring = string[string.startIndex..<string.index(string.startIndex, offsetBy: 4)]
    var attributed = AttributedString("Styled")
    attributed.inlinePresentationIntent = .stronglyEmphasized

    #expect(Text(string).content == "Hello")
    #expect(Text(substring).content == "Hell")
    #expect(Text(verbatim: "Literal").content == "Literal")
    #expect(Text(LocalizedStringKey("Key")).content == "Key")
    #expect(Text(attributed).content == "Styled")
}

@Test func attributedTextMapsInlinePresentationIntentToRuns() {
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

@Test func attributedTextMergesAttributesWithEnvironmentStyle() {
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

@Test func attributedTextMapsForegroundAndBackgroundAttributesToRuns() {
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

@Test func attributedTextAttributesOverrideEnvironmentStyles() {
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

@Test func attributedTextPreservesRunStylesAcrossWrapping() {
    var attributed = AttributedString("Alpha Beta")
    attributed[attributed.range(of: "Beta")!].inlinePresentationIntent = .stronglyEmphasized

    let block = ViewResolver.block(from: Text(attributed), in: RenderProposal(columns: 5))

    #expect(block?.runs == [
        RenderedRun(text: "Alpha", row: 0),
        RenderedRun(text: "Beta", row: 1, style: TextStyle(isBold: true)),
    ])
    #expect(block?.lines == ["Alpha", "Beta "])
}

@Test func attributedTextAlignsLinesWithinProposal() {
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

@Test func attributedTextPreservesAlignmentAcrossWrapping() {
    var attributed = AttributedString("AB CD")
    attributed.alignment = .center

    let block = ViewResolver.block(from: Text(attributed), in: RenderProposal(columns: 4))

    #expect(block?.runs == [
        RenderedRun(text: "AB", column: 1),
        RenderedRun(text: "CD", row: 1, column: 1),
    ])
    #expect(block?.lines == [" AB ", " CD "])
}

@Test func attributedLinkIsClickableWithoutDefaultUnderline() {
    var attributed = AttributedString("Visit")
    let url = URL(string: "https://example.com")!
    attributed.link = url
    var opened: [URL] = []
    let runtime = StateRuntime()
    let view = Text(attributed)
        .environment(\.openURL, OpenURLAction { opened.append($0); return .handled })

    let block = runtime.block(from: view)

    #expect(block?.runs == [
        RenderedRun(text: "Visit", link: url),
    ])
    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(opened == [url])
}

@Test func attributedLinkUsesTintAsForegroundStyle() {
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

@Test func attributedLinkForegroundColorOverridesTint() {
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

@Test func defaultOpenURLActionDiscardsLinkClicks() {
    var attributed = AttributedString("Visit")
    attributed.link = URL(string: "https://example.com")!
    let runtime = StateRuntime()

    #expect(runtime.block(from: Text(attributed))?.text == "Visit")
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date
        ) == .ignored
    )
}

@Test func onOpenURLHandlesIncomingURL() {
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

@Test func textStyleDoesNotChangePlainTextProjection() {
    let block = ViewResolver.block(
        from: Text("Lorem ipsum")
            .foregroundStyle(.green)
            .bold()
            .dim()
            .italic()
            .underline()
            .strikethrough(),
        in: RenderProposal(columns: 5)
    )

    #expect(block?.lines == ["Lorem", "ipsum"])
    #expect(block?.text == "Lorem\nipsum")
}

@Test func textStyleInheritsThroughContainersAndCanBeOverridden() {
    let block = ViewResolver.block(
        from: VStack(alignment: .leading) {
            Text("A")
            Text("B")
                .foregroundStyle(.default)
                .bold(false)
                .dim(false)
                .italic(false)
                .underline(false)
                .strikethrough(false)
        }
        .foregroundStyle(.red)
        .bold()
        .dim()
        .italic()
        .underline()
        .strikethrough()
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "A",
            row: 0,
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.red),
                isBold: true,
                isDim: true,
                isItalic: true,
                isUnderline: true,
                isStrikethrough: true
            )
        ),
        RenderedRun(
            text: "B",
            row: 1,
            style: TextStyle(foregroundStyle: AnyColor(DefaultColor.default))
        ),
    ])
    #expect(block?.lines == ["A", "B"])
}

@Test func textStyleSurvivesPaddingAndFrameLayout() {
    let block = ViewResolver.block(
        from: Text("A")
            .foregroundStyle(.blue)
            .padding()
            .frame(width: 4, height: 3, alignment: .topLeading)
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "A",
            row: 1,
            column: 1,
            style: TextStyle(foregroundStyle: AnyColor(Color16.blue))
        ),
    ])
    #expect(block?.lines == ["    ", " A  ", "    "])
}

@Test func foregroundAndBackgroundStylesAcceptCustomColorShapeStyle() {
    let block = ViewResolver.block(
        from: Text("A")
            .foregroundStyle(CustomShapeStyle())
            .background(CustomShapeStyle())
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "A",
            style: TextStyle(
                foregroundStyle: AnyColor(CustomShapeStyle()),
                backgroundStyle: AnyColor(CustomShapeStyle())
            )
        ),
    ])
}

@Test func boxRendersSingleCellCross() {
    let block = ViewResolver.block(
        from: Box()
            .frame(width: 1, height: 1)
    )

    #expect(block?.lines == ["┼"])
}

@Test func boxRendersSingleRowWithSideTees() {
    let block = ViewResolver.block(
        from: Box()
            .frame(width: 3, height: 1)
    )

    #expect(block?.lines == ["├─┤"])
}

@Test func boxRendersSingleColumnWithTopAndBottomTees() {
    let block = ViewResolver.block(
        from: Box()
            .frame(width: 1, height: 3)
    )

    #expect(block?.lines == ["┬", "│", "┴"])
}

@Test func boxRendersRegularBorderAndOffsetsContentInsideBorder() {
    let block = ViewResolver.block(
        from: Box {
            Text("A")
        }
    )

    #expect(block?.width == 3)
    #expect(block?.height == 3)
    #expect(block?.lines == [
        "┌─┐",
        "│A│",
        "└─┘",
    ])
    #expect(block?.runs.contains(RenderedRun(text: "A", row: 1, column: 1)) == true)
}

@Test func boxClipsContentToInterior() {
    let block = ViewResolver.block(
        from: Box {
            Text("AB")
        }
        .frame(width: 3, height: 3)
    )

    #expect(block?.lines == [
        "┌─┐",
        "│A│",
        "└─┘",
    ])
}

@Test func twoByTwoBoxHasNoContentArea() {
    let block = ViewResolver.block(
        from: Box {
            Text("A")
        }
        .frame(width: 2, height: 2)
    )

    #expect(block?.lines == [
        "┌┐",
        "└┘",
    ])
}

@Test func heavyAndDoubleBoxesUseTheirDrawingSets() {
    let heavy = ViewResolver.block(
        from: HeavyBox()
            .frame(width: 3, height: 3)
    )
    let double = ViewResolver.block(
        from: DoubleBox()
            .frame(width: 3, height: 3)
    )

    #expect(heavy?.lines == [
        "┏━┓",
        "┃ ┃",
        "┗━┛",
    ])
    #expect(double?.lines == [
        "╔═╗",
        "║ ║",
        "╚═╝",
    ])
}

@Test func boxBorderStyleOnlyKeepsColorAndDim() {
    let block = ViewResolver.block(
        from: Box {
            Text("A")
        }
        .foregroundStyle(.red)
        ._backgroundStyle(.blue)
        .bold()
        .dim()
        .italic()
        .underline()
        .strikethrough()
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "┌─┐",
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.red),
                backgroundStyle: AnyColor(Color16.blue),
                isDim: true
            )
        ),
        RenderedRun(
            text: "│",
            row: 1,
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.red),
                backgroundStyle: AnyColor(Color16.blue),
                isDim: true
            )
        ),
        RenderedRun(
            text: "│",
            row: 1,
            column: 2,
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.red),
                backgroundStyle: AnyColor(Color16.blue),
                isDim: true
            )
        ),
        RenderedRun(
            text: "└─┘",
            row: 2,
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.red),
                backgroundStyle: AnyColor(Color16.blue),
                isDim: true
            )
        ),
        RenderedRun(
            text: "A",
            row: 1,
            column: 1,
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.red),
                backgroundStyle: AnyColor(Color16.blue),
                isBold: true,
                isDim: true,
                isItalic: true,
                isUnderline: true,
                isStrikethrough: true
            )
        ),
    ])
}

@Test func boxBorderScreenOutputOnlyUsesColorAndDimSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(
            from: Box()
                .frame(width: 1, height: 1)
                .foregroundStyle(.red)
                ._backgroundStyle(.blue)
                .bold()
                .dim()
                .italic()
                .underline()
                .strikethrough()
        )!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(
        output == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[2m\u{001B}[31m\u{001B}[44m┼\u{001B}[22m\u{001B}[39m\u{001B}[49m"
            + "\u{001B}[?25l"
    )
}

@Test func boxOffsetsContentInteractionRegionsInsideBorder() {
    let runtime = StateRuntime()
    let view = Box {
        ScrollView(.horizontal) {
            Text("ABCDE")
        }
        .scrollPosition(.constant(ScrollPosition(x: 1)))
        .onTapGesture {}
        .focusable()
    }
    .frame(width: 5, height: 3)

    let block = runtime.block(from: view)

    #expect(block?.lines == [
        "┌───┐",
        "│BCD│",
        "└───┘",
    ])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 1, y: 1, width: 3, height: 1),
    ])
    #expect(block?.hitRegions.map(\.frame) == [
        RenderedRect(x: 1, y: 1, width: 3, height: 1),
    ])
    #expect(block?.focusRegions.map(\.frame) == [
        RenderedRect(x: 1, y: 1, width: 3, height: 1),
    ])
}

@Test func textWrapsToProposedColumns() {
    let block = ViewResolver.block(
        from: Text("Lorem ipsum dolor"),
        in: RenderProposal(columns: 8)
    )

    #expect(block?.lines == ["Lorem", "ipsum", "dolor"])
}

@Test func textWrapsExplicitNewlines() {
    let block = ViewResolver.block(
        from: Text("Alpha beta\ngamma"),
        in: RenderProposal(columns: 7)
    )

    #expect(block?.lines == ["Alpha", "beta ", "gamma"])
}

@Test func textWrapsLongWordsAtCharacterBoundaries() {
    let block = ViewResolver.block(
        from: Text("ABCDEFGHIJ"),
        in: RenderProposal(columns: 3)
    )

    #expect(block?.lines == ["ABC", "DEF", "GHI", "J  "])
}

@Test func textPreservesTrailingSpacesWhenTheyWrapPastProposedColumns() {
    let line = "Lorem ipsum dolor sit amet."
    let block = ViewResolver.block(
        from: Text(line + "  "),
        in: RenderProposal(columns: 28)
    )

    #expect(block?.lines == [
        line + " ",
        String(repeating: " ", count: 28),
    ])
}

@Test func textPreservesTrailingSpacesBeforeNextWrappedCharacter() {
    let line = "Lorem ipsum dolor sit amet."
    let block = ViewResolver.block(
        from: Text(line + "  a"),
        in: RenderProposal(columns: 28)
    )

    #expect(block?.lines == [
        line + " ",
        " a" + String(repeating: " ", count: 26),
    ])
}

@Test func textLineLimitTruncatesWithEllipsis() {
    let block = ViewResolver.block(
        from: Text("Lorem ipsum dolor").lineLimit(2),
        in: RenderProposal(columns: 8)
    )

    #expect(block?.lines == ["Lorem   ", "ipsum..."])
}

@Test func textLineLimitReservesSpace() {
    let block = ViewResolver.block(from: Text("Hello").lineLimit(3, reservesSpace: true))

    #expect(block?.height == 3)
    #expect(block?.lines == ["Hello", "     ", "     "])
}

@Test func lineLimitAppliesThroughViewTree() {
    let view = VStack(alignment: .leading) {
        Text("Alpha beta gamma")
    }
    .lineLimit(2)

    let block = ViewResolver.block(from: view, in: RenderProposal(columns: 6))

    #expect(block?.lines == ["Alpha ", "bet..."])
}

@Test func lineLimitNilRemovesParentLimit() {
    let view = VStack(alignment: .leading) {
        Text("Alpha beta gamma")
            .lineLimit(nil)
    }
    .lineLimit(1)

    let block = ViewResolver.block(from: view, in: RenderProposal(columns: 6))

    #expect(block?.lines == ["Alpha", "beta ", "gamma"])
}

@Test func textWrapsWideCharactersByTerminalColumns() {
    let block = ViewResolver.block(
        from: Text("한글AB"),
        in: RenderProposal(columns: 4)
    )

    #expect(block?.lines == ["한글", "AB  "])
}

@Test func textDropsRemainderWhenWideCharacterCannotFitProposedColumns() {
    let block = ViewResolver.block(
        from: Text("한A"),
        in: RenderProposal(columns: 1)
    )

    #expect(block?.lines == [""])
}

@Test func fixedFrameClipsWideCharacterWhenNoColumnCanContainIt() {
    let block = ViewResolver.block(
        from: Text("한A").frame(width: 1, height: 1)
    )

    #expect(block?.lines == [" "])
}

@Test func textWrapsCJKWithoutSpacesUsingUnicodeLineBreaks() {
    let block = ViewResolver.block(
        from: Text("한국어문장"),
        in: RenderProposal(columns: 4)
    )

    #expect(block?.lines == ["한국", "어문", "장  "])
}

@Test func textDoesNotBreakAroundNoBreakSpace() {
    let block = ViewResolver.block(
        from: Text("A\u{00A0}B C"),
        in: RenderProposal(columns: 3)
    )

    #expect(block?.lines == ["A\u{00A0}B", "C  "])
}

@Test func textWrapsAfterZeroWidthSpace() {
    let block = ViewResolver.block(
        from: Text("ab\u{200B}cd"),
        in: RenderProposal(columns: 2)
    )

    #expect(block?.lines == ["ab\u{200B}", "cd"])
}

@Test func textKeepsCombiningSequenceTogether() {
    let block = ViewResolver.block(
        from: Text("e\u{0301}e"),
        in: RenderProposal(columns: 1)
    )

    #expect(block?.lines == ["e\u{0301}", "e"])
}

@Test func textWrapsExplicitCRLFAndNextLineBreaks() {
    let block = ViewResolver.block(from: Text("A\r\nB\u{0085}C"))

    #expect(block?.lines == ["A", "B", "C"])
}

@Test func unicodeLineBreakDataLoadsEmbeddedRanges() {
    #expect(UnicodeLineBreakClass.lineBreakDataRangeCount == 3654)
    #expect(UnicodeLineBreakClass.untailoredClass(for: Unicode.Scalar(0x0A)!) == .lineFeed)
    #expect(UnicodeLineBreakClass.untailoredClass(for: Unicode.Scalar(0x20)!) == .space)
    #expect(UnicodeLineBreakClass.untailoredClass(for: Unicode.Scalar(0xA0)!) == .glue)
    #expect(UnicodeLineBreakClass.untailoredClass(for: Unicode.Scalar(0x200B)!) == .zeroWidthSpace)
    #expect(UnicodeLineBreakClass.untailoredClass(for: Unicode.Scalar(0x4E00)!) == .ideographic)
}

@Test func textWrapsAfterSlash() {
    let block = ViewResolver.block(
        from: Text("aa/bb"),
        in: RenderProposal(columns: 3)
    )

    #expect(block?.lines == ["aa/", "bb "])
}

@Test func textWrapsCommaAndPeriodPunctuationAfterWords() {
    let block = ViewResolver.block(
        from: Text("Hello, world. Next"),
        in: RenderProposal(columns: 7)
    )

    #expect(block?.lines == ["Hello,", "world.", "Next  "])
}

@Test func textDoesNotFallbackWrapBeforeCommaAndPeriodPunctuation() {
    let block = ViewResolver.block(
        from: Text("Hello, world. Next"),
        in: RenderProposal(columns: 5)
    )

    #expect(block?.lines == ["Hell", "o,  ", "worl", "d.  ", "Next"])
}

@Test func textWrapsExclamationAndQuestionPunctuationAfterWords() {
    let block = ViewResolver.block(
        from: Text("Wait! What? Yes."),
        in: RenderProposal(columns: 6)
    )

    #expect(block?.lines == ["Wait!", "What?", "Yes. "])
}

@Test func textDoesNotFallbackWrapBeforeExclamationAndQuestionPunctuation() {
    let block = ViewResolver.block(
        from: Text("Wait! What? Yes."),
        in: RenderProposal(columns: 4)
    )

    #expect(block?.lines == ["Wai ", "t!  ", "Wha ", "t?  ", "Yes."])
}

@Test func textAllowsStandalonePunctuationWhenWidthIsTooNarrowToKeepPreviousCharacter() {
    let block = ViewResolver.block(
        from: Text("Wait! What? Yes."),
        in: RenderProposal(columns: 2)
    )

    #expect(block?.lines == ["Wa", "it", "! ", "Wh", "at", "? ", "Ye", "s."])
}

@Test func textWrapsColonAndSemicolonPunctuationAfterWords() {
    let block = ViewResolver.block(
        from: Text("Key: value; next"),
        in: RenderProposal(columns: 7)
    )

    #expect(block?.lines == ["Key:  ", "value;", "next  "])
}

@Test func textDoesNotFallbackWrapBeforeColonAndSemicolonPunctuation() {
    let block = ViewResolver.block(
        from: Text("Key: value; next"),
        in: RenderProposal(columns: 5)
    )

    #expect(block?.lines == ["Key:", "valu", "e;  ", "next"])
}

@Test func textDoesNotFallbackWrapBeforeJapanesePunctuation() {
    let block = ViewResolver.block(
        from: Text("こんにちは。\n元気です。"),
        in: RenderProposal(columns: 10)
    )

    #expect(block?.lines == ["こんにち  ", "は。      ", "元気です。"])
}

@Test func textWrapsQuotedPunctuationAsGroupedText() {
    let doubleQuoted = ViewResolver.block(
        from: Text("\"Hello\" next"),
        in: RenderProposal(columns: 7)
    )
    let singleQuoted = ViewResolver.block(
        from: Text("'Hello' next"),
        in: RenderProposal(columns: 7)
    )
    let cornerQuoted = ViewResolver.block(
        from: Text("「東京」へ行く"),
        in: RenderProposal(columns: 8)
    )

    #expect(doubleQuoted?.lines == ["\"Hello\"", "next   "])
    #expect(singleQuoted?.lines == ["'Hello'", "next   "])
    #expect(cornerQuoted?.lines == ["「東京」", "へ行く  "])
}

@Test func textDoesNotFallbackWrapBeforeClosingQuotePunctuation() {
    let block = ViewResolver.block(
        from: Text("\"Hi\" 'Yo'"),
        in: RenderProposal(columns: 3)
    )

    #expect(block?.lines == ["\"H", "i\"", "'Y", "o'"])
}

@Test func textWrapsBracketPunctuationAsGroupedText() {
    let parentheses = ViewResolver.block(
        from: Text("(AB) CD"),
        in: RenderProposal(columns: 4)
    )
    let brackets = ViewResolver.block(
        from: Text("[AB] CD"),
        in: RenderProposal(columns: 4)
    )
    let braces = ViewResolver.block(
        from: Text("{AB} CD"),
        in: RenderProposal(columns: 4)
    )

    #expect(parentheses?.lines == ["(AB)", "CD  "])
    #expect(brackets?.lines == ["[AB]", "CD  "])
    #expect(braces?.lines == ["{AB}", "CD  "])
}

@Test func textDoesNotFallbackWrapBeforeClosingBracketPunctuation() {
    let block = ViewResolver.block(
        from: Text("(AB) [CD] {EF}"),
        in: RenderProposal(columns: 3)
    )

    #expect(block?.lines == ["(A", "B)", "[C", "D]", "{E", "F}"])
}

@Test func textWrapsCJKPunctuationWithPrecedingCharacters() {
    let block = ViewResolver.block(
        from: Text("東京、京都。大阪！奈良？"),
        in: RenderProposal(columns: 6)
    )

    #expect(block?.lines == ["東京、", "京都。", "大阪！", "奈良？"])
}

@Test func textWrapsNumericPunctuationTogether() {
    let block = ViewResolver.block(
        from: Text("ID 1,234.56% OK"),
        in: RenderProposal(columns: 11)
    )

    #expect(block?.lines == ["ID       ", "1,234.56%", "OK       "])
}

@Test func textWrapsHyphenAndSlashPunctuationAtAllowedBoundaries() {
    let block = ViewResolver.block(
        from: Text("pre-fix / path/to/file"),
        in: RenderProposal(columns: 8)
    )

    #expect(block?.lines == ["pre-    ", "fix /   ", "path/to/", "file    "])
}

@Test func unicodeLineBreakFindsZeroWidthSpaceOpportunity() {
    #expect(lineBreakOffsets(in: "ab\u{200B}cd") == [3])
    #expect(lineBreakKinds(in: "ab\u{200B}cd") == ["allowed"])
}

@Test func unicodeLineBreakSuppressesWordJoinerOpportunities() {
    #expect(lineBreakOffsets(in: "A\u{2060}B C") == [4])
}

@Test func unicodeLineBreakAllowsGeneralPunctuationAndPostSpaceBreaks() {
    #expect(lineBreakOffsets(in: "Hello, world. Next") == [7, 14])
    #expect(lineBreakOffsets(in: "Wait! What? Yes.") == [6, 12])
    #expect(lineBreakOffsets(in: "Key: value; next") == [5, 12])
}

@Test func unicodeLineBreakKeepsQuoteAndBracketPunctuationTogether() {
    #expect(lineBreakOffsets(in: "\"Hello\" next") == [8])
    #expect(lineBreakOffsets(in: "'Hello' next") == [8])
    #expect(lineBreakOffsets(in: "(AB) CD") == [5])
    #expect(lineBreakOffsets(in: "[AB] CD") == [5])
    #expect(lineBreakOffsets(in: "{AB} CD") == [5])
}

@Test func unicodeLineBreakKeepsNumericPunctuationTogether() {
    #expect(lineBreakOffsets(in: "A 1,234.56% B") == [2, 12])
}

@Test func unicodeLineBreakAllowsHyphenAndSlashPunctuationBreaks() {
    #expect(lineBreakOffsets(in: "pre-fix / path/to/file") == [4, 10, 15, 18])
}

@Test func unicodeLineBreakMarksHardBreakOpportunities() {
    #expect(lineBreakOffsets(in: "A\nB") == [2])
    #expect(lineBreakKinds(in: "A\nB") == ["mandatory"])
}

private func lineBreakOffsets(in text: String) -> [Int] {
    UnicodeLineBreak.opportunities(in: text).map {
        text.distance(from: text.startIndex, to: $0.index)
    }
}

private func lineBreakKinds(in text: String) -> [String] {
    UnicodeLineBreak.opportunities(in: text).map {
        switch $0.kind {
        case .allowed:
            "allowed"
        case .mandatory:
            "mandatory"
        }
    }
}

@Test func textFieldDisplaysBoundText() {
    var value = "mayu"
    let textField = TextField(
        "Name",
        text: Binding(
            get: {
                value
            },
            set: { newValue in
                value = newValue
            }
        )
    )

    #expect(ViewResolver.text(from: textField) == "mayu")
}

@Test func textFieldDisplayTextInheritsTextStyle() {
    let textField = TextField("Name", text: .constant("mayu"))
        .foregroundStyle(.brightGreen)
        .bold()
        .dim()
        .italic()
        .underline()
        .strikethrough()

    #expect(ViewResolver.block(from: textField)?.runs == [
        RenderedRun(
            text: "mayu",
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.brightGreen),
                isBold: true,
                isDim: true,
                isItalic: true,
                isUnderline: true,
                isStrikethrough: true
            )
        ),
    ])
}

@Test func emptyTextFieldDisplaysPromptBeforeTitle() {
    let textField = TextField(
        "Name",
        text: .constant(""),
        prompt: Text("Required")
    )

    #expect(ViewResolver.text(from: textField) == "Required")
}

@Test func emptyTextFieldDisplaysTitleWhenPromptIsAbsent() {
    let textField = TextField("Name", text: .constant(""))

    #expect(ViewResolver.text(from: textField) == "Name")
}

@Test func maskedSecureFieldDisplaysBoundText() {
    let secureField = SecureField("Password", text: .constant("secret"))

    #expect(ViewResolver.text(from: secureField) == "••••••")
}

@Test func styledSecureFieldMasksText() {
    let secureField = SecureField("Password", text: .constant("secret"))
        .foregroundStyle(.brightGreen)
        .bold()
        .dim()
        .italic()
        .underline()
        .strikethrough()

    #expect(ViewResolver.block(from: secureField)?.runs == [
        RenderedRun(
            text: "••••••",
            style: TextStyle(
                foregroundStyle: AnyColor(Color16.brightGreen),
                isBold: true,
                isDim: true,
                isItalic: true,
                isUnderline: true,
                isStrikethrough: true
            )
        ),
    ])
}

@Test func emptySecureFieldDisplaysPromptBeforeTitle() {
    let secureField = SecureField(
        "Password",
        text: .constant(""),
        prompt: Text("Required")
    )

    #expect(ViewResolver.text(from: secureField) == "Required")
}

@Test func emptySecureFieldDisplaysTitleWhenPromptIsAbsent() {
    let secureField = SecureField("Password", text: .constant(""))

    #expect(ViewResolver.text(from: secureField) == "Password")
}

@Test func focusedSecureFieldEditsBoundTextWhileMaskingOutput() {
    let runtime = StateRuntime()
    let probe = BindingProbe<String>()
    let view = SecureFieldEditingView(textProbe: probe)

    #expect(runtime.block(from: view)?.text == "Password")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Password")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 0))

    #expect(runtime.dispatch(KeyPress(key: "s", characters: "s")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "e", characters: "e")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(probe.binding?.wrappedValue == "sec")
    #expect(runtime.block(from: view)?.text == "•••")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 3))

    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "r", characters: "r")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(probe.binding?.wrappedValue == "sec")
    #expect(runtime.block(from: view)?.text == "•••")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))
}

@Test func clickingSecureFieldMovesCaretWithinMaskedText() {
    let runtime = StateRuntime()
    let probe = BindingProbe<String>()
    let view = SecureFieldEditingView(textProbe: probe)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    for character in "secret" {
        #expect(
            runtime.dispatch(
                KeyPress(key: KeyEquivalent(character), characters: String(character))
            ) == .handled
        )
    }
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 3, row: 1, phase: .down)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    #expect(probe.binding?.wrappedValue == "seXcret")
    #expect(runtime.block(from: view)?.text == "•••••••")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 3))
}

@Test func draggingSecureFieldMovesCaretWithinMaskedText() {
    let runtime = StateRuntime()
    let probe = BindingProbe<String>()
    let view = SecureFieldEditingView(textProbe: probe)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    for character in "secret" {
        #expect(
            runtime.dispatch(
                KeyPress(key: KeyEquivalent(character), characters: String(character))
            ) == .handled
        )
    }
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 4, row: 1, phase: .motion)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    #expect(probe.binding?.wrappedValue == "secXret")
    #expect(runtime.block(from: view)?.text == "•••••••")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 4))
}

@Test func focusedSecureFieldUsesMaskedColumnWidthForCursorAndScroll() {
    let runtime = StateRuntime()
    let view = SecureFieldInitialTextView(text: "한ABC")
        .frame(width: 3)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view)

    #expect(block?.lines == ["•• "])
    #expect(block?.cursor == RenderedCursor(column: 2))

    #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["•••"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 0))
}

@Test func submittingSecureFieldWithReturnKey() {
    let runtime = StateRuntime()
    let view = SecureFieldSubmitView()

    #expect(runtime.block(from: view)?.lines == ["Password", "  none  "])
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "s", characters: "s")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["•", "s"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))
}

@Test func flexibleSecureFieldTakesRemainingColumnsBeforeSpacer() {
    let stack = HStack {
        SecureField("Password", text: .constant(""))
        Spacer()
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 20))

    #expect(block?.width == 20)
    #expect(block?.lines == ["Password            "])
    #expect(block?.focusRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 20, height: 1),
    ])
}

@Test func focusedTextFieldEditsBoundTextContinuously() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    #expect(runtime.block(from: view)?.text == "Name")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Name")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 0))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "a")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "c", characters: "c", modifiers: .control)) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "a")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))
}

@Test func disabledTextFieldIgnoresFocusAndTyping() {
    let runtime = StateRuntime()
    let textProbe = BindingProbe<String>()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = DisabledFocusedTextFieldView(
        textProbe: textProbe,
        focusProbe: focusProbe
    )

    #expect(runtime.block(from: view)?.text == "Name")
    #expect(focusProbe.binding?.wrappedValue == false)
    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
    #expect(textProbe.binding?.wrappedValue == "")
}

@Test func focusedTextFieldMovesCaretWithHorizontalArrows() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "ab")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))

    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "ab")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))

    #expect(runtime.dispatch(KeyPress(key: "c", characters: "c")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "acb")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))

    #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "acb")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 3))
}

@Test func focusedTextFieldCursorComposesThroughStacks() {
    let runtime = StateRuntime()
    let view = LabeledTextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view)

    #expect(block?.lines == ["Label: Name"])
    #expect(block?.cursor == RenderedCursor(column: 7))
}

@Test func focusedTextFieldCursorUsesTerminalColumnWidth() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "한A")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 3))
}

@Test func focusedTextFieldScrollsHorizontallyToKeepCaretVisible() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView().frame(width: 3)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    for character in "abcd" {
        #expect(
            runtime.dispatch(
                KeyPress(key: KeyEquivalent(character), characters: String(character))
            ) == .handled
        )
    }

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["cd "])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))

    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["bcd"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 0))
}

@Test func focusedTextFieldScrollsWideTextByTerminalColumns() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView().frame(width: 3)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "B", characters: "B")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["AB "])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 2))
}

@Test func focusedTextFieldDoesNotScrollExactWideTextFit() {
    let runtime = StateRuntime()
    let text = String(repeating: "ㅁ", count: 16)
    let view = TextFieldInitialTextView(text: text)
        .frame(width: 32)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view)

    #expect(block?.lines == [String(repeating: "ㅁ", count: 15) + "  "])
    #expect(block?.cursor == RenderedCursor(column: 30))
}

@Test func focusedTextFieldScrollsRightWhenNextWideCharacterIsHidden() {
    let runtime = StateRuntime()
    let view = TextFieldInitialTextView(text: "ㄱㄴㄷㄹㅁ")
        .frame(width: 6)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["ㄱㄴㄷ"])

    for _ in 0..<3 {
        #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
    }

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["ㄴㄷㄹ"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 4))
}

@Test func focusedTextFieldDeletionDoesNotScrollIntoWideCharacterMiddle() {
    let runtime = StateRuntime()
    let text = "ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆ"
    let view = TextFieldInitialTextView(text: text)
        .frame(width: 32)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    #expect(runtime.block(from: view)?.lines == ["ㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆ  "])

    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.lines == ["ㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃ  "])
    #expect(block?.cursor == RenderedCursor(column: 30))
}

@Test func framedTextFieldInsertionAtTrailingCaretScrollsBeforeTrailingSibling() {
    let runtime = StateRuntime()
    let text = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcde"
    let view = DelimitedTextFieldView(text: text)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "f", characters: "f")) == .handled)
    #expect(runtime.consumeInvalidation())
    let block = runtime.block(from: view)

    #expect(block?.lines == ["[BCDEFGHIJKLMNOPQRSTUVWXYZabcdef ]"])
    #expect(block?.cursor == RenderedCursor(column: 32))
}

@Test func flexibleTextFieldWideScrollStabilizesAfterMeasurementRender() {
    let runtime = StateRuntime()
    let view = FlexibleLabeledTextFieldView(
        text: String(repeating: "한글", count: 30)
    )

    for _ in 0..<3 {
        _ = runtime.block(from: view, in: RenderProposal(columns: 40, rows: 4))
        _ = runtime.consumeInvalidation()
    }

    _ = runtime.block(from: view, in: RenderProposal(columns: 40, rows: 4))
    #expect(!runtime.consumeInvalidation())
}

@Test func focusedTextFieldDoesNotInsertVerticalArrowCharacters() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .ignored)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "a")
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))
}

@Test func clickingTextFieldMovesCaretToClickedColumn() {
    let runtime = StateRuntime()
    let view = TextFieldInitialTextView(text: "abcd")

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 3, row: 1, phase: .down)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.text == "abXcd")
    #expect(block?.cursor == RenderedCursor(column: 3))
}

@Test func draggingTextFieldMovesCaretToPointerColumn() {
    let runtime = StateRuntime()
    let view = TextFieldInitialTextView(text: "abcd")

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 4, row: 1, phase: .motion)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.text == "abcXd")
    #expect(block?.cursor == RenderedCursor(column: 4))
}

@Test func draggingTextFieldOutsideFrameScrollsToCaret() {
    let runtime = StateRuntime()
    let view = PrefixedNarrowTextFieldInitialTextView(text: "abcdef")

    #expect(renderUntilStable(runtime, view: view) <= 3)
    var block = runtime.block(from: view)
    #expect(block?.lines == ["|ef "])
    #expect(block?.cursor == RenderedCursor(column: 3))

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 4, row: 1, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .motion)
        ) == .handled
    )
    #expect(renderUntilStable(runtime, view: view) <= 3)

    block = runtime.block(from: view)
    #expect(block?.lines == ["|def"])
    #expect(block?.cursor == RenderedCursor(column: 1))
}

@Test func textFieldMouseMotionWithoutPressDoesNotMoveCaret() {
    let runtime = StateRuntime()
    let view = TextFieldInitialTextView(text: "abcd")

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .motion)
        ) == .ignored
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.text == "abcdX")
    #expect(block?.cursor == RenderedCursor(column: 5))
}

@Test func textFieldMouseUpEndsCaretDrag() {
    let runtime = StateRuntime()
    let view = TextFieldInitialTextView(text: "abcd")

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 4, row: 1, phase: .motion)
        ) == .ignored
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.text == "Xabcd")
    #expect(block?.cursor == RenderedCursor(column: 1))
}

@Test func clickingScrolledWideTextFieldMovesCaretByTerminalColumns() {
    let runtime = StateRuntime()
    let view = TextFieldInitialTextView(text: "한ABC")
        .frame(width: 3)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    var block = runtime.block(from: view)
    #expect(block?.lines == ["BC "])
    #expect(block?.cursor == RenderedCursor(column: 2))

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 1, phase: .down)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    block = runtime.block(from: view)
    #expect(block?.lines == ["BXC"])
    #expect(block?.cursor == RenderedCursor(column: 2))
}

@Test func clickingTextFieldMovesFocusAndSubsequentTyping() {
    let runtime = StateRuntime()
    let focusProbe = FocusBindingProbe<FocusField?>()
    let textProbe = LabeledStringBindingProbe()
    let view = TwoTextFieldsClickFocusView(
        focusProbe: focusProbe,
        textProbe: textProbe
    )

    #expect(runtime.block(from: view)?.lines == ["first ", "second"])

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 2, phase: .down)
        ) == .handled
    )
    #expect(focusProbe.binding?.wrappedValue == .second)

    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view)
    #expect(runtime.dispatch(KeyPress(key: "z", characters: "z")) == .handled)

    #expect(textProbe.bindings["first"]?.wrappedValue == "")
    #expect(textProbe.bindings["second"]?.wrappedValue == "z")
}

@Test func clickingFramedTextFieldBlankAreaRequestsFocus() {
    let runtime = StateRuntime()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FramedTextFieldClickFocusView(focusProbe: focusProbe)

    #expect(runtime.block(from: view)?.lines == ["A    "])

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 5, row: 1, phase: .down)
        ) == .handled
    )
    #expect(focusProbe.binding?.wrappedValue == true)
}

@Test func textFieldSubmitsWithReturnKey() {
    let runtime = StateRuntime()
    let view = TextFieldSubmitView()

    #expect(runtime.block(from: view)?.lines == ["Name", "none"])
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["a", "a"])
    #expect(runtime.block(from: view)?.cursor == RenderedCursor(column: 1))
}

@Test func emptyTextEditorRendersFocusableRowsAndCursor() {
    let runtime = StateRuntime()
    let view = TextEditorEditingView()

    _ = runtime.block(from: view, in: RenderProposal(columns: 5, rows: 2))
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view, in: RenderProposal(columns: 5, rows: 2))

    #expect(block?.lines == ["     ", "     "])
    #expect(block?.cursor == RenderedCursor(row: 0, column: 0))
    #expect(block?.focusRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 5, height: 2),
    ])
}

@Test func focusedTextEditorEditsBoundTextContinuously() {
    let runtime = StateRuntime()
    let view = TextEditorEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.lines == ["a", "b"])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func clickingTextEditorMovesCaretToClickedLineAndColumn() {
    let runtime = StateRuntime()
    let view = TextEditorInitialTextView(text: "ab\ncd")
    let proposal = RenderProposal(columns: 4)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 2, phase: .down)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["ab  ", "cXd "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 2))
}

@Test func draggingTextEditorMovesCaretToPointerLineAndColumn() {
    let runtime = StateRuntime()
    let view = TextEditorInitialTextView(text: "ab\ncd")
    let proposal = RenderProposal(columns: 4)

    _ = runtime.block(from: view, in: proposal)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: proposal)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 3, row: 2, phase: .motion)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["ab  ", "cdX "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 3))
}

@Test func draggingTextEditorOutsideFrameScrollsToCaret() {
    let runtime = StateRuntime()
    let view = PrefixedBoundedTextEditorInitialTextView(text: "a\nb\nc\nd")
    let proposal = RenderProposal(columns: 4)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["top ", "c   ", "d   "])
    #expect(block?.cursor == RenderedCursor(row: 2, column: 1))

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 3, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .motion)
        ) == .handled
    )
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["top ", "b   ", "c   "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 0))
}

@Test func clickingScrolledTextEditorMovesCaretThroughScrollPoint() {
    let runtime = StateRuntime()
    let view = TextEditorInitialTextView(text: "a\nb\nc\nd")
    let proposal = RenderProposal(columns: 3, rows: 2)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["c  ", "d  "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 1))

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 1, phase: .down)
        ) == .handled
    )
    #expect(runtime.dispatch(KeyPress(key: "X", characters: "X")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["cX ", "d  "])
    #expect(block?.cursor == RenderedCursor(row: 0, column: 2))
}

@Test func disabledTextEditorIgnoresFocusAndTyping() {
    let runtime = StateRuntime()
    let textProbe = BindingProbe<String>()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = DisabledFocusedTextEditorView(
        textProbe: textProbe,
        focusProbe: focusProbe
    )

    #expect(runtime.block(from: view)?.lines == [" "])
    #expect(focusProbe.binding?.wrappedValue == false)
    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
    #expect(textProbe.binding?.wrappedValue == "")
}

@Test func textEditorReturnInsertsNewlineAndDoesNotSubmit() {
    let runtime = StateRuntime()
    let view = TextEditorSubmitView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.lines == ["    ", "    ", "none"])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 0))
}

@Test func focusedTextEditorDeletionWorksAcrossLineBoundaries() {
    let runtime = StateRuntime()
    let view = TextEditorInitialTextView(text: "ab\ncd")

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .delete, characters: "\u{0008}")) == .handled)
    #expect(runtime.consumeInvalidation())

    let block = runtime.block(from: view)
    #expect(block?.lines == ["ab"])
    #expect(block?.cursor == RenderedCursor(row: 0, column: 2))
}

@Test func focusedTextEditorMovesCaretAcrossVisualLines() {
    let runtime = StateRuntime()
    let view = TextEditorInitialTextView(text: "abcde")

    _ = runtime.block(from: view, in: RenderProposal(columns: 3))
    _ = runtime.consumeInvalidation()
    var block = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(block?.lines == ["abc", "de "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 2))

    #expect(runtime.dispatch(KeyPress(key: .upArrow, characters: "\u{F700}")) == .handled)
    #expect(runtime.consumeInvalidation())
    block = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(block?.cursor == RenderedCursor(row: 0, column: 2))

    #expect(runtime.dispatch(KeyPress(key: .home, characters: "\u{F729}")) == .handled)
    #expect(runtime.consumeInvalidation())
    block = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(block?.cursor == RenderedCursor(row: 0, column: 0))

    #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .rightArrow, characters: "\u{F703}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(runtime.consumeInvalidation())
    block = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(block?.cursor == RenderedCursor(row: 1, column: 2))
}

@Test func focusedTextEditorMovesCaretToNextRowWhenLineExactlyFilled() {
    let runtime = StateRuntime()
    let view = TextEditorEditingView()
    let proposal = RenderProposal(columns: 3, rows: 2)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

    for character in "abc" {
        #expect(
            runtime.dispatch(
                KeyPress(key: KeyEquivalent(character), characters: String(character))
            ) == .handled
        )
    }
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["abc", "   "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 0))

    #expect(runtime.dispatch(KeyPress(key: "d", characters: "d")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines == ["abc", "d  "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func focusedTextEditorPreservesTrailingSpacesWhenTheyWrapPastLineEnd() {
    let runtime = StateRuntime()
    let line = "Lorem ipsum dolor sit amet."
    let view = TextEditorInitialTextView(text: line + "  ")
    let proposal = RenderProposal(columns: 28, rows: 2)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    let block = runtime.block(from: view, in: proposal)

    #expect(block?.lines == [
        line + " ",
        String(repeating: " ", count: 28),
    ])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func focusedTextEditorPreservesTrailingSpacesBeforeNextWrappedCharacter() {
    let runtime = StateRuntime()
    let line = "Lorem ipsum dolor sit amet."
    let view = TextEditorInitialTextView(text: line + "  a")
    let proposal = RenderProposal(columns: 28, rows: 2)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    let block = runtime.block(from: view, in: proposal)

    #expect(block?.lines == [
        line + " ",
        " a" + String(repeating: " ", count: 26),
    ])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 2))
}

@Test func focusedTextEditorCursorUsesTerminalColumnWidth() {
    let runtime = StateRuntime()
    let view = TextEditorEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "한", characters: "한")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "A", characters: "A")) == .handled)
    #expect(runtime.consumeInvalidation())
    let block = runtime.block(from: view)

    #expect(block?.lines == ["한A"])
    #expect(block?.cursor == RenderedCursor(row: 0, column: 3))
}

@Test func focusedTextEditorScrollsVerticallyToKeepCaretVisible() {
    let runtime = StateRuntime()
    let view = TextEditorInitialTextView(text: "a\nb\nc\nd")

    _ = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))

    #expect(block?.lines == ["c  ", "d  "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func focusedTextEditorKeepsEditingAfterReturnAtViewportBottom() {
    let runtime = StateRuntime()
    let view = TextEditorEditingView()

    _ = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    let bottomBlock = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
    #expect(bottomBlock?.cursor == RenderedCursor(row: 1, column: 0))

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    let scrolledBlock = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
    #expect(scrolledBlock?.lines == ["   ", "   "])
    #expect(scrolledBlock?.cursor == RenderedCursor(row: 1, column: 0))

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 3, rows: 2))
    #expect(editedBlock?.lines == ["   ", "b  "])
    #expect(editedBlock?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func framedTextEditorKeepsEditingAfterReturnAtFrameBottom() {
    let runtime = StateRuntime()
    let view = FramedTextEditorEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    let scrolledBlock = runtime.block(from: view)
    #expect(scrolledBlock?.lines == ["   ", "   "])
    #expect(scrolledBlock?.cursor == RenderedCursor(row: 1, column: 0))

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editedBlock = runtime.block(from: view)
    #expect(editedBlock?.lines == ["   ", "b  "])
    #expect(editedBlock?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func maxHeightFramedTextEditorKeepsEditingAfterReturnAtFrameBottom() {
    let runtime = StateRuntime()
    let view = MaxHeightFramedTextEditorEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let initialBlock = runtime.block(from: view)
    #expect(initialBlock?.lines == ["   "])
    #expect(initialBlock?.cursor == RenderedCursor(row: 0, column: 0))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    let scrolledBlock = runtime.block(from: view)
    #expect(scrolledBlock?.lines == ["   ", "   "])
    #expect(scrolledBlock?.cursor == RenderedCursor(row: 1, column: 0))

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editedBlock = runtime.block(from: view)
    #expect(editedBlock?.lines == ["   ", "b  "])
    #expect(editedBlock?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func maxHeightOnlyTextEditorAcceptsTyping() {
    let runtime = StateRuntime()
    let view = MaxHeightOnlyTextEditorEditingView()

    _ = runtime.block(from: view, in: RenderProposal(columns: 3))
    _ = runtime.consumeInvalidation()
    let initialBlock = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(initialBlock?.lines == ["   "])
    #expect(initialBlock?.cursor == RenderedCursor(row: 0, column: 0))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(editedBlock?.lines == ["a  "])
    #expect(editedBlock?.cursor == RenderedCursor(row: 0, column: 1))
}

@Test func maxHeightOnlyTextEditorAcceptsTypingAfterClickFocus() {
    let runtime = StateRuntime()
    let view = MaxHeightOnlyTextEditorClickFocusView()

    _ = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: RenderProposal(columns: 3))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 3))
    #expect(editedBlock?.lines == ["a  "])
    #expect(editedBlock?.cursor == RenderedCursor(row: 0, column: 1))
}

@Test func maxHeightConstantTextEditorBelowScrollViewAcceptsTypingAfterClickFocus() {
    let runtime = StateRuntime()
    let view = MaxHeightConstantTextEditorBelowScrollViewView()
    let proposal = RenderProposal(columns: 8, rows: 6)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 5, phase: .down)
        ) == .handled
    )

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    let editedBlock = runtime.block(from: view, in: proposal)
    #expect(editedBlock?.lines.suffix(2) == ["│a     │", "└──────┘"])
    #expect(editedBlock?.cursor == RenderedCursor(row: 4, column: 2))
}

@Test func maxHeightConstantTextEditorBelowScrollViewAcceptsTypingAfterClickFocusInTallViewport() {
    let runtime = StateRuntime()
    let view = MaxHeightConstantTextEditorBelowScrollViewView()
    let proposal = RenderProposal(columns: 80, rows: 24)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 23, phase: .down)
        ) == .handled
    )

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    let editedBlock = runtime.block(from: view, in: proposal)
    #expect(editedBlock?.lines.suffix(2) == [
        "│a                                                                             │",
        "└──────────────────────────────────────────────────────────────────────────────┘"
    ])
    #expect(editedBlock?.cursor == RenderedCursor(row: 22, column: 2))
}

@Test func maxHeightConstantTextEditorBelowScrollViewKeepsPriorLineVisibleAfterReturns() {
    let runtime = StateRuntime()
    let view = MaxHeightConstantTextEditorBelowScrollViewView()
        .onTerminate {}
    let proposal = RenderProposal(columns: 80)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 3, phase: .down)
        ) == .handled
    )
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    var block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.suffix(3) == [
        "┌──────────────────────────────────────────────────────────────────────────────┐",
        "│a                                                                             │",
        "└──────────────────────────────────────────────────────────────────────────────┘"
    ])

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.suffix(4) == [
        "┌──────────────────────────────────────────────────────────────────────────────┐",
        "│a                                                                             │",
        "│                                                                              │",
        "└──────────────────────────────────────────────────────────────────────────────┘"
    ])

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.suffix(4) == [
        "┌──────────────────────────────────────────────────────────────────────────────┐",
        "│a                                                                             │",
        "│b                                                                             │",
        "└──────────────────────────────────────────────────────────────────────────────┘"
    ])

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    block = runtime.block(from: view, in: proposal)
    #expect(block?.lines.suffix(5) == [
        "┌──────────────────────────────────────────────────────────────────────────────┐",
        "│a                                                                             │",
        "│b                                                                             │",
        "│                                                                              │",
        "└──────────────────────────────────────────────────────────────────────────────┘"
    ])
}

@Test func filledTextEditorKeepsEditingAfterReturnAtFrameBottom() {
    let runtime = StateRuntime()
    let view = FramedTextEditorInitialTextView(text: "abcdef")

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let initialBlock = runtime.block(from: view)
    #expect(initialBlock?.lines == ["def", "   "])
    #expect(initialBlock?.cursor == RenderedCursor(row: 1, column: 0))

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    let scrolledBlock = runtime.block(from: view)
    #expect(scrolledBlock?.lines == ["def", "   "])
    #expect(scrolledBlock?.cursor == RenderedCursor(row: 1, column: 0))

    #expect(runtime.dispatch(KeyPress(key: "g", characters: "g")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editedBlock = runtime.block(from: view)
    #expect(editedBlock?.lines == ["def", "g  "])
    #expect(editedBlock?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func wrappingTextEditorKeepsEditingAfterCaretScrollsPastFrameBottom() {
    let runtime = StateRuntime()
    let view = FramedTextEditorEditingView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    for character in "abcdefg" {
        #expect(
            runtime.dispatch(
                KeyPress(key: KeyEquivalent(character), characters: String(character))
            ) == .handled
        )
    }
    #expect(runtime.consumeInvalidation())
    let block = runtime.block(from: view)
    #expect(block?.lines == ["def", "g  "])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 1))
}

@Test func boxedTextEditorBelowScrollViewKeepsEditingAtBottom() {
    let runtime = StateRuntime()
    let view = TextEditorBelowScrollViewView()

    _ = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    let bottomBlock = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))
    #expect(bottomBlock?.cursor == RenderedCursor(row: 4, column: 1))

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.consumeInvalidation())
    let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 8, rows: 6))
    #expect(editedBlock?.lines.suffix(2) == ["│b     │", "└──────┘"])
    #expect(editedBlock?.cursor == RenderedCursor(row: 4, column: 2))
}

@Test func boxedTextEditorBelowScrollViewKeepsEditingAfterFillingVisibleRows() {
    let runtime = StateRuntime()
    let view = TextEditorBelowScrollViewView()
    let proposal = RenderProposal(columns: 80, rows: 24)

    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    for _ in 0..<9 {
        #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    }
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    let bottomBlock = runtime.block(from: view, in: proposal)
    #expect(bottomBlock?.cursor == RenderedCursor(row: 22, column: 1))

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    let scrolledBlock = runtime.block(from: view, in: proposal)
    #expect(scrolledBlock?.cursor == RenderedCursor(row: 22, column: 1))

    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(renderUntilStable(runtime, view: view, in: proposal) <= 3)
    let editedBlock = runtime.block(from: view, in: proposal)
    #expect(editedBlock?.cursor == RenderedCursor(row: 22, column: 2))
}

@Test func clickingTextEditorBlankAreaRequestsFocus() {
    let runtime = StateRuntime()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FramedTextEditorClickFocusView(focusProbe: focusProbe)

    #expect(runtime.block(from: view)?.lines == ["     ", "     ", "     "])
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 3, row: 2, phase: .down)
        ) == .handled
    )
    #expect(focusProbe.binding?.wrappedValue == true)
}

@Test func textEditorSynchronizesExternalBindingChangesAndClampsCaret() {
    let runtime = StateRuntime()
    let probe = BindingProbe<String>()
    let view = CapturedTextEditorView(text: "abc", probe: probe)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    probe.binding?.wrappedValue = "x"
    #expect(runtime.consumeInvalidation())
    let block = runtime.block(from: view)

    #expect(block?.lines == ["x"])
    #expect(block?.cursor == RenderedCursor(row: 0, column: 1))
}

@Test func dynamicTextFieldFocusWithOptionalRowFocusShowsCursorAndEdits() {
    let runtime = StateRuntime()
    let view = DynamicTextFieldFocusWithOptionalRowFocusView()

    _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    let editorBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
    #expect(editorBlock?.cursor == RenderedCursor(row: 1, column: 2))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())

    let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
    #expect(editedBlock?.lines.dropFirst().first?.hasPrefix("> a") == true)
    #expect(editedBlock?.cursor == RenderedCursor(row: 1, column: 3))
}

@Test func dynamicTextFieldFocusInsideVerticalScrollViewShowsCursorAndEdits() {
    let runtime = StateRuntime()
    let view = ScrollWrappedDynamicTextFieldFocusView()

    _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\n")) == .handled)
    #expect(runtime.consumeInvalidation())

    let editorBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
    #expect(editorBlock?.cursor == RenderedCursor(row: 1, column: 2))

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())

    let editedBlock = runtime.block(from: view, in: RenderProposal(columns: 20, rows: 3))
    #expect(editedBlock?.lines.dropFirst().first?.hasPrefix("> a") == true)
    #expect(editedBlock?.cursor == RenderedCursor(row: 1, column: 3))
}

@Test func compositeViewResolvesToTextBody() {
    struct ContentView: View {
        var body: some View {
            Text("Hello from body")
        }
    }

    #expect(ViewResolver.text(from: ContentView()) == "Hello from body")
}

@Test func viewBuilderResolvesMultipleChildrenInOrder() {
    struct ContentView: View {
        var body: some View {
            Text("First")
            Text("Second")
        }
    }

    #expect(ViewResolver.text(from: ContentView()) == "First \nSecond")
}

@Test func emptyBuilderResolvesToNoText() {
    struct ContentView: View {
        var body: some View {}
    }

    #expect(ViewResolver.text(from: ContentView()) == nil)
}

@Test func viewBuilderIfIncludesContentWhenTrueAndSkipsWhenFalse() {
    struct ContentView: View {

        let isVisible: Bool

        var body: some View {
            VStack(alignment: .leading) {
                Text("A")
                if isVisible {
                    Text("B")
                }
                Text("C")
            }
        }
    }

    #expect(ViewResolver.block(from: ContentView(isVisible: true))?.lines == ["A", "B", "C"])
    #expect(ViewResolver.block(from: ContentView(isVisible: false))?.lines == ["A", "C"])
}

@Test func viewBuilderIfElseRendersSelectedBranch() {
    struct ContentView: View {

        let usesFirstBranch: Bool

        var body: some View {
            if usesFirstBranch {
                Text("First")
            }
            else {
                Text("Second")
            }
        }
    }

    #expect(ViewResolver.text(from: ContentView(usesFirstBranch: true)) == "First")
    #expect(ViewResolver.text(from: ContentView(usesFirstBranch: false)) == "Second")
}

@Test func viewBuilderConditionalBranchesFlattenMultipleChildren() {
    struct ContentView: View {

        let usesFirstBranch: Bool

        var body: some View {
            VStack(alignment: .leading) {
                if usesFirstBranch {
                    Text("A")
                    Text("B")
                }
                else {
                    Text("C")
                }
                Text("D")
            }
        }
    }

    #expect(ViewResolver.block(from: ContentView(usesFirstBranch: true))?.lines == ["A", "B", "D"])
    #expect(ViewResolver.block(from: ContentView(usesFirstBranch: false))?.lines == ["C", "D"])
}

@Test func viewBuilderLimitedAvailabilityContentRenders() {
    let view = VStack(alignment: .leading) {
        ViewBuilder.buildLimitedAvailability(Text("limited"))
    }

    #expect(ViewResolver.block(from: view)?.lines == ["limited"])
}

@Test func groupFlattensChildrenInsideVStack() {
    let view = VStack(alignment: .leading) {
        Group {
            Text("A")
            Text("B")
        }
        Text("C")
    }

    #expect(ViewResolver.block(from: view)?.lines == ["A", "B", "C"])
}

@Test func rootGroupResolvesLikeMultipleChildren() {
    let view = Group {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: view) == "A\nB")
}

@Test func nestedGroupsDoNotAddLayout() {
    let view = VStack(alignment: .leading) {
        Text("A")
        Group {
            Group {
                Text("B")
                Text("C")
            }
        }
        Text("D")
    }

    #expect(ViewResolver.block(from: view)?.lines == ["A", "B", "C", "D"])
}

@Test func forEachKeyPathRendersCollectionOrder() {
    let items = [
        ForEachTestItem(id: "a", label: "A"),
        ForEachTestItem(id: "b", label: "B"),
    ]

    let view = ForEach(items, id: \.id) { item in
        Text(item.label)
    }

    #expect(ViewResolver.block(from: view)?.lines == ["A", "B"])
}

@Test func forEachIdentifiableInitializerRendersCollectionOrder() {
    let items = [
        ForEachTestItem(id: "a", label: "A"),
        ForEachTestItem(id: "b", label: "B"),
    ]

    let view = ForEach(items) { item in
        Text(item.label)
    }

    #expect(ViewResolver.block(from: view)?.lines == ["A", "B"])
}

@Test func forEachRangeInitializerRendersValues() {
    let view = ForEach(0..<3) { value in
        Text(String(value))
    }

    #expect(ViewResolver.block(from: view)?.lines == ["0", "1", "2"])
}

@Test func forEachChildStateFollowsIDAfterReorder() {
    let runtime = StateRuntime()
    let probe = LabeledBindingProbe()
    let firstOrder = [
        ForEachTestItem(id: "a", label: "A"),
        ForEachTestItem(id: "b", label: "B"),
    ]
    let secondOrder = [
        ForEachTestItem(id: "b", label: "B"),
        ForEachTestItem(id: "a", label: "A"),
    ]

    #expect(
        runtime.block(from: ForEachStateView(items: firstOrder, probe: probe))?.lines
            == ["0", "0"]
    )

    probe.bindings["a"]?.wrappedValue = 7

    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(from: ForEachStateView(items: secondOrder, probe: probe))?.lines
            == ["0", "7"]
    )
}

@Test func forEachDeletedIDReinsertedStartsFreshState() {
    let runtime = StateRuntime()
    let probe = LabeledBindingProbe()
    let item = ForEachTestItem(id: "a", label: "A")

    #expect(runtime.block(from: ForEachStateView(items: [item], probe: probe))?.lines == ["0"])

    probe.bindings["a"]?.wrappedValue = 5

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: ForEachStateView(items: [], probe: probe)) == nil)
    #expect(runtime.block(from: ForEachStateView(items: [item], probe: probe))?.lines == ["0"])
}

@Test func forEachTapGestureDispatchesToRenderedRow() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let firstOrder = [
        ForEachTestItem(id: "a", label: "A"),
        ForEachTestItem(id: "b", label: "B"),
    ]
    let secondOrder = [
        ForEachTestItem(id: "b", label: "B"),
        ForEachTestItem(id: "a", label: "A"),
    ]

    _ = runtime.block(from: ForEachTapView(items: firstOrder, tapProbe: tapProbe))
    dispatchClick(to: runtime, column: 1, row: 2)

    _ = runtime.block(from: ForEachTapView(items: secondOrder, tapProbe: tapProbe))
    dispatchClick(to: runtime, column: 1, row: 2)

    #expect(tapProbe.events == ["b", "a"])
}

@Test func forEachButtonDispatchesToRenderedRow() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let firstOrder = [
        ForEachTestItem(id: "a", label: "A"),
        ForEachTestItem(id: "b", label: "B"),
    ]
    let secondOrder = [
        ForEachTestItem(id: "b", label: "B"),
        ForEachTestItem(id: "a", label: "A"),
    ]

    _ = runtime.block(from: ForEachButtonView(items: firstOrder, tapProbe: tapProbe))
    dispatchClick(to: runtime, column: 1, row: 2)

    _ = runtime.block(from: ForEachButtonView(items: secondOrder, tapProbe: tapProbe))
    dispatchClick(to: runtime, column: 1, row: 2)

    #expect(tapProbe.events == ["b", "a"])
}

@Test func windowGroupStoresRootView() {
    let scene = WindowGroup {
        Text("Hello, SwiftTUI")
    }

    #expect(ViewResolver.text(from: scene.root) == "Hello, SwiftTUI")
}

@Test func sceneResolverResolvesWindowGroupRootView() {
    let scene = WindowGroup {
        Text("Hello, SwiftTUI")
    }

    let root = SceneResolver.rootScene(from: scene)

    #expect(root != nil)
    if let root {
        #expect(ViewResolver.text(from: root.root) == "Hello, SwiftTUI")
    }
}

@Test func sceneBuilderLimitedAvailabilityResolvesRootScene() {
    let scene = SceneBuilder.buildLimitedAvailability(
        WindowGroup {
            Text("Limited scene")
        }
    )
    let root = SceneResolver.rootScene(from: scene)

    #expect(root != nil)
    if let root {
        #expect(ViewResolver.text(from: root.root) == "Limited scene")
    }
}

@Test func sceneBuilderOptionalLimitedAvailabilityResolvesNoRootSceneWhenAbsent() {
    let scene: LimitedAvailabilityScene<WindowGroup<Text>>? = nil

    #expect(SceneResolver.rootScene(from: SceneBuilder.buildOptional(scene)) == nil)
}

@Test func hStackDefaultSpacingPlacesTextSideBySide() {
    let stack = HStack {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "AB")
}

@Test func hStackExplicitSpacingInsertsSpaces() {
    let stack = HStack(spacing: 1) {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "A B")
}

@Test func textRunPreservesContentSpaces() {
    let block = ViewResolver.block(from: Text("A B C"))

    #expect(block?.runs == [RenderedRun(text: "A B C")])
}

@Test func hStackSpacingUsesRunCoordinatesInsteadOfSpaceRuns() {
    let block = ViewResolver.block(
        from: HStack(spacing: 3) {
            Text("A")
            Text("B")
        }
    )

    #expect(block?.runs == [
        RenderedRun(text: "A", row: 0, column: 0),
        RenderedRun(text: "B", row: 0, column: 4),
    ])
    #expect(block?.lines == ["A   B"])
}

@Test func vStackDefaultSpacingPlacesTextOnAdjacentRows() {
    let stack = VStack {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "A\nB")
}

@Test func vStackExplicitSpacingInsertsBlankRows() {
    let stack = VStack(spacing: 1) {
        Text("A")
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "A\n\nB")
}

@Test func layoutPaddingFrameAndSpacerDoNotCreateSpaceRuns() {
    let padded = ViewResolver.block(from: Text("A").padding())
    let framed = ViewResolver.block(from: Text("A").frame(width: 4, height: 3))
    let spacer = ViewResolver.block(from: Spacer(minLength: 2))

    #expect(padded?.runs == [RenderedRun(text: "A", row: 1, column: 1)])
    #expect(framed?.runs == [RenderedRun(text: "A", row: 1, column: 1)])
    #expect(spacer?.runs == [])
    #expect(spacer?.width == 2)
    #expect(spacer?.height == 2)
}

@Test func hiddenPreservesLayoutButRemovesOutputAndRegions() {
    let block = ViewResolver.block(
        from: Text("C")
            .onTapGesture {}
            .focusable()
            .hidden()
    )

    #expect(block?.width == 1)
    #expect(block?.height == 1)
    #expect(block?.runs == [])
    #expect(block?.cursor == nil)
    #expect(block?.hitRegions == [])
    #expect(block?.scrollRegions == [])
    #expect(block?.focusRegions == [])
}

@Test func hiddenKeepsStackSpacingFootprint() {
    let view = HStack {
        Text("A")
        Text("B")
            .hidden()
        Text("C")
    }

    #expect(ViewResolver.block(from: view)?.lines == ["A C"])
}

@Test func hiddenPreservesFramedPaddedWideCharacterSize() {
    let block = ViewResolver.block(
        from: Text("한")
            .padding()
            .frame(width: 5, height: 3)
            .hidden()
    )

    #expect(block?.width == 5)
    #expect(block?.height == 3)
    #expect(block?.runs == [])
}

@Test func hStackAlignsChildrenVertically() {
    let top = HStack(alignment: .top, spacing: 1) {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
        Text("X")
    }
    let center = HStack(alignment: .center, spacing: 1) {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
        Text("X")
    }
    let bottom = HStack(alignment: .bottom, spacing: 1) {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
        Text("X")
    }

    #expect(ViewResolver.block(from: top)?.lines == ["A X", "B  ", "C  "])
    #expect(ViewResolver.block(from: center)?.lines == ["A  ", "B X", "C  "])
    #expect(ViewResolver.block(from: bottom)?.lines == ["A  ", "B  ", "C X"])
}

@Test func renderedBlockWidthUsesTerminalColumns() {
    let block = ViewResolver.block(from: Text("한A"))

    #expect(block?.width == 3)
}

@Test func vStackAlignsChildrenHorizontally() {
    let leading = VStack(alignment: .leading) {
        Text("A")
        Text("BBB")
    }
    let center = VStack(alignment: .center) {
        Text("A")
        Text("BBB")
    }
    let trailing = VStack(alignment: .trailing) {
        Text("A")
        Text("BBB")
    }

    #expect(ViewResolver.block(from: leading)?.lines == ["A  ", "BBB"])
    #expect(ViewResolver.block(from: center)?.lines == [" A ", "BBB"])
    #expect(ViewResolver.block(from: trailing)?.lines == ["  A", "BBB"])
}

@Test func vStackAlignsWideTextByTerminalColumns() {
    let stack = VStack(alignment: .trailing) {
        Text("한")
        Text("ABC")
    }

    #expect(ViewResolver.block(from: stack)?.lines == [" 한", "ABC"])
}

@Test func spacerStoresNormalizedMinimumLength() {
    #expect(Spacer().minLength == nil)
    #expect(Spacer(minLength: 2).minLength == 2)
    #expect(Spacer(minLength: -1).minLength == 0)
}

@Test func terminalGeometryValuesPreserveNegativeComponents() {
    let size = Size(columns: -1, rows: -2)
    let point = Point(column: -3, row: -4)
    let frame = Rect(origin: point, size: size)

    #expect(size.columns == -1)
    #expect(size.rows == -2)
    #expect(point.column == -3)
    #expect(point.row == -4)
    #expect(frame.origin == point)
    #expect(frame.size == size)
    #expect(Size() == .zero)
    #expect(Point() == .zero)
    #expect(Rect() == .zero)
}

@Test func geometryReaderPassesProposedSizeToProxy() {
    let reader = GeometryReader { proxy in
        Text("\(proxy.size.columns)x\(proxy.size.rows)")
    }

    let block = ViewResolver.block(
        from: reader,
        in: RenderProposal(columns: 5, rows: 2)
    )

    #expect(block?.lines == ["5x2  ", "     "])
}

@Test func geometryReaderWithoutProposalUsesZeroSizeAndNaturalContent() {
    let reader = GeometryReader { proxy in
        Text("\(proxy.columns)x\(proxy.rows)")
    }

    let block = ViewResolver.block(from: reader)

    #expect(block?.lines == ["0x0"])
}

@Test func geometryProxyColumnsRowsAndFrameMirrorSize() {
    let proxy = GeometryProxy(columns: 7, rows: 1)

    #expect(proxy.columns == 7)
    #expect(proxy.rows == 1)
    #expect(proxy.frame == Rect(origin: .zero, size: Size(columns: 7, rows: 1)))
}

@Test func geometryReaderExposesLocalFrameFromProposal() {
    let reader = GeometryReader { proxy in
        Text(
            "\(proxy.frame.origin.column),\(proxy.frame.origin.row),"
                + "\(proxy.frame.size.columns),\(proxy.frame.size.rows)"
        )
    }

    let block = ViewResolver.block(
        from: reader,
        in: RenderProposal(columns: 7, rows: 1)
    )

    #expect(block?.lines == ["0,0,7,1"])
}

@Test func geometryReaderUsesStackAxisProposals() {
    let vertical = VStack {
        GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
    }
    let horizontal = HStack {
        GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }
    }

    let verticalBlock = ViewResolver.block(
        from: vertical,
        in: RenderProposal(columns: 6, rows: 2)
    )
    let horizontalBlock = ViewResolver.block(
        from: horizontal,
        in: RenderProposal(columns: 6, rows: 2)
    )

    #expect(verticalBlock?.lines == ["6x2   ", "      "])
    #expect(horizontalBlock?.lines == ["6x2   ", "      "])
}

@Test func geometryReaderClipsAndPadsKnownProposedAxes() {
    let reader = GeometryReader { _ in
        Text("ABCDE")
            .fixedSize(horizontal: true, vertical: false)
    }

    let block = ViewResolver.block(
        from: reader,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["ABC", "   "])
}

@Test func hStackSpacerWithoutProposalUsesZeroMinimumLength() {
    let stack = HStack {
        Text("A")
        Spacer()
        Text("B")
    }

    #expect(ViewResolver.text(from: stack) == "AB")
}

@Test func hStackSpacerFillsProposedColumns() {
    let stack = HStack {
        Text("A")
        Spacer()
        Text("B")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 5))

    #expect(block?.lines == ["A   B"])
}

@Test func hStackSpacersShareRemainingColumns() {
    let stack = HStack {
        Text("A")
        Spacer()
        Text("B")
        Spacer()
        Text("C")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 8))

    #expect(block?.lines == ["A   B  C"])
}

@Test func vStackSpacerFillsProposedRows() {
    let stack = VStack {
        Text("A")
        Spacer()
        Text("B")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(rows: 5))

    #expect(block?.lines == ["A", " ", " ", " ", "B"])
}

@Test func plainVStackKeepsNaturalHeightWhenRowsAreProposed() {
    let stack = VStack {
        Text("A")
        Text("B")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 4, rows: 5))

    #expect(block?.height == 2)
    #expect(block?.lines == ["A", "B"])
}

@Test func scrollViewClipsVerticallyByDefault() {
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }

    let block = ViewResolver.block(from: scrollView, in: RenderProposal(rows: 2))

    #expect(block?.lines == ["A", "B"])
}

@Test func verticalScrollViewInsideVStackReceivesRemainingViewport() {
    let stack = VStack(alignment: .leading) {
        Text("H")
        ScrollView {
            VStack(alignment: .leading) {
                Text("A")
                Text("B")
                Text("C")
                Text("D")
            }
        }
        Text("F")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 4, rows: 5))

    #expect(block?.lines == [
        "H   ",
        "A   ",
        "B   ",
        "C   ",
        "F   ",
    ])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 1, width: 4, height: 3),
    ])
}

@Test func retortFediLikeScreenKeepsScrollViewportFooterAndInputRegions() {
    let runtime = StateRuntime()
    let view = RetortFediLikeConfigurationScreen()

    let block = runtime.block(from: view, in: RenderProposal(columns: 10, rows: 7))

    #expect(block?.lines == [
        "Title     ",
        "Name      ",
        "Row2      ",
        "Row3      ",
        "Row4      ",
        "Desc      ",
        "Footer    ",
    ])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 1, width: 10, height: 4),
    ])

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 2, phase: .down)
        ) == .handled
    )
    #expect(runtime.consumeInvalidation())
    #expect(runtime.dispatch(KeyPress(key: "x", characters: "x")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(from: view, in: RenderProposal(columns: 10, rows: 7))?.lines == [
            "Title     ",
            "x         ",
            "Row2      ",
            "Row3      ",
            "Row4      ",
            "Desc      ",
            "Footer    ",
        ]
    )
}

@Test func geometryReaderRouteTransitionKeepsFocusAndKeyDispatch() {
    let runtime = StateRuntime()
    let view = GeometryReaderRouteHost()
    let proposal = RenderProposal(columns: 12, rows: 7)

    #expect(runtime.block(from: view, in: proposal)?.lines == [
        "Menu",
    ])

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())

    let configurationBlock = runtime.block(from: view, in: proposal)
    #expect(configurationBlock?.lines == [
        "Size 12x7   ",
        "> Row0      ",
        "  Row1      ",
        "  Row2      ",
        "  Row3      ",
        "Desc        ",
        "Footer      ",
    ])
    #expect(configurationBlock?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 1, width: 12, height: 4),
    ])
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view, in: proposal)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 2, phase: .down)
        ) == .handled
    )
    _ = runtime.consumeInvalidation()
    #expect(runtime.dispatch(KeyPress(key: .downArrow, characters: "\u{F701}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view, in: proposal)?.lines == [
        "Size 12x7   ",
        "  Row0      ",
        "> Row1      ",
        "  Row2      ",
        "  Row3      ",
        "Desc        ",
        "Footer      ",
    ])
}

@Test func scrollViewClipsHorizontally() {
    let scrollView = ScrollView(.horizontal) {
        Text("ABCDE")
    }

    let block = ViewResolver.block(from: scrollView, in: RenderProposal(columns: 3))

    #expect(block?.lines == ["ABC"])
}

@Test func scrollViewAppliesPointPositionOnBothAxes() {
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(.constant(ScrollPosition(point: ScrollPoint(x: 1, y: 1))))

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["GHI", "LMN"])
}

@Test func textFieldFillsRemainingColumnsInHStack() {
    let stack = HStack {
        Text("[")
        TextField("Name", text: .constant(""))
        Text("]")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 8))

    #expect(block?.lines == ["[Name  ]"])
}

@Test func textFieldTakesRemainingColumnsBeforeSpacer() {
    let stack = HStack {
        TextField("Text Field", text: .constant(""))
        Spacer()
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 20))

    #expect(block?.width == 20)
    #expect(block?.lines == ["Text Field          "])
    #expect(block?.focusRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 20, height: 1),
    ])
}

@Test func textFieldKeepsFullWidthInsideProposedVStack() {
    let stack = VStack {
        HStack {
            TextField("Text Field", text: .constant(""))
            Spacer()
        }
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 20, rows: 5))

    #expect(block?.width == 20)
    #expect(block?.height == 1)
    #expect(block?.lines == ["Text Field          "])
}

@Test func longFixedSiblingDoesNotMoveProposedStackOrigin() {
    let longText = String(repeating: "가나다라마바사아자차카타파하", count: 4)
    let stack = VStack {
        HStack {
            Text("Settings")
            Spacer()
        }
        HStack(spacing: 1) {
            Text(" ")
            TextField("Admin Token", text: .constant(longText))
            Spacer()
        }
        HStack {
            Text(longText)
            Spacer()
        }
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 40, rows: 24))

    #expect(block?.width == 40)
    #expect(block?.lines.first?.hasPrefix("Settings") == true)
}

@Test func verticalScrollViewProposesWidthToTextField() {
    let scrollView = ScrollView {
        TextField("Vertical", text: .constant(""))
    }

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 10, rows: 3)
    )

    #expect(block?.lines == [
        "Vertical  ",
        "          ",
        "          ",
    ])
    #expect(block?.focusRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 10, height: 1),
    ])
}

@Test func horizontalScrollViewKeepsTextFieldContentIntrinsic() {
    let scrollView = ScrollView(.horizontal) {
        TextField("Horizontal", text: .constant(""))
    }

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 15)
    )

    #expect(block?.lines == ["Horizontal     "])
    #expect(block?.focusRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 10, height: 1),
    ])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 15, height: 1),
    ])
}

@Test func textFieldScrollViewCombinationMatchesSwiftUIExpansionShape() {
    let stack = HStack {
        ScrollView {
            TextField("Vertically expanded", text: .constant(""))
        }
        ScrollView(.horizontal) {
            TextField("Horizontally expanded", text: .constant(""))
        }
    }

    let block = ViewResolver.block(
        from: stack,
        in: RenderProposal(columns: 50, rows: 5)
    )

    #expect(block?.lines == [
        "Vertically expanded" + String(repeating: " ", count: 31),
        String(repeating: " ", count: 50),
        String(repeating: " ", count: 25) + "Horizontally expanded    ",
        String(repeating: " ", count: 50),
        String(repeating: " ", count: 50),
    ])
    #expect(block?.focusRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 25, height: 1),
        RenderedRect(x: 25, y: 2, width: 21, height: 1),
    ])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 25, height: 5),
        RenderedRect(x: 25, y: 2, width: 25, height: 1),
    ])
}

@Test func clickingConstantTextFieldsInsideScrollViewsMovesFocusAndTypes() {
    let runtime = StateRuntime()
    let view = ScrollWrappedTextFieldsClickFocusView()

    #expect(
        runtime.block(
            from: view,
            in: RenderProposal(columns: 20, rows: 3)
        )?.lines == [
            "Vertical            ",
            "          Horizontal",
            "                    ",
        ]
    )

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(runtime.consumeInvalidation())
    #expect(runtime.dispatch(KeyPress(key: "v", characters: "v")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: view,
            in: RenderProposal(columns: 20, rows: 3)
        )?.lines == [
            "v                   ",
            "          Horizontal",
            "                    ",
        ]
    )

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 11, row: 2, phase: .down)
        ) == .handled
    )
    #expect(runtime.consumeInvalidation())
    #expect(runtime.dispatch(KeyPress(key: "h", characters: "h")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: view,
            in: RenderProposal(columns: 20, rows: 3)
        )?.lines == [
            "v                   ",
            "          h         ",
            "                    ",
        ]
    )
}

@Test func topLevelScrollViewsExpandAlongScrollableAxesOnly() {
    let vertical = ScrollView {
        VStack {
            Text("V0")
            Text("V1")
            Text("V2")
        }
    }
    let horizontal = ScrollView(.horizontal) {
        Text("H012345")
    }
    let both = ScrollView([.horizontal, .vertical]) {
        VStack(alignment: .leading) {
            Text("B012345")
            Text("B1")
        }
    }

    let verticalBlock = ViewResolver.block(
        from: vertical,
        in: RenderProposal(columns: 8, rows: 4)
    )
    let horizontalBlock = ViewResolver.block(
        from: horizontal,
        in: RenderProposal(columns: 5, rows: 4)
    )
    let bothBlock = ViewResolver.block(
        from: both,
        in: RenderProposal(columns: 5, rows: 3)
    )

    #expect(verticalBlock?.lines == ["V0      ", "V1      ", "V2      ", "        "])
    #expect(horizontalBlock?.lines == ["H0123"])
    #expect(bothBlock?.lines == ["B0123", "B1   ", "     "])
    #expect(verticalBlock?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 8, height: 4),
    ])
    #expect(horizontalBlock?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 5, height: 1),
    ])
    #expect(bothBlock?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 5, height: 3),
    ])
}

@Test func runtimeRootScrollViewUsesTopLevelExpansionRules() {
    let runtime = StateRuntime()
    let scrollView = ScrollView(.horizontal) {
        Text("ABCDE")
    }

    let block = runtime.block(from: scrollView, in: RenderProposal(columns: 3, rows: 2))

    #expect(block?.lines == ["ABC"])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 3, height: 1),
    ])
}

@Test func scrollViewsExpandAlongScrollableAxesInsideHStack() {
    let stack = HStack {
        ScrollView {
            VStack {
                Text("V0")
                Text("V1")
                Text("V2")
            }
        }
        ScrollView(.horizontal) {
            Text("H0123456789")
        }
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 8, rows: 4))

    #expect(block?.lines == [
        "V0      ",
        "V1  H012",
        "V2      ",
        "        ",
    ])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 4, height: 4),
        RenderedRect(x: 4, y: 1, width: 4, height: 1),
    ])
}

@Test func scrollViewsExpandAlongScrollableAxesInsideVStack() {
    let stack = VStack(alignment: .leading) {
        ScrollView(.horizontal) {
            Text("ABCDE")
        }
        ScrollView {
            VStack {
                Text("V0")
                Text("V1")
                Text("V2")
            }
        }
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading) {
                Text("B012345")
                Text("B1")
            }
        }
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 5, rows: 6))

    #expect(block?.lines == [
        "ABCDE",
        "V0   ",
        "V1   ",
        "V2   ",
        "B0123",
        "B1   ",
    ])
}

@Test func emptyScrollViewParticipatesInVStackExpansion() {
    let stack = VStack(alignment: .leading) {
        Box {
            TextEditor(text: .constant("TextEditor"))
        }
        ScrollView {
        }
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 14, rows: 6))

    #expect(block?.lines == [
        "┌────────────┐",
        "│TextEditor  │",
        "└────────────┘",
        "              ",
        "              ",
        "              ",
    ])
    #expect(block?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 3, width: 14, height: 3),
    ])
}

@Test func scrollViewAndSpacerShareStackRemainder() {
    let stack = HStack {
        ScrollView(.horizontal) {
            Text("ABCDE")
        }
        Spacer()
        Text("Z")
    }

    let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 10))

    #expect(block?.lines == ["ABCDE    Z"])
}

@Test func fixedSizeAndFramePreventScrollExpansionOnFixedAxes() {
    let fixedSize = HStack {
        ScrollView(.horizontal) {
            Text("ABCDE")
        }
        .fixedSize(horizontal: true, vertical: false)
        Text("Z")
    }
    let fixedFrame = HStack {
        ScrollView(.horizontal) {
            Text("ABCDE")
        }
        .frame(width: 3, alignment: .leading)
        Text("Z")
    }

    #expect(ViewResolver.block(from: fixedSize, in: RenderProposal(columns: 10))?.lines == ["ABCDEZ"])
    #expect(ViewResolver.block(from: fixedFrame, in: RenderProposal(columns: 10))?.lines == ["ABCZ"])
}

@Test func scrollExpansionPreservesWrappedHitFocusAndScrollRegions() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = HStack {
        ScrollView(.horizontal) {
            Text("ABCDE")
        }
        .scrollPosition(.constant(ScrollPosition(x: 1)))
        .padding(.horizontal, 1)
        .onTapGesture {
            tapProbe.record("tap")
        }
        .focusable()
    }

    let block = runtime.block(from: view, in: RenderProposal(columns: 5, rows: 1))

    #expect(block?.lines == [" BCD "])
    #expect(block?.scrollRegions.map(\.frame) == [RenderedRect(x: 1, y: 0, width: 3, height: 1)])
    #expect(block?.hitRegions.map(\.frame) == [RenderedRect(x: 0, y: 0, width: 5, height: 1)])
    #expect(block?.focusRegions.map(\.frame) == [RenderedRect(x: 0, y: 0, width: 5, height: 1)])
}

@Test func stackMeasurementDoesNotUpdateScrollPositionBindingBeforeFinalViewport() {
    var position = ScrollPosition(x: 99)
    let view = HStack {
        ScrollView(.horizontal) {
            Text("ABCDE")
        }
        .scrollPosition(
            Binding(
                get: { position },
                set: { position = $0 }
            )
        )
    }

    let block = ViewResolver.block(from: view, in: RenderProposal(columns: 3))

    #expect(block?.lines == ["CDE"])
    #expect(position.point == ScrollPoint(x: 2))
}

@Test func scrollPositionMutatingMethodsReplacePosition() {
    var position = ScrollPosition()
    #expect(position.point == nil)
    #expect(position.edge == nil)

    position.scrollTo(point: ScrollPoint(x: 1, y: 2))
    #expect(position.point == ScrollPoint(x: 1, y: 2))
    #expect(position.x == 1)
    #expect(position.y == 2)

    position.scrollTo(x: 4)
    #expect(position.point == ScrollPoint(x: 4, y: 0))

    position.scrollTo(y: 5)
    #expect(position.point == ScrollPoint(x: 0, y: 5))

    position.scrollTo(x: 6, y: 7)
    #expect(position.point == ScrollPoint(x: 6, y: 7))

    position.scrollTo(edge: .bottom)
    #expect(position.point == nil)
    #expect(position.edge == .bottom)
}

@Test func scrollPositionNormalizesNegativeCoordinates() {
    #expect(ScrollPoint(x: -1, y: -2) == ScrollPoint())
    #expect(ScrollPosition(x: -3).point == ScrollPoint())
    #expect(ScrollPosition(y: -4).point == ScrollPoint())
    #expect(ScrollPosition(x: -5, y: -6).point == ScrollPoint())
}

@Test func scrollViewResolvesEdgePositions() {
    let vertical = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .scrollPosition(.constant(ScrollPosition(edge: .bottom)))
    let horizontal = ScrollView(.horizontal) {
        Text("ABCDE")
    }
    .scrollPosition(.constant(ScrollPosition(edge: .trailing)))

    let verticalBlock = ViewResolver.block(from: vertical, in: RenderProposal(rows: 2))
    let horizontalBlock = ViewResolver.block(from: horizontal, in: RenderProposal(columns: 3))

    #expect(verticalBlock?.lines == ["B", "C"])
    #expect(horizontalBlock?.lines == ["CDE"])
}

@Test func scrollViewIgnoresPositionOnDisabledAxes() {
    let vertical = ScrollView {
        Text("ABCDE")
    }
    .scrollPosition(.constant(ScrollPosition(x: 2, y: 0)))
    .frame(width: 3, height: 1, alignment: .leading)
    let horizontal = ScrollView(.horizontal) {
        VStack {
            Text("ABC")
            Text("DEF")
        }
    }
    .scrollPosition(.constant(ScrollPosition(x: 0, y: 1)))
    .frame(width: 3, height: 1, alignment: .topLeading)

    let verticalBlock = ViewResolver.block(from: vertical)
    let horizontalBlock = ViewResolver.block(from: horizontal)

    #expect(verticalBlock?.lines == ["ABC"])
    #expect(horizontalBlock?.lines == ["ABC"])
}

@Test func scrollViewClampsOversizedPositions() {
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(.constant(ScrollPosition(x: 99, y: 99)))

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["HIJ", "MNO"])
}

@Test func scrollViewScrollsWithMouseWheelWithoutFocus() {
    let runtime = StateRuntime()
    let view = FocusedScrollWheelView()

    #expect(runtime.block(from: view)?.lines == ["focus", "A    ", "B    "])
    _ = runtime.consumeInvalidation()

    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 2)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["focus", "B    ", "C    "])
}

@Test func scrollViewWheelUpdatesScrollPositionBinding() {
    var position = ScrollPosition()
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .scrollPosition(
        Binding(
            get: { position },
            set: { position = $0 }
        )
    )
    .frame(width: 1, height: 2)
    let runtime = StateRuntime()

    #expect(runtime.block(from: scrollView)?.lines == ["A", "B"])
    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)

    #expect(position.point == ScrollPoint(y: 1))
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["B", "C"])
}

@Test func disabledScrollViewIgnoresWheelInput() {
    var position = ScrollPosition()
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .scrollPosition(
        Binding(
            get: { position },
            set: { position = $0 }
        )
    )
    .frame(width: 1, height: 2)
    .disabled(true)
    let runtime = StateRuntime()

    let block = runtime.block(from: scrollView)

    #expect(block?.lines == ["A", "B"])
    #expect(block?.scrollRegions == [])
    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1, expecting: .ignored)

    #expect(position.point == nil)
    #expect(!runtime.consumeInvalidation())
}

@Test func scrollViewWheelStoresPositionWithoutBinding() {
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .frame(width: 1, height: 2)
    let runtime = StateRuntime()

    #expect(runtime.block(from: scrollView)?.lines == ["A", "B"])
    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["B", "C"])
}

@Test func scrollViewWheelSupportsHorizontalAxes() {
    let scrollView = ScrollView(.horizontal) {
        Text("ABCDE")
    }
    .frame(width: 3, height: 1)
    let runtime = StateRuntime()

    #expect(runtime.block(from: scrollView)?.lines == ["ABC"])
    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["BCD"])
}

@Test func horizontalScrollViewWheelRegionUsesFramedViewport() {
    var position = ScrollPosition()
    let scrollView = ScrollView(.horizontal) {
        Text("ABCDE")
    }
    .scrollPosition(
        Binding(
            get: { position },
            set: { position = $0 }
        )
    )
    .frame(width: 3, height: 4, alignment: .topLeading)
    let runtime = StateRuntime()

    #expect(runtime.block(from: scrollView)?.scrollRegions.map(\.frame) == [
        RenderedRect(x: 0, y: 0, width: 3, height: 4),
    ])

    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 4)

    #expect(position.point == ScrollPoint(x: 1))
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["BCD", "   ", "   ", "   "])
}

@Test func scrollViewWheelSupportsNativeHorizontalAndShiftFallback() {
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
        }
    }
    .frame(width: 3, height: 1)
    let runtime = StateRuntime()

    #expect(runtime.block(from: scrollView)?.lines == ["ABC"])
    dispatchWheel(to: runtime, button: .wheelRight, column: 1, row: 1)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["BCD"])

    dispatchWheel(to: runtime, button: .wheelLeft, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["ABC"])

    dispatchWheel(
        to: runtime,
        button: .wheelDown,
        column: 1,
        row: 1,
        modifiers: .shift
    )
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["BCD"])
}

@Test func scrollViewWheelBubblesWhenInnerRegionCannotScroll() {
    let scrollView = ScrollView {
        VStack {
            ScrollView {
                VStack {
                    Text("A")
                    Text("B")
                }
            }
            .frame(width: 1, height: 2)
            Text("C")
            Text("D")
        }
    }
    .frame(width: 1, height: 2)
    let runtime = StateRuntime()

    #expect(runtime.block(from: scrollView)?.lines == ["A", "B"])
    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: scrollView)?.lines == ["B", "C"])
}

@Test func nestedScrollViewWheelPrefersInnerRegionBeforeOuterRegion() {
    var outerPosition = ScrollPosition()
    var innerPosition = ScrollPosition()
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack(alignment: .leading) {
            Text("top")
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            .scrollPosition(
                Binding(
                    get: { innerPosition },
                    set: { innerPosition = $0 }
                )
            )
            .frame(width: 3, height: 1, alignment: .leading)
            Text("bottom")
        }
    }
    .scrollPosition(
        Binding(
            get: { outerPosition },
            set: { outerPosition = $0 }
        )
    )
    let runtime = StateRuntime()

    #expect(
        runtime.block(
            from: scrollView,
            in: RenderProposal(columns: 5, rows: 2)
        )?.lines == ["top  ", "ABC  "]
    )
    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 2)

    #expect(innerPosition.point == ScrollPoint(x: 1))
    #expect(outerPosition.point == nil)
    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: scrollView,
            in: RenderProposal(columns: 5, rows: 2)
        )?.lines == ["top  ", "BCD  "]
    )
}

@Test func scrollViewWheelIgnoresEventsOutsideRenderedRegion() {
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .frame(width: 1, height: 2)
    let runtime = StateRuntime()

    #expect(runtime.block(from: scrollView)?.lines == ["A", "B"])
    dispatchWheel(
        to: runtime,
        button: .wheelDown,
        column: 2,
        row: 1,
        expecting: .ignored
    )
    #expect(!runtime.consumeInvalidation())
}

@Test func frameClipsAndPadsToFixedSize() {
    let view = Text("AB").frame(width: 4, height: 2)

    let block = ViewResolver.block(from: view)

    #expect(block?.lines == [" AB ", "    "])
}

@Test func frameClipsWideTextByTerminalColumns() {
    let view = Text("한A").frame(width: 2, height: 1)

    let block = ViewResolver.block(from: view)

    #expect(block?.lines == ["한"])
    #expect(block?.width == 2)
}

@Test func edgeSetConstantsAndArrayLiteralsMatchEdges() {
    let horizontal: Edge.Set = [.leading, .trailing]
    let vertical: Edge.Set = [.top, .bottom]

    #expect(Edge.Set(.top) == .top)
    #expect(horizontal == .horizontal)
    #expect(vertical == .vertical)
    #expect(Edge.Set.all == [.horizontal, .vertical])
}

@Test func edgeInsetsNormalizeNegativeComponents() {
    let insets = EdgeInsets(top: -1, leading: 2, bottom: -3, trailing: 4)

    #expect(insets == EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 4))
}

@Test func paddingDefaultsToOneCellOnAllEdges() {
    let block = ViewResolver.block(from: Text("A").padding())

    #expect(block?.lines == ["   ", " A ", "   "])
}

@Test func paddingAppliesSelectedEdgesAndExplicitLengths() {
    let horizontal = ViewResolver.block(from: Text("A").padding(.horizontal, 2))
    let insets = ViewResolver.block(
        from: Text("A").padding(EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 2))
    )

    #expect(horizontal?.lines == ["  A  "])
    #expect(insets?.lines == ["   ", "A  "])
}

@Test func paddingPreservesWideTextCellWidth() {
    let block = ViewResolver.block(from: Text("한A").padding(.trailing, 1))

    #expect(block?.lines == ["한A "])
    #expect(block?.width == 4)
}

@Test func paddingReducesProposalForContent() {
    let view = GeometryReader { proxy in
        Text("\(proxy.columns)x\(proxy.rows)")
    }
    .padding()

    let block = ViewResolver.block(from: view, in: RenderProposal(columns: 6, rows: 3))

    #expect(block?.lines == ["      ", " 4x1  ", "      "])
}

@Test func paddingOffsetsCursor() {
    let runtime = StateRuntime()
    let view = TextFieldEditingView()
        .padding(EdgeInsets(top: 1, leading: 2, bottom: 0, trailing: 0))

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    let block = runtime.block(from: view)

    #expect(block?.lines == ["      ", "  Name"])
    #expect(block?.cursor == RenderedCursor(row: 1, column: 2))
}

@Test func paddingOffsetsHitRegions() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = Text("A")
        .onTapGesture {
            tapProbe.record("tap")
        }
        .padding(EdgeInsets(top: 1, leading: 1, bottom: 0, trailing: 0))

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
    dispatchClick(to: runtime, column: 2, row: 2)

    #expect(tapProbe.events == ["tap"])
}

@Test func frameAlignsContentWithinLargerSize() {
    let block = ViewResolver.block(
        from: Text("A").frame(width: 4, height: 3, alignment: .bottomTrailing)
    )

    #expect(block?.lines == ["    ", "    ", "   A"])
}

@Test func frameAlignmentControlsClippingOrigin() {
    let center = ViewResolver.block(
        from: Text("ABCDE")
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: 3)
    )
    let trailing = ViewResolver.block(
        from: Text("ABCDE")
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: 3, alignment: .trailing)
    )

    #expect(center?.lines == ["BCD"])
    #expect(trailing?.lines == ["CDE"])
}

@Test func constrainedFrameAppliesMinimums() {
    let block = ViewResolver.block(
        from: Text("A").frame(minWidth: 3, minHeight: 2, alignment: .topLeading)
    )

    #expect(block?.lines == ["A  ", "   "])
}

@Test func constrainedFrameAppliesMaximums() {
    let block = ViewResolver.block(
        from: Text("ABCDE").frame(maxWidth: 3, alignment: .trailing)
    )

    #expect(block?.lines == ["CDE"])
}

@Test func constrainedFrameClampsParentProposalWhenMinimumAndMaximumAreSet() {
    let view = Text("A").frame(minWidth: 2, maxWidth: 4, alignment: .trailing)

    let block = ViewResolver.block(from: view, in: RenderProposal(columns: 5))

    #expect(block?.lines == ["   A"])
}

@Test func constrainedFrameDoesNotForceIdealSizeOnFixedContent() {
    let block = ViewResolver.block(
        from: Text("A").frame(idealWidth: 4, idealHeight: 2, alignment: .bottomTrailing)
    )

    #expect(block?.lines == ["A"])
}

@Test func constrainedFrameProposesIdealSizeToFlexibleContent() {
    let view = GeometryReader { proxy in
        Text("\(proxy.columns)x\(proxy.rows)")
    }
    .frame(idealWidth: 4, idealHeight: 2, alignment: .bottomTrailing)

    let block = ViewResolver.block(from: view)

    #expect(block?.lines == ["4x2 ", "    "])
}

@Test func constrainedFrameNormalizesNegativeLengths() {
    let block = ViewResolver.block(
        from: Text("A").frame(minWidth: -2, maxWidth: -1, minHeight: -2, maxHeight: -1)
    )

    #expect(block?.lines == [])
}

@Test func fixedSizeIgnoresSelectedProposedAxes() {
    let horizontal = GeometryReader { proxy in
        Text("\(proxy.columns)x\(proxy.rows)")
    }
    .fixedSize(horizontal: true, vertical: false)
    let vertical = GeometryReader { proxy in
        Text("\(proxy.columns)x\(proxy.rows)")
    }
    .fixedSize(horizontal: false, vertical: true)
    let both = GeometryReader { proxy in
        Text("\(proxy.columns)x\(proxy.rows)")
    }
    .fixedSize()

    #expect(
        ViewResolver.block(from: horizontal, in: RenderProposal(columns: 5, rows: 2))?.lines
            == ["0x2", "   "]
    )
    #expect(
        ViewResolver.block(from: vertical, in: RenderProposal(columns: 5, rows: 2))?.lines
            == ["5x0  "]
    )
    #expect(
        ViewResolver.block(from: both, in: RenderProposal(columns: 5, rows: 2))?.lines
            == ["0x0"]
    )
}

@Test func frameProvidesViewportToNestedScrollView() {
    let view = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(.constant(ScrollPosition(x: 1, y: 1)))
    .frame(width: 3, height: 2)

    let block = ViewResolver.block(from: view)

    #expect(block?.lines == ["GHI", "LMN"])
}

@Test func scrollPositionBindingClampsOversizedPoint() {
    var position = ScrollPosition(x: 99, y: 99)
    let scrollView = ScrollView([.horizontal, .vertical]) {
        VStack {
            Text("ABCDE")
            Text("FGHIJ")
            Text("KLMNO")
        }
    }
    .scrollPosition(
        Binding(
            get: { position },
            set: { position = $0 }
        )
    )

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 2)
    )

    #expect(block?.lines == ["HIJ", "MNO"])
    #expect(position.point == ScrollPoint(x: 2, y: 1))
}

@Test func scrollPositionBindingResolvesEdgeToClampedPoint() {
    var position = ScrollPosition(edge: .bottom)
    let scrollView = ScrollView {
        VStack {
            Text("A")
            Text("B")
            Text("C")
        }
    }
    .scrollPosition(
        Binding(
            get: { position },
            set: { position = $0 }
        )
    )

    let block = ViewResolver.block(from: scrollView, in: RenderProposal(rows: 2))

    #expect(block?.lines == ["B", "C"])
    #expect(position.point == ScrollPoint(y: 1))
}

@Test func viewIDResetsSubtreeStateWhenIDChanges() {
    let runtime = StateRuntime()

    #expect(runtime.block(from: ExplicitIDCounterHost(id: 1))?.text == "0")
    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: ExplicitIDCounterHost(id: 1))?.text == "1")
    #expect(runtime.block(from: ExplicitIDCounterHost(id: 1))?.text == "1")
    #expect(runtime.block(from: ExplicitIDCounterHost(id: 2))?.text == "0")
}

@Test func viewIDResetsNestedScrollStateWhenIDChanges() {
    let runtime = StateRuntime()

    #expect(runtime.block(from: ExplicitIDScrollHost(id: 1))?.lines == ["A", "B"])
    dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: ExplicitIDScrollHost(id: 1))?.lines == ["B", "C"])
    #expect(runtime.block(from: ExplicitIDScrollHost(id: 2))?.lines == ["A", "B"])
}

@Test func scrollViewReaderScrollsToIdentifiedViewFromButtonAction() {
    let runtime = StateRuntime()
    let view = ReaderScrollToBottomView()

    #expect(runtime.block(from: view)?.lines == ["go", "A ", "B "])
    dispatchClick(to: runtime, column: 1, row: 1)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["go", "C ", "D "])
}

@Test func scrollViewReaderAlignsExplicitAnchors() {
    let runtime = StateRuntime()
    let bottom = ReaderAnchorScrollView(anchor: .bottom)

    #expect(runtime.block(from: bottom)?.lines == ["go", "A ", "B "])
    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: bottom)?.lines == ["go", "B ", "C "])

    let topRuntime = StateRuntime()
    let top = ReaderAnchorScrollView(anchor: .top)
    #expect(topRuntime.block(from: top)?.lines == ["go", "A ", "B "])
    dispatchClick(to: topRuntime, column: 1, row: 1)
    #expect(topRuntime.consumeInvalidation())
    #expect(topRuntime.block(from: top)?.lines == ["go", "C ", "D "])
}

@Test func scrollViewReaderUpdatesScrollPositionBinding() {
    var position = ScrollPosition()
    let runtime = StateRuntime()
    let view = ReaderBindingScrollView(
        position: Binding(
            get: { position },
            set: { position = $0 }
        )
    )

    #expect(runtime.block(from: view)?.lines == ["go", "A ", "B "])
    dispatchClick(to: runtime, column: 1, row: 1)

    #expect(position.point == ScrollPoint(y: 1))
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.lines == ["go", "B ", "C "])
}

@Test func scrollViewReaderSupportsHorizontalAndTwoAxisScrolling() {
    let horizontalRuntime = StateRuntime()
    let horizontal = ReaderHorizontalScrollView()

    #expect(horizontalRuntime.block(from: horizontal)?.lines == ["go", "AB"])
    dispatchClick(to: horizontalRuntime, column: 1, row: 1)
    #expect(horizontalRuntime.consumeInvalidation())
    #expect(horizontalRuntime.block(from: horizontal)?.lines == ["go", "BC"])

    let twoAxisRuntime = StateRuntime()
    let twoAxis = ReaderTwoAxisScrollView()

    #expect(twoAxisRuntime.block(from: twoAxis)?.lines == ["go", "AB", "DE"])
    dispatchClick(to: twoAxisRuntime, column: 1, row: 1)
    #expect(twoAxisRuntime.consumeInvalidation())
    #expect(twoAxisRuntime.block(from: twoAxis)?.lines == ["go", "EF", "HI"])
}

@Test func scrollViewReaderIgnoresMissingAndOutOfScopeIDs() {
    let missingRuntime = StateRuntime()
    let missing = ReaderMissingIDView()

    #expect(missingRuntime.block(from: missing)?.lines == ["go", "A ", "B "])
    dispatchClick(to: missingRuntime, column: 1, row: 1)
    _ = missingRuntime.consumeInvalidation()
    #expect(missingRuntime.block(from: missing)?.lines == ["go", "A ", "B "])

    let scopedRuntime = StateRuntime()
    let scoped = ReaderOutOfScopeView()
    #expect(scopedRuntime.block(from: scoped)?.lines == ["go", "X ", "A ", "B "])
    dispatchClick(to: scopedRuntime, column: 1, row: 1)
    _ = scopedRuntime.consumeInvalidation()
    #expect(scopedRuntime.block(from: scoped)?.lines == ["go", "X ", "A ", "B "])
}

@Test func scrollPositionModifierAffectsScrollableDescendantOnly() {
    let scrolled = HStack {
        ScrollView {
            VStack {
                Text("A")
                Text("B")
                Text("C")
            }
        }
    }
    .scrollPosition(.constant(ScrollPosition(y: 1)))
    let unchanged = Text("Hello").scrollPosition(.constant(ScrollPosition(y: 9)))

    let scrolledBlock = ViewResolver.block(from: scrolled, in: RenderProposal(rows: 2))
    let unchangedBlock = ViewResolver.block(from: unchanged, in: RenderProposal(rows: 1))

    #expect(scrolledBlock?.lines == ["B", "C"])
    #expect(unchangedBlock?.lines == ["Hello"])
}

@Test func textStyleSurvivesScrollViewClipping() {
    let scrollView = ScrollView(.horizontal) {
        Text("ABCDE")
            .foregroundStyle(.magenta)
    }
    .scrollPosition(.constant(ScrollPosition(x: 2)))

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 1)
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "CDE",
            style: TextStyle(foregroundStyle: AnyColor(Color16.magenta))
        ),
    ])
    #expect(block?.lines == ["CDE"])
}

@Test func textFrameCentersInViewport() {
    let frame = TextRenderer.frame(
        for: "Hello",
        in: TerminalViewportSize(columns: 400, rows: 240)
    )

    #expect(frame == TextFrame(text: "Hello", row: 120, column: 198))
}

@Test func screenOutputClearsAndMovesCursorBeforeText() {
    let output = TextRenderer.screen(
        for: "Hello",
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[3;3HHello\u{001B}[?25l")
}

@Test func screenOutputCentersMultipleLines() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["A", "B"]),
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[2;5HA\u{001B}[3;5HB\u{001B}[?25l")
}

@Test func screenOutputMovesDirectlyBetweenLayoutRuns() {
    let block = ViewResolver.block(
        from: HStack(spacing: 3) {
            Text("A")
            Text("B")
        }
    )!
    let output = TextRenderer.screen(
        for: block,
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[3;3HA\u{001B}[3;7HB\u{001B}[?25l")
    #expect(!output.contains(" "))
}

@Test func screenOutputPreservesContentSpacesInsideRuns() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A B"))!,
        in: TerminalViewportSize(columns: 7, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;3HA B\u{001B}[?25l")
}

@Test func screenOutputRendersForegroundColorSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").foregroundStyle(.red))!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[31mA\u{001B}[39m\u{001B}[?25l")
}

@Test func screenOutputRendersColor256ForegroundSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").foregroundStyle(Color256(rawValue: 196)))!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(
        output
            == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[38;5;196mA\u{001B}[39m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputRendersTrueColorForegroundSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(
            from: Text("A").foregroundStyle(TrueColor(red: 1, green: 2, blue: 3))
        )!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(
        output
            == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[38;2;1;2;3mA\u{001B}[39m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputRendersBackgroundColorSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").background(.red))!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[41mA\u{001B}[49m\u{001B}[?25l")
}

@Test func screenOutputRendersColor256BackgroundSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").background(Color256(rawValue: 196)))!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(
        output
            == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[48;5;196mA\u{001B}[49m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputRendersTrueColorBackgroundSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(
            from: Text("A").background(TrueColor(red: 1, green: 2, blue: 3))
        )!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(
        output
            == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[48;2;1;2;3mA\u{001B}[49m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputRendersDefaultBackgroundOverride() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(
            from: VStack(alignment: .leading) {
                Text("A")
                Text("B")
                    ._backgroundStyle(.default)
            }
            ._backgroundStyle(.red)
        )!,
        in: TerminalViewportSize(columns: 1, rows: 2)
    )

    #expect(
        output
            == "\u{001B}[2J"
            + "\u{001B}[1;1H\u{001B}[41mA\u{001B}[49m"
            + "\u{001B}[2;1H\u{001B}[49mB\u{001B}[49m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputRendersBoldSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").bold())!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[1mA\u{001B}[22m\u{001B}[?25l")
}

@Test func screenOutputRendersDimSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").dim())!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[2mA\u{001B}[22m\u{001B}[?25l")
}

@Test func screenOutputRendersItalicSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").italic())!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[3mA\u{001B}[23m\u{001B}[?25l")
}

@Test func screenOutputRendersUnderlineSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").underline())!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[4mA\u{001B}[24m\u{001B}[?25l")
}

@Test func screenOutputRendersStrikethroughSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").strikethrough())!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[9mA\u{001B}[29m\u{001B}[?25l")
}

@Test func screenOutputRendersCombinedStyleInDeterministicOrder() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(
            from: Text("A")
                .bold()
                .dim()
                .italic()
                .underline()
                .strikethrough()
                .foregroundStyle(.brightCyan)
                .background(.blue)
        )!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(
        output
            == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[1m\u{001B}[2m\u{001B}[3m\u{001B}[4m\u{001B}[9m\u{001B}[96m\u{001B}[44m"
            + "A"
            + "\u{001B}[22m\u{001B}[23m\u{001B}[24m\u{001B}[29m\u{001B}[39m\u{001B}[49m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputRendersDefaultForegroundOverride() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(
            from: VStack(alignment: .leading) {
                Text("A")
                Text("B")
                    .foregroundStyle(.default)
                    .bold(false)
                    .dim(false)
                    .italic(false)
                    .underline(false)
                    .strikethrough(false)
            }
            .foregroundStyle(.red)
            .bold()
            .dim()
            .italic()
            .underline()
            .strikethrough()
        )!,
        in: TerminalViewportSize(columns: 1, rows: 2)
    )

    #expect(
        output
            == "\u{001B}[2J"
            + "\u{001B}[1;1H"
            + "\u{001B}[1m\u{001B}[2m\u{001B}[3m\u{001B}[4m\u{001B}[9m\u{001B}[31m"
            + "A"
            + "\u{001B}[22m\u{001B}[23m\u{001B}[24m\u{001B}[29m\u{001B}[39m"
            + "\u{001B}[2;1H\u{001B}[39mB\u{001B}[39m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputShowsAndPositionsRenderedCursor() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["Hello"], cursor: RenderedCursor(column: 2)),
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[3;3HHello\u{001B}[?25h\u{001B}[3;5H")
}

@Test func screenOutputClipsLinesToViewportWidth() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["ABCDE"]),
        in: TerminalViewportSize(columns: 3, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1HABC\u{001B}[?25l")
}

@Test func screenOutputClipsStyledLinesToViewportWidth() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("ABCDE").foregroundStyle(.blue).dim())!,
        in: TerminalViewportSize(columns: 3, rows: 1)
    )

    #expect(
        output
            == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[2m\u{001B}[34m"
            + "ABC"
            + "\u{001B}[22m\u{001B}[39m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputPositionsRenderedCursorAfterWideText() {
    let output = TextRenderer.screen(
        for: RenderedBlock(lines: ["한A"], cursor: RenderedCursor(column: 3)),
        in: TerminalViewportSize(columns: 10, rows: 5)
    )

    #expect(output == "\u{001B}[2J\u{001B}[3;4H한A\u{001B}[?25h\u{001B}[3;7H")
}

@Test func terminalSessionSequencesAreStable() {
    #expect(TerminalControl.enterAlternateScreenSequence == "\u{001B}[?1049h")
    #expect(TerminalControl.hideCursorSequence == "\u{001B}[?25l")
    #expect(TerminalControl.showCursorSequence == "\u{001B}[?25h")
    #expect(TerminalControl.exitAlternateScreenSequence == "\u{001B}[?1049l")
    #expect(TerminalControl.enableMouseTrackingSequence == "\u{001B}[?1003h\u{001B}[?1006h")
    #expect(TerminalControl.disableMouseTrackingSequence == "\u{001B}[?1006l\u{001B}[?1003l")
}

@Test func terminalViewportTrackerIgnoresSameViewport() {
    let viewport = TerminalViewportSize(columns: 80, rows: 24)
    let tracker = TerminalViewportTracker(renderedViewport: viewport)

    #expect(!tracker.needsRedraw(for: viewport))
}

@Test func terminalViewportTrackerRequestsRedrawForChangedViewport() {
    let tracker = TerminalViewportTracker(
        renderedViewport: TerminalViewportSize(columns: 80, rows: 24)
    )

    #expect(tracker.needsRedraw(for: TerminalViewportSize(columns: 100, rows: 24)))
    #expect(tracker.needsRedraw(for: TerminalViewportSize(columns: 80, rows: 30)))
}

@Test func terminalViewportTrackerUpdatesRenderedViewport() {
    var tracker = TerminalViewportTracker(
        renderedViewport: TerminalViewportSize(columns: 80, rows: 24)
    )
    let resizedViewport = TerminalViewportSize(columns: 100, rows: 30)

    #expect(tracker.needsRedraw(for: resizedViewport))

    tracker.update(renderedViewport: resizedViewport)

    #expect(!tracker.needsRedraw(for: resizedViewport))
}

@Test func controlCQuitsAndOtherInputProducesKeyPresses() {
    #expect(TerminalControl.input(for: 3) == .quit)
    #expect(TerminalControl.input(for: 27) == .keyPress(KeyPress(key: .escape, characters: "\u{001B}")))
    #expect(TerminalControl.input(for: 113) == .keyPress(KeyPress(key: "q", characters: "q")))
}

@Test func terminateActionPerformsStoredOperation() {
    var didTerminate = false
    let action = TerminateAction {
        didTerminate = true
    }

    action()

    #expect(didTerminate)
}

@Test func terminateActionCanBeReadFromEnvironment() {
    var didTerminate = false
    let probe = TerminateActionProbe()
    let view = CapturedTerminateActionView(probe: probe)
        .environment(\.terminate, TerminateAction {
            didTerminate = true
        })

    _ = ViewResolver.text(from: view)
    probe.action?()

    #expect(didTerminate)
}

@Test func defaultTerminateHandlerRequestsTermination() {
    let runtime = StateRuntime()
    let termination = TerminationController()
    let action = termination.action
    let view = Text("A")
        .onTerminate {
            action()
        }
        .environment(\.terminate, action)

    _ = runtime.block(from: view)
    runtime.dispatchTerminate()

    #expect(termination.isRequested)
}

@Test func terminateHandlerRestoresEnvironmentForAction() {
    let runtime = StateRuntime()
    let termination = TerminationController()
    let action = termination.action
    let view = EnvironmentBackedTerminateView()
        .environment(\.terminate, action)

    _ = runtime.block(from: view)
    runtime.dispatchTerminate()

    #expect(termination.isRequested)
}

@Test func customTerminateHandlerCanUpdateStateWithoutTerminating() {
    let runtime = StateRuntime()
    let termination = TerminationController()
    let action = termination.action
    let view = TerminateStatusView()
        .onTerminate {
            action()
        }
        .environment(\.terminate, action)

    #expect(runtime.block(from: view)?.text == "running")

    runtime.dispatchTerminate()

    #expect(!termination.isRequested)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "interrupted")
}

@Test func terminateHandlerObservableNavigationPathInvalidatesImmediately() {
    let runtime = StateRuntime()
    let view = ObservableTerminateNavigationView()

    #expect(runtime.block(from: view)?.text == "main")

    runtime.dispatchTerminate()

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "confirm quit")
}

@Test func inputEventValueTypesExposeExpectedSemantics() {
    let key: KeyEquivalent = "a"
    let modifiers: EventModifiers = [.shift, .control]
    let phases: KeyPress.Phases = [.down, .repeat]
    let mouse = MouseEvent(
        button: .left,
        column: 2,
        row: 3,
        modifiers: .shift,
        phase: .down
    )

    #expect(key.character == "a")
    #expect(KeyEquivalent.upArrow.character == "\u{F700}")
    #expect(EventModifiers.all.contains(.command))
    #expect(modifiers.contains(.shift))
    #expect(modifiers.contains(.control))
    #expect(!modifiers.contains(.option))
    #expect(KeyPress.Phases.all.contains(.up))
    #expect(phases.contains(.down))
    #expect(phases.contains(.repeat))
    #expect(KeyPress.Result.handled != .ignored)
    #expect(mouse.button == .left)
    #expect(mouse.column == 2)
    #expect(mouse.row == 3)
    #expect(mouse.modifiers == .shift)
    #expect(mouse.phase == .down)
}

@Test func environmentReadsDefaultValue() {
    #expect(ViewResolver.text(from: EnvironmentMarkerText()) == "default")
}

@Test func environmentWrapperReadsDefaultSnapshotBeforeMaterialization() {
    let marker = Environment(\.testMarker)

    #expect(marker.wrappedValue == "default")
}

@Test func environmentValueIsInheritedByChildBody() {
    let view = EnvironmentMarkerText()
        .environment(\.testMarker, "parent")

    #expect(ViewResolver.text(from: view) == "parent")
}

@Test func nearestEnvironmentValueOverridesParentValue() {
    let view = VStack(alignment: .leading) {
        EnvironmentMarkerText()
        EnvironmentMarkerText()
            .environment(\.testMarker, "child!")
    }
    .environment(\.testMarker, "parent")

    #expect(ViewResolver.block(from: view)?.lines == ["parent", "child!"])
}

@Test func transformEnvironmentChangesExistingValue() {
    let view = EnvironmentMarkerText()
        .transformEnvironment(\.testMarker) {
            $0 += "-transformed"
        }
        .environment(\.testMarker, "base")

    #expect(ViewResolver.text(from: view) == "base-transformed")
}

@Test func environmentValueDoesNotLeakToSibling() {
    let view = VStack(alignment: .leading) {
        EnvironmentMarkerText()
            .environment(\.testMarker, "changed")
        EnvironmentMarkerText()
    }

    #expect(ViewResolver.block(from: view)?.lines == ["changed", "default"])
}

@Test func stateDrivenEnvironmentValueUpdatesOnNextRender() {
    let runtime = StateRuntime()
    let probe = BindingProbe<String>()
    let view = EnvironmentStateMarkerView(probe: probe)

    #expect(runtime.block(from: view)?.text == "initial")

    probe.binding?.wrappedValue = "updated"
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "updated")
}

@Test func environmentValuePassedFromParentBodyKeepsParentSnapshot() {
    let view = ParentCapturedEnvironmentMarkerView()
        .environment(\.testMarker, "parent")

    #expect(ViewResolver.text(from: view) == "captured parent direct child")
}

@Test func typedEnvironmentObjectIsInheritedByChildBody() {
    let model = TestObservableModel(count: 1)
    let objectProbe = ObjectProbe<TestObservableModel>()
    let view = TypedEnvironmentObjectMarkerText(objectProbe: objectProbe)
        .environment(model)

    #expect(ViewResolver.text(from: view) == "1")
    #expect(objectProbe.object === model)
}

@Test func nearestTypedEnvironmentObjectOverridesParentObject() {
    let parent = TestObservableModel(count: 1)
    let child = TestObservableModel(count: 2)
    let view = VStack(alignment: .leading) {
        TypedEnvironmentObjectMarkerText()
        TypedEnvironmentObjectMarkerText()
            .environment(child)
    }
    .environment(parent)

    #expect(ViewResolver.block(from: view)?.lines == ["1", "2"])
}

@Test func typedEnvironmentObjectDoesNotLeakToSibling() {
    let parent = TestObservableModel(count: 1)
    let child = TestObservableModel(count: 2)
    let view = VStack(alignment: .leading) {
        TypedEnvironmentObjectMarkerText()
            .environment(child)
        TypedEnvironmentObjectMarkerText()
    }
    .environment(parent)

    #expect(ViewResolver.block(from: view)?.lines == ["2", "1"])
}

@Test func optionalTypedEnvironmentObjectReadsNilWhenMissing() {
    #expect(ViewResolver.text(from: OptionalTypedEnvironmentObjectMarkerText()) == "nil")
}

@Test func optionalTypedEnvironmentObjectReadsObjectWhenPresent() {
    let model = TestObservableModel(count: 4)
    let objectProbe = ObjectProbe<TestObservableModel>()
    let view = OptionalTypedEnvironmentObjectMarkerText(objectProbe: objectProbe)
        .environment(model)

    #expect(ViewResolver.text(from: view) == "4")
    #expect(objectProbe.object === model)
}

@Test func typedEnvironmentObjectComposesWithKeyPathEnvironment() {
    let model = TestObservableModel(count: 3)
    let view = TypedAndKeyPathEnvironmentMarkerText()
        .environment(\.testMarker, "marker")
        .environment(model)

    #expect(ViewResolver.text(from: view) == "marker:3")
}

@Test func typedEnvironmentObjectProjectionCreatesPropertyBinding() {
    let model = TestObservableModel(token: "initial")
    let probe = BindingProbe<String>()
    let objectProbe = ObjectProbe<TestObservableModel>()
    let view = TypedEnvironmentObjectProjectionMarkerText(
        bindingProbe: probe,
        objectProbe: objectProbe
    )
    .environment(model)

    #expect(ViewResolver.text(from: view) == "initial")
    #expect(objectProbe.object === model)

    probe.binding?.wrappedValue = "updated"
    #expect(model.token == "updated")
    #expect(probe.binding?.wrappedValue == "updated")
}

@Test func missingTypedEnvironmentObjectDiagnosticNamesType() {
    let message = missingObservableObjectMessage(for: TestObservableModel.self)

    #expect(message.contains("TestObservableModel"))
    #expect(message.contains("View.environment(_:)"))
}

@Test func typedEnvironmentTextFieldTracksObservableObjectChanges() {
    let runtime = StateRuntime()
    let objectProbe = ObjectProbe<TestObservableModel>()
    let view = TypedEnvironmentTextFieldRootView(
        initialToken: "",
        objectProbe: objectProbe
    )

    #expect(runtime.block(from: view)?.text == "Token")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Token")

    objectProbe.object?.token = "abc"
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "abc")

    #expect(runtime.dispatch(KeyPress(key: .end, characters: "\u{F72B}")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "d", characters: "d")) == .handled)
    #expect(objectProbe.object?.token == "abcd")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "abcd")
}

@Test func buttonSizingEnvironmentDefaultsToAutomatic() {
    #expect(EnvironmentValues().buttonSizing == .automatic)
    #expect(ViewResolver.text(from: ButtonSizingMarkerText()) == "automatic")
}

@Test func buttonSizingEnvironmentPropagatesToChildren() {
    let view = VStack(alignment: .leading) {
        ButtonSizingMarkerText()
    }
    .buttonSizing(.flexible)

    #expect(ViewResolver.text(from: view) == "flexible")
}

@Test func isEnabledEnvironmentDefaultsToTrue() {
    #expect(EnvironmentValues().isEnabled)
    #expect(ViewResolver.text(from: IsEnabledMarkerText()) == "enabled")
}

@Test func disabledModifierUpdatesIsEnabledEnvironment() {
    #expect(ViewResolver.text(from: IsEnabledMarkerText().disabled(true)) == "disabled")
    #expect(ViewResolver.text(from: IsEnabledMarkerText().disabled(false)) == "enabled")
}

@Test func parentDisabledOverridesChildEnabledEnvironment() {
    let view = VStack(alignment: .leading) {
        IsEnabledMarkerText()
            .disabled(false)
    }
    .disabled(true)

    #expect(ViewResolver.text(from: view) == "disabled")
}

@Test func disabledEnvironmentDoesNotLeakToSibling() {
    let view = VStack(alignment: .leading) {
        IsEnabledMarkerText()
            .disabled(true)
        IsEnabledMarkerText()
    }

    #expect(ViewResolver.block(from: view)?.lines == ["disabled", "enabled "])
}

@Test func onAppearRunsOnceForStableIdentity() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()
    let view = Text("A")
        .onAppear {
            probe.events.append("appear")
        }

    #expect(runtime.block(from: view)?.text == "A")
    #expect(probe.events == ["appear"])

    #expect(runtime.block(from: view)?.text == "A")
    #expect(probe.events == ["appear"])
}

@Test func onAppearNilActionHasNoEffect() {
    let runtime = StateRuntime()

    #expect(runtime.block(from: Text("A").onAppear())?.text == "A")
}

@Test func hiddenPreservesLifecycleRegistration() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()
    let view = Text("A")
        .onAppear {
            probe.events.append("appear")
        }
        .hidden()

    #expect(runtime.block(from: view)?.runs == [])
    #expect(probe.events == ["appear"])

    #expect(runtime.block(from: view)?.runs == [])
    #expect(probe.events == ["appear"])
}

@Test func onDisappearRunsWhenRenderedIdentityIsRemoved() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: ConditionalLifecycleView(isVisible: true, probe: probe)
        )?.lines == ["A", "B"]
    )
    #expect(probe.events == ["appear"])

    #expect(
        runtime.block(
            from: ConditionalLifecycleView(isVisible: true, probe: probe)
        )?.lines == ["A", "B"]
    )
    #expect(probe.events == ["appear"])

    #expect(
        runtime.block(
            from: ConditionalLifecycleView(isVisible: false, probe: probe)
        )?.lines == ["B"]
    )
    #expect(probe.events == ["appear", "disappear"])

    #expect(
        runtime.block(
            from: ConditionalLifecycleView(isVisible: true, probe: probe)
        )?.lines == ["A", "B"]
    )
    #expect(probe.events == ["appear", "disappear", "appear"])
}

@Test func lifecycleActionsMutateStateWithRestoredViewContext() {
    let appearRuntime = StateRuntime()

    #expect(appearRuntime.block(from: LifecycleAppearStateView())?.text == "initial")
    #expect(appearRuntime.consumeInvalidation())
    #expect(appearRuntime.block(from: LifecycleAppearStateView())?.text == "appeared")

    let disappearRuntime = StateRuntime()
    #expect(
        disappearRuntime.block(
            from: LifecycleDisappearStateView(isVisible: true)
        )?.lines == ["visible", "child  "]
    )
    #expect(
        disappearRuntime.block(
            from: LifecycleDisappearStateView(isVisible: false)
        )?.lines == ["visible"]
    )
    #expect(disappearRuntime.consumeInvalidation())
    #expect(
        disappearRuntime.block(
            from: LifecycleDisappearStateView(isVisible: false)
        )?.lines == ["gone"]
    )
}

@Test func lifecycleActionsRestoreEnvironment() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()
    let view = EnvironmentLifecycleView(probe: probe)
        .environment(\.testMarker, "parent")

    #expect(runtime.block(from: view)?.text == "marker")
    #expect(probe.events == ["parent"])
}

@Test func taskStartsOnceForStableIdentity() async {
    let runtime = StateRuntime()
    let probe = AsyncTaskProbe()
    let view = Text("A")
        .task {
            probe.record("start")
        }

    #expect(runtime.block(from: view)?.text == "A")
    await probe.waitForCount(1)
    #expect(probe.events == ["start"])

    #expect(runtime.block(from: view)?.text == "A")
    await Task.yield()
    #expect(probe.events == ["start"])
}

@Test func hiddenPreservesTaskRegistration() async {
    let runtime = StateRuntime()
    let probe = AsyncTaskProbe()
    let view = Text("A")
        .task {
            probe.record("start")
        }
        .hidden()

    #expect(runtime.block(from: view)?.runs == [])
    await probe.waitForCount(1)
    #expect(probe.events == ["start"])
}

@Test func taskAcceptsSwiftUILikeMetadataArguments() async {
    let runtime = StateRuntime()
    let probe = AsyncTaskProbe()
    let view = Text("A")
        .task(
            name: "metadata",
            priority: .userInitiated,
            file: "SwiftTUITests.swift",
            line: 1
        ) {
            probe.record("metadata")
        }

    #expect(runtime.block(from: view)?.text == "A")
    await probe.waitForCount(1)
    #expect(probe.events == ["metadata"])
}

@Test func taskIDChangeCancelsAndRestarts() async {
    let runtime = StateRuntime()
    let probe = AsyncTaskProbe()

    #expect(runtime.block(from: IdentifiedTaskView(id: 1, probe: probe))?.text == "1")
    await probe.waitForCount(1)

    #expect(runtime.block(from: IdentifiedTaskView(id: 1, probe: probe))?.text == "1")
    await Task.yield()
    #expect(probe.events == ["start 1"])

    #expect(runtime.block(from: IdentifiedTaskView(id: 2, probe: probe))?.text == "2")
    await probe.waitForCount(3)
    let events = probe.events
    #expect(events.contains("cancel 1"))
    #expect(events.contains("start 2"))

    _ = runtime.block(from: EmptyView())
}

@Test func taskIDAcceptsSwiftUILikeMetadataArguments() async {
    let runtime = StateRuntime()
    let probe = AsyncTaskProbe()
    let view = Text("A")
        .task(
            id: 1,
            name: "metadata-id",
            priority: .userInitiated,
            file: "SwiftTUITests.swift",
            line: 1
        ) {
            probe.record("metadata-id")
        }

    #expect(runtime.block(from: view)?.text == "A")
    await probe.waitForCount(1)
    #expect(probe.events == ["metadata-id"])
}

@Test func taskCancelsWhenViewDisappears() async {
    let runtime = StateRuntime()
    let probe = AsyncTaskProbe()

    #expect(runtime.block(from: ConditionalTaskView(isVisible: true, probe: probe))?.text == "A")
    await probe.waitForCount(1)

    #expect(runtime.block(from: ConditionalTaskView(isVisible: false, probe: probe)) == nil)
    await probe.waitForCount(2)
    #expect(probe.events == ["start", "cancel"])
}

@Test func taskStateMutationAfterAwaitInvalidatesAndRerenders() async {
    let runtime = StateRuntime()
    let probe = AsyncTaskProbe()

    #expect(runtime.block(from: TaskStateMutationView(probe: probe))?.text == "idle")
    await probe.waitForCount(1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: TaskStateMutationView(probe: probe))?.text == "done")
}

@Test func forEachReorderDoesNotTriggerLifecycleActions() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()
    let first = [
        LifecycleItem(id: "a", label: "A"),
        LifecycleItem(id: "b", label: "B"),
    ]
    let reordered = [
        LifecycleItem(id: "b", label: "B"),
        LifecycleItem(id: "a", label: "A"),
    ]

    #expect(runtime.block(from: ForEachLifecycleView(items: first, probe: probe))?.lines == ["A", "B"])
    #expect(probe.events == ["appear a", "appear b"])

    #expect(runtime.block(from: ForEachLifecycleView(items: reordered, probe: probe))?.lines == ["B", "A"])
    #expect(probe.events == ["appear a", "appear b"])
}

@Test func forEachRemovalRunsDisappearBeforeStateCleanup() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()
    let item = LifecycleItem(id: "a", label: "A")

    #expect(
        runtime.block(
            from: StatefulForEachLifecycleView(items: [item], probe: probe)
        )?.text == "A:fresh"
    )
    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: StatefulForEachLifecycleView(items: [item], probe: probe)
        )?.text == "A:active"
    )

    #expect(runtime.block(from: StatefulForEachLifecycleView(items: [], probe: probe)) == nil)
    #expect(probe.events == ["disappear A:active"])

    #expect(
        runtime.block(
            from: StatefulForEachLifecycleView(items: [item], probe: probe)
        )?.text == "A:fresh"
    )
}

@Test func stackedLifecycleModifiersRunInDeterministicOrder() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    _ = runtime.block(from: StackedLifecycleView(isVisible: true, probe: probe))
    #expect(probe.events == ["outer appear", "inner appear"])

    _ = runtime.block(from: StackedLifecycleView(isVisible: false, probe: probe))
    #expect(
        probe.events == [
            "outer appear",
            "inner appear",
            "outer disappear",
            "inner disappear",
        ]
    )
}

@Test func onChangeDoesNotRunInitiallyByDefault() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(runtime.block(from: OnChangeValueView(value: 1, probe: probe))?.text == "1")
    #expect(probe.events.isEmpty)

    #expect(runtime.block(from: OnChangeValueView(value: 1, probe: probe))?.text == "1")
    #expect(probe.events.isEmpty)
}

@Test func onChangeInitialRunsOnceForStableIdentity() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: OnChangeValueView(value: 1, initial: true, probe: probe)
        )?.text == "1"
    )
    #expect(probe.events == ["changed 1"])

    #expect(
        runtime.block(
            from: OnChangeValueView(value: 1, initial: true, probe: probe)
        )?.text == "1"
    )
    #expect(probe.events == ["changed 1"])
}

@Test func hiddenPreservesChangeRegistration() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: OnChangeValueView(value: 1, initial: true, probe: probe)
                .hidden()
        )?.runs == []
    )
    #expect(probe.events == ["changed 1"])

    #expect(
        runtime.block(
            from: OnChangeValueView(value: 2, initial: true, probe: probe)
                .hidden()
        )?.runs == []
    )
    #expect(probe.events == ["changed 1", "changed 2"])
}

@Test func onChangeRunsWhenValueChanges() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(runtime.block(from: OnChangeValueView(value: 1, probe: probe))?.text == "1")
    #expect(runtime.block(from: OnChangeValueView(value: 2, probe: probe))?.text == "2")

    #expect(probe.events == ["changed 2"])
}

@Test func onChangeWithOldAndNewValuesRunsWhenValueChanges() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(runtime.block(from: OnChangePairValueView(value: 1, probe: probe))?.text == "1")
    #expect(runtime.block(from: OnChangePairValueView(value: 2, probe: probe))?.text == "2")

    #expect(probe.events == ["changed 1 -> 2"])
}

@Test func onChangeWithOldAndNewValuesDoesNotRunWhenValueIsEqual() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(runtime.block(from: OnChangePairValueView(value: 1, probe: probe))?.text == "1")
    #expect(runtime.block(from: OnChangePairValueView(value: 1, probe: probe))?.text == "1")

    #expect(probe.events.isEmpty)
}

@Test func onChangeWithOldAndNewInitialRunsOnceForStableIdentity() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: OnChangePairValueView(value: 1, initial: true, probe: probe)
        )?.text == "1"
    )
    #expect(probe.events == ["changed 1 -> 1"])

    #expect(
        runtime.block(
            from: OnChangePairValueView(value: 1, initial: true, probe: probe)
        )?.text == "1"
    )
    #expect(probe.events == ["changed 1 -> 1"])
}

@Test func onChangeActionMutatesStateWithRestoredViewContext() {
    let runtime = StateRuntime()

    #expect(runtime.block(from: OnChangeStateMutationView(value: 1))?.text == "idle")
    #expect(runtime.block(from: OnChangeStateMutationView(value: 2))?.text == "idle")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: OnChangeStateMutationView(value: 2))?.text == "changed")
}

@Test func onChangeWithOldAndNewActionMutatesStateWithRestoredViewContext() {
    let runtime = StateRuntime()

    #expect(runtime.block(from: OnChangePairStateMutationView(value: 1))?.text == "idle")
    #expect(runtime.block(from: OnChangePairStateMutationView(value: 2))?.text == "idle")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: OnChangePairStateMutationView(value: 2))?.text == "1 -> 2")
}

@Test func onChangeActionUsesLatestEnvironment() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: OnChangeEnvironmentView(value: 1, probe: probe)
                .environment(\.testMarker, "first")
        )?.text == "marker"
    )
    #expect(
        runtime.block(
            from: OnChangeEnvironmentView(value: 2, probe: probe)
                .environment(\.testMarker, "second")
        )?.text == "marker"
    )

    #expect(probe.events == ["second"])
}

@Test func onChangeWithOldAndNewActionUsesLatestEnvironment() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: OnChangePairEnvironmentView(value: 1, probe: probe)
                .environment(\.testMarker, "first")
        )?.text == "marker"
    )
    #expect(
        runtime.block(
            from: OnChangePairEnvironmentView(value: 2, probe: probe)
                .environment(\.testMarker, "second")
        )?.text == "marker"
    )

    #expect(probe.events == ["second 1 -> 2"])
}

@Test func onChangeInitialRunsAgainAfterConditionalReinsert() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: ConditionalOnChangeView(isVisible: true, value: 1, probe: probe)
        )?.text == "A"
    )
    #expect(probe.events == ["changed 1"])

    #expect(runtime.block(from: ConditionalOnChangeView(isVisible: false, value: 1, probe: probe)) == nil)
    #expect(
        runtime.block(
            from: ConditionalOnChangeView(isVisible: true, value: 1, probe: probe)
        )?.text == "A"
    )
    #expect(probe.events == ["changed 1", "changed 1"])
}

@Test func onChangeWithOldAndNewInitialRunsAgainAfterConditionalReinsert() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(
        runtime.block(
            from: ConditionalOnChangePairView(isVisible: true, value: 1, probe: probe)
        )?.text == "A"
    )
    #expect(probe.events == ["changed 1 -> 1"])

    #expect(runtime.block(from: ConditionalOnChangePairView(isVisible: false, value: 1, probe: probe)) == nil)
    #expect(
        runtime.block(
            from: ConditionalOnChangePairView(isVisible: true, value: 1, probe: probe)
        )?.text == "A"
    )
    #expect(probe.events == ["changed 1 -> 1", "changed 1 -> 1"])
}

@Test func forEachReorderDoesNotTriggerOnChangeActions() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()
    let first = [
        LifecycleItem(id: "a", label: "A"),
        LifecycleItem(id: "b", label: "B"),
    ]
    let reordered = [
        LifecycleItem(id: "b", label: "B"),
        LifecycleItem(id: "a", label: "A"),
    ]

    #expect(runtime.block(from: ForEachOnChangeView(items: first, probe: probe))?.lines == ["A", "B"])
    #expect(runtime.block(from: ForEachOnChangeView(items: reordered, probe: probe))?.lines == ["B", "A"])
    #expect(probe.events.isEmpty)
}

@Test func forEachReorderDoesNotTriggerOnChangeWithOldAndNewActions() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()
    let first = [
        LifecycleItem(id: "a", label: "A"),
        LifecycleItem(id: "b", label: "B"),
    ]
    let reordered = [
        LifecycleItem(id: "b", label: "B"),
        LifecycleItem(id: "a", label: "A"),
    ]

    #expect(runtime.block(from: ForEachOnChangePairView(items: first, probe: probe))?.lines == ["A", "B"])
    #expect(runtime.block(from: ForEachOnChangePairView(items: reordered, probe: probe))?.lines == ["B", "A"])
    #expect(probe.events.isEmpty)
}

@Test func terminalParsesPrintableAndUTF8Input() {
    #expect(TerminalControl.input(for: [65]) == .keyPress(KeyPress(key: "A", characters: "A")))
    #expect(
        TerminalControl.input(for: Array("é".utf8))
            == .keyPress(KeyPress(key: "é", characters: "é"))
    )
    #expect(
        TerminalControl.input(for: Array("한".utf8))
            == .keyPress(KeyPress(key: "한", characters: "한"))
    )
}

@Test func terminalReadInputParsesCompleteUTF8FromTimedByteReader() {
    var bytes = Array("한".utf8)
    var requestedTimeouts: [TimeInterval?] = []

    let input = TerminalControl.readInput(timeout: 1) { timeout in
        requestedTimeouts.append(timeout)
        guard !bytes.isEmpty else {
            return nil
        }

        return bytes.removeFirst()
    }

    #expect(input == .keyPress(KeyPress(key: "한", characters: "한")))
    #expect(requestedTimeouts == [1, 0.1, 0.1])
}

@Test func terminalReadInputReturnsNoneForIncompleteUTF8() {
    var bytes = [Array("한".utf8)[0]]
    var requestedTimeouts: [TimeInterval?] = []

    let input = TerminalControl.readInput { timeout in
        requestedTimeouts.append(timeout)
        guard !bytes.isEmpty else {
            return nil
        }

        return bytes.removeFirst()
    }

    #expect(input == .none)
    #expect(requestedTimeouts == [nil, 0.1])
}

@Test func terminalReadInputDoesNotSwallowEscapeAfterIncompleteUTF8() {
    var escapeBytes = [Array("한".utf8)[0], 27]

    #expect(
        TerminalControl.readInput {
            _ in

            guard !escapeBytes.isEmpty else {
                return nil
            }

            return escapeBytes.removeFirst()
        } == .keyPress(KeyPress(key: .escape, characters: "\u{001B}"))
    )

    var arrowBytes = [Array("한".utf8)[0], 27, 91, 65]

    #expect(
        TerminalControl.readInput {
            _ in

            guard !arrowBytes.isEmpty else {
                return nil
            }

            return arrowBytes.removeFirst()
        } == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}"))
    )
}

@Test func terminalReadInputReturnsEscapeImmediatelyWhenBufferIsEmptyAfterEscapeByte() {
    var bytes: [UInt8] = [27]
    var requestedTimeouts: [TimeInterval?] = []

    let input = TerminalControl.readInput {
        timeout in

        requestedTimeouts.append(timeout)
        guard !bytes.isEmpty else {
            return nil
        }

        return bytes.removeFirst()
    }

    #expect(input == .keyPress(KeyPress(key: .escape, characters: "\u{001B}")))
    #expect(requestedTimeouts == [nil, 0])
}

@Test func terminalReadInputParsesEscapeSequenceWhenBufferHasByteAfterEscape() {
    var bytes: [UInt8] = [27, 91, 65]
    var requestedTimeouts: [TimeInterval?] = []

    let input = TerminalControl.readInput {
        timeout in

        requestedTimeouts.append(timeout)
        guard !bytes.isEmpty else {
            return nil
        }

        return bytes.removeFirst()
    }

    #expect(input == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}")))
    #expect(requestedTimeouts == [nil, 0, 0.1])
}

@Test func terminalReadInputKeepsEscapeSequenceTimeoutAfterSecondByte() {
    var bytes: [UInt8] = [27, 91]
    var requestedTimeouts: [TimeInterval?] = []

    let input = TerminalControl.readInput {
        timeout in

        requestedTimeouts.append(timeout)
        guard !bytes.isEmpty else {
            return nil
        }

        return bytes.removeFirst()
    }

    #expect(input == .none)
    #expect(requestedTimeouts == [nil, 0, 0.1])
}

@Test func terminalReadInputTreatsEscapeThenPrintableAsUnknownEscapeSequence() {
    var bytes: [UInt8] = [27, 97]
    var requestedTimeouts: [TimeInterval?] = []

    let input = TerminalControl.readInput {
        timeout in

        requestedTimeouts.append(timeout)
        guard !bytes.isEmpty else {
            return nil
        }

        return bytes.removeFirst()
    }

    #expect(input == .none)
    #expect(requestedTimeouts == [nil, 0])
}

@Test func terminalParsesControlLettersWithControlModifier() {
    #expect(
        TerminalControl.input(for: 1)
            == .keyPress(KeyPress(key: "a", characters: "a", modifiers: .control))
    )
    #expect(
        TerminalControl.input(for: 26)
            == .keyPress(KeyPress(key: "z", characters: "z", modifiers: .control))
    )
}

@Test func terminalParsesSpecialKeys() {
    #expect(TerminalControl.input(for: 13) == .keyPress(KeyPress(key: .return, characters: "\r")))
    #expect(TerminalControl.input(for: 10) == .keyPress(KeyPress(key: .return, characters: "\r")))
    #expect(TerminalControl.input(for: 9) == .keyPress(KeyPress(key: .tab, characters: "\t")))
    #expect(TerminalControl.input(for: 32) == .keyPress(KeyPress(key: .space, characters: " ")))
    #expect(TerminalControl.input(for: 8) == .keyPress(KeyPress(key: .delete, characters: "\u{0008}")))
    #expect(TerminalControl.input(for: 127) == .keyPress(KeyPress(key: .delete, characters: "\u{0008}")))
}

@Test func terminalParsesCommonEscapeSequences() {
    #expect(TerminalControl.input(for: [27, 91, 65]) == .keyPress(KeyPress(key: .upArrow, characters: "\u{F700}")))
    #expect(TerminalControl.input(for: [27, 91, 66]) == .keyPress(KeyPress(key: .downArrow, characters: "\u{F701}")))
    #expect(TerminalControl.input(for: [27, 91, 67]) == .keyPress(KeyPress(key: .rightArrow, characters: "\u{F703}")))
    #expect(TerminalControl.input(for: [27, 91, 68]) == .keyPress(KeyPress(key: .leftArrow, characters: "\u{F702}")))
    #expect(TerminalControl.input(for: [27, 91, 72]) == .keyPress(KeyPress(key: .home, characters: "\u{F729}")))
    #expect(TerminalControl.input(for: [27, 91, 70]) == .keyPress(KeyPress(key: .end, characters: "\u{F72B}")))
    #expect(TerminalControl.input(for: [27, 91, 53, 126]) == .keyPress(KeyPress(key: .pageUp, characters: "\u{F72C}")))
    #expect(TerminalControl.input(for: [27, 91, 54, 126]) == .keyPress(KeyPress(key: .pageDown, characters: "\u{F72D}")))
    #expect(TerminalControl.input(for: [27, 91, 51, 126]) == .keyPress(KeyPress(key: .deleteForward, characters: "\u{F728}")))
    #expect(TerminalControl.input(for: [27, 91, 90]) == .none)
}

@Test func terminalRecognizesCompleteEscapeSequences() {
    #expect(TerminalControl.escapeSequenceIsComplete([27]))
    #expect(!TerminalControl.escapeSequenceIsComplete(Array("\u{001B}[<64;88;17".utf8)))
    #expect(TerminalControl.escapeSequenceIsComplete(Array("\u{001B}[<64;88;17M".utf8)))
    #expect(TerminalControl.escapeSequenceIsComplete([27, 91, 65]))
    #expect(TerminalControl.escapeSequenceIsComplete([27, 91, 51, 126]))
}

@Test func terminalParsesSGRMouseInput() {
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<0;12;3M".utf8))
            == .mouse(MouseEvent(button: .left, column: 12, row: 3, phase: .down))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<0;12;3m".utf8))
            == .mouse(MouseEvent(button: .left, column: 12, row: 3, phase: .up))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<20;1;2M".utf8))
            == .mouse(
                MouseEvent(
                    button: .left,
                    column: 1,
                    row: 2,
                    modifiers: [.shift, .control],
                    phase: .down
                )
            )
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<32;12;3M".utf8))
            == .mouse(MouseEvent(button: .left, column: 12, row: 3, phase: .motion))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<52;1;2M".utf8))
            == .mouse(
                MouseEvent(
                    button: .left,
                    column: 1,
                    row: 2,
                    modifiers: [.shift, .control],
                    phase: .motion
                )
            )
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<35;8;9M".utf8))
            == .mouse(MouseEvent(button: .other(3), column: 8, row: 9, phase: .motion))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<2;4;5M".utf8))
            == .mouse(MouseEvent(button: .right, column: 4, row: 5, phase: .down))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<64;6;7M".utf8))
            == .mouse(MouseEvent(button: .wheelUp, column: 6, row: 7, phase: .down))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<65;6;7M".utf8))
            == .mouse(MouseEvent(button: .wheelDown, column: 6, row: 7, phase: .down))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<66;6;7M".utf8))
            == .mouse(MouseEvent(button: .wheelRight, column: 6, row: 7, phase: .down))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<67;6;7M".utf8))
            == .mouse(MouseEvent(button: .wheelLeft, column: 6, row: 7, phase: .down))
    )
    #expect(
        TerminalControl.input(for: Array("\u{001B}[<68;6;7M".utf8))
            == .mouse(
                MouseEvent(
                    button: .wheelUp,
                    column: 6,
                    row: 7,
                    modifiers: .shift,
                    phase: .down
                )
            )
    )
    #expect(TerminalControl.input(for: Array("\u{001B}[<0;12M".utf8)) == .none)
}

@Test func stateInitializersProvideWrappedValues() {
    struct Probe {

        @State var wrapped = 1

        @State(initialValue: 2) var initial: Int

        @State var optional: Int?
    }

    let probe = Probe()

    #expect(probe.wrapped == 1)
    #expect(probe.initial == 2)
    #expect(probe.optional == nil)
}

@Test func stateWrappedAndProjectedValuesShareStorage() {
    let state = State(wrappedValue: 1)

    #expect(state.wrappedValue == 1)

    state.wrappedValue = 2
    let binding = state.projectedValue

    #expect(binding.wrappedValue == 2)

    binding.wrappedValue = 3

    #expect(state.wrappedValue == 3)
}

@Test func stateObservableInitializesOnceForStableViewIdentity() {
    let runtime = StateRuntime()
    let creationProbe = ObjectCreationProbe()
    let objectProbe = ObjectProbe<TestObservableModel>()

    #expect(
        runtime.block(
            from: StateObservableCounterView(
                initialCount: 1,
                creationProbe: creationProbe,
                objectProbe: objectProbe
            )
        )?.text == "1"
    )
    #expect(creationProbe.createdIDs == [1])

    #expect(
        runtime.block(
            from: StateObservableCounterView(
                initialCount: 9,
                creationProbe: creationProbe,
                objectProbe: objectProbe
            )
        )?.text == "1"
    )
    #expect(creationProbe.createdIDs == [1])
}

@Test func stateObservableChangeInvalidatesAndRerendersRootView() {
    let runtime = StateRuntime()
    let creationProbe = ObjectCreationProbe()
    let objectProbe = ObjectProbe<TestObservableModel>()

    #expect(
        runtime.block(
            from: StateObservableCounterView(
                initialCount: 1,
                creationProbe: creationProbe,
                objectProbe: objectProbe
            )
        )?.text == "1"
    )

    objectProbe.object?.count = 3

    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: StateObservableCounterView(
                initialCount: 1,
                creationProbe: creationProbe,
                objectProbe: objectProbe
            )
        )?.text == "3"
    )
}

@Test func unreadObservablePropertyChangeDoesNotInvalidateRootView() {
    let runtime = StateRuntime()
    let creationProbe = ObjectCreationProbe()
    let objectProbe = ObjectProbe<TestObservableModel>()

    #expect(
        runtime.block(
            from: StateObservableCounterView(
                initialCount: 1,
                creationProbe: creationProbe,
                objectProbe: objectProbe
            )
        )?.text == "1"
    )

    objectProbe.object?.unreadCount = 10

    #expect(!runtime.consumeInvalidation())
}

@Test func bindableProjectionCreatesPropertyBinding() {
    let runtime = StateRuntime()
    let model = TestObservableModel(count: 1)
    let bindingProbe = BindingProbe<Int>()

    #expect(
        runtime.block(
            from: BindableCounterView(model: model, bindingProbe: bindingProbe)
        )?.text == "1"
    )

    bindingProbe.binding?.wrappedValue = 4

    #expect(model.count == 4)
    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: BindableCounterView(model: model, bindingProbe: bindingProbe)
        )?.text == "4"
    )
}

@Test func obsoleteOneShotObservationCanInvalidateOnce() {
    let runtime = StateRuntime()
    let first = TestObservableModel(count: 1)
    let second = TestObservableModel(count: 10)

    #expect(
        runtime.block(
            from: ConditionalObservableCounterView(
                first: first,
                second: second,
                usesFirst: true
            )
        )?.text == "1"
    )
    #expect(
        runtime.block(
            from: ConditionalObservableCounterView(
                first: first,
                second: second,
                usesFirst: false
            )
        )?.text == "10"
    )

    first.count = 2
    #expect(runtime.consumeInvalidation())

    first.count = 3
    #expect(!runtime.consumeInvalidation())

    second.count = 11
    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: ConditionalObservableCounterView(
                first: first,
                second: second,
                usesFirst: false
            )
        )?.text == "11"
    )
}

@Test func forEachDeletedIDReinsertedStartsFreshStateObservable() {
    let runtime = StateRuntime()
    let creationProbe = ObjectCreationProbe()
    let item = ForEachTestItem(id: "a", label: "A")

    #expect(
        runtime.block(
            from: ForEachStateObservableView(items: [item], creationProbe: creationProbe)
        )?.text == "1"
    )
    #expect(creationProbe.createdIDs == [1])

    #expect(
        runtime.block(
            from: ForEachStateObservableView(items: [], creationProbe: creationProbe)
        ) == nil
    )
    #expect(
        runtime.block(
            from: ForEachStateObservableView(items: [item], creationProbe: creationProbe)
        )?.text == "2"
    )
    #expect(creationProbe.createdIDs == [1, 2])
}

@Test func bindingReadsAndWritesWithClosures() {
    var value = 1
    let binding = Binding(
        get: {
            value
        },
        set: { newValue in
            value = newValue
        }
    )

    #expect(binding.wrappedValue == 1)

    binding.wrappedValue = 2

    #expect(value == 2)
}

@Test func bindingProjectedValueReusesBinding() {
    var value = 1
    let binding = Binding(
        get: {
            value
        },
        set: { newValue in
            value = newValue
        }
    )
    let projected = Binding(projectedValue: binding)

    projected.wrappedValue = 4

    #expect(binding.projectedValue.wrappedValue == 4)
    #expect(value == 4)
}

@Test func constantBindingIgnoresWrites() {
    let binding = Binding.constant("fixed")

    binding.wrappedValue = "changed"

    #expect(binding.wrappedValue == "fixed")
}

@Test func bindingDynamicMemberProjectsNestedValue() {
    struct Episode: Equatable {

        var title: String

        var isFavorite: Bool
    }

    var episode = Episode(title: "Pilot", isFavorite: false)
    let binding = Binding(
        get: {
            episode
        },
        set: { newValue in
            episode = newValue
        }
    )
    let favorite = binding.isFavorite

    #expect(favorite.wrappedValue == false)

    favorite.wrappedValue = true

    #expect(episode == Episode(title: "Pilot", isFavorite: true))
}

@Test func stateBindingMutationInvalidatesAndRerendersRootView() {
    let runtime = StateRuntime()
    let probe = BindingProbe<Int>()

    #expect(runtime.block(from: RootCounterView(probe: probe))?.text == "0")

    probe.binding?.wrappedValue = 1

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: RootCounterView(probe: probe))?.text == "1")
}

@Test func childStatePersistsAcrossParentBodyReevaluation() {
    let runtime = StateRuntime()
    let probe = BindingProbe<Int>()

    #expect(runtime.block(from: ParentCounterView(probe: probe))?.text == "0")

    probe.binding?.wrappedValue = 5

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: ParentCounterView(probe: probe))?.text == "5")
}

@Test func siblingStateCellsAreIndependent() {
    let runtime = StateRuntime()
    let probe = LabeledBindingProbe()

    #expect(runtime.block(from: SiblingCounterView(probe: probe))?.lines == ["0", "0"])

    probe.bindings["first"]?.wrappedValue = 7

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: SiblingCounterView(probe: probe))?.lines == ["7", "0"])

    probe.bindings["second"]?.wrappedValue = 4

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: SiblingCounterView(probe: probe))?.lines == ["7", "4"])
}

@Test func conditionalViewBranchStateCellsAreIndependent() {
    let runtime = StateRuntime()
    let probe = LabeledBindingProbe()

    #expect(
        runtime.block(
            from: ConditionalBranchStateView(usesFirstBranch: true, probe: probe)
        )?.text == "0"
    )

    probe.bindings["first"]?.wrappedValue = 3

    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: ConditionalBranchStateView(usesFirstBranch: true, probe: probe)
        )?.text == "3"
    )
    #expect(
        runtime.block(
            from: ConditionalBranchStateView(usesFirstBranch: false, probe: probe)
        )?.text == "0"
    )

    probe.bindings["second"]?.wrappedValue = 8

    #expect(runtime.consumeInvalidation())
    #expect(
        runtime.block(
            from: ConditionalBranchStateView(usesFirstBranch: false, probe: probe)
        )?.text == "8"
    )
    #expect(
        runtime.block(
            from: ConditionalBranchStateView(usesFirstBranch: true, probe: probe)
        )?.text == "3"
    )
}

@Test func focusStateInitializersProvideWrappedValues() {
    struct Probe {

        @FocusState var isFocused: Bool

        @FocusState var field: FocusField?
    }

    let probe = Probe()

    #expect(probe.isFocused == false)
    #expect(probe.field == nil)
}

@Test func focusStateWrappedValueInitializerProvidesWrappedValues() {
    struct Probe {

        @FocusState var isFocused = true

        @FocusState var field: FocusField? = .first
    }

    let probe = Probe()

    #expect(probe.isFocused == true)
    #expect(probe.field == .first)
}

@Test func focusStateBindingMutationInvalidatesAndRerendersRootView() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    #expect(runtime.block(from: BoolFocusableThenFocusedView(probe: probe))?.text == "A")

    probe.binding?.wrappedValue = true

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: BoolFocusableThenFocusedView(probe: probe))?.text == "A")
    #expect(probe.binding?.wrappedValue == true)
}

@Test func focusableThenFocusedRegistersFocusCandidate() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(probe.binding?.wrappedValue == true)
}

@Test func focusedThenFocusableRegistersFocusCandidate() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: BoolFocusedThenFocusableView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: BoolFocusedThenFocusableView(probe: probe))

    #expect(probe.binding?.wrappedValue == true)
}

@Test func focusedOnlyRegistersFocusCandidate() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: BoolFocusedOnlyView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: BoolFocusedOnlyView(probe: probe))

    #expect(probe.binding?.wrappedValue == true)
}

@Test func optionalFocusedOnlyRegistersFocusCandidate() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<FocusField?>()

    _ = runtime.block(from: OptionalFocusedOnlyView(probe: probe))

    probe.binding?.wrappedValue = .first
    _ = runtime.block(from: OptionalFocusedOnlyView(probe: probe))

    #expect(probe.binding?.wrappedValue == .first)
}

@Test func falseBooleanFocusStateClearsFocus() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(probe.binding?.wrappedValue == true)

    probe.binding?.wrappedValue = false
    _ = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(probe.binding?.wrappedValue == false)
}

@Test func optionalFocusStateMovesBetweenCandidates() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<FocusField?>()

    #expect(runtime.block(from: OptionalFocusView(probe: probe))?.lines == ["First ", "Second"])

    probe.binding?.wrappedValue = .first
    _ = runtime.block(from: OptionalFocusView(probe: probe))

    #expect(probe.binding?.wrappedValue == .first)

    probe.binding?.wrappedValue = .second
    _ = runtime.block(from: OptionalFocusView(probe: probe))

    #expect(probe.binding?.wrappedValue == .second)

    probe.binding?.wrappedValue = nil
    _ = runtime.block(from: OptionalFocusView(probe: probe))

    #expect(probe.binding?.wrappedValue == nil)
}

@Test func focusableFalsePreventsRegistration() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    _ = runtime.block(from: DisabledFocusableView(probe: probe))

    probe.binding?.wrappedValue = true
    _ = runtime.block(from: DisabledFocusableView(probe: probe))

    #expect(probe.binding?.wrappedValue == false)
}

@Test func duplicateFocusValuesChooseFirstRenderedCandidate() {
    let runtime = StateRuntime()
    let fieldProbe = FocusBindingProbe<FocusField?>()
    let firstProbe = FocusBindingProbe<Bool>()
    let secondProbe = FocusBindingProbe<Bool>()

    _ = runtime.block(
        from: DuplicateFocusValueView(
            fieldProbe: fieldProbe,
            firstProbe: firstProbe,
            secondProbe: secondProbe
        )
    )

    fieldProbe.binding?.wrappedValue = .first
    _ = runtime.block(
        from: DuplicateFocusValueView(
            fieldProbe: fieldProbe,
            firstProbe: firstProbe,
            secondProbe: secondProbe
        )
    )

    #expect(fieldProbe.binding?.wrappedValue == .first)
    #expect(firstProbe.binding?.wrappedValue == true)
    #expect(secondProbe.binding?.wrappedValue == false)
}

@Test func focusModifiersDoNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()

    let block = runtime.block(from: BoolFocusableThenFocusedView(probe: probe))

    #expect(block?.text == "A")
}

@Test func clickingFocusableTextRequestsFocus() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()
    let view = ClickableFocusedTextView(probe: probe)

    _ = runtime.block(from: view)

    #expect(probe.binding?.wrappedValue == false)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(probe.binding?.wrappedValue == true)
}

@Test func clickingFocusedOnlyTextRequestsFocus() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()
    let view = ClickableFocusedOnlyTextView(probe: probe)

    _ = runtime.block(from: view)

    #expect(probe.binding?.wrappedValue == false)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(probe.binding?.wrappedValue == true)
}

@Test func clickFocusRegionRespectsPaddingAndFrameClipping() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()
    let view = PaddedFramedClickFocusView(probe: probe)

    #expect(runtime.block(from: view)?.lines == ["top", " A "])

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 2, phase: .down)
        ) == .ignored
    )
    #expect(probe.binding?.wrappedValue == false)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 2, phase: .down)
        ) == .handled
    )
    #expect(probe.binding?.wrappedValue == true)
}

@Test func clickFocusRegionScrollsWithScrollView() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()
    let view = ScrolledClickFocusView(probe: probe)

    #expect(runtime.block(from: view)?.lines == ["B"])

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(probe.binding?.wrappedValue == true)
}

@Test func focusableFalsePreventsClickFocus() {
    let runtime = StateRuntime()
    let probe = FocusBindingProbe<Bool>()
    let view = DisabledClickFocusView(probe: probe)

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .ignored
    )
    #expect(probe.binding?.wrappedValue == false)
}

@Test func clickFocusCoexistsWithTapGesture() {
    let runtime = StateRuntime()
    let focusProbe = FocusBindingProbe<Bool>()
    let tapProbe = TapGestureProbe()
    let view = ClickFocusTapGestureView(
        focusProbe: focusProbe,
        tapProbe: tapProbe
    )
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(focusProbe.binding?.wrappedValue == true)
    #expect(tapProbe.events.isEmpty)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date
        ) == .handled
    )
    #expect(tapProbe.events == ["tap"])
}

@Test func keyPressModifierDoesNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()

    let block = runtime.block(
        from: FocusedKeyPressView(
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            result: .handled
        )
    )

    #expect(block?.text == "A")
}

@Test func keyPressDispatchRequiresFocusedView() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FocusedKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        result: .handled
    )

    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .ignored)
    #expect(keyProbe.events.isEmpty)
}

@Test func focusedViewReceivesMatchingKeyPress() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FocusedKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        result: .handled
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["child"])
}

@Test func keyPressActionMutatesStateAndInvalidatesView() {
    let runtime = StateRuntime()
    let view = KeyPressStateMutationView()

    #expect(runtime.block(from: view)?.text == "0")

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "1")
}

@Test("Navigation link direct destination activates with Return and tap")
func NavigationLinkDirectDestinationActivatesWithReturnAndTap() {
    let runtime = StateRuntime()
    let view = FocusedDirectNavigationLinkView()

    #expect(runtime.block(from: view)?.text == "Open")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Open")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")
}

@Test("Disabled navigation link ignores Return and tap")
func DisabledNavigationLinkIgnoresReturnAndTap() {
    let runtime = StateRuntime()
    let view = FocusedDirectNavigationLinkView()
        .disabled(true)

    #expect(runtime.block(from: view)?.text == "Open")
    _ = runtime.consumeInvalidation()
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
    #expect(runtime.consumeInvalidation() == false)
    #expect(runtime.block(from: view)?.text == "Open")
}

@Test("Navigation link value appends to bound path and renders destination")
func NavigationLinkValueAppendsToBoundPathAndRendersDestination() {
    var path: [Int] = []
    let runtime = StateRuntime()
    let view = FocusedValueNavigationLinkView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "One")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(path == [1])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Value 1")
}

@Test("Navigation stack reflects programmatic path changes and pops binding")
func NavigationStackReflectsProgrammaticPathChangesAndPopsBinding() {
    var path = [1, 2]
    let runtime = StateRuntime()
    let view = ValueNavigationPathView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Value 2")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(path == [1])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Value 1")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(path.isEmpty)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("NavigationPath supports heterogeneous destinations")
func NavigationPathSupportsHeterogeneousDestinations() {
    var path = NavigationPath()
    path.append(1)
    path.append("two")

    let runtime = StateRuntime()
    let view = HeterogeneousNavigationPathView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "String two")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Int 1")
}

@Test("Navigation link nil value is inactive")
func NavigationLinkNilValueIsInactive() {
    let runtime = StateRuntime()
    let view = NilValueNavigationLinkView()

    #expect(runtime.block(from: view)?.text == "Missing")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
    #expect(!runtime.consumeInvalidation())
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date
        ) == .ignored
    )
    #expect(runtime.block(from: view)?.text == "Missing")
}

@Test("Navigation destination action can mutate parent state")
func NavigationDestinationActionCanMutateParentState() {
    let runtime = StateRuntime()
    let view = NavigationStateMutationView()

    #expect(runtime.block(from: view)?.lines == ["Open ", "empty"])
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Destination empty")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Destination updated")
}

@Test("Navigation destination state resets after pop and re-push")
func NavigationDestinationStateResetsAfterPopAndRepush() {
    var path: [Int] = []
    let runtime = StateRuntime()
    let view = NavigationDestinationStateResetView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Open")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Value 1 count 0")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Value 1 count 1")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Open")

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Value 1 count 0")
}

@Test("Navigation push action appends value to bound path")
func NavigationPushActionAppendsValueToBoundPath() {
    var path: [Int] = []
    let runtime = StateRuntime()
    let view = NavigationPushValueView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(path == [1])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Value 1")
}

@Test("Navigation push action appends child enum value to root bound path")
func NavigationPushActionAppendsChildEnumValueToRootBoundPath() {
    var path: [NavigationPushDestination] = []
    let runtime = StateRuntime()
    let view = NavigationPushChildRootDestinationView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(path == [.detail])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")
}

@Test("Navigation push action appends value to observable object bound path")
func NavigationPushActionAppendsValueToObservableObjectBoundPath() {
    let runtime = StateRuntime()
    let view = NavigationPushObservableObjectPathView()

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")
}

@Test("Navigation push action preserves initialized observable object bound path")
func NavigationPushActionPreservesInitializedObservableObjectBoundPath() {
    let runtime = StateRuntime()
    let view = NavigationPushInitializedObservableObjectPathRootView()

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")
}

@Test("Navigation runtime value push appends before destination types are registered")
func NavigationRuntimeValuePushAppendsBeforeDestinationTypesAreRegistered() {
    var path: [NavigationPushDestination] = []
    let runtime = NavigationRuntime()
    runtime.registerStack(
        at: [],
        accessor: NavigationPathAccessor(
            Binding(
                get: {
                    path
                },
                set: {
                    path = $0
                }
            )
        )
    )

    #expect(runtime.pushValue(AnyNavigationValue(NavigationPushDestination.detail), at: []))
    #expect(path == [.detail])
}

@Test("Navigation push action presents direct destination")
func NavigationPushActionPresentsDirectDestination() {
    let runtime = StateRuntime()
    let view = NavigationPushDirectDestinationView()

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")
}

@Test("Navigation push direct destination can mutate parent state")
func NavigationPushDirectDestinationCanMutateParentState() {
    let runtime = StateRuntime()
    let view = NavigationPushDirectStateMutationView()

    #expect(runtime.block(from: view)?.lines == ["Push ", "empty"])
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Destination empty")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Destination updated")
}

@Test("Navigation pop action resets direct destination state")
func NavigationPopActionResetsDirectDestinationState() {
    let runtime = StateRuntime()
    let view = NavigationPushDirectStateResetView()

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.trimmedLines == ["Value count 0", "Back"])

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.trimmedLines == ["Value count 1", "Back"])

    dispatchClick(to: runtime, column: 1, row: 2)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Push")

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.trimmedLines == ["Value count 0", "Back"])
}

@Test("Navigation pop action removes bound path value and no-ops at root")
func NavigationPopActionRemovesBoundPathValueAndNoOpsAtRoot() {
    var path = [1]
    let runtime = StateRuntime()
    let view = NavigationPopValueView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Value 1")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(path.isEmpty)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(path.isEmpty)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation destination isPresented binding presents and resets on Escape")
func NavigationDestinationIsPresentedBindingPresentsAndResetsOnEscape() {
    var isPresented = false
    let runtime = StateRuntime()
    let view = NavigationPresentedBoolView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Root")

    isPresented = true
    #expect(runtime.block(from: view)?.text == "Presented")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation destination isPresented state presents after global key press")
func NavigationDestinationIsPresentedStatePresentsAfterGlobalKeyPress() {
    let runtime = StateRuntime()
    let view = NavigationPresentedBoolStateGlobalKeyView()

    #expect(runtime.block(from: view)?.text == "Root")

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Presented")
}

@Test("Navigation destination isPresented state presents after character global key press with onAppear")
func NavigationDestinationIsPresentedStatePresentsAfterCharacterGlobalKeyPressWithOnAppear() {
    let runtime = StateRuntime()
    let view = NavigationPresentedBoolStateCharacterGlobalKeyOnAppearView()

    #expect(runtime.block(from: view)?.text == "Root")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root appeared")

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Presented")
}

@Test("Navigation destination isPresented state presents from direct destination")
func NavigationDestinationIsPresentedStatePresentsFromDirectDestination() {
    let runtime = StateRuntime()
    let view = NavigationPresentedBoolStateDirectDestinationView()

    #expect(runtime.block(from: view)?.text == "Open")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Presented")
}

@Test("Navigation destination isPresented direct destination Escape dismisses presented first")
func NavigationDestinationIsPresentedDirectDestinationEscapeDismissesPresentedFirst() {
    let runtime = StateRuntime()
    let view = NavigationPresentedBoolStateDirectDestinationView()

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Presented")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")
}

@Test("Navigation destination isPresented direct destination keeps presented input active")
func NavigationDestinationIsPresentedDirectDestinationKeepsPresentedInputActive() {
    let runtime = StateRuntime()
    let probe = KeyPressProbe()
    let view = NavigationPresentedBoolStateDirectDestinationInputView(probe: probe)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Activate")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(probe.events == ["activated"])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Activated")
}

@Test("Navigation destination isPresented direct destination keeps presented focused key input active")
func NavigationDestinationIsPresentedDirectDestinationKeepsPresentedFocusedKeyInputActive() {
    let runtime = StateRuntime()
    let probe = KeyPressProbe()
    let view = NavigationPresentedBoolStateDirectDestinationInputView(probe: probe)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Activate")

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(probe.events == ["activated"])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Activated")
}

@Test("Navigation destination item binding presents and resets on Escape")
func NavigationDestinationItemBindingPresentsAndResetsOnEscape() {
    var item: Int? = nil
    let runtime = StateRuntime()
    let view = NavigationPresentedItemView(
        item: Binding(
            get: {
                item
            },
            set: {
                item = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Root")

    item = 7
    #expect(runtime.block(from: view)?.text == "Item 7")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(item == nil)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation destination item binding resets state when item changes")
func NavigationDestinationItemBindingResetsStateWhenItemChanges() {
    var item: Int? = 1
    let runtime = StateRuntime()
    let view = NavigationPresentedItemStateResetView(
        item: Binding(
            get: {
                item
            },
            set: {
                item = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Value 1 count 0")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Value 1 count 1")

    item = 2
    #expect(runtime.block(from: view)?.text == "Value 2 count 0")
}

@Test("Navigation pop action dismisses binding destination")
func NavigationPopActionDismissesBindingDestination() {
    var isPresented = true
    let runtime = StateRuntime()
    let view = NavigationPresentedPopActionView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Back")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation dismiss action captured by parent no-ops for presented destination")
func NavigationDismissActionCapturedByParentNoOpsForPresentedDestination() {
    var isPresented = true
    let runtime = StateRuntime()
    let view = NavigationParentCapturedDismissActionView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Close")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(isPresented)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Close")
}

@Test("Navigation dismiss action dismisses isPresented destination")
func NavigationDismissActionDismissesIsPresentedDestination() {
    var isPresented = true
    let runtime = StateRuntime()
    let view = NavigationPresentedDismissActionView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Close")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation dismiss action dismisses item destination")
func NavigationDismissActionDismissesItemDestination() {
    var item: Int? = 7
    let runtime = StateRuntime()
    let view = NavigationItemDismissActionView(
        item: Binding(
            get: {
                item
            },
            set: {
                item = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Item 7")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(item == nil)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation dismiss action removes bound path value")
func NavigationDismissActionRemovesBoundPathValue() {
    var path = [1]
    let runtime = StateRuntime()
    let view = NavigationDismissValueView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        )
    )

    #expect(runtime.block(from: view)?.text == "Value 1")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(path.isEmpty)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation dismiss action dismisses direct destination")
func NavigationDismissActionDismissesDirectDestination() {
    let runtime = StateRuntime()
    let view = NavigationPushDirectDismissActionView()

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Close")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Push")
}

@Test("Root dismiss action is a no-op")
func RootDismissActionIsNoOp() {
    let runtime = StateRuntime()
    let view = NavigationRootDismissActionView()

    #expect(runtime.block(from: view)?.text == "Dismiss")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Dismiss")
}

@Test("Navigation expired presented dismiss action no-ops after re-presentation")
func NavigationExpiredPresentedDismissActionNoOpsAfterRePresentation() {
    var isPresented = true
    let probe = DismissActionProbe()
    let runtime = StateRuntime()
    let view = NavigationCapturedPresentedDismissActionView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        ),
        probe: probe
    )

    #expect(runtime.block(from: view)?.text == "Close")
    let staleDismiss = probe.dismiss

    staleDismiss?()
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")

    isPresented = true
    #expect(runtime.block(from: view)?.text == "Close")
    let currentDismiss = probe.dismiss

    staleDismiss?()
    #expect(isPresented)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Close")

    currentDismiss?()
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation expired direct dismiss action no-ops after direct destination is re-pushed")
func NavigationExpiredDirectDismissActionNoOpsAfterDirectDestinationIsRePushed() {
    let probe = NavigationActionProbe()
    let runtime = StateRuntime()
    let view = NavigationPushCapturedDirectActionView(probe: probe)

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")
    let expiredDismiss = probe.dismiss

    expiredDismiss?()
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Push")

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")
    let currentDismiss = probe.dismiss
    _ = runtime.consumeInvalidation()

    expiredDismiss?()
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")

    currentDismiss?()
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Push")
}

@Test("Navigation expired value dismiss action no-ops after value destination is re-pushed")
func NavigationExpiredValueDismissActionNoOpsAfterValueDestinationIsRePushed() {
    var path: [Int] = []
    let probe = NavigationActionProbe()
    let runtime = StateRuntime()
    let view = NavigationCapturedValueDismissActionView(
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        ),
        probe: probe
    )

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(path == [1])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")
    let expiredDismiss = probe.dismiss

    expiredDismiss?()
    #expect(path.isEmpty)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Push")

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(path == [1])
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")
    let currentDismiss = probe.dismiss
    _ = runtime.consumeInvalidation()

    expiredDismiss?()
    #expect(path == [1])
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")

    currentDismiss?()
    #expect(path.isEmpty)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Push")
}

@Test("Navigation covered direct dismiss action no-ops while presented destination is current")
func NavigationCoveredDirectDismissActionNoOpsWhilePresentedDestinationIsCurrent() {
    var isPresented = false
    let directProbe = NavigationActionProbe()
    let presentedProbe = NavigationActionProbe()
    let runtime = StateRuntime()
    let view = NavigationPushDirectWithPresentedActionView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        ),
        directProbe: directProbe,
        presentedProbe: presentedProbe
    )

    #expect(runtime.block(from: view)?.text == "Push")
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")
    let coveredDismiss = directProbe.dismiss

    isPresented = true
    #expect(runtime.block(from: view)?.text == "A")
    let currentDismiss = presentedProbe.dismiss
    _ = runtime.consumeInvalidation()

    coveredDismiss?()
    #expect(isPresented)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")

    currentDismiss?()
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")
}

@Test("Navigation stack scoped pop bypasses expired dismiss action scope")
func NavigationStackScopedPopBypassesExpiredDismissActionScope() {
    var isPresented = true
    let probe = NavigationActionProbe()
    let runtime = StateRuntime()
    let view = NavigationCapturedPresentedNavigationActionsView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        ),
        probe: probe
    )

    #expect(runtime.block(from: view)?.text == "A")
    let staleDismiss = probe.dismiss
    let stalePop = probe.pop

    staleDismiss?()
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")

    isPresented = true
    #expect(runtime.block(from: view)?.text == "A")

    staleDismiss?()
    #expect(isPresented)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")

    stalePop?()
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")
}

@Test("Navigation stack scoped value push bypasses expired dismiss action scope")
func NavigationStackScopedValuePushBypassesExpiredDismissActionScope() {
    var isPresented = true
    var path: [Int] = []
    let probe = NavigationActionProbe()
    let runtime = StateRuntime()
    let view = NavigationCapturedPresentedNavigationPathActionsView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        ),
        path: Binding(
            get: {
                path
            },
            set: {
                path = $0
            }
        ),
        probe: probe
    )

    #expect(runtime.block(from: view)?.text == "A")
    let staleDismiss = probe.dismiss
    let stalePush = probe.push

    staleDismiss?()
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")

    isPresented = true
    #expect(runtime.block(from: view)?.text == "A")

    staleDismiss?()
    #expect(isPresented)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")

    stalePush?(1)
    #expect(path == [1])
    #expect(runtime.consumeInvalidation())

    isPresented = false
    #expect(runtime.block(from: view)?.text == "Value 1")
}

@Test("Navigation stack scoped direct push bypasses expired dismiss action scope")
func NavigationStackScopedDirectPushBypassesExpiredDismissActionScope() {
    var isPresented = true
    let probe = NavigationActionProbe()
    let runtime = StateRuntime()
    let view = NavigationCapturedPresentedNavigationActionsView(
        isPresented: Binding(
            get: {
                isPresented
            },
            set: {
                isPresented = $0
            }
        ),
        probe: probe
    )

    #expect(runtime.block(from: view)?.text == "A")
    let staleDismiss = probe.dismiss
    let stalePush = probe.push

    staleDismiss?()
    #expect(!isPresented)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Root")

    isPresented = true
    #expect(runtime.block(from: view)?.text == "A")

    staleDismiss?()
    #expect(isPresented)
    #expect(!runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "A")

    stalePush? {
        Text("Direct")
    }
    #expect(runtime.consumeInvalidation())

    isPresented = false
    #expect(runtime.block(from: view)?.text == "Direct")
}

@Test("Default navigation environment actions are no-ops")
func DefaultNavigationEnvironmentActionsAreNoOps() {
    let probe = NavigationActionProbe()
    let view = CapturedNavigationActionsView(probe: probe)

    _ = ViewResolver.text(from: view)
    probe.push?(1)
    probe.push? {
        Text("Detail")
    }
    probe.pop?()
    probe.dismiss?()
}

@Suite(.serialized)
private struct ParentCallbackStateMutationTests {

@Test func parentCallbackDirectStateMutationFromChildKeyPressUpdatesRenderedState() {
    let runtime = StateRuntime()
    let view = ParentCallbackDirectStateMutationKeyPressView()

    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

    focusParentCallbackKeyPressChild(in: runtime)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
}

@Test func parentCallbackBindingMutationFromChildKeyPressMatchesDirectStateMutation() {
    let runtime = StateRuntime()
    let view = ParentCallbackBindingMutationKeyPressView()

    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

    focusParentCallbackKeyPressChild(in: runtime)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
}

@Test func parentCallbackDirectStateMutationFirstRenderedAfterActionUpdatesRenderedState() {
    let runtime = StateRuntime()
    let view = DeferredParentStateMutationView()

    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "idle"])

    focusParentCallbackKeyPressChild(in: runtime)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
}

@Test func parentCallbackDeferredStateMutationPromotesOverExistingRenderCell() {
    let runtime = StateRuntime()
    let view = DeferredParentStateMutationWithExistingStringCellView()

    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

    focusParentCallbackKeyPressChild(in: runtime)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
}

}

@Test func ignoredKeyPressContinuesToAncestorHandler() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = ParentKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        childResult: .ignored
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["child", "parent"])
}

@Test func handledKeyPressStopsBeforeAncestorHandler() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = ParentKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        childResult: .handled
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["child"])
}

@Test func samePathKeyPressHandlersRunInRegistrationOrder() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = OrderedKeyPressView(focusProbe: focusProbe, keyProbe: keyProbe)

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["second"])
}

@Test func keyPressOverloadsMatchExpectedEvents() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = KeyPressOverloadView(focusProbe: focusProbe, keyProbe: keyProbe)

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "b", characters: "b")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "5", characters: "5")) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "z", characters: "z", phase: .up)) == .handled)
    #expect(runtime.dispatch(KeyPress(key: "z", characters: "z")) == .ignored)
    #expect(keyProbe.events == ["exact", "set", "characters", "phase"])
}

@Test func globalKeyPressReceivesEventsWithoutFocus() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let view = Text("A")
        .onGlobalKeyPress(.escape) {
            keyProbe.record("global")
            return .handled
        }

    #expect(runtime.block(from: view)?.text == "A")
    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(keyProbe.events == ["global"])
}

@Test func nestedGlobalKeyPressDispatchesDeepestHandlerFirst() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let view = NestedGlobalKeyPressView(
        keyProbe: keyProbe,
        innerResult: .handled
    )

    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["inner"])
}

@Test func ignoredNestedGlobalKeyPressBubblesToOuterHandler() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let view = NestedGlobalKeyPressView(
        keyProbe: keyProbe,
        innerResult: .ignored
    )

    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["inner", "outer"])
}

@Test func focusedKeyPressRunsBeforeGlobalKeyPress() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FocusedAndGlobalKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        focusedResult: .handled
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["focused"])
}

@Test func ignoredFocusedKeyPressFallsBackToGlobalKeyPress() {
    let runtime = StateRuntime()
    let keyProbe = KeyPressProbe()
    let focusProbe = FocusBindingProbe<Bool>()
    let view = FocusedAndGlobalKeyPressView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        focusedResult: .ignored
    )

    _ = runtime.block(from: view)
    focusProbe.binding?.wrappedValue = true
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .handled)
    #expect(keyProbe.events == ["focused", "global"])
}

@Test func globalKeyPressRestoresEnvironmentForAction() {
    var didTerminate = false
    let runtime = StateRuntime()
    let view = GlobalEnvironmentTerminateView()
        .environment(\.terminate, TerminateAction {
            didTerminate = true
        })

    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(didTerminate)
}

@Test func tapGestureModifierDoesNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()

    let block = runtime.block(
        from: Text("A")
            .onTapGesture {
                tapProbe.record("tap")
            }
    )

    #expect(block?.text == "A")
    #expect(tapProbe.events.isEmpty)
}

@Test func longPressGestureModifierDoesNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()

    let block = runtime.block(
        from: Text("A")
            .onLongPressGesture {
                tapProbe.record("long")
            }
    )

    #expect(block?.text == "A")
    #expect(tapProbe.events.isEmpty)
}

@Test func hoverGestureModifiersDoNotChangeRenderedOutput() {
    let runtime = StateRuntime()
    let hoverProbe = HoverProbe()

    let block = runtime.block(
        from: Text("A")
            .onHover {
                hoverProbe.record($0 ? "enter" : "exit")
            }
            .onContinuousHover { phase in
                hoverProbe.record(String(describing: phase))
            }
    )

    #expect(block?.text == "A")
    #expect(hoverProbe.events.isEmpty)
}

@Test func hiddenSuppressesInteractiveRuntimeRegistrations() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = VStack {
        Button("Run") {
            tapProbe.record("button")
        }
        Text("Key")
            .focusable()
            .onKeyPress("k") {
                tapProbe.record("key")
                return .handled
            }
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onLongPressGesture {
                tapProbe.record("long")
            }
            .onHover { _ in
                tapProbe.record("hover")
            }
            .onContinuousHover { _ in
                tapProbe.record("continuous-hover")
            }
        ScrollView(.vertical) {
            Text("A")
            Text("B")
        }
    }
    .hidden()

    let block = runtime.block(from: view, in: RenderProposal(columns: 5, rows: 2))

    #expect(block?.runs == [])
    #expect(block?.hitRegions == [])
    #expect(block?.scrollRegions == [])
    #expect(block?.focusRegions == [])
    #expect(runtime.dispatch(KeyPress(key: "k", characters: "k")) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
    dispatchHover(to: runtime, column: 1, row: 1, expecting: .ignored)
    #expect(runtime.dispatchExpiredLongPressActions() == .ignored)
    #expect(tapProbe.events.isEmpty)
}

@Test func disabledInputModifiersIgnoreUserInput() {
    let runtime = StateRuntime()
    let focusProbe = FocusBindingProbe<Bool>()
    let keyProbe = KeyPressProbe()
    let tapProbe = TapGestureProbe()
    let view = DisabledInputModifiersView(
        focusProbe: focusProbe,
        keyProbe: keyProbe,
        tapProbe: tapProbe
    )

    #expect(runtime.block(from: view)?.text == "A")
    #expect(focusProbe.binding?.wrappedValue == false)
    #expect(runtime.dispatch(KeyPress(key: "a", characters: "a")) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: "g", characters: "g")) == .ignored)
    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
    dispatchHover(to: runtime, column: 1, row: 1, expecting: .ignored)
    #expect(runtime.dispatchExpiredLongPressActions() == .ignored)
    #expect(keyProbe.events.isEmpty)
    #expect(tapProbe.events.isEmpty)
}

@Test func tapGestureActionMutatesStateAndInvalidatesView() {
    let runtime = StateRuntime()
    let view = TapGestureStateMutationView()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    #expect(runtime.block(from: view)?.text == "0")

    dispatchClick(to: runtime, column: 1, row: 1, at: date)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "1")
}

@Test func parentCallbackDirectStateMutationFromChildTapUpdatesRenderedState() {
    let runtime = StateRuntime()
    let view = ParentCallbackDirectStateMutationTapView()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Tap", "empty"])

    dispatchClick(to: runtime, column: 1, row: 1, at: date)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Tap", "updated"])
}

@Test func longPressGestureRecognizesAfterMinimumDuration() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    let view = Text("A")
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: Size(columns: 10, rows: 10),
            perform: {
                tapProbe.record("long")
            },
            onPressingChanged: {
                tapProbe.record($0 ? "pressing" : "ended")
            }
        )

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(runtime.nextLongPressDeadline == date.addingTimeInterval(0.5))
    #expect(tapProbe.events == ["pressing"])
    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.49)) == .ignored)
    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.5)) == .handled)
    #expect(tapProbe.events == ["pressing", "long"])
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date.addingTimeInterval(0.6)
        ) == .handled
    )
    #expect(tapProbe.events == ["pressing", "long", "ended"])
}

@Test func longPressGestureReleaseBeforeDeadlineCancelsWithoutPerforming() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    let view = Text("A")
        .onLongPressGesture(
            minimumDuration: 0.5,
            perform: {
                tapProbe.record("long")
            },
            onPressingChanged: {
                tapProbe.record($0 ? "pressing" : "ended")
            }
        )

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date.addingTimeInterval(0.1)
        ) == .handled
    )
    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.6)) == .ignored)
    #expect(tapProbe.events == ["pressing", "ended"])
}

@Test func longPressGestureMotionBeyondMaximumDistanceCancels() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    let view = Text("ABCDE")
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: Size(columns: 2, rows: 0),
            perform: {
                tapProbe.record("long")
            },
            onPressingChanged: {
                tapProbe.record($0 ? "pressing" : "ended")
            }
        )

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 4, row: 1, phase: .motion),
            at: date.addingTimeInterval(0.1)
        ) == .handled
    )
    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.6)) == .ignored)
    #expect(tapProbe.events == ["pressing", "ended"])
}

@Test func longPressGestureUsesMostSpecificRegionAndRespectsFrameClipping() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    let view = VStack {
        Text("ABCD")
            .frame(width: 2)
            .onLongPressGesture(minimumDuration: 0.1) {
                tapProbe.record("child")
            }
    }
    .onLongPressGesture(minimumDuration: 0.1) {
        tapProbe.record("parent")
    }

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 1, phase: .up),
            at: date.addingTimeInterval(0.2)
        ) == .handled
    )

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 3, row: 1, phase: .down),
            at: date.addingTimeInterval(1)
        ) == .ignored
    )
    #expect(tapProbe.events == ["child"])
}

@Test func longPressGestureSuccessfulPressSuppressesTap() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    let view = Text("A")
        .onTapGesture {
            tapProbe.record("tap")
        }
        .onLongPressGesture(minimumDuration: 0.1) {
            tapProbe.record("long")
        }

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, at: date)
    #expect(tapProbe.events == ["tap"])

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date.addingTimeInterval(1)
        ) == .handled
    )
    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(1.1)) == .handled)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date.addingTimeInterval(1.2)
        ) == .handled
    )
    #expect(tapProbe.events == ["tap", "long"])
}

@Test func longPressGestureStateMutationInvalidatesView() {
    let runtime = StateRuntime()
    let view = LongPressGestureStateMutationView()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    #expect(runtime.block(from: view)?.text == "0:false")

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "0:true")

    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "1:true")

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date.addingTimeInterval(0.2)
        ) == .handled
    )
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "1:false")
}

@Test func parentCallbackDirectStateMutationFromChildLongPressUpdatesRenderedState() {
    let runtime = StateRuntime()
    let view = ParentCallbackDirectStateMutationLongPressView()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "empty"])

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(runtime.dispatchExpiredLongPressActions(at: date.addingTimeInterval(0.1)) == .handled)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Press", "updated"])
}

@Test func hoverGestureReportsEnterAndExitWithoutRepeatingUnchangedState() {
    let runtime = StateRuntime()
    let hoverProbe = HoverProbe()
    let view = Text("AB")
        .onHover {
            hoverProbe.record($0 ? "enter" : "exit")
        }

    _ = runtime.block(from: view)

    dispatchHover(to: runtime, column: 1, row: 1)
    dispatchHover(to: runtime, column: 2, row: 1)
    dispatchHover(to: runtime, column: 3, row: 1)
    dispatchHover(to: runtime, column: 4, row: 1, expecting: .ignored)

    #expect(hoverProbe.events == ["enter", "exit"])
}

@Test func continuousHoverReportsActiveMovementAndEnded() {
    let runtime = StateRuntime()
    let hoverProbe = HoverProbe()
    let view = Text("ABC")
        .onContinuousHover(coordinateSpace: .local) { phase in
            hoverProbe.record(phase)
        }

    _ = runtime.block(from: view)

    dispatchHover(to: runtime, column: 1, row: 1)
    dispatchHover(to: runtime, column: 3, row: 1)
    dispatchHover(to: runtime, column: 4, row: 1)

    #expect(
        hoverProbe.phases == [
            .active(Point(column: 0, row: 0)),
            .active(Point(column: 2, row: 0)),
            .ended,
        ]
    )
}

@Test func continuousHoverReportsLocalGlobalAndNamedLocations() {
    let runtime = StateRuntime()
    let locationProbe = TapLocationProbe()
    let view = HStack(spacing: 0) {
        Text("..")
        VStack(alignment: .leading, spacing: 0) {
            Text("x")
            Text("ABCD")
                .frame(width: 2)
                .onContinuousHover(coordinateSpace: .local) { phase in
                    if case .active(let location) = phase {
                        locationProbe.record("local", location)
                    }
                }
                .onContinuousHover(coordinateSpace: .global) { phase in
                    if case .active(let location) = phase {
                        locationProbe.record("global", location)
                    }
                }
                .onContinuousHover(coordinateSpace: .named("stack")) { phase in
                    if case .active(let location) = phase {
                        locationProbe.record("named", location)
                    }
                }
        }
        .coordinateSpace(.named("stack"))
    }

    _ = runtime.block(from: view)

    dispatchHover(to: runtime, column: 4, row: 2)

    #expect(
        locationProbe.events == [
            TapLocationEvent(name: "named", location: Point(column: 1, row: 1)),
            TapLocationEvent(name: "global", location: Point(column: 3, row: 1)),
            TapLocationEvent(name: "local", location: Point(column: 1, row: 0)),
        ]
    )
}

@Test func hoverGestureKeepsParentActiveWhenPointerEntersAndExitsChild() {
    let runtime = StateRuntime()
    let hoverProbe = HoverProbe()
    let view = VStack(alignment: .leading, spacing: 0) {
        Text("A")
            .onHover {
                hoverProbe.record($0 ? "child-enter" : "child-exit")
            }
        Text("B")
    }
    .onHover {
        hoverProbe.record($0 ? "parent-enter" : "parent-exit")
    }

    _ = runtime.block(from: view)

    dispatchHover(to: runtime, column: 1, row: 2)
    dispatchHover(to: runtime, column: 1, row: 1)
    dispatchHover(to: runtime, column: 1, row: 2)
    dispatchHover(to: runtime, column: 2, row: 2)

    #expect(
        hoverProbe.events == [
            "parent-enter",
            "child-enter",
            "child-exit",
            "parent-exit",
        ]
    )
}

@Test func hoverGestureRespectsFrameClipping() {
    let runtime = StateRuntime()
    let hoverProbe = HoverProbe()
    let view = Text("ABCD")
        .onHover {
            hoverProbe.record($0 ? "enter" : "exit")
        }
        .frame(width: 2)

    _ = runtime.block(from: view)

    dispatchHover(to: runtime, column: 2, row: 1)
    dispatchHover(to: runtime, column: 3, row: 1)

    #expect(hoverProbe.events == ["enter", "exit"])
}

@Test func hoverGestureStateMutationInvalidatesView() {
    let runtime = StateRuntime()
    let view = HoverGestureStateMutationView()

    #expect(runtime.block(from: view)?.text == "false:0")

    dispatchHover(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "true:1")

    dispatchHover(to: runtime, column: 10, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "false:1")
}

@Test func parentCallbackDirectStateMutationFromChildHoverUpdatesRenderedState() {
    let runtime = StateRuntime()
    let view = ParentCallbackDirectStateMutationHoverView()

    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Hover", "empty"])

    dispatchHover(to: runtime, column: 1, row: 1)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.runs.map(\.text) == ["Hover", "updated"])
}

@Test func tapGestureHitTestingUsesStackCoordinates() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = StackTapGestureView(tapProbe: tapProbe)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1)
    dispatchClick(to: runtime, column: 3, row: 1)
    dispatchClick(to: runtime, column: 1, row: 2)
    dispatchClick(to: runtime, column: 2, row: 1, expecting: .ignored)

    #expect(tapProbe.events == ["left", "right", "bottom"])
}

@Test func tapGestureHitTestingUsesMostSpecificRegion() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = NestedTapGestureView(tapProbe: tapProbe)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1)

    #expect(tapProbe.events == ["child"])
}

@Test func tapGestureHitTestingRespectsFrameClipping() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = Text("ABCD")
        .onTapGesture {
            tapProbe.record("tap")
        }
        .frame(width: 2)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 2, row: 1)
    dispatchClick(to: runtime, column: 3, row: 1, expecting: .ignored)

    #expect(tapProbe.events == ["tap"])
}

@Test func tapGestureReportsLocalAndGlobalLocations() {
    let runtime = StateRuntime()
    let locationProbe = TapLocationProbe()
    let view = VStack(alignment: .leading, spacing: 0) {
        Text("top")
        HStack(spacing: 0) {
            Text("..")
            Text("ABCD")
                .frame(width: 2)
                .onTapGesture(coordinateSpace: .local) { location in
                    locationProbe.record("local", location)
                }
                .onTapGesture(coordinateSpace: .global) { location in
                    locationProbe.record("global", location)
                }
        }
    }

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 4, row: 2)

    #expect(
        locationProbe.events == [
            TapLocationEvent(name: "global", location: Point(column: 3, row: 1)),
            TapLocationEvent(name: "local", location: Point(column: 1, row: 0)),
        ]
    )
}

@Test func tapGestureReportsNamedCoordinateSpaceLocation() {
    let runtime = StateRuntime()
    let locationProbe = TapLocationProbe()
    let view = HStack(spacing: 0) {
        Text("..")
        VStack(alignment: .leading, spacing: 0) {
            Text("x")
            Text("AB")
                .onTapGesture(coordinateSpace: .named("stack")) { location in
                    locationProbe.record("named", location)
                }
        }
        .coordinateSpace(.named("stack"))
    }

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 4, row: 2)

    #expect(
        locationProbe.events == [
            TapLocationEvent(name: "named", location: Point(column: 1, row: 1))
        ]
    )
}

@Test func tapGestureNamedCoordinateSpaceUsesDeepestMatchingAncestor() {
    let runtime = StateRuntime()
    let locationProbe = TapLocationProbe()
    let view = HStack(spacing: 0) {
        Text("..")
        VStack(alignment: .leading, spacing: 0) {
            Text("x")
            Text("AB")
                .onTapGesture(coordinateSpace: .named("space")) { location in
                    locationProbe.record("named", location)
                }
        }
        .coordinateSpace(.named("space"))
    }
    .coordinateSpace(.named("space"))

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 4, row: 2)

    #expect(
        locationProbe.events == [
            TapLocationEvent(name: "named", location: Point(column: 1, row: 1))
        ]
    )
}

@Test func tapGestureNamedCoordinateSpaceSurvivesLayoutTransforms() {
    let runtime = StateRuntime()
    let locationProbe = TapLocationProbe()
    let view = ZStack(alignment: .topLeading) {
        Text("....")
        Text("AB")
            .onTapGesture(coordinateSpace: .named("target")) { location in
                locationProbe.record("named", location)
            }
            .coordinateSpace(.named("target"))
            .padding(.leading, 1)
            .frame(width: 4, alignment: .trailing)
    }

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 4, row: 1)

    #expect(
        locationProbe.events == [
            TapLocationEvent(name: "named", location: Point(column: 1, row: 0))
        ]
    )
}

@Test func tapGestureWaitsForLargerAvailableCounts() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = CountedTapGestureView(tapProbe: tapProbe)
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, at: date)
    #expect(tapProbe.events.isEmpty)

    dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.1))
    #expect(tapProbe.events.isEmpty)

    dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.2))
    #expect(tapProbe.events == ["three"])
}

@Test func tapGestureTimeoutPerformsLargestReachedCount() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = CountedTapGestureView(tapProbe: tapProbe)
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, at: date)
    dispatchClick(to: runtime, column: 1, row: 1, at: date.addingTimeInterval(0.1))

    #expect(tapProbe.events.isEmpty)
    #expect(
        runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(0.61)) == .handled
    )
    #expect(tapProbe.events == ["two"])
}

@Test func tapGestureTimeoutPerformsLargestReachedCountWithLastLocation() {
    let runtime = StateRuntime()
    let locationProbe = TapLocationProbe()
    let view = Text("ABCD")
        .onTapGesture(count: 1, coordinateSpace: .local) { location in
            locationProbe.record("one", location)
        }
        .onTapGesture(count: 2, coordinateSpace: .local) { location in
            locationProbe.record("two", location)
        }
        .onTapGesture(count: 3, coordinateSpace: .local) { location in
            locationProbe.record("three", location)
        }
    let date = Date(timeIntervalSinceReferenceDate: 1_000)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, at: date)
    dispatchClick(to: runtime, column: 3, row: 1, at: date.addingTimeInterval(0.1))

    #expect(locationProbe.events.isEmpty)
    #expect(
        runtime.dispatchExpiredTapActions(at: date.addingTimeInterval(0.61)) == .handled
    )
    #expect(
        locationProbe.events == [
            TapLocationEvent(name: "two", location: Point(column: 2, row: 0))
        ]
    )
}

@Test func tapGestureIgnoresOtherButtonsAndMismatchedTargets() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = Text("A")
        .onTapGesture {
            tapProbe.record("tap")
        }

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .right, column: 1, row: 1, phase: .down)
        ) == .ignored
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down)
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 2, row: 1, phase: .up)
        ) == .ignored
    )

    #expect(tapProbe.events.isEmpty)
}

@Test func disabledTapGestureWithNamedCoordinateSpaceIgnoresClicks() {
    let runtime = StateRuntime()
    let locationProbe = TapLocationProbe()
    let view = Text("A")
        .onTapGesture(coordinateSpace: .named("disabled")) { location in
            locationProbe.record("tap", location)
        }
        .coordinateSpace(.named("disabled"))
        .disabled(true)

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)

    #expect(locationProbe.events.isEmpty)
}

@Test func buttonRendersLabelWithoutPerformingAction() {
    var didRun = false
    let custom = Button(action: { didRun = true }) {
        Text("Run")
    }
    let titled = Button("Save") {
        didRun = true
    }

    #expect(ViewResolver.text(from: custom) == "Run")
    #expect(ViewResolver.text(from: titled) == "Save")
    #expect(!didRun)
}

@Test func buttonClickPerformsActionOnMouseUpInsideSameRegion() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    let view = Button("Run") {
        tapProbe.record("run")
    }

    _ = runtime.block(from: view)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .down),
            at: date
        ) == .handled
    )
    #expect(tapProbe.events.isEmpty)

    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 1, phase: .up),
            at: date
        ) == .handled
    )
    #expect(tapProbe.events == ["run"])
}

@Test func buttonIgnoresClicksOutsideHitRegion() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = Button("Run") {
        tapProbe.record("run")
    }

    _ = runtime.block(from: view)

    dispatchClick(to: runtime, column: 4, row: 1, expecting: .ignored)

    #expect(tapProbe.events.isEmpty)
}

@Test func focusedButtonPerformsActionWithReturn() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = FocusedButtonView(tapProbe: tapProbe)

    _ = runtime.block(from: view)
    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)

    #expect(runtime.dispatch(KeyPress(key: "x", characters: "x")) == .ignored)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)
    #expect(tapProbe.events == ["go"])
}

@Test func disabledButtonIgnoresClickAndReturnActivation() {
    let runtime = StateRuntime()
    let focusProbe = FocusBindingProbe<Bool>()
    let tapProbe = TapGestureProbe()
    let view = DisabledFocusedButtonView(
        focusProbe: focusProbe,
        tapProbe: tapProbe
    )

    #expect(runtime.block(from: view)?.text == "Run")
    #expect(focusProbe.binding?.wrappedValue == false)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .ignored)
    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
    #expect(tapProbe.events.isEmpty)
}

@Test func buttonActionMutatesStateAndInvalidatesView() {
    let runtime = StateRuntime()
    let view = ButtonStateMutationView()

    #expect(runtime.block(from: view)?.text == "0")

    dispatchClick(to: runtime, column: 1, row: 1)

    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "1")
}

@Test func buttonActionRestoresEnvironmentForKeyAndTapActivation() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = ButtonEnvironmentActionView(tapProbe: tapProbe)
        .environment(\.testMarker, "button")

    _ = runtime.block(from: view)
    dispatchClick(to: runtime, column: 1, row: 1)

    _ = runtime.consumeInvalidation()
    _ = runtime.block(from: view)
    #expect(runtime.dispatch(KeyPress(key: .return, characters: "\r")) == .handled)

    #expect(tapProbe.events == ["button", "button"])
}

@Test func automaticAndFittedButtonSizingUseIntrinsicWidthInStacks() {
    let automatic = HStack {
        Button("A") {}
        Text("B")
    }
    let fitted = HStack {
        Button("A") {}
            .buttonSizing(.fitted)
        Text("B")
    }

    #expect(ViewResolver.block(from: automatic, in: RenderProposal(columns: 5))?.lines == ["AB"])
    #expect(ViewResolver.block(from: fitted, in: RenderProposal(columns: 5))?.lines == ["AB"])
}

@Test func flexibleButtonSizingExpandsToProposedWidth() {
    let view = Button("Open") {}
        .buttonSizing(.flexible)

    #expect(ViewResolver.block(from: view, in: RenderProposal(columns: 8))?.lines == ["Open    "])
}

@Test func flexibleButtonSizingReceivesRemainingHorizontalStackWidth() {
    let view = HStack {
        Button("A") {}
            .buttonSizing(.flexible)
        Text("B")
    }

    #expect(ViewResolver.block(from: view, in: RenderProposal(columns: 5))?.lines == ["A   B"])
}

@Test func flexibleButtonBlankAreaIsClickable() {
    let runtime = StateRuntime()
    let tapProbe = TapGestureProbe()
    let view = Button("A") {
        tapProbe.record("tap")
    }
    .buttonSizing(.flexible)

    #expect(runtime.block(from: view, in: RenderProposal(columns: 5))?.lines == ["A    "])

    dispatchClick(to: runtime, column: 5, row: 1)

    #expect(tapProbe.events == ["tap"])
}

private struct FocusedDirectNavigationLinkView: View {

    @FocusState var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            NavigationLink("Open") {
                Text("Detail")
            }
            .focused($isFocused)
        }
    }
}

private struct FocusedValueNavigationLinkView: View {

    @FocusState var isFocused: Bool = true

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            NavigationLink("One", value: 1)
                .focused($isFocused)
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

private struct ValueNavigationPathView: View {

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

private struct HeterogeneousNavigationPathView: View {

    let path: Binding<NavigationPath>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(for: Int.self) { value in
                    Text("Int \(value)")
                }
                .navigationDestination(for: String.self) { value in
                    Text("String \(value)")
                }
        }
    }
}

private struct NilValueNavigationLinkView: View {

    @FocusState var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            NavigationLink("Missing", value: Optional<Int>.none)
                .focused($isFocused)
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

private struct NavigationStateMutationView: View {

    @State var status = "empty"

    @FocusState var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                NavigationLink("Open") {
                    NavigationStateMutationDestination(status: $status)
                }
                .focused($isFocused)

                Text(status)
            }
        }
    }
}

private struct NavigationStateMutationDestination: View {

    let status: Binding<String>

    var body: some View {
        Text("Destination \(status.wrappedValue)")
            .onTapGesture {
                status.wrappedValue = "updated"
            }
    }
}

private struct NavigationDestinationStateResetView: View {

    @FocusState var isFocused: Bool = true

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            NavigationLink("Open", value: 1)
                .focused($isFocused)
                .navigationDestination(for: Int.self) { value in
                    NavigationStatefulDestination(value: value)
                }
        }
    }
}

private struct NavigationStatefulDestination: View {

    let value: Int

    @State var count = 0

    var body: some View {
        Text("Value \(value) count \(count)")
            .onTapGesture {
                count += 1
            }
    }
}

private struct NavigationPushValueView: View {

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            NavigationPushValueButton()
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

private struct NavigationPushValueButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push(1)
                return .handled
            }
    }
}

private enum NavigationPushDestination: Codable, Hashable, Sendable {

    case detail
}

private struct NavigationPushChildRootDestinationView: View {

    let path: Binding<[NavigationPushDestination]>

    var body: some View {
        NavigationStack(path: path) {
            NavigationPushChildButton()
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("Detail")
                    }
                }
        }
    }
}

private struct NavigationPushChildButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Button {
            push(NavigationPushDestination.detail)
        } label: {
            Text("Push")
        }
        .focused($isFocused)
    }
}

@Observable
private final class NavigationPushObservablePathModel {

    var path: [NavigationPushDestination] = []
}

private struct NavigationPushObservableObjectPathView: View {

    @State private var model = NavigationPushObservablePathModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            NavigationPushChildButton()
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("Detail")
                    }
                }
        }
    }
}

private struct NavigationPushInitializedObservableObjectPathRootView: View {

    @State private var route = true

    var body: some View {
        Group {
            if route {
                NavigationPushInitializedObservableObjectPathView(
                    model: NavigationPushObservablePathModel()
                )
            }
        }
    }
}

private struct NavigationPushInitializedObservableObjectPathView: View {

    @State private var model: NavigationPushObservablePathModel

    init(model: NavigationPushObservablePathModel) {
        self._model = State(wrappedValue: model)
    }

    var body: some View {
        NavigationStack(path: navigationPath) {
            NavigationPushChildButton()
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("Detail")
                    }
                }
        }
    }

    private var navigationPath: Binding<[NavigationPushDestination]> {
        Binding(
            get: {
                model.path
            },
            set: {
                model.path = $0
            }
        )
    }
}

private struct NavigationPushDirectDestinationView: View {

    var body: some View {
        NavigationStack {
            NavigationPushDirectDestinationButton()
        }
    }
}

private struct NavigationPushDirectDestinationButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    Text("Detail")
                }
                return .handled
            }
    }
}

private struct NavigationPushDirectStateMutationView: View {

    @State var status = "empty"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                NavigationPushDirectStateMutationButton(status: $status)
                Text(status)
            }
        }
    }
}

private struct NavigationPushDirectStateMutationButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    let status: Binding<String>

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationStateMutationDestination(status: status)
                }
                return .handled
            }
    }
}

private struct NavigationPushDirectStateResetView: View {

    var body: some View {
        NavigationStack {
            NavigationPushDirectStateResetButton()
        }
    }
}

private struct NavigationPushDirectStateResetButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationPoppableStatefulDestination()
                }
                return .handled
            }
    }
}

private struct NavigationPoppableStatefulDestination: View {

    @Environment(\.pop) private var pop

    @State var count = 0

    var body: some View {
        VStack(alignment: .leading) {
            Text("Value count \(count)")
                .onTapGesture {
                    count += 1
                }

            Text("Back")
                .onTapGesture {
                    pop()
                }
        }
    }
}

private struct NavigationPopValueView: View {

    @Environment(\.pop) private var pop

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .onTapGesture {
                    pop()
                }
                .navigationDestination(for: Int.self) { value in
                    NavigationPopValueDestination(value: value)
                }
        }
    }
}

private struct NavigationPopValueDestination: View {

    @Environment(\.pop) private var pop

    let value: Int

    var body: some View {
        Text("Value \(value)")
            .onTapGesture {
                pop()
            }
    }
}

private struct NavigationPresentedBoolView: View {

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    Text("Presented")
                }
        }
    }
}

private struct NavigationPresentedBoolStateGlobalKeyView: View {

    @State
    private var isPresented = false

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: $isPresented) {
                    Text("Presented")
                }
                .onGlobalKeyPress("a") {
                    isPresented = true
                    return .handled
                }
        }
    }
}

private struct NavigationPresentedBoolStateCharacterGlobalKeyOnAppearView: View {

    @State
    private var didAppear = false

    @State
    private var isPresented = false

    var body: some View {
        NavigationStack {
            Text(didAppear ? "Root appeared" : "Root")
                .navigationDestination(isPresented: $isPresented) {
                    Text("Presented")
                }
                .onAppear {
                    didAppear = true
                }
                .onGlobalKeyPress(characters: .init(charactersIn: "a")) {
                    _ in

                    isPresented = true
                    return .handled
                }
        }
    }
}

private struct NavigationPresentedBoolStateDirectDestinationView: View {

    @FocusState
    private var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            NavigationLink("Open") {
                NavigationPresentedBoolStateDirectDestinationDetailView()
            }
            .focusable()
            .focused($isFocused)
        }
    }
}

private struct NavigationPresentedBoolStateDirectDestinationDetailView: View {

    @State
    private var isPresented = false

    var body: some View {
        Text("Detail")
            .navigationDestination(isPresented: $isPresented) {
                Text("Presented")
            }
            .onGlobalKeyPress(characters: .init(charactersIn: "a")) {
                _ in

                isPresented = true
                return .handled
            }
    }
}

private struct NavigationPresentedBoolStateDirectDestinationInputView: View {

    let probe: KeyPressProbe

    @FocusState
    private var isFocused: Bool = true

    var body: some View {
        NavigationStack {
            NavigationLink("Open") {
                NavigationPresentedBoolStateDirectDestinationInputDetailView(probe: probe)
            }
            .focusable()
            .focused($isFocused)
        }
    }
}

private struct NavigationPresentedBoolStateDirectDestinationInputDetailView: View {

    let probe: KeyPressProbe

    @State
    private var isPresented = false

    var body: some View {
        Text("Detail")
            .navigationDestination(isPresented: $isPresented) {
                NavigationPresentedBoolStateDirectDestinationInputPresentedView(probe: probe)
            }
            .onGlobalKeyPress(characters: .init(charactersIn: "a")) {
                _ in

                isPresented = true
                return .handled
            }
    }
}

private struct NavigationPresentedBoolStateDirectDestinationInputPresentedView: View {

    let probe: KeyPressProbe

    @FocusState
    private var isFocused: Bool = true

    @State
    private var wasActivated = false

    var body: some View {
        Button(wasActivated ? "Activated" : "Activate") {
            probe.record("activated")
            wasActivated = true
        }
        .focused($isFocused)
    }
}

private struct NavigationPresentedItemView: View {

    let item: Binding<Int?>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(item: item) { value in
                    Text("Item \(value)")
                }
        }
    }
}

private struct NavigationPresentedItemStateResetView: View {

    let item: Binding<Int?>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(item: item) { value in
                    NavigationStatefulDestination(value: value)
                }
        }
    }
}

private struct NavigationPresentedPopActionView: View {

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationPresentedPopDestination()
                }
        }
    }
}

private struct NavigationPresentedPopDestination: View {

    @Environment(\.pop) private var pop

    var body: some View {
        Text("Back")
            .onTapGesture {
                pop()
            }
    }
}

private struct NavigationParentCapturedDismissActionView: View {

    @Environment(\.dismiss) private var dismiss

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationPassedDismissActionDestination(dismiss: dismiss)
                }
        }
    }
}

private struct NavigationPassedDismissActionDestination: View {

    let dismiss: DismissAction

    var body: some View {
        Text("Close")
            .onTapGesture {
                dismiss()
            }
    }
}

private struct NavigationPresentedDismissActionView: View {

    let isPresented: Binding<Bool>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationDismissActionDestination(label: "Close")
                }
        }
    }
}

private struct NavigationItemDismissActionView: View {

    let item: Binding<Int?>

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(item: item) { value in
                    NavigationDismissActionDestination(label: "Item \(value)")
                }
        }
    }
}

private struct NavigationDismissValueView: View {

    let path: Binding<[Int]>

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(for: Int.self) { value in
                    NavigationDismissActionDestination(label: "Value \(value)")
                }
        }
    }
}

private struct NavigationPushDirectDismissActionView: View {

    var body: some View {
        NavigationStack {
            NavigationPushDirectDismissActionButton()
        }
    }
}

private struct NavigationPushDirectDismissActionButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationDismissActionDestination(label: "Close")
                }
                return .handled
            }
    }
}

private struct NavigationPushCapturedDirectActionView: View {

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack {
            NavigationPushCapturedDirectActionButton(probe: probe)
        }
    }
}

private struct NavigationPushCapturedDirectActionButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    let probe: NavigationActionProbe

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    CapturedNavigationActionsView(probe: probe)
                }
                return .handled
            }
    }
}

private struct NavigationCapturedValueDismissActionView: View {

    let path: Binding<[Int]>

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack(path: path) {
            NavigationPushValueButton()
                .navigationDestination(for: Int.self) { _ in
                    CapturedNavigationActionsView(probe: probe)
                }
        }
    }
}

private struct NavigationPushDirectWithPresentedActionView: View {

    let isPresented: Binding<Bool>

    let directProbe: NavigationActionProbe

    let presentedProbe: NavigationActionProbe

    var body: some View {
        NavigationStack {
            NavigationPushDirectWithPresentedActionButton(
                isPresented: isPresented,
                directProbe: directProbe,
                presentedProbe: presentedProbe
            )
        }
    }
}

private struct NavigationPushDirectWithPresentedActionButton: View {

    @Environment(\.push) private var push

    @FocusState var isFocused: Bool = true

    let isPresented: Binding<Bool>

    let directProbe: NavigationActionProbe

    let presentedProbe: NavigationActionProbe

    var body: some View {
        Text("Push")
            .focusable()
            .focused($isFocused)
            .onKeyPress(.return) {
                push {
                    NavigationDirectWithPresentedActionDestination(
                        isPresented: isPresented,
                        directProbe: directProbe,
                        presentedProbe: presentedProbe
                    )
                }
                return .handled
            }
    }
}

private struct NavigationDirectWithPresentedActionDestination: View {

    let isPresented: Binding<Bool>

    let directProbe: NavigationActionProbe

    let presentedProbe: NavigationActionProbe

    var body: some View {
        CapturedNavigationActionsView(probe: directProbe)
            .navigationDestination(isPresented: isPresented) {
                CapturedNavigationActionsView(probe: presentedProbe)
            }
    }
}

private struct NavigationRootDismissActionView: View {

    var body: some View {
        NavigationStack {
            NavigationDismissActionDestination(label: "Dismiss")
        }
    }
}

private struct NavigationCapturedPresentedDismissActionView: View {

    let isPresented: Binding<Bool>

    let probe: DismissActionProbe

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    NavigationCapturedDismissActionDestination(probe: probe)
                }
        }
    }
}

private struct NavigationCapturedPresentedNavigationActionsView: View {

    let isPresented: Binding<Bool>

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    CapturedNavigationActionsView(probe: probe)
                }
        }
    }
}

private struct NavigationCapturedPresentedNavigationPathActionsView: View {

    let isPresented: Binding<Bool>

    let path: Binding<[Int]>

    let probe: NavigationActionProbe

    var body: some View {
        NavigationStack(path: path) {
            Text("Root")
                .navigationDestination(isPresented: isPresented) {
                    CapturedNavigationActionsView(probe: probe)
                }
                .navigationDestination(for: Int.self) { value in
                    Text("Value \(value)")
                }
        }
    }
}

private struct NavigationCapturedDismissActionDestination: View {

    @Environment(\.dismiss) private var dismiss

    let probe: DismissActionProbe

    var body: some View {
        CapturedDismissAction(dismiss: dismiss, probe: probe)
    }
}

private struct CapturedDismissAction: View {

    init(dismiss: DismissAction, probe: DismissActionProbe) {
        probe.capture(dismiss)
    }

    var body: some View {
        NavigationDismissActionDestination(label: "Close")
    }
}

private struct NavigationDismissActionDestination: View {

    @Environment(\.dismiss) private var dismiss

    let label: String

    var body: some View {
        Text(label)
            .onTapGesture {
                dismiss()
            }
    }
}

private final class DismissActionProbe {

    var dismiss: DismissAction?

    func capture(_ dismiss: DismissAction) {
        self.dismiss = dismiss
    }
}

private final class NavigationActionProbe {

    var push: PushAction?

    var pop: PopAction?

    var dismiss: DismissAction?

    func capture(push: PushAction, pop: PopAction, dismiss: DismissAction) {
        self.push = push
        self.pop = pop
        self.dismiss = dismiss
    }
}

private struct CapturedNavigationActionsView: View {

    @Environment(\.push) private var push

    @Environment(\.pop) private var pop

    @Environment(\.dismiss) private var dismiss

    let probe: NavigationActionProbe

    var body: some View {
        CapturedNavigationActions(push: push, pop: pop, dismiss: dismiss, probe: probe)
    }
}

private struct CapturedNavigationActions: View {

    init(push: PushAction, pop: PopAction, dismiss: DismissAction, probe: NavigationActionProbe) {
        probe.capture(push: push, pop: pop, dismiss: dismiss)
    }

    var body: some View {
        Text("A")
    }
}

private final class BindingProbe<Value> {

    var binding: Binding<Value>?

    func capture(_ binding: Binding<Value>) {
        self.binding = binding
    }
}

private final class LabeledBindingProbe {

    var bindings: [String: Binding<Int>] = [:]

    func capture(_ binding: Binding<Int>, label: String) {
        bindings[label] = binding
    }
}

private final class LabeledStringBindingProbe {

    var bindings: [String: Binding<String>] = [:]

    func capture(_ binding: Binding<String>, label: String) {
        bindings[label] = binding
    }
}

private final class ObjectProbe<ObjectType: AnyObject> {

    var object: ObjectType?

    func capture(_ object: ObjectType) {
        self.object = object
    }
}

private final class ObjectCreationProbe {

    private(set) var createdIDs: [Int] = []

    func nextID() -> Int {
        let id = createdIDs.count + 1
        createdIDs.append(id)
        return id
    }
}

@Observable private final class TestObservableModel {

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

private final class FocusBindingProbe<Value: Hashable> {

    var binding: FocusState<Value>.Binding?

    func capture(_ binding: FocusState<Value>.Binding) {
        self.binding = binding
    }
}

private final class KeyPressProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private final class TapGestureProbe {

    var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private final class HoverProbe {

    var events: [String] = []

    var phases: [HoverPhase] = []

    func record(_ event: String) {
        events.append(event)
    }

    func record(_ phase: HoverPhase) {
        phases.append(phase)
    }
}

private struct TapLocationEvent: Equatable {

    var name: String

    var location: Point
}

private final class TapLocationProbe {

    var events: [TapLocationEvent] = []

    func record(_ name: String, _ location: Point) {
        events.append(TapLocationEvent(name: name, location: location))
    }
}

private final class LifecycleProbe {

    var events: [String] = []
}

@MainActor
private final class AsyncTaskProbe {

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

private final class TerminateActionProbe {

    var action: TerminateAction?

    func capture(_ action: TerminateAction) {
        self.action = action
    }
}

private struct ForEachTestItem: Identifiable {

    let id: String

    let label: String
}

private struct TestMarkerKey: EnvironmentKey {

    nonisolated static let defaultValue = "default"
}

private extension EnvironmentValues {

    var testMarker: String {
        get {
            self[TestMarkerKey.self]
        }
        set {
            self[TestMarkerKey.self] = newValue
        }
    }
}

private struct EnvironmentMarkerText: View {

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text(marker)
    }
}

private struct TypedEnvironmentObjectMarkerText: View {

    @Environment(TestObservableModel.self) private var model

    let objectProbe: ObjectProbe<TestObservableModel>?

    init(objectProbe: ObjectProbe<TestObservableModel>? = nil) {
        self.objectProbe = objectProbe
    }

    var body: some View {
        CapturedTypedEnvironmentObjectMarker(
            model: model,
            objectProbe: objectProbe
        )
    }
}

private struct CapturedTypedEnvironmentObjectMarker: View {

    let model: TestObservableModel

    init(
        model: TestObservableModel,
        objectProbe: ObjectProbe<TestObservableModel>?
    ) {
        self.model = model
        objectProbe?.capture(model)
    }

    var body: some View {
        Text("\(model.count)")
    }
}

private struct OptionalTypedEnvironmentObjectMarkerText: View {

    @Environment(TestObservableModel.self) private var model: TestObservableModel?

    let objectProbe: ObjectProbe<TestObservableModel>?

    init(objectProbe: ObjectProbe<TestObservableModel>? = nil) {
        self.objectProbe = objectProbe
    }

    var body: some View {
        CapturedOptionalTypedEnvironmentObjectMarker(
            model: model,
            objectProbe: objectProbe
        )
    }
}

private struct CapturedOptionalTypedEnvironmentObjectMarker: View {

    let model: TestObservableModel?

    init(
        model: TestObservableModel?,
        objectProbe: ObjectProbe<TestObservableModel>?
    ) {
        self.model = model
        if let model {
            objectProbe?.capture(model)
        }
    }

    var body: some View {
        Text(model.map { "\($0.count)" } ?? "nil")
    }
}

private struct TypedAndKeyPathEnvironmentMarkerText: View {

    @Environment(\.testMarker) private var marker

    @Environment(TestObservableModel.self) private var model

    var body: some View {
        Text("\(marker):\(model.count)")
    }
}

private struct TypedEnvironmentObjectProjectionMarkerText: View {

    @Environment(TestObservableModel.self) private var model

    let bindingProbe: BindingProbe<String>

    let objectProbe: ObjectProbe<TestObservableModel>

    var body: some View {
        CapturedTypedEnvironmentObjectProjectionMarker(
            text: $model.token,
            model: model,
            bindingProbe: bindingProbe,
            objectProbe: objectProbe
        )
    }
}

private struct CapturedTypedEnvironmentObjectProjectionMarker: View {

    let text: Binding<String>

    init(
        text: Binding<String>,
        model: TestObservableModel,
        bindingProbe: BindingProbe<String>,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        self.text = text
        bindingProbe.capture(text)
        objectProbe.capture(model)
    }

    var body: some View {
        Text(text.wrappedValue)
    }
}

private struct TypedEnvironmentTextFieldRootView: View {

    @State private var model: TestObservableModel

    let objectProbe: ObjectProbe<TestObservableModel>

    init(initialToken: String, objectProbe: ObjectProbe<TestObservableModel>) {
        _model = State(wrappedValue: TestObservableModel(token: initialToken))
        self.objectProbe = objectProbe
    }

    var body: some View {
        TypedEnvironmentTextField(objectProbe: objectProbe)
            .environment(model)
    }
}

private struct TypedEnvironmentTextField: View {

    @Environment(TestObservableModel.self) private var model

    @FocusState private var isFocused = true

    let objectProbe: ObjectProbe<TestObservableModel>

    var body: some View {
        CapturedTypedEnvironmentTextField(
            text: $model.token,
            model: model,
            focus: $isFocused,
            objectProbe: objectProbe
        )
    }
}

private struct CapturedTypedEnvironmentTextField: View {

    let text: Binding<String>

    let focus: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        model: TestObservableModel,
        focus: FocusState<Bool>.Binding,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        self.text = text
        self.focus = focus
        objectProbe.capture(model)
    }

    var body: some View {
        TextField("Token", text: text)
            .focused(focus)
    }
}

private struct ButtonSizingMarkerText: View {

    @Environment(\.buttonSizing) private var sizing

    var body: some View {
        if sizing == .flexible {
            Text("flexible")
        }
        else if sizing == .fitted {
            Text("fitted")
        }
        else {
            Text("automatic")
        }
    }
}

private struct IsEnabledMarkerText: View {

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Text(isEnabled ? "enabled" : "disabled")
    }
}

private struct EnvironmentStateMarkerView: View {

    @State var marker = "initial"

    let probe: BindingProbe<String>

    var body: some View {
        EnvironmentMarkerProbe(
            binding: $marker,
            probe: probe
        )
        .environment(\.testMarker, marker)
    }
}

private struct ParentCapturedEnvironmentMarkerView: View {

    @Environment(\.testMarker) private var marker

    var body: some View {
        CapturedEnvironmentMarkerText(capturedMarker: marker)
            .environment(\.testMarker, "child")
    }
}

private struct CapturedEnvironmentMarkerText: View {

    @Environment(\.testMarker) private var directMarker

    let capturedMarker: String

    var body: some View {
        Text("captured \(capturedMarker) direct \(directMarker)")
    }
}

private struct ConditionalLifecycleView: View {

    let isVisible: Bool

    let probe: LifecycleProbe

    var body: some View {
        VStack(alignment: .leading) {
            if isVisible {
                Text("A")
                    .onAppear {
                        probe.events.append("appear")
                    }
                    .onDisappear {
                        probe.events.append("disappear")
                    }
            }
            Text("B")
        }
    }
}

private struct LifecycleAppearStateView: View {

    @State private var status = "initial"

    var body: some View {
        Text(status)
            .onAppear {
                status = "appeared"
            }
    }
}

private struct LifecycleDisappearStateView: View {

    let isVisible: Bool

    @State private var status = "visible"

    var body: some View {
        VStack(alignment: .leading) {
            Text(status)
            if isVisible {
                Text("child")
                    .onDisappear {
                        status = "gone"
                    }
            }
        }
    }
}

private struct EnvironmentLifecycleView: View {

    let probe: LifecycleProbe

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text("marker")
            .onAppear {
                probe.events.append(marker)
            }
    }
}

private struct IdentifiedTaskView: View {

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

private struct ExplicitIDCounterHost: View {

    let id: Int

    var body: some View {
        ExplicitIDCounter()
            .id(id)
    }
}

private struct ExplicitIDCounter: View {

    @State private var count = 0

    var body: some View {
        Text("\(count)")
            .onTapGesture {
                count += 1
            }
    }
}

private struct ExplicitIDScrollHost: View {

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

private struct ReaderScrollToBottomView: View {

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

private struct ReaderAnchorScrollView: View {

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

private struct ReaderBindingScrollView: View {

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

private struct ReaderHorizontalScrollView: View {

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

private struct ReaderTwoAxisScrollView: View {

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

private struct ReaderMissingIDView: View {

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

private struct ReaderOutOfScopeView: View {

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

private struct ConditionalTaskView: View {

    let isVisible: Bool

    let probe: AsyncTaskProbe

    var body: some View {
        if isVisible {
            Text("A")
                .task {
                    probe.record("start")
                    do {
                        try await Task.sleep(nanoseconds: 60_000_000_000)
                    }
                    catch {
                        probe.record("cancel")
                    }
                }
        }
    }
}

private struct TaskStateMutationView: View {

    let probe: AsyncTaskProbe

    @State private var status = "idle"

    var body: some View {
        Text(status)
            .task {
                await Task.yield()
                status = "done"
                probe.record("done")
            }
    }
}

private struct LifecycleItem: Identifiable, Equatable {

    let id: String

    var label: String
}

private struct ForEachLifecycleView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            Text(item.label)
                .onAppear {
                    probe.events.append("appear \(item.id)")
                }
                .onDisappear {
                    probe.events.append("disappear \(item.id)")
                }
        }
    }
}

private struct StatefulForEachLifecycleView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            StatefulLifecycleRow(item: item, probe: probe)
        }
    }
}

private struct StatefulLifecycleRow: View {

    let item: LifecycleItem

    let probe: LifecycleProbe

    @State private var status = "fresh"

    var body: some View {
        Text("\(item.label):\(status)")
            .onAppear {
                status = "active"
            }
            .onDisappear {
                probe.events.append("disappear \(item.label):\(status)")
            }
    }
}

private struct StackedLifecycleView: View {

    let isVisible: Bool

    let probe: LifecycleProbe

    var body: some View {
        VStack(alignment: .leading) {
            if isVisible {
                Text("A")
                    .onAppear {
                        probe.events.append("inner appear")
                    }
                    .onDisappear {
                        probe.events.append("inner disappear")
                    }
                    .onAppear {
                        probe.events.append("outer appear")
                    }
                    .onDisappear {
                        probe.events.append("outer disappear")
                    }
            }
        }
    }
}

private struct OnChangeValueView: View {

    let value: Int

    var initial = false

    let probe: LifecycleProbe

    var body: some View {
        Text("\(value)")
            .onChange(of: value, initial: initial) {
                probe.events.append("changed \(value)")
            }
    }
}

private struct OnChangePairValueView: View {

    let value: Int

    var initial = false

    let probe: LifecycleProbe

    var body: some View {
        Text("\(value)")
            .onChange(of: value, initial: initial) { oldValue, newValue in
                probe.events.append("changed \(oldValue) -> \(newValue)")
            }
    }
}

private struct OnChangeStateMutationView: View {

    let value: Int

    @State private var status = "idle"

    var body: some View {
        Text(status)
            .onChange(of: value) {
                status = "changed"
            }
    }
}

private struct OnChangePairStateMutationView: View {

    let value: Int

    @State private var status = "idle"

    var body: some View {
        Text(status)
            .onChange(of: value) { oldValue, newValue in
                status = "\(oldValue) -> \(newValue)"
            }
    }
}

private struct OnChangeEnvironmentView: View {

    let value: Int

    let probe: LifecycleProbe

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text("marker")
            .onChange(of: value) {
                probe.events.append(marker)
            }
    }
}

private struct OnChangePairEnvironmentView: View {

    let value: Int

    let probe: LifecycleProbe

    @Environment(\.testMarker) private var marker

    var body: some View {
        Text("marker")
            .onChange(of: value) { oldValue, newValue in
                probe.events.append("\(marker) \(oldValue) -> \(newValue)")
            }
    }
}

private struct ConditionalOnChangeView: View {

    let isVisible: Bool

    let value: Int

    let probe: LifecycleProbe

    var body: some View {
        if isVisible {
            Text("A")
                .onChange(of: value, initial: true) {
                    probe.events.append("changed \(value)")
                }
        }
    }
}

private struct ConditionalOnChangePairView: View {

    let isVisible: Bool

    let value: Int

    let probe: LifecycleProbe

    var body: some View {
        if isVisible {
            Text("A")
                .onChange(of: value, initial: true) { oldValue, newValue in
                    probe.events.append("changed \(oldValue) -> \(newValue)")
                }
        }
    }
}

private struct ForEachOnChangeView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            Text(item.label)
                .onChange(of: item.label) {
                    probe.events.append("changed \(item.id)")
                }
        }
    }
}

private struct ForEachOnChangePairView: View {

    let items: [LifecycleItem]

    let probe: LifecycleProbe

    var body: some View {
        ForEach(items) { item in
            Text(item.label)
                .onChange(of: item.label) { _, _ in
                    probe.events.append("changed \(item.id)")
                }
        }
    }
}

private struct EnvironmentMarkerProbe: View {

    init(binding: Binding<String>, probe: BindingProbe<String>) {
        probe.capture(binding)
    }

    var body: some View {
        EnvironmentMarkerText()
    }
}

private struct TerminateStatusView: View {

    @State var status = "running"

    var body: some View {
        Text(status)
            .onTerminate {
                status = "interrupted"
            }
    }
}

@Observable
private final class ObservableTerminateNavigationModel {

    var path: [NavigationPushDestination] = []
}

private struct ObservableTerminateNavigationView: View {

    @State private var model = ObservableTerminateNavigationModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            Text("main")
                .navigationDestination(for: NavigationPushDestination.self) { destination in
                    switch destination {
                    case .detail:
                        Text("confirm quit")
                    }
                }
        }
        .onTerminate {
            model.path.append(.detail)
        }
    }
}

private struct EnvironmentBackedTerminateView: View {

    @Environment(\.terminate) private var terminate

    var body: some View {
        Text("A")
            .onTerminate {
                terminate()
            }
    }
}

private struct CapturedTerminateActionView: View {

    @Environment(\.terminate) private var terminate

    let probe: TerminateActionProbe

    var body: some View {
        CapturedTerminateAction(action: terminate, probe: probe)
    }
}

private struct CapturedTerminateAction: View {

    init(action: TerminateAction, probe: TerminateActionProbe) {
        probe.capture(action)
    }

    var body: some View {
        Text("A")
    }
}

private struct ForEachStateView: View {

    let items: [ForEachTestItem]

    let probe: LabeledBindingProbe

    var body: some View {
        ForEach(items, id: \.id) { item in
            LabeledChildCounterView(label: item.id, probe: probe)
        }
    }
}

private struct ForEachTapView: View {

    let items: [ForEachTestItem]

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(items, id: \.id) { item in
                Text(item.label)
                    .onTapGesture {
                        tapProbe.record(item.id)
                    }
            }
        }
    }
}

private struct ForEachButtonView: View {

    let items: [ForEachTestItem]

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(items, id: \.id) { item in
                Button(action: {
                    tapProbe.record(item.id)
                }) {
                    Text(item.label)
                }
            }
        }
    }
}

private struct FocusedButtonView: View {

    @FocusState var isFocused: Bool = true

    let tapProbe: TapGestureProbe

    var body: some View {
        Button("Go") {
            tapProbe.record("go")
        }
        .focused($isFocused)
    }
}

private struct DisabledFocusedButtonView: View {

    @FocusState var isFocused: Bool = true

    let focusProbe: FocusBindingProbe<Bool>

    let tapProbe: TapGestureProbe

    var body: some View {
        CapturedFocusedButton(
            focus: $isFocused,
            focusProbe: focusProbe,
            tapProbe: tapProbe
        )
        .disabled(true)
    }
}

private struct CapturedFocusedButton: View {

    let focus: FocusState<Bool>.Binding

    let tapProbe: TapGestureProbe

    init(
        focus: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        tapProbe: TapGestureProbe
    ) {
        self.focus = focus
        self.tapProbe = tapProbe
        focusProbe.capture(focus)
    }

    var body: some View {
        Button("Run") {
            tapProbe.record("run")
        }
        .focused(focus)
    }
}

private struct ButtonStateMutationView: View {

    @State var count = 0

    var body: some View {
        Button(action: {
            count += 1
        }) {
            Text("\(count)")
        }
    }
}

private struct ButtonEnvironmentActionView: View {

    @FocusState var isFocused: Bool = true

    @Environment(\.testMarker) private var marker

    let tapProbe: TapGestureProbe

    var body: some View {
        Button("Read") {
            tapProbe.record(marker)
        }
        .focused($isFocused)
    }
}

private extension RenderedBlock {

    var trimmedLines: [String] {
        lines.map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }
}

private func dispatchClick(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    at date: Date = Date(timeIntervalSinceReferenceDate: 1_000),
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .down),
            at: date
        ) == result
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: column, row: row, phase: .up),
            at: date
        ) == result
    )
}

private func dispatchWheel(
    to runtime: StateRuntime,
    button: MouseButton,
    column: Int,
    row: Int,
    modifiers: EventModifiers = [],
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            MouseEvent(
                button: button,
                column: column,
                row: row,
                modifiers: modifiers,
                phase: .down
            )
        ) == result
    )
}

private func dispatchHover(
    to runtime: StateRuntime,
    column: Int,
    row: Int,
    button: MouseButton = .other(3),
    expecting result: KeyPress.Result = .handled
) {
    #expect(
        runtime.dispatch(
            MouseEvent(button: button, column: column, row: row, phase: .motion)
        ) == result
    )
}

private enum FocusField: Hashable {

    case first

    case second
}

private struct CapturedCounterText: View {

    let text: String

    init(_ value: Int, binding: Binding<Int>, probe: BindingProbe<Int>) {
        self.text = String(value)
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
    }
}

private struct LabeledCapturedCounterText: View {

    let text: String

    init(_ value: Int, binding: Binding<Int>, label: String, probe: LabeledBindingProbe) {
        self.text = String(value)
        probe.capture(binding, label: label)
    }

    var body: some View {
        Text(text)
    }
}

private struct RootCounterView: View {

    @State var count = 0

    let probe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(count, binding: $count, probe: probe)
    }
}

private struct ParentCounterView: View {

    let probe: BindingProbe<Int>

    var body: some View {
        ChildCounterView(probe: probe)
    }
}

private struct ChildCounterView: View {

    @State var count = 0

    let probe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(count, binding: $count, probe: probe)
    }
}

private struct SiblingCounterView: View {

    let probe: LabeledBindingProbe

    var body: some View {
        VStack {
            LabeledChildCounterView(label: "first", probe: probe)
            LabeledChildCounterView(label: "second", probe: probe)
        }
    }
}

private struct ConditionalBranchStateView: View {

    let usesFirstBranch: Bool

    let probe: LabeledBindingProbe

    var body: some View {
        if usesFirstBranch {
            LabeledChildCounterView(label: "first", probe: probe)
        }
        else {
            LabeledChildCounterView(label: "second", probe: probe)
        }
    }
}

private struct LabeledChildCounterView: View {

    @State var count = 0

    let label: String

    let probe: LabeledBindingProbe

    var body: some View {
        LabeledCapturedCounterText(
            count,
            binding: $count,
            label: label,
            probe: probe
        )
    }
}

private struct StateObservableCounterView: View {

    @State private var model: TestObservableModel

    let objectProbe: ObjectProbe<TestObservableModel>

    init(
        initialCount: Int,
        creationProbe: ObjectCreationProbe,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        _model = State(
            wrappedValue: TestObservableModel(
                count: initialCount,
                creationProbe: creationProbe
            )
        )
        self.objectProbe = objectProbe
    }

    var body: some View {
        CapturedObservableCounterText(
            model: model,
            objectProbe: objectProbe
        )
    }
}

private struct BindableCounterView: View {

    @Bindable var model: TestObservableModel

    let bindingProbe: BindingProbe<Int>

    var body: some View {
        CapturedCounterText(model.count, binding: $model.count, probe: bindingProbe)
    }
}

private struct ConditionalObservableCounterView: View {

    let first: TestObservableModel

    let second: TestObservableModel

    let usesFirst: Bool

    var body: some View {
        if usesFirst {
            Text("\(first.count)")
        }
        else {
            Text("\(second.count)")
        }
    }
}

private struct ForEachStateObservableView: View {

    let items: [ForEachTestItem]

    let creationProbe: ObjectCreationProbe

    var body: some View {
        ForEach(items, id: \.id) { item in
            StateObservableRow(label: item.label, creationProbe: creationProbe)
        }
    }
}

private struct StateObservableRow: View {

    @State private var model: TestObservableModel

    let label: String

    init(label: String, creationProbe: ObjectCreationProbe) {
        _model = State(
            wrappedValue: TestObservableModel(creationProbe: creationProbe)
        )
        self.label = label
    }

    var body: some View {
        Text("\(model.id)")
    }
}

private struct CapturedObservableCounterText: View {

    let text: String

    init(
        model: TestObservableModel,
        objectProbe: ObjectProbe<TestObservableModel>
    ) {
        self.text = String(model.count)
        objectProbe.capture(model)
    }

    var body: some View {
        Text(text)
    }
}

private struct BoolFocusableThenFocusedView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusableThenFocusedText(binding: $isFocused, probe: probe)
    }
}

private struct ClickableFocusedTextView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFocusableText(binding: $isFocused, probe: probe)
    }
}

private struct PaddedFramedClickFocusView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("top")
            CapturedFocusableText(binding: $isFocused, probe: probe)
                .padding(.leading, 1)
                .frame(width: 3, alignment: .leading)
        }
    }
}

private struct RetortFediLikeConfigurationScreen: View {

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Title")
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading) {
                    TextField("Name", text: $text)
                    Text("Row2")
                    Text("Row3")
                    Text("Row4")
                    Text("Row5")
                }
            }
            Text("Desc")
                .lineLimit(3)
            Spacer()
            HStack {
                Text("Footer")
                Spacer()
            }
        }
    }
}

private enum GeometryReaderRoute {

    case menu

    case configuration
}

private struct GeometryReaderRouteHost: View {

    @State private var route = GeometryReaderRoute.menu

    @FocusState private var menuFocused = true

    var body: some View {
        switch route {
        case .menu:
            Text("Menu")
                .focusable()
                .focused($menuFocused)
                .onKeyPress(.return) {
                    route = .configuration
                    return .handled
                }
        case .configuration:
            GeometryReaderRouteConfigurationScreen()
        }
    }
}

private struct GeometryReaderRouteConfigurationScreen: View {

    @State private var selectedRow = 0

    @FocusState private var focusedRow: Int?

    var body: some View {
        GeometryReader { proxy in
            let listRows = max(proxy.rows - 3, 1)

            VStack(alignment: .leading) {
                Text("Size \(proxy.columns)x\(proxy.rows)")
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(0..<6) { row in
                            GeometryReaderRouteRow(
                                row: row,
                                isSelected: row == selectedRow,
                                focusedRow: $focusedRow
                            )
                        }
                    }
                }
                .frame(height: listRows)
                Text("Desc")
                Text("Footer")
            }
            .onAppear {
                focusedRow = selectedRow
            }
            .onKeyPress(.downArrow) {
                selectedRow = min(selectedRow + 1, 5)
                focusedRow = selectedRow
                return .handled
            }
        }
    }
}

private struct GeometryReaderRouteRow: View {

    let row: Int

    let isSelected: Bool

    let focusedRow: FocusState<Int?>.Binding

    var body: some View {
        Text("\(isSelected ? ">" : " ") Row\(row)")
            .focusable()
            .focused(focusedRow, equals: row)
            .onKeyPress(.downArrow) {
                .ignored
            }
    }
}

private struct ScrolledClickFocusView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("A")
                CapturedFocusableText(binding: $isFocused, probe: probe, text: "B")
            }
        }
        .scrollPosition(.constant(ScrollPosition(y: 1)))
        .frame(width: 1, height: 1)
    }
}

private struct ScrollWrappedTextFieldsClickFocusView: View {

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                TextField("Vertical", text: .constant(""))
            }
            ScrollView(.horizontal) {
                TextField("Horizontal", text: .constant(""))
            }
        }
    }
}

private struct DisabledClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledClickFocusTextField(
            text: $text,
            binding: $isFocused,
            probe: probe
        )
    }
}

private struct CapturedDisabledClickFocusTextField: View {

    let text: Binding<String>

    let binding: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        binding: FocusState<Bool>.Binding,
        probe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        TextField("A", text: text)
            .focusable(false)
            .focused(binding)
    }
}

private struct ClickFocusTapGestureView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let tapProbe: TapGestureProbe

    var body: some View {
        CapturedFocusableText(binding: $isFocused, probe: focusProbe)
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onLongPressGesture {
                tapProbe.record("long")
            }
    }
}

private struct CapturedFocusableText: View {

    let binding: FocusState<Bool>.Binding

    let text: String

    init(
        binding: FocusState<Bool>.Binding,
        probe: FocusBindingProbe<Bool>,
        text: String = "A"
    ) {
        self.binding = binding
        self.text = text
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(binding)
    }
}

private struct FocusedScrollWheelView: View {

    @FocusState var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("focus")
                .focusable()
                .focused($isFocused)
            ScrollView {
                VStack {
                    Text("A")
                    Text("B")
                    Text("C")
                }
            }
            .frame(width: 1, height: 2)
        }
    }
}

private struct BoolFocusedThenFocusableView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusedThenFocusableText(binding: $isFocused, probe: probe)
    }
}

private struct BoolFocusedOnlyView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusedOnlyText(binding: $isFocused, probe: probe)
    }
}

private struct ClickableFocusedOnlyTextView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedBoolFocusedOnlyText(binding: $isFocused, probe: probe)
    }
}

private struct OptionalFocusedOnlyView: View {

    @FocusState var field: FocusField?

    let probe: FocusBindingProbe<FocusField?>

    var body: some View {
        CapturedOptionalFocusedOnlyText(
            binding: $field,
            value: .first,
            probe: probe
        )
    }
}

private struct DisabledFocusableView: View {

    @FocusState var isFocused: Bool

    let probe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusableText(binding: $isFocused, probe: probe)
    }
}

private struct CapturedBoolFocusableThenFocusedText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(binding)
    }
}

private struct CapturedBoolFocusedThenFocusableText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focused(binding)
            .focusable()
    }
}

private struct CapturedBoolFocusedOnlyText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focused(binding)
    }
}

private struct CapturedOptionalFocusedOnlyText: View {

    let binding: FocusState<FocusField?>.Binding

    let value: FocusField

    init(
        binding: FocusState<FocusField?>.Binding,
        value: FocusField,
        probe: FocusBindingProbe<FocusField?>
    ) {
        self.binding = binding
        self.value = value
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focused(binding, equals: value)
    }
}

private struct CapturedDisabledFocusableText: View {

    let binding: FocusState<Bool>.Binding

    init(binding: FocusState<Bool>.Binding, probe: FocusBindingProbe<Bool>) {
        self.binding = binding
        probe.capture(binding)
    }

    var body: some View {
        Text("A")
            .focusable(false)
            .focused(binding)
    }
}

private struct FocusedKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    var body: some View {
        CapturedFocusedKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            result: result
        )
    }
}

private struct CapturedFocusedKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        result: KeyPress.Result
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.result = result
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("child")
                return result
            }
    }
}

private struct KeyPressStateMutationView: View {

    @State var count = 0

    @FocusState var isFocused = true

    var body: some View {
        Text(String(count))
            .focusable()
            .focused($isFocused)
            .onKeyPress("a") {
                count += 1
                return .handled
            }
    }
}

private struct ParentCallbackDirectStateMutationKeyPressView: View {

    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParentCallbackKeyPressChildView {
                message = "updated"
            }
            Text(message.isEmpty ? "empty" : message)
        }
    }
}

private struct ParentCallbackBindingMutationKeyPressView: View {

    @State private var message = ""

    var body: some View {
        let message = $message

        return VStack(alignment: .leading, spacing: 0) {
            ParentCallbackKeyPressChildView {
                message.wrappedValue = "updated"
            }
            Text(message.wrappedValue.isEmpty ? "empty" : message.wrappedValue)
        }
    }
}

private struct ParentCallbackKeyPressChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Press")
            .focusable()
            .onKeyPress(.return) {
                action()
                return .handled
            }
    }
}

private func focusParentCallbackKeyPressChild(in runtime: StateRuntime) {
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 0, phase: .down),
            at: date
        ) == .handled
    )
    #expect(
        runtime.dispatch(
            MouseEvent(button: .left, column: 1, row: 0, phase: .up),
            at: date
        ) == .ignored
    )
}

private func renderUntilStable<Content: View>(
    _ runtime: StateRuntime,
    view: Content,
    in proposal: RenderProposal? = nil,
    maximumPasses: Int = 8
) -> Int {
    for pass in 1...maximumPasses {
        _ = runtime.block(from: view, in: proposal)
        if !runtime.consumeInvalidation() {
            return pass
        }
    }

    return maximumPasses + 1
}

private struct DeferredParentStateMutationView: View {

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

private struct DeferredParentStateMutationWithExistingStringCellView: View {

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

private struct TapGestureStateMutationView: View {

    @State var count = 0

    var body: some View {
        Text(String(count))
            .onTapGesture {
                count += 1
            }
    }
}

private struct LongPressGestureStateMutationView: View {

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

private struct HoverGestureStateMutationView: View {

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

private struct ParentCallbackDirectStateMutationTapView: View {

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

private struct ParentCallbackDirectStateMutationLongPressView: View {

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

private struct ParentCallbackDirectStateMutationHoverView: View {

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

private struct ParentCallbackTapChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Tap")
            .onTapGesture {
                action()
            }
    }
}

private struct ParentCallbackLongPressChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Press")
            .onLongPressGesture(minimumDuration: 0.1) {
                action()
            }
    }
}

private struct ParentCallbackHoverChildView: View {

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

private struct StackTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack(alignment: .leading) {
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

private struct NestedTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        VStack {
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

private struct CountedTapGestureView: View {

    let tapProbe: TapGestureProbe

    var body: some View {
        Text("A")
            .onTapGesture(count: 1) {
                tapProbe.record("one")
            }
            .onTapGesture(count: 2) {
                tapProbe.record("two")
            }
            .onTapGesture(count: 3) {
                tapProbe.record("three")
            }
    }
}

private struct TextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextField("Name", text: $text)
            .focused($isFocused)
    }
}

private struct DisabledFocusedTextFieldView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusedTextField(
            text: $text,
            focus: $isFocused,
            textProbe: textProbe,
            focusProbe: focusProbe
        )
        .disabled(true)
    }
}

private struct CapturedDisabledFocusedTextField: View {

    let text: Binding<String>

    let focus: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        focus: FocusState<Bool>.Binding,
        textProbe: BindingProbe<String>,
        focusProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.focus = focus
        textProbe.capture(text)
        focusProbe.capture(focus)
    }

    var body: some View {
        TextField("Name", text: text)
            .focused(focus)
    }
}

private struct TextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
    }
}

private struct FramedTextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(width: 3, height: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

private struct MaxHeightFramedTextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(width: 3, alignment: .topLeading)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

private struct MaxHeightOnlyTextEditorEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

private struct MaxHeightOnlyTextEditorClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .frame(maxHeight: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

private struct MaxHeightConstantTextEditorBelowScrollViewView: View {

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    Text("")
                }
            }
            HStack {
                Box {
                    TextEditor(text: .constant(""))
                        .frame(maxHeight: 4)
                }
                Spacer()
            }
        }
    }
}

private struct FramedTextEditorInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .frame(width: 3, height: 2, alignment: .topLeading)
            .focused($isFocused)
    }
}

private struct TextEditorBelowScrollViewView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    Text("")
                }
            }
            Box {
                TextEditor(text: $text)
                    .focused($isFocused)
            }
        }
    }
}

private struct DisabledFocusedTextEditorView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedDisabledFocusedTextEditor(
            text: $text,
            focus: $isFocused,
            textProbe: textProbe,
            focusProbe: focusProbe
        )
        .disabled(true)
    }
}

private struct CapturedDisabledFocusedTextEditor: View {

    let text: Binding<String>

    let focus: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        focus: FocusState<Bool>.Binding,
        textProbe: BindingProbe<String>,
        focusProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.focus = focus
        textProbe.capture(text)
        focusProbe.capture(focus)
    }

    var body: some View {
        TextEditor(text: text)
            .focused(focus)
    }
}

private struct TextEditorInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
    }
}

private struct PrefixedBoundedTextEditorInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("top")
            TextEditor(text: $text)
                .focused($isFocused)
                .frame(width: 4, height: 2, alignment: .leading)
        }
    }
}

private struct TextEditorSubmitView: View {

    @State var text = ""

    @State var submitted = "none"

    @FocusState var isFocused = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $text)
                .focused($isFocused)
                .onSubmit {
                    submitted = text
                }
            Text(submitted)
        }
    }
}

private struct FramedTextEditorClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFramedTextEditor(
            text: $text,
            binding: $isFocused,
            focusProbe: focusProbe
        )
    }
}

private struct CapturedFramedTextEditor: View {

    let text: Binding<String>

    let binding: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        binding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.binding = binding
        focusProbe.capture(binding)
    }

    var body: some View {
        TextEditor(text: text)
            .frame(width: 5, height: 3, alignment: .topLeading)
            .focused(binding)
    }
}

private struct CapturedTextEditorView: View {

    @State var text: String

    @FocusState var isFocused = true

    let probe: BindingProbe<String>

    var body: some View {
        CapturedTextEditor(
            text: $text,
            isFocused: $isFocused,
            probe: probe
        )
    }
}

private struct CapturedTextEditor: View {

    let text: Binding<String>

    let isFocused: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        probe: BindingProbe<String>
    ) {
        self.text = text
        self.isFocused = isFocused
        probe.capture(text)
    }

    var body: some View {
        TextEditor(text: text)
            .focused(isFocused)
    }
}

private struct SecureFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    let textProbe: BindingProbe<String>

    var body: some View {
        CapturedSecureField(
            text: $text,
            isFocused: $isFocused,
            textProbe: textProbe
        )
    }
}

private struct CapturedSecureField: View {

    let text: Binding<String>

    let isFocused: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        textProbe: BindingProbe<String>
    ) {
        self.text = text
        self.isFocused = isFocused
        textProbe.capture(text)
    }

    var body: some View {
        SecureField("Password", text: text)
            .focused(isFocused)
    }
}

private struct TwoTextFieldsClickFocusView: View {

    @State var first = ""

    @State var second = ""

    @FocusState var field: FocusField? = .first

    let focusProbe: FocusBindingProbe<FocusField?>

    let textProbe: LabeledStringBindingProbe

    var body: some View {
        CapturedTwoTextFields(
            field: $field,
            first: $first,
            second: $second,
            focusProbe: focusProbe,
            textProbe: textProbe
        )
    }
}

private struct FramedTextFieldClickFocusView: View {

    @State var text = ""

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    var body: some View {
        CapturedFramedTextField(
            text: $text,
            binding: $isFocused,
            focusProbe: focusProbe
        )
    }
}

private struct CapturedFramedTextField: View {

    let text: Binding<String>

    let binding: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        binding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.binding = binding
        focusProbe.capture(binding)
    }

    var body: some View {
        TextField("A", text: text)
            .frame(width: 5, alignment: .leading)
            .focused(binding)
    }
}

private struct CapturedTwoTextFields: View {

    let field: FocusState<FocusField?>.Binding

    let first: Binding<String>

    let second: Binding<String>

    init(
        field: FocusState<FocusField?>.Binding,
        first: Binding<String>,
        second: Binding<String>,
        focusProbe: FocusBindingProbe<FocusField?>,
        textProbe: LabeledStringBindingProbe
    ) {
        self.field = field
        self.first = first
        self.second = second
        focusProbe.capture(field)
        textProbe.capture(first, label: "first")
        textProbe.capture(second, label: "second")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("first", text: first)
                .focused(field, equals: .first)
            TextField("second", text: second)
                .focused(field, equals: .second)
        }
    }
}

private struct TextFieldInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        TextField("Name", text: $text)
            .focused($isFocused)
    }
}

private struct PrefixedNarrowTextFieldInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("|")
            TextField("Name", text: $text)
                .focused($isFocused)
                .frame(width: 3, alignment: .leading)
        }
    }
}

private struct SecureFieldInitialTextView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        SecureField("Password", text: $text)
            .focused($isFocused)
    }
}

private struct DelimitedTextFieldView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 0) {
            Text("[")
            TextField("Name", text: $text)
                .focused($isFocused)
                .frame(width: 32)
            Text("]")
        }
    }
}

private struct FlexibleLabeledTextFieldView: View {

    @State var text: String

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 1) {
            Text("Admin Token")
            TextField("Admin Token", text: $text)
                .focused($isFocused)
            Spacer()
        }
    }
}

private struct LabeledTextFieldEditingView: View {

    @State var text = ""

    @FocusState var isFocused = true

    var body: some View {
        HStack(spacing: 1) {
            Text("Label:")
            TextField("Name", text: $text)
                .focused($isFocused)
        }
    }
}

private struct TextFieldSubmitView: View {

    @State var text = ""

    @State var submitted = "none"

    @FocusState var isFocused = true

    var body: some View {
        VStack {
            TextField("Name", text: $text)
                .focused($isFocused)
                .onSubmit {
                    submitted = text
                }
            Text(submitted)
        }
    }
}

private struct SecureFieldSubmitView: View {

    @State var text = ""

    @State var submitted = "none"

    @FocusState var isFocused = true

    var body: some View {
        VStack {
            SecureField("Password", text: $text)
                .focused($isFocused)
                .onSubmit {
                    submitted = text
                }
            Text(submitted)
        }
    }
}

private enum DynamicFocusRow: Hashable {

    case row
}

private struct DynamicTextFieldFocusWithOptionalRowFocusView: View {

    @State var isEditing = false

    @State var draft = ""

    @FocusState var selectedRow: DynamicFocusRow? = .row

    @FocusState var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("row")
                .focusable(!isEditing)
                .focused($selectedRow, equals: .row)

            if isEditing {
                HStack(spacing: 0) {
                    Text("> ")
                    TextField("", text: $draft)
                        .focused($editorFocused)
                    Spacer()
                }
            }
        }
        .onKeyPress(.return) {
            isEditing = true
            editorFocused = true
            return .handled
        }
    }
}

private struct ScrollWrappedDynamicTextFieldFocusView: View {

    var body: some View {
        ScrollView(.vertical) {
            DynamicTextFieldFocusWithOptionalRowFocusView()
        }
    }
}

private struct ParentKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let childResult: KeyPress.Result

    var body: some View {
        VStack {
            CapturedParentChildKeyPressText(
                focusBinding: $isFocused,
                focusProbe: focusProbe,
                keyProbe: keyProbe,
                result: childResult
            )
        }
        .onKeyPress("a") {
            keyProbe.record("parent")
            return .handled
        }
    }
}

private struct CapturedParentChildKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let result: KeyPress.Result

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        result: KeyPress.Result
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.result = result
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("child")
                return result
            }
    }
}

private struct OrderedKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    var body: some View {
        CapturedOrderedKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe
        )
    }
}

private struct FocusedAndGlobalKeyPressView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let focusedResult: KeyPress.Result

    var body: some View {
        CapturedFocusedAndGlobalKeyPressText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            focusedResult: focusedResult
        )
    }
}

private struct DisabledInputModifiersView: View {

    @FocusState var isFocused: Bool = true

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    let tapProbe: TapGestureProbe

    var body: some View {
        CapturedDisabledInputModifiersText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe,
            tapProbe: tapProbe
        )
        .disabled(true)
    }
}

private struct NestedGlobalKeyPressView: View {

    let keyProbe: KeyPressProbe

    let innerResult: KeyPress.Result

    var body: some View {
        VStack {
            VStack {
                Text("C")
                    .onGlobalKeyPress("a") {
                        keyProbe.record("inner")
                        return innerResult
                    }
            }
        }
        .onGlobalKeyPress("a") {
            keyProbe.record("outer")
            return .handled
        }
    }
}

private struct CapturedDisabledInputModifiersText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let tapProbe: TapGestureProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        tapProbe: TapGestureProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.tapProbe = tapProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("focused")
                return .handled
            }
            .onGlobalKeyPress("g") {
                keyProbe.record("global")
                return .handled
            }
            .onTapGesture {
                tapProbe.record("tap")
            }
            .onHover { _ in
                tapProbe.record("hover")
            }
            .onContinuousHover { _ in
                tapProbe.record("continuous-hover")
            }
    }
}

private struct CapturedFocusedAndGlobalKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    let focusedResult: KeyPress.Result

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe,
        focusedResult: KeyPress.Result
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        self.focusedResult = focusedResult
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("focused")
                return focusedResult
            }
            .onGlobalKeyPress("a") {
                keyProbe.record("global")
                return .handled
            }
    }
}

private struct GlobalEnvironmentTerminateView: View {

    @Environment(\.terminate) private var terminate

    var body: some View {
        Text("A")
            .onGlobalKeyPress(.escape) {
                terminate()
                return .handled
            }
    }
}

private struct CapturedOrderedKeyPressText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a") {
                keyProbe.record("first")
                return .handled
            }
            .onKeyPress("a") {
                keyProbe.record("second")
                return .handled
            }
    }
}

private struct KeyPressOverloadView: View {

    @FocusState var isFocused: Bool

    let focusProbe: FocusBindingProbe<Bool>

    let keyProbe: KeyPressProbe

    var body: some View {
        CapturedKeyPressOverloadText(
            focusBinding: $isFocused,
            focusProbe: focusProbe,
            keyProbe: keyProbe
        )
    }
}

private struct CapturedKeyPressOverloadText: View {

    let focusBinding: FocusState<Bool>.Binding

    let keyProbe: KeyPressProbe

    init(
        focusBinding: FocusState<Bool>.Binding,
        focusProbe: FocusBindingProbe<Bool>,
        keyProbe: KeyPressProbe
    ) {
        self.focusBinding = focusBinding
        self.keyProbe = keyProbe
        focusProbe.capture(focusBinding)
    }

    var body: some View {
        Text("A")
            .focusable()
            .focused(focusBinding)
            .onKeyPress("a", phases: [.down, .repeat]) { _ in
                keyProbe.record("exact")
                return .handled
            }
            .onKeyPress(keys: ["b", "c"]) { _ in
                keyProbe.record("set")
                return .handled
            }
            .onKeyPress(characters: .decimalDigits) { _ in
                keyProbe.record("characters")
                return .handled
            }
            .onKeyPress(phases: .up) { _ in
                keyProbe.record("phase")
                return .handled
            }
    }
}

private struct OptionalFocusView: View {

    @FocusState var field: FocusField?

    let probe: FocusBindingProbe<FocusField?>

    var body: some View {
        VStack {
            CapturedOptionalFocusedText(
                "First",
                binding: $field,
                value: .first,
                probe: probe
            )
            CapturedOptionalFocusedText(
                "Second",
                binding: $field,
                value: .second,
                probe: probe
            )
        }
    }
}

private struct CapturedOptionalFocusedText: View {

    let text: String

    let binding: FocusState<FocusField?>.Binding

    let value: FocusField

    init(
        _ text: String,
        binding: FocusState<FocusField?>.Binding,
        value: FocusField,
        probe: FocusBindingProbe<FocusField?>
    ) {
        self.text = text
        self.binding = binding
        self.value = value
        probe.capture(binding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(binding, equals: value)
    }
}

private struct DuplicateFocusValueView: View {

    @FocusState var field: FocusField?

    @FocusState var firstIsFocused: Bool

    @FocusState var secondIsFocused: Bool

    let fieldProbe: FocusBindingProbe<FocusField?>

    let firstProbe: FocusBindingProbe<Bool>

    let secondProbe: FocusBindingProbe<Bool>

    var body: some View {
        VStack {
            DuplicateFocusedText(
                "First",
                fieldBinding: $field,
                boolBinding: $firstIsFocused,
                fieldProbe: fieldProbe,
                boolProbe: firstProbe
            )
            DuplicateFocusedText(
                "Second",
                fieldBinding: $field,
                boolBinding: $secondIsFocused,
                fieldProbe: fieldProbe,
                boolProbe: secondProbe
            )
        }
    }
}

private struct DuplicateFocusedText: View {

    let text: String

    let fieldBinding: FocusState<FocusField?>.Binding

    let boolBinding: FocusState<Bool>.Binding

    init(
        _ text: String,
        fieldBinding: FocusState<FocusField?>.Binding,
        boolBinding: FocusState<Bool>.Binding,
        fieldProbe: FocusBindingProbe<FocusField?>,
        boolProbe: FocusBindingProbe<Bool>
    ) {
        self.text = text
        self.fieldBinding = fieldBinding
        self.boolBinding = boolBinding
        fieldProbe.capture(fieldBinding)
        boolProbe.capture(boolBinding)
    }

    var body: some View {
        Text(text)
            .focusable()
            .focused(fieldBinding, equals: .first)
            .focused(boolBinding)
    }
}
