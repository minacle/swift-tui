import Testing
@testable import SwiftTUIEssentials

@Suite("Lazy Stack Layout")
struct LazyStackLayoutTests {

    @Test
    func `lazy stacks match eager stacks when rendered without a same-axis viewport`() {
        let lazyHorizontal = LazyHStack(alignment: .bottom, spacing: 1) {
            Text("A")
            Text("BC")
        }
        let eagerHorizontal = HStack(alignment: .bottom, spacing: 1) {
            Text("A")
            Text("BC")
        }
        let lazyVertical = LazyVStack(alignment: .trailing, spacing: 0) {
            Text("A")
            Text("BC")
        }
        let eagerVertical = VStack(alignment: .trailing, spacing: 0) {
            Text("A")
            Text("BC")
        }

        #expect(ViewResolver.block(from: lazyHorizontal) == ViewResolver.block(from: eagerHorizontal))
        #expect(ViewResolver.block(from: lazyVertical) == ViewResolver.block(from: eagerVertical))
    }

    @Test
    func `negative lazy stack spacing renders as zero cells`() {
        let horizontal = LazyHStack(spacing: -2) {
            Text("A")
            Text("B")
        }
        let vertical = LazyVStack(spacing: -2) {
            Text("A")
            Text("B")
        }

        #expect(ViewResolver.block(from: horizontal)?.lines == ["AB"])
        #expect(ViewResolver.block(from: vertical)?.lines == ["A", "B"])
    }

    @Test
    func `Section flattens its header content and footer in source order`() {
        let section = Section {
            Text("body")
        } header: {
            Text("header")
        } footer: {
            Text("footer")
        }

        #expect(ViewResolver.block(from: section)?.trimmedLines == ["header", "body", "footer"])
    }

    @Test
    func `Section convenience initializers omit only their absent supplementary views`() {
        let contentOnly = Section {
            Text("body")
        }
        let titled = Section("title") {
            Text("body")
        }
        let footerOnly = Section {
            Text("body")
        } footer: {
            Text("footer")
        }

        #expect(ViewResolver.block(from: contentOnly)?.trimmedLines == ["body"])
        #expect(ViewResolver.block(from: titled)?.trimmedLines == ["title", "body"])
        #expect(ViewResolver.block(from: footerOnly)?.trimmedLines == ["body", "footer"])
    }

    @Test
    func `lazy stack content flattens Group AnyView and conditional wrappers`() {
        let includesConditional = true
        let view = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Group {
                    AnyView(Text("A"))
                    if includesConditional {
                        Text("B")
                    }
                }
                Text("C")
            }
        }
        .frame(width: 1, height: 3)

        #expect(ViewResolver.block(from: view)?.lines == ["A", "B", "C"])
    }
}
