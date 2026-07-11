import Testing

@testable import SwiftTUIRuns
import Terminal

@Suite("Run Groups")
struct RunGroupTests {

    @Test
    func `nested groups preserve source order and recursively concatenate content`() {
        let suffixes = ["C", "D"]
        let group = RunGroup {
            Run("A")
            RunGroup {
                Run("B")
                for suffix in suffixes {
                    Run(suffix)
                }
            }
        }

        #expect(group.content == "ABCD")
    }

    @Test
    func `builder control flow preserves conditional switched and repeated runs`() {
        let includesPrefix = true
        let choice = 2
        let values = ["C", "D"]
        let group = RunGroup {
            if includesPrefix {
                Run("A")
            }
            switch choice {
            case 1:
                Run("one")
            default:
                Run("B")
            }
            for value in values {
                Run(value)
            }
        }

        #expect(group.content == "ABCD")
    }

    @Test
    func `a child explicitly disables an attribute inherited from its group`() {
        let group = RunGroup {
            Run("A")
            Run("B").bold(false)
        }
        .bold()

        let laidOutRuns = group.layout().lines.flatMap(\.runs)
        #expect(laidOutRuns.map(\.attributes.isBold) == [true, false])
    }
}
