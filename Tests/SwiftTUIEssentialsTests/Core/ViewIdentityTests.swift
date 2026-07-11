import Foundation
import Observation
import Testing
@testable import SwiftTUIEssentials
import SwiftTUIControls

@Suite("View Identity")
struct ViewIdentityTests {

    @Test
    func `changing an explicit view ID resets subtree state`() {
        let runtime = StateRuntime()

        #expect(runtime.block(from: ExplicitIDCounterHost(id: 1))?.text == "0")
        dispatchClick(to: runtime, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: ExplicitIDCounterHost(id: 1))?.text == "1")
        #expect(runtime.block(from: ExplicitIDCounterHost(id: 1))?.text == "1")
        #expect(runtime.block(from: ExplicitIDCounterHost(id: 2))?.text == "0")
    }

    @Test
    func `changing an explicit view ID resets nested scroll state`() {
        let runtime = StateRuntime()

        #expect(runtime.block(from: ExplicitIDScrollHost(id: 1))?.lines == ["A", "B"])
        dispatchWheel(to: runtime, button: .wheelDown, column: 1, row: 1)
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: ExplicitIDScrollHost(id: 1))?.lines == ["B", "C"])
        #expect(runtime.block(from: ExplicitIDScrollHost(id: 2))?.lines == ["A", "B"])
    }
}
