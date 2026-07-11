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
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerFocusable(isFocusable, at: interactionPath)
        guard var block = render(
            isFocused: isFocusable && runtime?.isFocused(at: interactionPath) == true,
            focusPath: interactionPath,
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
            block.setFocusFrame(block.bounds, at: interactionPath)
        }

        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerFocusable(isFocusable, at: interactionPath)
        guard let element = render(
            isFocused: isFocusable && runtime?.isFocused(at: interactionPath) == true,
            focusPath: interactionPath,
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

        block.setFocusFrame(block.bounds, at: interactionPath)
        return .block(block)
    }

    private func render<Value>(
        isFocused: Bool,
        focusPath: [Int]? = nil,
        operation: () -> Value
    ) -> Value {
        var environment = EnvironmentRenderContext.current
        environment.isFocused = isFocused
        if environment.focusPath == nil, let focusPath {
            environment.focusPath = focusPath
        }
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
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerFocusable(true, at: interactionPath)
        runtime?.registerFocusAttachment(attachment, at: interactionPath)
        guard var block = render(
            isFocused: runtime?.isFocused(at: interactionPath) == true,
            focusPath: interactionPath,
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

        block.setFocusFrame(block.bounds, at: interactionPath)
        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        let interactionPath = EnvironmentRenderContext.current.focusPath ?? path
        runtime?.registerFocusable(true, at: interactionPath)
        runtime?.registerFocusAttachment(attachment, at: interactionPath)
        guard let element = render(
            isFocused: runtime?.isFocused(at: interactionPath) == true,
            focusPath: interactionPath,
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

        block.setFocusFrame(block.bounds, at: interactionPath)
        return .block(block)
    }

    private func render<Value>(
        isFocused: Bool,
        focusPath: [Int]? = nil,
        operation: () -> Value
    ) -> Value {
        var environment = EnvironmentRenderContext.current
        environment.isFocused = isFocused
        if environment.focusPath == nil, let focusPath {
            environment.focusPath = focusPath
        }
        return EnvironmentRenderContext.withValues(environment, perform: operation)
    }
}

private extension RenderedBlock {

    mutating func setFocusFrame(_ frame: RenderedRect, at path: [Int]) {
        if let index = focusRegions.firstIndex(where: { $0.path == path }) {
            focusRegions[index].frame = frame
        }
        else {
            focusRegions.append(RenderedFocusRegion(path: path, frame: frame))
        }
    }
}

extension EnvironmentValues {

    var focusPath: [Int]? {
        get {
            self[FocusPathKey.self]
        }
        set {
            self[FocusPathKey.self] = newValue
        }
    }
}

private struct FocusPathKey: EnvironmentKey {

    nonisolated static var defaultValue: [Int]? {
        nil
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
    /// A focusable view registers its rendered terminal frame as a focus region
    /// for keyboard traversal, programmatic focus requests, and pointer-down
    /// focus. The modifier does not draw a focus indicator or otherwise change
    /// the rendered cells; descendants can read `EnvironmentValues.isFocused`
    /// to choose their own focused appearance.
    ///
    /// Passing `false` explicitly removes the view from focus eligibility and
    /// rejects focus requests associated with the same interaction path. A
    /// disabled or hidden view is likewise not focusable.
    ///
    /// - Parameter isFocusable: `true` to register a focus candidate; `false`
    ///   to make this interaction path ineligible. The default is `true`.
    /// - Returns: A view with the requested focus eligibility.
    func focusable(_ isFocusable: Bool = true) -> some View {
        FocusableView(content: self, isFocusable: isFocusable)
    }

    /// Binds this view's focus state to a Boolean focus-state value.
    ///
    /// This modifier implicitly registers a focus candidate; a separate
    /// ``View/focusable(_:)`` call is not required. Setting the binding to
    /// `true` requests focus for the view, and setting it to `false` clears that
    /// request. Keyboard or pointer focus changes update the binding. The
    /// modifier also supplies the resulting state through
    /// `EnvironmentValues.isFocused` to the modified subtree.
    ///
    /// - Parameter condition: The binding that is `true` exactly while this
    ///   view owns focus.
    /// - Returns: A view registered for focus and synchronized with the binding.
    func focused(_ condition: FocusState<Bool>.Binding) -> some View {
        FocusedView(content: self, attachment: condition.focusAttachment())
    }

    /// Binds this view's focus state to one value of an optional focus state.
    ///
    /// This modifier implicitly registers a focus candidate. Assigning `value`
    /// to `binding` requests focus for this view; assigning `nil` clears the
    /// focus request. When focus moves to this view, SwiftTUI stores `value` in
    /// the binding, and when the binding's focused candidate loses focus it is
    /// cleared. The focused state is also available to descendants through
    /// `EnvironmentValues.isFocused`.
    ///
    /// - Parameters:
    ///   - binding: The optional focus-state binding shared by a group of focus
    ///     candidates.
    ///   - value: The value that identifies this candidate. If multiple visible
    ///     candidates use the same value, the first rendered candidate receives
    ///     a programmatic request.
    /// - Returns: A view registered for focus and associated with `value`.
    func focused<Value>(
        _ binding: FocusState<Value?>.Binding,
        equals value: Value
    ) -> some View where Value: Hashable {
        FocusedView(content: self, attachment: binding.focusAttachment(equals: value))
    }
}
