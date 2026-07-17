import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Text Styling")
struct TextStyleTests {

    @Test
    func `AccentColor accentColor satisfies Color and ShapeStyle and uses blue SGR outside a tint environment`() {
        let accent = AccentColor.accentColor

        func acceptsColor<C: Color>(_: C) {}
        func acceptsShapeStyle<S: ShapeStyle>(_: S) {}

        acceptsColor(accent)
        acceptsShapeStyle(accent)
        #expect(accent.foreground == Color16.blue.foreground)
        #expect(accent.background == Color16.blue.background)
    }

    @Test
    func `accentColor resolves the default and nearest tint for foreground styling`() {
        let block = ViewResolver.block(
            from: VStack(spacing: 0) {
                Text("A")
                    .foregroundStyle(.accentColor)
                Text("B")
                    .foregroundStyle(.accentColor)
                    .tint(.green)
            }
        )

        #expect(block?.runs == [
            RenderedRun(
                text: "A",
                style: TextStyle(foregroundStyle: AnyColor(Color16.blue))
            ),
            RenderedRun(
                text: "B",
                row: 1,
                style: TextStyle(foregroundStyle: AnyColor(Color16.green))
            ),
        ])
    }

    @Test
    func `clearing tint removes an accentColor foreground`() {
        let block = ViewResolver.block(
            from: Text("A")
                .foregroundStyle(.accentColor)
                .tint(Optional<Color16>.none)
        )

        #expect(block?.runs == [RenderedRun(text: "A")])
    }

    @Test
    func `AnyColor factories preserve each concrete color in type-erased form`() {
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

    @Test
    func `AnyShapeStyle preserves built-in and custom colors and conforms to ShapeStyle and Sendable while style environment values expose their defaults`() {
        let builtIn = AnyShapeStyle(Color16.red)
        let custom = AnyShapeStyle(CustomErasedShapeStyle())

        func acceptsShapeStyle<S: ShapeStyle>(_: S) {}
        func acceptsSendable<S: Sendable>(_: S) {}

        #expect(builtIn._swiftTUIAnyColor == AnyColor(Color16.red))
        #expect(custom._swiftTUIAnyColor == AnyColor(Color16.brightMagenta))
        acceptsShapeStyle(builtIn)
        acceptsSendable(builtIn)
        #expect(EnvironmentValues().textSelectionForegroundStyle == nil)
        #expect(EnvironmentValues().tint == AnyColor(Color16.blue))
    }

    @Test
    func `text styling leaves the wrapped plain-text projection unchanged`() {
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

    @Test
    func `container text styles are inherited unless a child explicitly resets them`() {
        let block = ViewResolver.block(
            from: VStack(alignment: .leading, spacing: 0) {
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

    @Test
    func `padding and framing retain a text run's style and translated position`() {
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

    @Test
    func `custom color ShapeStyle values drive both foreground and background colors`() {
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

    @Test
    func `AnyColor factory results can be passed directly to foreground and background modifiers`() {
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
}
