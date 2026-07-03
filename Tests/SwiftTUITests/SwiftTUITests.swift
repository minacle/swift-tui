import Foundation
import Observation
import Testing
import Terminal
@testable import SwiftTUI

@Test func textPreservesContent() {
    let text = Text("Hello")

    #expect(text.content == "Hello")
}

@Test func textStyleDoesNotChangePlainTextProjection() {
    let block = ViewResolver.block(
        from: Text("Lorem ipsum").color(.green).bold().dim(),
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
                .color(.default)
                .bold(false)
                .dim(false)
        }
        .color(.red)
        .bold()
        .dim()
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "A",
            row: 0,
            style: TextStyle(color: AnyColor(Color16.red), isBold: true, isDim: true)
        ),
        RenderedRun(
            text: "B",
            row: 1,
            style: TextStyle(color: AnyColor(DefaultColor.default), isBold: false)
        ),
    ])
    #expect(block?.lines == ["A", "B"])
}

@Test func textStyleSurvivesPaddingAndFrameLayout() {
    let block = ViewResolver.block(
        from: Text("A")
            .color(.blue)
            .padding()
            .frame(width: 4, height: 3, alignment: .topLeading)
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "A",
            row: 1,
            column: 1,
            style: TextStyle(color: AnyColor(Color16.blue), isBold: false)
        ),
    ])
    #expect(block?.lines == ["    ", " A  ", "    "])
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
        .color(.brightGreen)
        .bold()
        .dim()

    #expect(ViewResolver.block(from: textField)?.runs == [
        RenderedRun(
            text: "mayu",
            style: TextStyle(
                color: AnyColor(Color16.brightGreen),
                isBold: true,
                isDim: true
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

@Test func geometryValuesNormalizeNegativeComponents() {
    let size = GeometrySize(columns: -1, rows: -2)
    let point = GeometryPoint(column: -3, row: -4)
    let frame = GeometryFrame(origin: point, size: size)

    #expect(size == GeometrySize())
    #expect(point == GeometryPoint())
    #expect(frame == GeometryFrame())
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
    #expect(proxy.frame == GeometryFrame(size: GeometrySize(columns: 7, rows: 1)))
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
            .color(.magenta)
    }
    .scrollPosition(.constant(ScrollPosition(x: 2)))

    let block = ViewResolver.block(
        from: scrollView,
        in: RenderProposal(columns: 3, rows: 1)
    )

    #expect(block?.runs == [
        RenderedRun(
            text: "CDE",
            style: TextStyle(color: AnyColor(Color16.magenta), isBold: false)
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
        for: ViewResolver.block(from: Text("A").color(.red))!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(output == "\u{001B}[2J\u{001B}[1;1H\u{001B}[31mA\u{001B}[39m\u{001B}[?25l")
}

@Test func screenOutputRendersColor256ForegroundSGR() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").color(Color256(rawValue: 196)))!,
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
            from: Text("A").color(TrueColor(red: 1, green: 2, blue: 3))
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

@Test func screenOutputRendersCombinedStyleInDeterministicOrder() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(from: Text("A").bold().dim().color(.brightCyan))!,
        in: TerminalViewportSize(columns: 1, rows: 1)
    )

    #expect(
        output
            == "\u{001B}[2J\u{001B}[1;1H"
            + "\u{001B}[1m\u{001B}[2m\u{001B}[96m"
            + "A"
            + "\u{001B}[22m\u{001B}[39m"
            + "\u{001B}[?25l"
    )
}

@Test func screenOutputRendersDefaultForegroundOverride() {
    let output = TextRenderer.screen(
        for: ViewResolver.block(
            from: VStack(alignment: .leading) {
                Text("A")
                Text("B")
                    .color(.default)
                    .bold(false)
                    .dim(false)
            }
            .color(.red)
            .bold()
            .dim()
        )!,
        in: TerminalViewportSize(columns: 1, rows: 2)
    )

    #expect(
        output
            == "\u{001B}[2J"
            + "\u{001B}[1;1H"
            + "\u{001B}[1m\u{001B}[2m\u{001B}[31m"
            + "A"
            + "\u{001B}[22m\u{001B}[39m"
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
        for: ViewResolver.block(from: Text("ABCDE").color(.blue).dim())!,
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
    #expect(TerminalControl.enableMouseTrackingSequence == "\u{001B}[?1000h\u{001B}[?1006h")
    #expect(TerminalControl.disableMouseTrackingSequence == "\u{001B}[?1006l\u{001B}[?1000l")
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

@Test func onChangeRunsWhenValueChanges() {
    let runtime = StateRuntime()
    let probe = LifecycleProbe()

    #expect(runtime.block(from: OnChangeValueView(value: 1, probe: probe))?.text == "1")
    #expect(runtime.block(from: OnChangeValueView(value: 2, probe: probe))?.text == "2")

    #expect(probe.events == ["changed 2"])
}

@Test func onChangeActionMutatesStateWithRestoredViewContext() {
    let runtime = StateRuntime()

    #expect(runtime.block(from: OnChangeStateMutationView(value: 1))?.text == "idle")
    #expect(runtime.block(from: OnChangeStateMutationView(value: 2))?.text == "idle")
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: OnChangeStateMutationView(value: 2))?.text == "changed")
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

@Test("Navigation link direct destination activates with Return, Space, and tap")
func NavigationLinkDirectDestinationActivatesWithReturnSpaceAndTap() {
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

    #expect(runtime.dispatch(KeyPress(key: .space, characters: " ")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")

    #expect(runtime.dispatch(KeyPress(key: .escape, characters: "\u{001B}")) == .handled)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Open")

    dispatchClick(to: runtime, column: 1, row: 1)
    #expect(runtime.consumeInvalidation())
    #expect(runtime.block(from: view)?.text == "Detail")
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

    #expect(runtime.dispatch(KeyPress(key: .leftArrow, characters: "\u{F702}")) == .handled)
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
    dispatchClick(to: runtime, column: 1, row: 1, expecting: .ignored)
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

    init(count: Int = 0, creationProbe: ObjectCreationProbe? = nil) {
        self.id = creationProbe?.nextID() ?? 0
        self.count = count
        self.unreadCount = 0
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

    static let defaultValue = "default"
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

private struct ParentCallbackTapChildView: View {

    let action: () -> Void

    var body: some View {
        Text("Tap")
            .onTapGesture {
                action()
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
