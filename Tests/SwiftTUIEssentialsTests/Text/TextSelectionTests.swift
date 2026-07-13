import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Text Selection")
struct TextSelectionTests {

    @Test
    func `TextSelection models Unicode insertion points and ranges with value equality and hashing`() {
        let text = "A👨‍👩‍👧‍👦한"
        let emojiStart = text.index(after: text.startIndex)
        let emojiEnd = text.index(after: emojiStart)
        let insertion = TextSelection(insertionPoint: emojiStart)
        var selection = insertion

        #expect(insertion.isInsertion)
        #expect(selectionCharacterOffsets(insertion, in: text) == 1..<1)

        selection.indices = .selection(emojiStart..<emojiEnd)
        #expect(!selection.isInsertion)
        #expect(selectionCharacterOffsets(selection, in: text) == 1..<2)
        #expect(Set([insertion, insertion, selection]).count == 2)
    }

    @Test
    func `selection navigation exposes both modes and chooses a platform-specific default`() {
        let values: Set<TextSelectionNavigationBehavior> = [
            .dragEndpoint,
            .navigationDirection,
        ]

        #expect(values.count == 2)
        #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS) || os(watchOS)
        #expect(EnvironmentValues().textSelectionNavigationBehavior == .navigationDirection)
        #else
        #expect(EnvironmentValues().textSelectionNavigationBehavior == .dragEndpoint)
        #endif
    }

    @Test
    func `navigationDirection reanchors a dragged selection before keyboard extension`() {
        let backward = TextSelectionState(offset: 2) {}
        backward.begin(at: 2, upperBound: 6)
        backward.extendFromPointer(to: 5, upperBound: 6)
        backward.prepareForSelectionNavigation(
            toward: .backward,
            behavior: .navigationDirection,
            upperBound: 6
        )
        backward.move(to: 1, upperBound: 6, selecting: true)
        #expect(backward.anchor == 5)
        #expect(backward.offset == 1)
        #expect(backward.range == 1..<5)

        backward.move(to: 2, upperBound: 6, selecting: true)
        #expect(backward.range == 2..<5)
        backward.move(to: 6, upperBound: 6, selecting: true)
        #expect(backward.anchor == 5)
        #expect(backward.offset == 6)
        #expect(backward.range == 5..<6)

        let forward = TextSelectionState(offset: 5) {}
        forward.begin(at: 5, upperBound: 6)
        forward.extendFromPointer(to: 2, upperBound: 6)
        forward.prepareForSelectionNavigation(
            toward: .forward,
            behavior: .navigationDirection,
            upperBound: 6
        )
        forward.move(to: 6, upperBound: 6, selecting: true)
        #expect(forward.anchor == 2)
        #expect(forward.offset == 6)
        #expect(forward.range == 2..<6)
    }

    @Test
    func `dragEndpoint keeps the original anchor and continues from the pointer endpoint`() {
        let forwardDrag = TextSelectionState(offset: 2) {}
        forwardDrag.begin(at: 2, upperBound: 6)
        forwardDrag.extendFromPointer(to: 5, upperBound: 6)
        forwardDrag.prepareForSelectionNavigation(
            toward: .backward,
            behavior: .dragEndpoint,
            upperBound: 6
        )
        forwardDrag.move(to: 4, upperBound: 6, selecting: true)
        #expect(forwardDrag.anchor == 2)
        #expect(forwardDrag.offset == 4)
        #expect(forwardDrag.range == 2..<4)

        let reverseDrag = TextSelectionState(offset: 5) {}
        reverseDrag.begin(at: 5, upperBound: 6)
        reverseDrag.extendFromPointer(to: 2, upperBound: 6)
        reverseDrag.prepareForSelectionNavigation(
            toward: .forward,
            behavior: .dragEndpoint,
            upperBound: 6
        )
        reverseDrag.move(to: 3, upperBound: 6, selecting: true)
        #expect(reverseDrag.anchor == 5)
        #expect(reverseDrag.offset == 3)
        #expect(reverseDrag.range == 3..<5)
    }

