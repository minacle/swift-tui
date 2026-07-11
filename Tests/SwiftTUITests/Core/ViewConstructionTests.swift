import Foundation
import Observation
import Testing
@testable import SwiftTUI

@Suite("View Construction")
struct ViewConstructionTests {

    @Test
    func `a composite view renders the content of its body`() {
        struct ContentView: View {
            var body: some View {
                Text("Hello from body")
            }
        }

        #expect(ViewResolver.text(from: ContentView()) == "Hello from body")
    }

    @Test
    func `a view builder renders multiple root children in declaration order`() {
        struct ContentView: View {
            var body: some View {
                Text("First")
                Text("Second")
            }
        }

        #expect(ViewResolver.text(from: ContentView()) == "First \nSecond")
    }

    @Test
    func `an empty view builder renders no content`() {
        struct ContentView: View {
            var body: some View {}
        }

        #expect(ViewResolver.text(from: ContentView()) == nil)
    }

    @Test
    func `an if statement in a view builder conditionally includes its content`() {
        struct ContentView: View {

            let isVisible: Bool

            var body: some View {
                VStack(alignment: .leading, spacing: 0) {
                    Text("A")
                    if isVisible {
                        Text("B")
                    }
                    Text("C")
                }
            }
        }

        #expect(ViewResolver.block(from: ContentView(isVisible: true))?.lines == ["A", "B", "C"])
        #expect(ViewResolver.block(from: ContentView(isVisible: false))?.lines == ["A", "C"])
    }

    @Test
    func `an if-else statement in a view builder renders the selected branch`() {
        struct ContentView: View {

            let usesFirstBranch: Bool

            var body: some View {
                if usesFirstBranch {
                    Text("First")
                }
                else {
                    Text("Second")
                }
            }
        }

        #expect(ViewResolver.text(from: ContentView(usesFirstBranch: true)) == "First")
        #expect(ViewResolver.text(from: ContentView(usesFirstBranch: false)) == "Second")
    }

    @Test
    func `conditional view-builder branches flatten multiple children into their parent`() {
        struct ContentView: View {

            let usesFirstBranch: Bool

            var body: some View {
                VStack(alignment: .leading, spacing: 0) {
                    if usesFirstBranch {
                        Text("A")
                        Text("B")
                    }
                    else {
                        Text("C")
                    }
                    Text("D")
                }
            }
        }

        #expect(ViewResolver.block(from: ContentView(usesFirstBranch: true))?.lines == ["A", "B", "D"])
        #expect(ViewResolver.block(from: ContentView(usesFirstBranch: false))?.lines == ["C", "D"])
    }

    @Test
    func `limited-availability view-builder content renders normally`() {
        let view = VStack(alignment: .leading, spacing: 0) {
            ViewBuilder.buildLimitedAvailability(Text("limited"))
        }

        #expect(ViewResolver.block(from: view)?.lines == ["limited"])
    }

    @Test
    func `a group flattens its children into a vertical stack`() {
        let view = VStack(alignment: .leading, spacing: 0) {
            Group {
                Text("A")
                Text("B")
            }
            Text("C")
        }

        #expect(ViewResolver.block(from: view)?.lines == ["A", "B", "C"])
    }

    @Test
    func `a root group renders its children in declaration order`() {
        let view = Group {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.text(from: view) == "A\nB")
    }

    @Test
    func `nested groups flatten without introducing layout`() {
        let view = VStack(alignment: .leading, spacing: 0) {
            Text("A")
            Group {
                Group {
                    Text("B")
                    Text("C")
                }
            }
            Text("D")
        }

        #expect(ViewResolver.block(from: view)?.lines == ["A", "B", "C", "D"])
    }
}
