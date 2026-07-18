import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Scroll Views, Positions, and Flexible Layout")
struct ScrollViewPositionAndFlexibleLayoutTests {

    @Test
    func `a scroll view clips vertically by default`() {
        let scrollView = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }

        let block = ViewResolver.block(from: scrollView, in: RenderProposal(rows: 2))

        #expect(block?.lines == ["A", "B"])
    }

    @Test
    func `vertical scroll view inside VStack receives remaining viewport`() {
        let stack = VStack(alignment: .leading, spacing: 0) {
            Text("H")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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

    @Test
    func `a Retort Fedi-style screen keeps its footer fixed while scroll-region TextField input remains interactive`() {
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
                PointerPress(button: .left, location: Point(column: 0, row: 1), phase: .down)
            ) == .ignored
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

    @Test
    func `a GeometryReader-backed route transition keeps destination focus and key dispatch active`() {
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
                PointerPress(button: .left, location: Point(column: 1, row: 1), phase: .down)
            ) == .ignored
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

    @Test
    func `a scroll view clips horizontally`() {
        let scrollView = ScrollView(.horizontal) {
            Text("ABCDE")
        }

        let block = ViewResolver.block(from: scrollView, in: RenderProposal(columns: 3))

        #expect(block?.lines == ["ABC"])
    }

    @Test
    func `a scroll view applies point position on both axes`() {
        let scrollView = ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
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

    @Test
    func `a text field fills remaining columns in HStack`() {
        let stack = HStack(spacing: 0) {
            Text("[")
            TextField("Name", text: .constant(""))
            Text("]")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 8))

        #expect(block?.lines == ["[Name  ]"])
    }

    @Test
    func `a text field takes remaining columns before spacer`() {
        let stack = HStack(spacing: 0) {
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

    @Test
    func `a TextField fills the proposed VStack width through a nested HStack`() {
        let stack = VStack(spacing: 0) {
            HStack(spacing: 0) {
                TextField("Text Field", text: .constant(""))
                Spacer()
            }
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 20, rows: 5))

        #expect(block?.width == 20)
        #expect(block?.height == 1)
        #expect(block?.lines == ["Text Field          "])
    }

    @Test
    func `nested HStack text field receives parent proposal`() {
        let stack = HStack(spacing: 0) {
            Text("A")
            HStack(spacing: 0) {
                TextField("Name", text: .constant(""))
            }
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 10))

        #expect(block?.width == 10)
        #expect(block?.lines == ["AName     "])
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(x: 1, y: 0, width: 9, height: 1),
        ])
    }

    @Test
    func `nested HStack spacer propagates horizontal flexibility`() {
        let stack = HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Title")
                Spacer()
            }
            Text("X")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 10))

        #expect(block?.width == 10)
        #expect(block?.lines == ["Title    X"])
    }

    @Test
    func `a TextField receives the parent width proposal through nested VStack and HStack containers`() {
        let stack = HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TextField("Name", text: .constant(""))
                }
            }
            Text("X")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 10))

        #expect(block?.width == 10)
        #expect(block?.lines == ["Name     X"])
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(x: 0, y: 0, width: 9, height: 1),
        ])
    }

    @Test
    func `VStack local spacer does not propagate horizontal flexibility`() {
        let stack = HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("A")
                Spacer()
            }
            Text("X")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 10, rows: 3))

        #expect(block?.width == 2)
        #expect(block?.lines == [
            "A ",
            " X",
            "  ",
        ])
    }

    @Test
    func `an overlaid TextField in nested stacks receives all available width`() {
        let stack = VStack(spacing: 1) {
            HStack(spacing: 2) {
                HStack(alignment: .top, spacing: 0) {
                    Text("App Title")
                        .bold()
                    Spacer()
                }
                HStack(spacing: 0) {
                    Text("[")
                        .dim()
                    ZStack {
                        TextField("Enter URL...", text: .constant(""))
                        Text("Enter URL...")
                            .dim()
                    }
                    Text("]")
                        .dim()
                }
            }
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 80, rows: 24))

        #expect(block?.width == 80)
        #expect(block?.lines.first?.count == 80)
        #expect(block?.lines.first?.last == "]")
        #expect(block?.focusRegions.map(\.frame) == [
            RenderedRect(x: 42, y: 0, width: 37, height: 1),
        ])
    }

    @Test
    func `an oversized fixed-width sibling does not shift the leading edge of an earlier VStack row`() {
        let longText = String(repeating: "가나다라마바사아자차카타파하", count: 4)
        let stack = VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Settings")
                Spacer()
            }
            HStack(spacing: 1) {
                Text(" ")
                TextField("Admin Token", text: .constant(longText))
                Spacer()
            }
            HStack(spacing: 0) {
                Text(longText)
                Spacer()
            }
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 40, rows: 24))

        #expect(block?.width == 40)
        #expect(block?.lines.first?.hasPrefix("Settings") == true)
    }

    @Test
    func `a vertical ScrollView proposes its viewport width to a TextField`() {
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

    @Test
    func `a horizontal ScrollView keeps a TextField at intrinsic width inside a wider viewport`() {
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

    @Test
    func `vertical and horizontal ScrollViews apply axis-specific expansion to their TextField content`() {
        let stack = HStack(spacing: 0) {
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

    @Test
    func `clicking constant-bound TextFields inside ScrollViews changes focus and routes typing`() {
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
                PointerPress(button: .left, location: Point(column: 0, row: 0), phase: .down)
            ) == .ignored
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
                PointerPress(button: .left, location: Point(column: 10, row: 1), phase: .down)
            ) == .ignored
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

    @Test
    func `top-level scroll views expand along scrollable axes only`() {
        let vertical = ScrollView {
            VStack(spacing: 0) {
                Text("V0")
                Text("V1")
                Text("V2")
            }
        }
        let horizontal = ScrollView(.horizontal) {
            Text("H012345")
        }
        let both = ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
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

    @Test
    func `a runtime-rendered root ScrollView follows the top-level expansion rules`() {
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

    @Test
    func `scroll views expand along scrollable axes inside HStack`() {
        let stack = HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
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

    @Test
    func `scroll views expand along scrollable axes inside VStack`() {
        let stack = VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            ScrollView {
                VStack(spacing: 0) {
                    Text("V0")
                    Text("V1")
                    Text("V2")
                }
            }
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
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

    @Test
    func `empty scroll view participates in VStack expansion`() {
        let stack = VStack(alignment: .leading, spacing: 0) {
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

    @Test
    func `a scroll view and spacer share stack remainder`() {
        let stack = HStack(spacing: 0) {
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            Spacer()
            Text("Z")
        }

        let block = ViewResolver.block(from: stack, in: RenderProposal(columns: 10))

        #expect(block?.lines == ["ABCDE    Z"])
    }

    @Test
    func `fixedSize and fixed frames prevent ScrollView expansion along constrained axes`() {
        let fixedSize = HStack(spacing: 0) {
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            .fixedSize(horizontal: true, vertical: false)
            Text("Z")
        }
        let fixedFrame = HStack(spacing: 0) {
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            .frame(width: 3, alignment: .leading)
            Text("Z")
        }

        #expect(ViewResolver.block(from: fixedSize, in: RenderProposal(columns: 10))?.lines == ["ABCDEZ"])
        #expect(ViewResolver.block(from: fixedFrame, in: RenderProposal(columns: 10))?.lines == ["ABCZ"])
    }

    @Test
    func `ScrollView expansion preserves scroll, hit, and focus regions through its wrappers`() {
        let runtime = StateRuntime()
        let tapProbe = TapGestureProbe()
        let view = HStack(spacing: 0) {
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

    @Test
    func `stack measurement clamps the viewport without replacing a programmatic position or invoking its setter`() {
        var position = ScrollPosition(x: 99)
        var setterCallCount = 0
        let view = HStack(spacing: 0) {
            ScrollView(.horizontal) {
                Text("ABCDE")
            }
            .scrollPosition(
                Binding(
                    get: { position },
                    set: {
                        setterCallCount += 1
                        position = $0
                    }
                )
            )
        }

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 3))

        #expect(block?.lines == ["CDE"])
        #expect(position.point == ScrollPoint(x: 99))
        #expect(setterCallCount == 0)
    }

    @Test
    func `ScrollPosition scrolling methods replace point and edge targets`() {
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

    @Test
    func `ScrollPoint and ScrollPosition clamp negative coordinates to zero`() {
        #expect(ScrollPoint(x: -1, y: -2) == ScrollPoint())
        #expect(ScrollPosition(x: -3).point == ScrollPoint())
        #expect(ScrollPosition(y: -4).point == ScrollPoint())
        #expect(ScrollPosition(x: -5, y: -6).point == ScrollPoint())
    }

    @Test
    func `a scroll view resolves edge positions`() {
        let vertical = ScrollView {
            VStack(spacing: 0) {
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

    @Test
    func `a scroll view ignores position on disabled axes`() {
        let vertical = ScrollView {
            Text("ABCDE")
        }
        .scrollPosition(.constant(ScrollPosition(x: 2, y: 0)))
        .frame(width: 3, height: 1, alignment: .leading)
        let horizontal = ScrollView(.horizontal) {
            VStack(spacing: 0) {
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

    @Test
    func `a scroll view clamps oversized positions`() {
        let scrollView = ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
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

    @Test
    func `pointer-wheel input scrolls a ScrollView that does not own focus`() {
        let runtime = StateRuntime()
        let view = FocusedScrollWheelView()

        #expect(runtime.block(from: view)?.lines == ["focus", "A    ", "B    "])
        _ = runtime.consumeInvalidation()

        dispatchWheel(to: runtime, direction: .down, column: 1, row: 2)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.lines == ["focus", "B    ", "C    "])
    }

    @Test
    func `wheel input updates a ScrollView's bound position`() {
        var position = ScrollPosition()
        let scrollView = ScrollView {
            VStack(spacing: 0) {
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
        dispatchWheel(to: runtime, direction: .down, column: 1, row: 1)

        #expect(position.point == ScrollPoint(y: 1))
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["B", "C"])
    }

    @Test
    func `a disabled ScrollView removes its wheel region and ignores wheel input`() {
        var position = ScrollPosition()
        let scrollView = ScrollView {
            VStack(spacing: 0) {
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
        dispatchWheel(to: runtime, direction: .down, column: 1, row: 1, expecting: .ignored)

        #expect(position.point == nil)
        #expect(!runtime.consumeInvalidation())
    }

    @Test
    func `scrollDisabled blocks wheel input without overriding a programmatic position`() {
        let scrollView = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .scrollPosition(.constant(ScrollPosition(point: ScrollPoint(y: 1))))
        .frame(width: 1, height: 2)
        .scrollDisabled(true)
        let runtime = StateRuntime()

        let block = runtime.block(from: scrollView)

        #expect(block?.lines == ["B", "C"])
        #expect(block?.scrollRegions == [])
        dispatchWheel(to: runtime, direction: .up, column: 1, row: 1, expecting: .ignored)
        #expect(!runtime.consumeInvalidation())
    }

    @Test
    func `wheel input updates a ScrollView's stored position without a binding`() {
        let scrollView = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .frame(width: 1, height: 2)
        let runtime = StateRuntime()

        #expect(runtime.block(from: scrollView)?.lines == ["A", "B"])
        dispatchWheel(to: runtime, direction: .down, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["B", "C"])
    }

    @Test
    func `vertical wheel input scrolls a horizontal-only ScrollView`() {
        let scrollView = ScrollView(.horizontal) {
            Text("ABCDE")
        }
        .frame(width: 3, height: 1)
        let runtime = StateRuntime()

        #expect(runtime.block(from: scrollView)?.lines == ["ABC"])
        dispatchWheel(to: runtime, direction: .down, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["BCD"])
    }

    @Test
    func `a framed horizontal ScrollView uses its full frame as the wheel region`() {
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

        dispatchWheel(to: runtime, direction: .down, column: 1, row: 4)

        #expect(position.point == ScrollPoint(x: 1))
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["BCD", "   ", "   ", "   "])
    }

    @Test
    func `a two-axis ScrollView responds to horizontal wheel buttons and Shift-modified vertical wheel input`() {
        let scrollView = ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                Text("ABCDE")
                Text("FGHIJ")
            }
        }
        .frame(width: 3, height: 1)
        let runtime = StateRuntime()

        #expect(runtime.block(from: scrollView)?.lines == ["ABC"])
        dispatchWheel(to: runtime, direction: .right, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["BCD"])

        dispatchWheel(to: runtime, direction: .left, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["ABC"])

        dispatchWheel(
            to: runtime,
            direction: .down,
            column: 1,
            row: 1,
            modifiers: .shift
        )
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["BCD"])
    }

    @Test
    func `wheel input bubbles to an outer ScrollView when the inner ScrollView cannot scroll`() {
        let scrollView = ScrollView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
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
        dispatchWheel(to: runtime, direction: .down, column: 1, row: 1)

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: scrollView)?.lines == ["B", "C"])
    }

    @Test
    func `wheel input targets an inner ScrollView before its outer ancestor`() {
        var outerPosition = ScrollPosition()
        var innerPosition = ScrollPosition()
        let scrollView = ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
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
        dispatchWheel(to: runtime, direction: .down, column: 1, row: 2)

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

    @Test
    func `a ScrollView ignores wheel input outside its rendered region`() {
        let scrollView = ScrollView {
            VStack(spacing: 0) {
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
            direction: .down,
            column: 2,
            row: 1,
            expecting: .ignored
        )
        #expect(!runtime.consumeInvalidation())
    }
}