    @Test
    func `a nil selection-foreground override clears both stored and inherited values`() {
        var environment = EnvironmentValues()
        environment.textSelectionForegroundStyle = AnyShapeStyle(Color16.green)
        #expect(
            environment.textSelectionForegroundStyle?._swiftTUIAnyColor
                == AnyColor(Color16.green)
        )
        environment.textSelectionForegroundStyle = nil
        #expect(environment.textSelectionForegroundStyle == nil)

        let runtime = StateRuntime()
        let view = VStack(spacing: 0) {
            Text("ab")
                .foregroundStyle(.yellow)
                .textSelection(.enabled)
                .textSelectionForegroundStyle(Optional<Color16>.none)
        }
        .textSelectionForegroundStyle(Optional(Color16.white))

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 2, row: 0), modifiers: []))

        #expect(runtime.block(from: view)?.runs == [
            RenderedRun(
                text: "ab",
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.yellow),
                    backgroundStyle: AnyColor(Color16.blue)
                )
            ),
        ])
    }

    @Test
    func `EnabledTextSelectability and DisabledTextSelectability report whether selection is allowed`() {
        let enabled: EnabledTextSelectability = .enabled
        let disabled: DisabledTextSelectability = .disabled

        #expect(type(of: enabled).allowsSelection)
        #expect(!type(of: disabled).allowsSelection)
    }

    @Test
    func `selected text uses tint for its background and an optional foreground override`() {
        let runtime = StateRuntime()
        let view = Text("abcd")
            .foregroundStyle(.yellow)
            .textSelection(.enabled)
            .textSelectionForegroundStyle(Optional(Color16.white))

        _ = runtime.block(from: view)
        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 3, row: 0), modifiers: [])
            ) == .ignored
        )

        let block = runtime.block(from: view)
        #expect(block?.runs == [
            RenderedRun(
                text: "abc",
                style: TextStyle(
                    foregroundStyle: AnyColor(Color16.white),
                    backgroundStyle: AnyColor(Color16.blue)
                )
            ),
            RenderedRun(
                text: "d",
                column: 3,
                style: TextStyle(foregroundStyle: AnyColor(Color16.yellow))
            ),
        ])
    }

    @Test
    func `selected text emits foreground and background SGR sequences while screen rendering hides the terminal cursor`() {
        let runtime = StateRuntime()
        let view = Text("A")
            .textSelection(.enabled)
            .textSelectionForegroundStyle(Optional(Color16.white))

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 1, row: 0), modifiers: []))
        let output = TerminalScreenRenderer.screen(
            for: runtime.block(from: view)!,
            in: TerminalViewportSize(columns: 1, rows: 1)
        )

        #expect(
            output
                == "\u{001B}[2J\u{001B}[1;1H"
                + "\u{001B}[37m\u{001B}[44mA\u{001B}[39m\u{001B}[49m"
                + "\u{001B}[?25l"
        )
    }

    @Test
    func `without a selection-foreground override selected text keeps its original foreground`() {
        let runtime = StateRuntime()
        let view = Text("ab")
            .foregroundStyle(.yellow)
            .textSelection(.enabled)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 1, row: 0), modifiers: []))

        #expect(runtime.block(from: view)?.runs.first?.style == TextStyle(
            foregroundStyle: AnyColor(Color16.yellow),
            backgroundStyle: AnyColor(Color16.blue)
        ))
    }

    @Test
    func `clearing tint removes the selection background without clearing its foreground override`() {
        let runtime = StateRuntime()
        let view = Text("ab")
            .foregroundStyle(.yellow)
            .textSelection(.enabled)
            .tint(Optional<Color16>.none)
            .textSelectionForegroundStyle(Optional(Color16.white))

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 2, row: 0), modifiers: []))

        #expect(runtime.block(from: view)?.runs == [
            RenderedRun(
                text: "ab",
                style: TextStyle(foregroundStyle: AnyColor(Color16.white))
            ),
        ])
    }

    @Test
    func `reverse dragging selects multiline text containing a wide glyph in logical order`() {
        let runtime = StateRuntime()
        let view = Text("한a\nbc").textSelection(.enabled)

        _ = runtime.block(from: view, in: RenderProposal(columns: 4))
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 2, row: 1), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 0, row: 0), modifiers: []))

        #expect(runtime.block(from: view, in: RenderProposal(columns: 4))?.runs == [
            RenderedRun(
                text: "한a",
                style: TextStyle(backgroundStyle: AnyColor(Color16.blue))
            ),
            RenderedRun(
                text: "bc",
                row: 1,
                style: TextStyle(backgroundStyle: AnyColor(Color16.blue))
            ),
        ])
    }

    @Test
    func `starting a selection in a sibling text view clears the previous target and selects only the new one`() {
        let runtime = StateRuntime()
        let view = HStack(spacing: 1) {
            Text("ab")
            Text("cd")
        }
        .textSelection(.enabled)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 2, row: 0), modifiers: []))
        #expect(runtime.block(from: view)?.runs.first?.style.backgroundStyle == AnyColor(Color16.blue))

        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 3, row: 0), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 5, row: 0), modifiers: []))

        #expect(runtime.block(from: view)?.runs == [
            RenderedRun(text: "ab"),
            RenderedRun(
                text: "cd",
                column: 3,
                style: TextStyle(backgroundStyle: AnyColor(Color16.blue))
            ),
        ])
    }

    @Test
    func `disabled and hidden text ignore attempts to begin static selection`() {
        let disabledRuntime = StateRuntime()
        let disabled = Text("ab").textSelection(.enabled).disabled(true)
        _ = disabledRuntime.block(from: disabled)
        #expect(
            disabledRuntime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )

        let hiddenRuntime = StateRuntime()
        let hidden = Text("ab").textSelection(.enabled).hidden()
        _ = hiddenRuntime.block(from: hidden)
        #expect(
            hiddenRuntime.dispatch(
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
        )
    }

    @Test
    func `a selectable link opens after a click but not after a selection drag`() {
        var attributed = AttributedString("Visit")
        let url = URL(string: "https://example.com")!
        attributed.link = url
        var opened: [URL] = []
        let runtime = StateRuntime()
        let view = Text(attributedContent: attributed)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { opened.append($0); return .handled })

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down))
        _ = runtime.dispatch(PointerMotion(button: .left, location: Point(column: 3, row: 0), modifiers: []))
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 3, row: 0), phase: .up))
        #expect(opened.isEmpty)
        #expect(runtime.block(from: view)?.runs.first?.style.backgroundStyle == AnyColor(Color16.blue))

        dispatchClick(to: runtime, column: 5, row: 1)
        #expect(opened == [url])
    }

    @Test
    func `clicking inside selected static text defers collapse until pointer-up`() {
        let runtime = StateRuntime()
        let view = Text("abcd").textSelection(.enabled)

        _ = runtime.block(from: view)
        dispatchSelectionDrag(
            to: runtime,
            fromColumn: 1,
            fromRow: 1,
            toColumn: 4,
            toRow: 1
        )

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .down)
            ) == .ignored
        )
        #expect(runtime.block(from: view)?.runs.first?.style.backgroundStyle == AnyColor(Color16.blue))

        #expect(
            runtime.dispatch(
                PointerPress(button: .left, location: Point(column: 1, row: 0), phase: .up)
            ) == .ignored
        )
        #expect(runtime.block(from: view)?.runs.first?.style.backgroundStyle == nil)
    }

    @Test
    func `button labels are excluded from static-text selection registration`() {
        let runtime = StateRuntime()
        let view = Button("Run") {}.textSelection(.enabled)

        _ = runtime.block(from: view)
        _ = runtime.dispatch(PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down))
        #expect(
            runtime.dispatch(
                PointerMotion(button: .left, location: Point(column: 2, row: 0), modifiers: [])
            ) == .ignored
        )
        #expect(runtime.block(from: view)?.runs.first?.style.backgroundStyle == nil)
    }

}
