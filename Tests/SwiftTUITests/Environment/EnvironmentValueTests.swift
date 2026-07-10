import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("Environment Values")
struct EnvironmentValueTests {

    @Test
    func `an environment property reads the default value for its key`() {
        #expect(ViewResolver.text(from: EnvironmentMarkerText()) == "default")
    }

    @Test
    func `isScrollEnabled defaults to true and scrollDisabled propagates false to descendants`() {
        #expect(EnvironmentValues().isScrollEnabled)
        #expect(ViewResolver.text(from: IsScrollEnabledEnvironmentMarkerText()) == "enabled")
        #expect(
            ViewResolver.text(
                from: IsScrollEnabledEnvironmentMarkerText().scrollDisabled(true)
            ) == "disabled"
        )
    }

    @Test
    func `an enabled descendant cannot override a disabled scrolling ancestor`() {
        let view = IsScrollEnabledEnvironmentMarkerText()
            .scrollDisabled(false)
            .scrollDisabled(true)

        #expect(ViewResolver.text(from: view) == "disabled")
    }

    @Test
    func `an environment property wrapper exposes its default before view resolution`() {
        let marker = Environment(\.testMarker)

        #expect(marker.wrappedValue == "default")
    }

    @Test
    func `an injected environment value is inherited by a child view`() {
        let view = EnvironmentMarkerText()
            .environment(\.testMarker, "parent")

        #expect(ViewResolver.text(from: view) == "parent")
    }

    @Test
    func `the nearest environment value overrides an ancestor value`() {
        let view = VStack(alignment: .leading) {
            EnvironmentMarkerText()
            EnvironmentMarkerText()
                .environment(\.testMarker, "child!")
        }
        .environment(\.testMarker, "parent")

        #expect(ViewResolver.block(from: view)?.lines == ["parent", "child!"])
    }

    @Test
    func `transformEnvironment mutates the inherited value`() {
        let view = EnvironmentMarkerText()
            .transformEnvironment(\.testMarker) {
                $0 += "-transformed"
            }
            .environment(\.testMarker, "base")

        #expect(ViewResolver.text(from: view) == "base-transformed")
    }

    @Test
    func `an environment override applies only to the modified subtree`() {
        let view = VStack(alignment: .leading) {
            EnvironmentMarkerText()
                .environment(\.testMarker, "changed")
            EnvironmentMarkerText()
        }

        #expect(ViewResolver.block(from: view)?.lines == ["changed", "default"])
    }

    @Test
    func `a state-driven environment value updates after invalidation and rerender`() {
        let runtime = StateRuntime()
        let probe = BindingProbe<String>()
        let view = EnvironmentStateMarkerView(probe: probe)

        #expect(runtime.block(from: view)?.text == "initial")

        probe.binding?.wrappedValue = "updated"
        #expect(runtime.consumeInvalidation())
        #expect(runtime.block(from: view)?.text == "updated")
    }

    @Test
    func `a value captured by a parent body remains distinct from a child environment override`() {
        let view = ParentCapturedEnvironmentMarkerView()
            .environment(\.testMarker, "parent")

        #expect(ViewResolver.text(from: view) == "captured parent direct child")
    }

    @Test
    func `buttonSizing defaults to automatic in environment values and descendants`() {
        #expect(EnvironmentValues().buttonSizing == .automatic)
        #expect(ViewResolver.text(from: ButtonSizingMarkerText()) == "automatic")
    }

    @Test
    func `the buttonSizing modifier propagates its value to descendants`() {
        let view = VStack(alignment: .leading) {
            ButtonSizingMarkerText()
        }
        .buttonSizing(.flexible)

        #expect(ViewResolver.text(from: view) == "flexible")
    }

    @Test
    func `isEnabled defaults to true in environment values and descendants`() {
        #expect(EnvironmentValues().isEnabled)
        #expect(ViewResolver.text(from: IsEnabledMarkerText()) == "enabled")
    }

    @Test
    func `disabled writes the inverse value to isEnabled`() {
        #expect(ViewResolver.text(from: IsEnabledMarkerText().disabled(true)) == "disabled")
        #expect(ViewResolver.text(from: IsEnabledMarkerText().disabled(false)) == "enabled")
    }

    @Test
    func `an enabled descendant cannot override a disabled ancestor`() {
        let view = VStack(alignment: .leading) {
            IsEnabledMarkerText()
                .disabled(false)
        }
        .disabled(true)

        #expect(ViewResolver.text(from: view) == "disabled")
    }

    @Test
    func `disabled applies only to the modified subtree`() {
        let view = VStack(alignment: .leading) {
            IsEnabledMarkerText()
                .disabled(true)
            IsEnabledMarkerText()
        }

        #expect(ViewResolver.block(from: view)?.lines == ["disabled", "enabled "])
    }
}
