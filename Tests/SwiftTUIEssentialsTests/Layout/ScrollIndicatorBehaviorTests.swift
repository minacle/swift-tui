import Foundation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Scroll Indicator Behavior")
struct ScrollIndicatorBehaviorTests {

    @Test
    func `visible vertical indicators reserve a column only while content overflows`() {
        let overflowing = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .scrollIndicators(.visible, axes: .vertical)
        let fitting = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
            }
        }
        .scrollIndicators(.visible, axes: .vertical)

        #expect(ViewResolver.block(from: overflowing, in: RenderProposal(columns: 2, rows: 2))?.lines == ["A╻", "B╵"])
        #expect(ViewResolver.block(from: fitting, in: RenderProposal(columns: 2, rows: 2))?.lines == ["A ", "B "])
    }

    @Test
    func `one reserved indicator can make the other axis scrollable`() {
        let view = ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                Text("ABCD")
                Text("ABCD")
                Text("ABCD")
                Text("ABCD")
                Text("ABCD")
                Text("ABCD")
            }
        }
        .scrollIndicators(.visible)

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 4, rows: 5))

        #expect(block?.lines == ["ABC╻", "ABC┃", "ABC╿", "ABC╵", "╺━╴ "])
        #expect(block?.scrollRegions.map(\.frame) == [RenderedRect(width: 4, height: 5)])
    }

    @Test
    func `a reserved vertical indicator reflows content on the non-scrolling axis`() {
        let view = ScrollView {
            Text("ABCD\nX")
        }
        .scrollIndicators(.visible, axes: .vertical)

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 4, rows: 1))

        #expect(block?.lines == ["ABC┃"])
    }

    @Test
    func `hidden indicators overlay content after an actual wheel scroll and then expire`() throws {
        let runtime = StateRuntime()
        let view = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
                Text("D")
            }
        }
        .scrollIndicators(.hidden, axes: .vertical)
        let proposal = RenderProposal(columns: 2, rows: 2)

        #expect(runtime.block(from: view, in: proposal)?.lines == ["A ", "B "])
        dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)
        #expect(runtime.block(from: view, in: proposal)?.lines == ["B╻", "C╵"])
        let deadline = try #require(runtime.nextScrollIndicatorFlashDeadline)
        runtime.dispatchExpiredScrollIndicatorFlashes(at: deadline)
        #expect(runtime.block(from: view, in: proposal)?.lines == ["B ", "C "])
    }

    @Test
    func `never visibility suppresses indicator creation while preserving scrolling`() {
        let runtime = StateRuntime()
        let probe = AttachmentEvaluationProbe()
        let view = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .viewAttachment(VerticalScrollIndicatorAttachmentKey.self) { _ in
            probe.count += 1
            return Text("!")
        }
        .environment(\.verticalScrollIndicatorVisibility, .never)
        let proposal = RenderProposal(columns: 2, rows: 2)

        _ = runtime.block(from: view, in: proposal)
        dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)
        #expect(runtime.block(from: view, in: proposal)?.lines == ["B ", "C "])
        #expect(probe.count == 0)
    }

    @Test
    func `a custom attachment receives geometry and replaces the standard indicator`() {
        let probe = ScrollIndicatorConfigurationProbe()
        let view = ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
        .viewAttachment(VerticalScrollIndicatorAttachmentKey.self) { configuration in
            probe.values.append(configuration)
            return Text("!")
        }
        .scrollIndicators(.visible, axes: .vertical)

        let block = ViewResolver.block(from: view, in: RenderProposal(columns: 2, rows: 2))

        #expect(block?.lines == ["A!", "B "])
        #expect(probe.values.last?.offset == 0)
        #expect(probe.values.last?.maximumOffset == 1)
        #expect(probe.values.last?.viewportLength == 2)
        #expect(probe.values.last?.contentLength == 3)
    }

    @Test
    func `onAppear flashes hidden indicators once for a stable identity`() {
        let clock = ScrollIndicatorClock()
        let runtime = StateRuntime(now: { clock.date })
        let view = overflowingScrollView
            .scrollIndicators(.hidden, axes: .vertical)
            .scrollIndicatorsFlash(onAppear: true)
        let proposal = RenderProposal(columns: 2, rows: 2)

        #expect(runtime.block(from: view, in: proposal)?.lines == ["A ", "B "])
        #expect(runtime.block(from: view, in: proposal)?.lines == ["A╻", "B╵"])
        #expect(runtime.nextScrollIndicatorFlashDeadline == clock.date.addingTimeInterval(0.5))

        clock.date.addTimeInterval(0.5)
        runtime.dispatchExpiredScrollIndicatorFlashes(at: clock.date)
        #expect(runtime.block(from: view, in: proposal)?.lines == ["A ", "B "])
    }

    @Test
    func `a trigger ignores its initial value and flashes after a change`() {
        let clock = ScrollIndicatorClock()
        let runtime = StateRuntime(now: { clock.date })
        let view = TriggeredIndicatorFlashView()
        let proposal = RenderProposal(columns: 2, rows: 3)

        #expect(runtime.block(from: view, in: proposal)?.lines == ["F ", "A ", "B "])
        dispatchClick(to: runtime, column: 1, row: 1)
        _ = runtime.block(from: view, in: proposal)
        #expect(runtime.block(from: view, in: proposal)?.lines == ["F ", "A╻", "B╵"])
        #expect(runtime.nextScrollIndicatorFlashDeadline == clock.date.addingTimeInterval(0.5))
    }

    @Test
    func `interaction keeps a hidden indicator visible and restarts its delay when it ends`() throws {
        let clock = ScrollIndicatorClock()
        let runtime = StateRuntime(now: { clock.date })
        let probe = ScrollIndicatorConfigurationProbe()
        let view = overflowingScrollView
            .viewAttachment(VerticalScrollIndicatorAttachmentKey.self) { configuration in
                probe.values.append(configuration)
                return Text("!")
            }
            .environment(\.verticalScrollIndicatorVisibility, .hidden)
        let proposal = RenderProposal(columns: 2, rows: 2)

        _ = runtime.block(from: view, in: proposal)
        dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)
        #expect(runtime.block(from: view, in: proposal)?.lines == ["B!", "C "])
        let configuration = try #require(probe.values.last)
        configuration.beginInteraction()

        clock.date.addTimeInterval(1)
        runtime.dispatchExpiredScrollIndicatorFlashes(at: clock.date)
        #expect(runtime.block(from: view, in: proposal)?.lines == ["B!", "C "])

        configuration.endInteraction()
        #expect(runtime.nextScrollIndicatorFlashDeadline == clock.date.addingTimeInterval(0.5))
    }

    @Test
    func `retained indicator actions do nothing after their scroll view is removed`() throws {
        let runtime = StateRuntime()
        let probe = ScrollIndicatorConfigurationProbe()
        let view = overflowingScrollView
            .viewAttachment(VerticalScrollIndicatorAttachmentKey.self) { configuration in
                probe.values.append(configuration)
                return Text("!")
            }
            .environment(\.verticalScrollIndicatorVisibility, .visible)

        _ = runtime.block(from: view, in: RenderProposal(columns: 2, rows: 2))
        let configuration = try #require(probe.values.last)
        _ = runtime.consumeInvalidation()
        _ = runtime.block(from: Text("removed"))
        _ = runtime.consumeInvalidation()

        configuration.scroll(to: 1)
        configuration.beginInteraction()

        #expect(!runtime.consumeInvalidation())
    }

    private var overflowingScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("A")
                Text("B")
                Text("C")
            }
        }
    }
}

private final class AttachmentEvaluationProbe {
    var count = 0
}

private final class ScrollIndicatorConfigurationProbe {
    var values: [ScrollIndicatorConfiguration] = []
}

private final class ScrollIndicatorClock {
    var date = Date(timeIntervalSinceReferenceDate: 1_000)
}

private struct TriggeredIndicatorFlashView: View {
    @State private var trigger = 0

    var body: some View {
        VStack(spacing: 0) {
            Text("F")
                .onTapGesture { trigger += 1 }
            ScrollView {
                VStack(spacing: 0) {
                    Text("A")
                    Text("B")
                    Text("C")
                }
            }
            .scrollIndicators(.hidden, axes: .vertical)
            .scrollIndicatorsFlash(trigger: trigger)
        }
    }
}
