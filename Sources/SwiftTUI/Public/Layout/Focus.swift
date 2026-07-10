/// A transparent view modifier that marks its content as a focus candidate.
struct FocusableView<Content: View>: View, FocusModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let isFocusable: Bool

    var layoutTraits: LayoutTraits {
        render(isFocused: false) {
            ViewResolver.layoutTraits(from: content)
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerFocusable(isFocusable, at: path)
        guard var block = render(
            isFocused: isFocusable && runtime?.isFocused(at: path) == true,
            operation: {
                ViewResolver.block(
                    from: content,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        ) else {
            return nil
        }

        if isFocusable {
            block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
        }

        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        runtime?.registerFocusable(isFocusable, at: path)
        guard let element = render(
            isFocused: isFocusable && runtime?.isFocused(at: path) == true,
            operation: {
                ViewResolver.element(
                    from: content,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        ) else {
            return nil
        }

        guard isFocusable, case .block(var block) = element else {
            return element
        }

        block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
        return .block(block)
    }

    private func render<Value>(
        isFocused: Bool,
        operation: () -> Value
    ) -> Value {
        var environment = EnvironmentRenderContext.current
        environment.isFocused = isFocused
        return EnvironmentRenderContext.withValues(environment, perform: operation)
    }
}

/// A transparent view modifier that binds focus state to its content.
struct FocusedView<Content: View>: View, FocusModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let attachment: any FocusAttachment

    var layoutTraits: LayoutTraits {
        render(isFocused: false) {
            ViewResolver.layoutTraits(from: content)
        }
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        runtime?.registerFocusable(true, at: path)
        runtime?.registerFocusAttachment(attachment, at: path)
        guard var block = render(
            isFocused: runtime?.isFocused(at: path) == true,
            operation: {
                ViewResolver.block(
                    from: content,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        ) else {
            return nil
        }

        if !block.focusRegions.contains(where: { $0.path == path }) {
            block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
        }
        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        runtime?.registerFocusable(true, at: path)
        runtime?.registerFocusAttachment(attachment, at: path)
        guard let element = render(
            isFocused: runtime?.isFocused(at: path) == true,
            operation: {
                ViewResolver.element(
                    from: content,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        ) else {
            return nil
        }

        guard case .block(var block) = element else {
            return element
        }

        if !block.focusRegions.contains(where: { $0.path == path }) {
            block.focusRegions.append(RenderedFocusRegion(path: path, frame: block.bounds))
        }
        return .block(block)
    }

    private func render<Value>(
        isFocused: Bool,
        operation: () -> Value
    ) -> Value {
        var environment = EnvironmentRenderContext.current
        environment.isFocused = isFocused
        return EnvironmentRenderContext.withValues(environment, perform: operation)
    }
}

protocol FocusModifierRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement?
}

public extension View {

    /// Specifies whether this view can receive focus.
    ///
    /// Focusable views register their rendered terminal frame as a focus region.
    ///
    /// - Parameter isFocusable: Pass `true` to allow focus, or `false` to
    ///   explicitly disable focus registration.
    /// - Returns: A view with focus registration behavior.
    func focusable(_ isFocusable: Bool = true) -> some View {
        FocusableView(content: self, isFocusable: isFocusable)
    }

    /// Binds this view's focus state to a Boolean focus state value.
    ///
    /// - Parameter condition: The focus binding that becomes `true` while this
    ///   view has focus.
    /// - Returns: A view connected to the supplied focus binding.
    func focused(_ condition: FocusState<Bool>.Binding) -> some View {
        FocusedView(content: self, attachment: condition.focusAttachment())
    }

    /// Binds this view's focus state to the given focus state value.
    ///
    /// - Parameters:
    ///   - binding: The optional focus binding that stores the focused value.
    ///   - value: The value assigned while this view has focus.
    /// - Returns: A view connected to the supplied focus binding.
    func focused<Value>(
        _ binding: FocusState<Value?>.Binding,
        equals value: Value
    ) -> some View where Value: Hashable {
        FocusedView(content: self, attachment: binding.focusAttachment(equals: value))
    }
}
