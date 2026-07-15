import Testing
@testable import SwiftTUIEssentials

@Suite("Layout Measurement Cache")
struct LayoutMeasurementCacheTests {

    @Test
    func `identical measurement keys reuse one rendered element within a render pass`() {
        var renderCount = 0

        let elements = LayoutMeasurementContext.withRenderPass {
            LayoutMeasurementContext.withMeasurement {
                let first = cachedElement(renderCount: &renderCount)
                let second = cachedElement(renderCount: &renderCount)
                return [first, second]
            }
        }

        #expect(renderCount == 1)
        #expect(elements[0] == elements[1])
    }

    @Test
    func `alignment queries and stack axes partition measurement cache entries`() {
        var renderCount = 0

        LayoutMeasurementContext.withRenderPass {
            LayoutMeasurementContext.withMeasurement {
                _ = cachedElement(
                    alignmentKeys: [],
                    stackAxis: .horizontal,
                    renderCount: &renderCount
                )
                _ = cachedElement(
                    alignmentKeys: [],
                    stackAxis: .horizontal,
                    renderCount: &renderCount
                )
                _ = cachedElement(
                    alignmentKeys: [HorizontalAlignment.center.key],
                    stackAxis: .horizontal,
                    renderCount: &renderCount
                )
                _ = cachedElement(
                    alignmentKeys: [HorizontalAlignment.center.key],
                    stackAxis: .vertical,
                    renderCount: &renderCount
                )
            }
        }

        #expect(renderCount == 3)
    }

    @Test
    func `placement resolutions bypass the measurement cache`() {
        var renderCount = 0

        LayoutMeasurementContext.withRenderPass {
            _ = cachedElement(renderCount: &renderCount)
            _ = cachedElement(renderCount: &renderCount)
        }

        #expect(renderCount == 2)
    }

    @Test
    func `a new render pass rereads changed state and environment inputs`() {
        var renderCount = 0
        var state = "collapsed"
        var environment = "light"

        let first = renderedInput(
            state: state,
            environment: environment,
            renderCount: &renderCount
        )
        state = "expanded"
        environment = "dark"
        let second = renderedInput(
            state: state,
            environment: environment,
            renderCount: &renderCount
        )

        #expect(renderCount == 2)
        #expect(first == .block(RenderedBlock(lines: ["collapsed light"])))
        #expect(second == .block(RenderedBlock(lines: ["expanded dark"])))
    }

    private func cachedElement(
        alignmentKeys: Set<AlignmentKey> = [],
        stackAxis: Axis? = nil,
        text: String = "cached",
        renderCount: inout Int
    ) -> RenderedElement? {
        LayoutMeasurementContext.cachedElement(
            type: MeasurementCacheProbe.self,
            path: [1, 2],
            proposal: RenderProposal(columns: 80, rows: 24),
            alignmentKeys: alignmentKeys,
            stackAxis: stackAxis
        ) {
            renderCount += 1
            return .block(RenderedBlock(lines: [text]))
        }
    }

    private func renderedInput(
        state: String,
        environment: String,
        renderCount: inout Int
    ) -> RenderedElement? {
        LayoutMeasurementContext.withRenderPass {
            LayoutMeasurementContext.withMeasurement {
                cachedElement(
                    text: "\(state) \(environment)",
                    renderCount: &renderCount
                )
            }
        }
    }
}

private enum MeasurementCacheProbe {}
