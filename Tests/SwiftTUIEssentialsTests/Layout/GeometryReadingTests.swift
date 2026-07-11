import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("Geometry Reading")
struct GeometryReadingTests {

    @Test
    func `a geometry reader passes proposed size to proxy`() {
        let reader = GeometryReader { proxy in
            Text("\(proxy.size.columns)x\(proxy.size.rows)")
        }

        let block = ViewResolver.block(
            from: reader,
            in: RenderProposal(columns: 5, rows: 2)
        )

        #expect(block?.lines == ["5x2  ", "     "])
    }

    @Test
    func `GeometryReader reports zero dimensions without a proposal while rendering content at its natural size`() {
        let reader = GeometryReader { proxy in
            Text("\(proxy.columns)x\(proxy.rows)")
        }

        let block = ViewResolver.block(from: reader)

        #expect(block?.lines == ["0x0"])
    }

    @Test
    func `GeometryProxy scalar dimensions and frame reflect the same initialized size`() {
        let proxy = GeometryProxy(columns: 7, rows: 1)

        #expect(proxy.columns == 7)
        #expect(proxy.rows == 1)
        #expect(proxy.frame == Rect(origin: .zero, size: Size(columns: 7, rows: 1)))
    }

    @Test
    func `a geometry reader exposes local frame from proposal`() {
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

    @Test
    func `GeometryReader receives both proposed axes inside HStack and VStack`() {
        let vertical = VStack(spacing: 0) {
            GeometryReader { proxy in
                Text("\(proxy.columns)x\(proxy.rows)")
            }
        }
        let horizontal = HStack(spacing: 0) {
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

    @Test
    func `GeometryReader clips overflowing columns and pads unused proposed rows`() {
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
}
