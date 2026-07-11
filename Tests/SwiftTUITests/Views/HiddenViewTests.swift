import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Hidden Views")
struct HiddenViewTests {

    @Test
    func `a hidden view preserves layout while suppressing rendered output, the caret, and interaction regions`() {
        let block = ViewResolver.block(
            from: Text("C")
                .onTapGesture {}
                .focusable()
                .hidden()
        )

        #expect(block?.width == 1)
        #expect(block?.height == 1)
        #expect(block?.runs == [])
        #expect(block?.caret == nil)
        #expect(block?.hitRegions == [])
        #expect(block?.scrollRegions == [])
        #expect(block?.focusRegions == [])
    }

    @Test
    func `a hidden stack child preserves its spacing footprint`() {
        let view = HStack(spacing: 0) {
            Text("A")
            Text("B")
                .hidden()
            Text("C")
        }

        #expect(ViewResolver.block(from: view)?.lines == ["A C"])
    }

    @Test
    func `a hidden padded wide-character view preserves its explicit frame size`() {
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
}
