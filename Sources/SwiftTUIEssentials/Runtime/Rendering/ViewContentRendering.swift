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
            ).map { element in
                guard case .block(var block) = element else {
                    return element
                }

                block.identifiedRegions.append(
                    RenderedIdentifiedRegion(id: elementID, frame: block.bounds)
                )
                return .block(block)
            }
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
            ).map {
                $0.identified(by: elementID)
            }
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

extension AnyView: LazyViewContent {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor] {
        storage.lazyStackDescriptors(
            path: path,
            runtime: runtime,
            sectionID: sectionID
        )
    }
}

extension Group: LazyViewContent {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor] {
        ViewResolver.lazyStackDescriptors(
            from: content,
            path: path + [0],
            runtime: runtime,
            sectionID: sectionID
        )
    }
}

extension OptionalViewContent: LazyViewContent {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor] {
        guard let content else {
            return []
        }

        return ViewResolver.lazyStackDescriptors(
            from: content,
            path: path + [0],
            runtime: runtime,
            sectionID: sectionID
        )
    }
}

extension ConditionalViewContent: LazyViewContent {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor] {
        switch storage {
        case .trueContent(let content):
            ViewResolver.lazyStackDescriptors(
                from: content,
                path: path + [0],
                runtime: runtime,
                sectionID: sectionID
            )
        case .falseContent(let content):
            ViewResolver.lazyStackDescriptors(
                from: content,
                path: path + [1],
                runtime: runtime,
                sectionID: sectionID
            )
        }
    }
}

extension LimitedAvailabilityViewContent: LazyViewContent {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor] {
        ViewResolver.lazyStackDescriptors(
            from: content,
            path: path + [0],
            runtime: runtime,
            sectionID: sectionID
        )
    }
}

extension ForEach: LazyViewContent where Content: View {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor] {
        var seenIDs: Set<AnyHashable> = []
        var activeIDs: [AnyHashable] = []
        let descriptors = data.enumerated().map { offset, element in
            let elementID = AnyHashable(element[keyPath: id])
            precondition(
                seenIDs.insert(elementID).inserted,
                "ForEach data IDs must be unique."
            )

            activeIDs.append(elementID)
            let childIndex = runtime?.forEachChildIndex(at: path, id: elementID) ?? offset
            let childPath = path + [childIndex]
            let identity = AnyHashable(
                LazyStackDescriptorIdentity(
                    path: path,
                    value: elementID,
                    role: .item
                )
            )
            return LazyStackDescriptor(
                identity: identity,
                scrollID: elementID,
                sectionID: sectionID,
                role: .item,
                expand: {
                    let child = contentElement(element, runtime: runtime)
                    var descriptors = ViewResolver.lazyStackDescriptors(
                        from: child,
                        path: childPath,
                        runtime: runtime,
                        sectionID: sectionID
                    )
                    if !descriptors.isEmpty {
                        descriptors[0].scrollID = elementID
                    }
                    return descriptors
                },
                render: { proposal, suppressRegistrations in
                    let render = {
                        let child = contentElement(element, runtime: runtime)
                        return ViewResolver.element(
                            from: child,
                            in: proposal,
                            path: childPath,
                            runtime: runtime
                        )
                    }
                    guard suppressRegistrations else {
                        return render()
                    }

                    return LayoutMeasurementContext.withMeasurement {
                        runtime?.withoutRenderRegistrations(render) ?? render()
                    }
                }
            )
        }

        runtime?.finishForEachRender(at: path, activeIDs: activeIDs)
        return descriptors
    }
}

extension Section: FlattenableViewContent {

    func renderedElements(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        ViewResolver.elements(
            from: parent,
            in: proposal,
            path: path + [0],
            runtime: runtime
        ) + ViewResolver.elements(
            from: content,
            in: proposal,
            path: path + [1],
            runtime: runtime
        ) + ViewResolver.elements(
            from: footer,
            in: proposal,
            path: path + [2],
            runtime: runtime
        )
    }

    func stackChildren(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        ViewResolver.stackChildren(
            from: parent,
            in: proposal,
            path: path + [0],
            runtime: runtime
        ) + ViewResolver.stackChildren(
            from: content,
            in: proposal,
            path: path + [1],
            runtime: runtime
        ) + ViewResolver.stackChildren(
            from: footer,
            in: proposal,
            path: path + [2],
            runtime: runtime
        )
    }
}

extension Section: LazyViewContent {

    func lazyStackDescriptors(
        path: [Int],
        runtime: StateRuntime?,
        sectionID _: AnyHashable?
    ) -> [LazyStackDescriptor] {
        let sectionID = AnyHashable(
            LazyStackDescriptorIdentity(
                path: path,
                value: nil,
                role: .section
            )
        )
        var descriptors: [LazyStackDescriptor] = []
        if !(parent is EmptyView) {
            descriptors.append(
                supplementaryDescriptor(
                    from: parent,
                    role: .sectionHeader,
                    path: path + [0],
                    sectionID: sectionID,
                    runtime: runtime
                )
            )
        }
        descriptors.append(
            contentsOf: ViewResolver.lazyStackDescriptors(
                from: content,
                path: path + [1],
                runtime: runtime,
                sectionID: sectionID
            )
        )
        if !(footer is EmptyView) {
            descriptors.append(
                supplementaryDescriptor(
                    from: footer,
                    role: .sectionFooter,
                    path: path + [2],
                    sectionID: sectionID,
                    runtime: runtime
                )
            )
        }
        return descriptors
    }

    private func supplementaryDescriptor<Supplementary: View>(
        from view: Supplementary,
        role: LazyStackDescriptorRole,
        path: [Int],
        sectionID: AnyHashable,
        runtime: StateRuntime?
    ) -> LazyStackDescriptor {
        let identity = AnyHashable(
            LazyStackDescriptorIdentity(path: path, value: nil, role: role)
        )
        return LazyStackDescriptor(
            identity: identity,
            scrollID: nil,
            sectionID: sectionID,
            role: role,
            expand: nil,
            render: { proposal, suppressRegistrations in
                let render = {
                    ViewResolver.element(
                        from: view,
                        in: proposal,
                        path: path,
                        runtime: runtime
                    )
                }
                guard suppressRegistrations else {
                    return render()
                }

                return LayoutMeasurementContext.withMeasurement {
                    runtime?.withoutRenderRegistrations(render) ?? render()
                }
            }
        )
    }
}
