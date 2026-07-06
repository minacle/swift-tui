nonisolated struct ViewGroup: View {

    typealias Body = Never

    let elements: [AnyViewStorage]

    init(_ elements: [AnyViewStorage]) {
        self.elements = elements
    }
}

nonisolated struct AnyViewStorage {

    private let element: @MainActor (RenderProposal?, [Int], StateRuntime?) -> RenderedElement?

    private let elements: @MainActor (RenderProposal?, [Int], StateRuntime?) -> [RenderedElement]

    private let stackChildElements: @MainActor (RenderProposal?, [Int], StateRuntime?) -> [StackChild]

    private let traits: @MainActor () -> LayoutTraits

    nonisolated init<Content: View>(_ content: Content) {
        let box = AnyViewStorageBox(content)
        self.element = { proposal, path, runtime in
            ViewResolver.element(
                from: box.content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
        self.stackChildElements = { proposal, path, runtime in
            ViewResolver.stackChildren(
                from: box.content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
        self.elements = { proposal, path, runtime in
            ViewResolver.elements(
                from: box.content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
        self.traits = {
            ViewResolver.layoutTraits(from: box.content)
        }
    }

    @MainActor
    func renderedElement(in proposal: RenderProposal? = nil) -> RenderedElement? {
        renderedElement(in: proposal, path: [], runtime: nil)
    }

    @MainActor
    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        element(proposal, path, runtime)
    }

    @MainActor
    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        elements(proposal, path, runtime)
    }

    @MainActor
    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        stackChildElements(proposal, path, runtime)
    }

    @MainActor
    var layoutTraits: LayoutTraits {
        traits()
    }

    @MainActor
    func renderedBlock() -> RenderedBlock? {
        renderedBlock(in: nil)
    }

    @MainActor
    func renderedBlock(in proposal: RenderProposal?) -> RenderedBlock? {
        guard case .block(let block) = renderedElement(in: proposal) else {
            return nil
        }

        return block
    }
}

private nonisolated final class AnyViewStorageBox<Content: View>: @unchecked Sendable {

    let content: Content

    init(_ content: Content) {
        self.content = content
    }
}
