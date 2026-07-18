/// Resolves declarative view values into layout traits and rendered elements.
///
/// Primitive and specialized renderable views are handled directly. Other
/// values fall back to recursive `body` evaluation. The integer path passed
/// through that recursion is the stable identity used to associate render-time
/// dynamic properties, state, actions, and interaction regions with a view.
enum ViewResolver {

    private enum BlockResolution {

        case unresolved

        case resolved(RenderedBlock?)
    }

    static func text<Content: View>(from view: Content) -> String? {
        block(from: view)?.text
    }

    static func block<Content: View>(from view: Content) -> RenderedBlock? {
        block(from: view, in: nil)
    }

    static func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> RenderedBlock? {
        block(
            from: view,
            in: rootProposal(for: view, proposal: proposal),
            path: [],
            runtime: nil
        )
    }

    static func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        LayoutMeasurementContext.withRenderPass {
            resolveBlock(
                from: view,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    private static func resolveBlock<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        switch directlyResolvedBlock(from: view, in: proposal, path: path, runtime: runtime) {
        case .resolved(let block):
            return block
        case .unresolved:
            break
        }

        if let geometryReader = view as? any GeometryReaderRenderable {
            return geometryReader.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let layout = view as? any LayoutRenderable {
            return layout.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let viewThatFits = view as? any ViewThatFitsRenderable {
            return viewThatFits.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let navigation = view as? any NavigationRenderable {
            return navigation.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any LayoutModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any ScrollPositionModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any EnvironmentModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any LifecycleModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any ChangeModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any HiddenModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any TerminationModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any OpenURLModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any FocusModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        if let modifier = view as? any InputModifierRenderable {
            return modifier.renderedBlock(in: proposal, path: path, runtime: runtime)
        }

        let body = body(from: view, path: path, runtime: runtime)
        return block(from: body, in: proposal, path: path + [0], runtime: runtime)
    }

    static func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> RenderedElement? {
        element(from: view, in: proposal, path: [], runtime: nil)
    }

    static func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        LayoutMeasurementContext.withRenderPass {
            LayoutMeasurementContext.cachedElement(
                type: Content.self,
                path: path,
                proposal: proposal,
                alignmentKeys: ExplicitAlignmentQueryContext.keys,
                stackAxis: StackAxisContext.axis
            ) {
                resolveElement(
                    from: view,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        }
    }

    private static func resolveElement<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        switch directlyResolvedBlock(from: view, in: proposal, path: path, runtime: runtime) {
        case .resolved(let block):
            if let spacer = view as? Spacer {
                return .spacer(minLength: spacer.minLength ?? 0)
            }
            return block.map { .block($0) }
        case .unresolved:
            break
        }

        if let geometryReader = view as? any GeometryReaderRenderable {
            return geometryReader.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let layout = view as? any LayoutRenderable {
            return layout.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let viewThatFits = view as? any ViewThatFitsRenderable {
            return viewThatFits.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let navigation = view as? any NavigationRenderable {
            return navigation.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any LayoutModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any ScrollPositionModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any EnvironmentModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any LifecycleModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any ChangeModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any HiddenModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any TerminationModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any OpenURLModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any FocusModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        if let modifier = view as? any InputModifierRenderable {
            return modifier.renderedElement(
                in: proposal,
                path: path,
                runtime: runtime
            )
        }

        let body = body(from: view, path: path, runtime: runtime)
        return element(from: body, in: proposal, path: path + [0], runtime: runtime)
    }

    private static func directlyResolvedBlock<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> BlockResolution {
        if let text = view as? Text {
            return .resolved(
                TextLayoutRenderer.block(
                    for: text,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            )
        }

        if view is EmptyView {
            return .resolved(nil)
        }

        if let spacer = view as? Spacer {
            return .resolved(block(for: spacer, in: proposal))
        }

        if let scroll = view as? any ScrollRenderable {
            return .resolved(scroll.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let editableText = view as? any EditableTextRenderable {
            return .resolved(
                editableText.renderedBlock(in: proposal, path: path, runtime: runtime)
            )
        }

        if let divider = view as? any DividerRenderable {
            return .resolved(
                DividerRenderer.renderedBlock(
                    drawingSet: divider.dividerDrawingSet,
                    proposal: proposal
                )
            )
        }

        if let fillShape = view as? any FillShapeRenderable {
            return .resolved(fillShape.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let shape = view as? any ShapeRenderable {
            return .resolved(ShapeRenderer.defaultBlock(shape: shape, proposal: proposal))
        }

        if let box = view as? any BoxRenderable {
            return .resolved(box.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let group = view as? ViewGroup {
            return .resolved(
                StackRenderer.vertical(
                    group.elements.enumerated().flatMap { index, element in
                        element.stackChildren(
                            in: proposal,
                            path: path + [index],
                            runtime: runtime
                        )
                    },
                    alignment: .leading,
                    spacing: 0,
                    proposal: proposal
                )
            )
        }

        if let content = view as? any FlattenableViewContent {
            return .resolved(content.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        if let stack = view as? any StackRenderable {
            return .resolved(stack.renderedBlock(in: proposal, path: path, runtime: runtime))
        }

        return .unresolved
    }

    private static func block(
        for spacer: Spacer,
        in proposal: RenderProposal?
    ) -> RenderedBlock? {
        let minLength = spacer.minLength ?? 0
        let width = max(proposal?.columns ?? minLength, minLength)
        let height = max(proposal?.rows ?? minLength, minLength)
        guard width > 0 || height > 0 else {
            return nil
        }

        let renderedHeight = max(height, 1)
        return RenderedBlock(
            runs: [],
            width: width,
            height: renderedHeight,
            paddedRows: Set(0..<renderedHeight)
        )
    }
}


extension ViewResolver {

    static func blocks<Content: View>(from view: Content) -> [RenderedBlock] {
        if let group = view as? ViewGroup {
            return group.elements.flatMap {
                $0.renderedElements(in: nil, path: [], runtime: nil).compactMap { element in
                    guard case .block(let block) = element else {
                        return nil
                    }

                    return block
                }
            }
        }

        return block(from: view).map { [$0] } ?? []
    }

    static func elements<Content: View>(
        from view: Content,
        in proposal: RenderProposal?
    ) -> [RenderedElement] {
        elements(from: view, in: proposal, path: [], runtime: nil)
    }

    static func elements<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [RenderedElement] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.renderedElements(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any FlattenableViewContent {
            return content.renderedElements(in: proposal, path: path, runtime: runtime)
        }

        return element(
            from: view,
            in: proposal,
            path: path,
            runtime: runtime
        ).map { [$0] } ?? []
    }

    static func gridItems<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [GridItem] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.gridItems(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any GridContentRenderable {
            return content.gridItems(in: proposal, path: path, runtime: runtime)
        }

        if view is EmptyView {
            return []
        }

        if Content.Body.self != Never.self {
            return gridItems(
                from: body(from: view, path: path, runtime: runtime),
                in: proposal,
                path: path + [0],
                runtime: runtime
            )
        }

        return stackChildren(
            from: view,
            in: proposal,
            path: path,
            runtime: runtime
        ).map(GridItem.fullWidth)
    }

    static func stackChildren<Content: View>(
        from view: Content,
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> [StackChild] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.stackChildren(
                    in: proposal,
                    path: path + [index],
                    runtime: runtime
                )
            }
        }

        if let content = view as? any FlattenableViewContent {
            return content.stackChildren(in: proposal, path: path, runtime: runtime)
        }

        let traits = layoutTraits(from: view)
        return [
            StackChild(
                traits: traits,
                isSpacer: view is Spacer,
                isEmptyView: view is EmptyView,
                suppressesVerticalFlexInParentStack: view is any VerticalStackFlexSuppressing,
                render: { childProposal, suppressRegistrations in
                    let render = {
                        element(
                            from: view,
                            in: childProposal,
                            path: path,
                            runtime: runtime
                        )
                    }

                    if suppressRegistrations {
                        return LayoutMeasurementContext.withMeasurement {
                            runtime?.withoutRenderRegistrations(render) ?? render()
                        }
                    }

                    return render()
                }
            ),
        ]
    }

    static func lazyStackDescriptors<Content: View>(
        from view: Content,
        path: [Int],
        runtime: StateRuntime?,
        sectionID: AnyHashable?
    ) -> [LazyStackDescriptor] {
        if let group = view as? ViewGroup {
            return group.elements.enumerated().flatMap { index, element in
                element.lazyStackDescriptors(
                    path: path + [index],
                    runtime: runtime,
                    sectionID: sectionID
                )
            }
        }

        if let content = view as? any LazyViewContent {
            return content.lazyStackDescriptors(
                path: path,
                runtime: runtime,
                sectionID: sectionID
            )
        }

        if view is EmptyView {
            return []
        }

        let identity = AnyHashable(
            LazyStackDescriptorIdentity(
                path: path,
                value: nil,
                role: .item
            )
        )
        return [
            LazyStackDescriptor(
                identity: identity,
                scrollID: nil,
                sectionID: sectionID,
                role: .item,
                expand: nil,
                render: { childProposal, suppressRegistrations in
                    let render = {
                        element(
                            from: view,
                            in: childProposal,
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
            ),
        ]
    }

    static func layoutTraits<Content: View>(from view: Content) -> LayoutTraits {
        if let traits = view as? any LayoutTraitRenderable {
            return traits.layoutTraits
        }

        guard Content.Body.self != Never.self else {
            return LayoutTraits()
        }

        return layoutTraits(from: body(from: view, path: [], runtime: nil))
    }

    static func stackLayoutTraits<Content: View>(
        from content: Content,
        propagatedAxes: Axis.Set,
        spacerAxis: Axis?
    ) -> LayoutTraits {
        let flexibleAxes = stackChildren(
            from: content,
            in: nil,
            path: [],
            runtime: nil
        )
        .reduce(into: Axis.Set()) { axes, child in
            axes.formUnion(child.traits.flexibleAxes.intersection(propagatedAxes))
            guard child.isSpacer, let spacerAxis else {
                return
            }

            switch spacerAxis {
            case .horizontal:
                axes.formUnion(.horizontal)
            case .vertical:
                axes.formUnion(.vertical)
            }
        }

        return LayoutTraits(flexibleAxes: flexibleAxes)
    }

    /// Evaluates a view body inside its render-time state identity context.
    private static func body<Content: View>(
        from view: Content,
        path: [Int],
        runtime: StateRuntime?
    ) -> Content.Body {
        guard let runtime else {
            materializeDynamicEnvironmentProperties(in: view)
            return view.body
        }

        return runtime.withView(at: path, mode: .render) {
            runtime.materializeDynamicProperties(in: view)
            return view.body
        }
    }

    static func rootProposal<Content: View>(
        for view: Content,
        proposal: RenderProposal?
    ) -> RenderProposal? {
        guard let traits = view as? any LayoutTraitRenderable else {
            return proposal
        }

        let axes = traits.layoutTraits.flexibleAxes
        guard !axes.isEmpty else {
            return proposal
        }

        return RenderProposal(
            columns: axes.contains(.horizontal) ? proposal?.columns : nil,
            rows: axes.contains(.vertical) ? proposal?.rows : nil
        )
    }
}
