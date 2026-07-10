import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Bindings")
struct BindingTests {

    @Test
    func `a closure-backed binding reads through its getter and writes through its setter`() {
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

    @Test
    func `a binding initialized from a projected value shares the original storage`() {
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

    @Test
    func `a constant binding ignores attempted writes`() {
        let binding = Binding.constant("fixed")

        binding.wrappedValue = "changed"

        #expect(binding.wrappedValue == "fixed")
    }

    @Test
    func `dynamic member lookup projects a binding to a nested property`() {
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

    @Test
    func `mutating a state binding invalidates and rerenders the root view`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<Int>()

        #expect(runtime.block(from: RootCounterView(probe: probe))?.text == "0")

        probe.binding?.wrappedValue = 1

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: RootCounterView(probe: probe))?.text == "1")
    }

    @Test
    func `child state survives reevaluation of its parent view`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<Int>()

        #expect(runtime.block(from: ParentCounterView(probe: probe))?.text == "0")

        probe.binding?.wrappedValue = 5

        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: ParentCounterView(probe: probe))?.text == "5")
    }

    @Test
    func `sibling views keep independent state storage`() {
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

    @Test
    func `conditional branches keep independent state storage across branch switches`() {
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
}
