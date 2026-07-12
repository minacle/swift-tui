/// Exposes builder content as independently measurable container children.
protocol FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement]

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild]
}

extension FlattenableViewContent {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        StackRenderer.vertical(
            renderedElements(in: proposal, path: path, runtime: runtime).map { element in
                let isSpacer: Bool
                switch element {
                case .block:
                    isSpacer = false
                case .spacer:
                    isSpacer = true
                }

                return StackChild(
                    traits: LayoutTraits(),
                    isSpacer: isSpacer,
                    suppressesVerticalFlexInParentStack: false,
                    render: { _, _ in element }
                )
            },
            alignment: .leading,
            spacing: 0,
            proposal: proposal
        )
    }
}

extension AnyView: FlattenableViewContent, GridContentRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        storage.layoutTraits
    }

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        storage.renderedElements(in: proposal, path: path, runtime: runtime)
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        storage.stackChildren(in: proposal, path: path, runtime: runtime)
    }

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        storage.gridItems(in: proposal, path: path, runtime: runtime)
    }
}

extension OptionalViewContent: LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        content.map(ViewResolver.layoutTraits) ?? LayoutTraits()
    }
}

extension ConditionalViewContent: LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        switch storage {
        case .trueContent(let content):
            return ViewResolver.layoutTraits(from: content)
        case .falseContent(let content):
            return ViewResolver.layoutTraits(from: content)
        }
    }
}

extension LimitedAvailabilityViewContent: LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }
}

extension GridRow: FlattenableViewContent, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.stackLayoutTraits(
            from: content,
            propagatedAxes: [.horizontal, .vertical],
            spacerAxis: nil
        )
    }

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension Group: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension OptionalViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        guard let content else {
            return []
        }

        return ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        guard let content else {
            return []
        }

        return ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ConditionalViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.elements(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.elements(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.stackChildren(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.stackChildren(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }
}

extension LimitedAvailabilityViewContent: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ForEach: FlattenableViewContent where Content: View {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let renderedElements = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(
                at: path,
                id: elementID
            ) ?? offset
            let childPath = path + [childIndex]
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.elements(
                from: child,
                in: proposal,
                path: childPath,
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return renderedElements
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let children = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(
                at: path,
                id: elementID
            ) ?? offset
            let childPath = path + [childIndex]
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.stackChildren(
                from: child,
                in: proposal,
                path: childPath,
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return children
    }

    private func contentElement(
        _ element: Data.Element,
        runtime: StateRuntime?
    ) -> Content {
        guard let runtime, let contextPath else {
            return content(element)
        }

        return runtime.withView(at: contextPath, mode: .render) {
            content(element)
        }
    }
}

extension Group: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        ViewResolver.gridItems(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension OptionalViewContent: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        guard let content else {
            return []
        }
        return ViewResolver.gridItems(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ConditionalViewContent: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.gridItems(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        case .falseContent(let content):
            ViewResolver.gridItems(
                from: content,
                in: proposal,
                path: path + [1],
                runtime: runtime
            )
        }
    }
}

extension LimitedAvailabilityViewContent: GridContentRenderable {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        ViewResolver.gridItems(
            from: content,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

extension ForEach: GridContentRenderable where Content: View {

    func gridItems(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let items = data.enumerated().flatMap { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(at: path, id: elementID) ?? offset
            let child = contentElement(element, runtime: runtime)
            return ViewResolver.gridItems(
                from: child,
                in: proposal,
                path: path + [childIndex],
                runtime: runtime
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return items
    }
}
