import Foundation
import SwiftTUIRuns
import Terminal

/// An axis in terminal-cell layout and scrolling.
public nonisolated enum Axis: Sendable {

    /// The horizontal axis measured in terminal columns.
    case horizontal

    /// The vertical axis measured in terminal rows.
    case vertical

    /// An option set of terminal layout axes.
    public struct Set: OptionSet, Sendable {

        /// The bit mask that stores the selected axes.
        public let rawValue: Int

        /// Creates an axis set from a raw bit mask.
        ///
        /// Unknown bits are preserved and ignored by SwiftTUI's axis-based
        /// layout operations.
        ///
        /// - Parameter rawValue: The bit mask to store.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The horizontal axis.
        public static let horizontal = Set(rawValue: 1 << 0)

        /// The vertical axis.
        public static let vertical = Set(rawValue: 1 << 1)
    }
}

/// A directional edge of a terminal-cell rectangle.
///
/// Leading and trailing mean left and right in SwiftTUI's current
/// left-to-right coordinate system.
public nonisolated enum Edge: Equatable, Hashable, Sendable {

    /// The top horizontal edge.
    case top

    /// The bottom horizontal edge.
    case bottom

    /// The leading vertical edge.
    case leading

    /// The trailing vertical edge.
    case trailing
}

/// A scale-independent point relative to a two-dimensional rectangle.
///
/// By convention, zero is the leading or top edge and one is the trailing or
/// bottom edge. The initializer does not clamp components to `0...1`; values
/// outside that interval extrapolate beyond the rectangle. Layout and scrolling
/// operations convert resolved coordinates to `Int`, so components must be
/// finite and produce `Int`-representable offsets; `NaN`, infinity, or extreme
/// magnitudes can trap when consumed.
public nonisolated struct UnitPoint: Equatable, Hashable, Sendable {

    /// The horizontal location, where `0` is leading and `1` is trailing.
    public let x: Double

    /// The vertical location, where `0` is top and `1` is bottom.
    public let y: Double

    /// Creates a unit point without normalizing its components.
    ///
    /// - Parameters:
    ///   - x: The horizontal fraction, where zero is leading and one is trailing.
    ///   - y: The vertical fraction, where zero is top and one is bottom.
    /// - Precondition: When this point is used for layout or scrolling, both
    ///   components are finite and their resolved offsets fit in `Int`.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// The top-leading point.
    public static let zero = UnitPoint(x: 0, y: 0)

    /// The center point.
    public static let center = UnitPoint(x: 0.5, y: 0.5)

    /// The top-center point.
    public static let top = UnitPoint(x: 0.5, y: 0)

    /// The bottom-center point.
    public static let bottom = UnitPoint(x: 0.5, y: 1)

    /// The leading-center point.
    public static let leading = UnitPoint(x: 0, y: 0.5)

    /// The trailing-center point.
    public static let trailing = UnitPoint(x: 1, y: 0.5)

    /// The top-leading point.
    public static let topLeading = UnitPoint(x: 0, y: 0)

    /// The top-trailing point.
    public static let topTrailing = UnitPoint(x: 1, y: 0)

    /// The bottom-leading point.
    public static let bottomLeading = UnitPoint(x: 0, y: 1)

    /// The bottom-trailing point.
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

/// A nonnegative offset into scrollable terminal content.
///
/// The point is measured from the content's top-leading origin. `x` counts
/// columns hidden to the leading side and `y` counts rows hidden above the
/// viewport.
public nonisolated struct ScrollPoint: Equatable, Sendable {

    /// The horizontal content offset in terminal columns.
    public let x: Int

    /// The vertical content offset in terminal rows.
    public let y: Int

    /// Creates a scroll point.
    ///
    /// Each negative value is independently clamped to zero. A ``ScrollView``
    /// later clamps the point again to the maximum offset supported by its
    /// content, viewport, and enabled axes.
    ///
    /// - Parameters:
    ///   - x: The horizontal content offset in columns. The default is zero.
    ///   - y: The vertical content offset in rows. The default is zero.
    public init(x: Int = 0, y: Int = 0) {
        self.x = max(x, 0)
        self.y = max(y, 0)
    }
}

/// A semantic position within a scroll view.
///
/// A scroll position can be automatic, a concrete content point, or an edge
/// request that the renderer resolves for the current content and viewport.
/// These states are mutually exclusive. When used through
/// ``View/scrollPosition(_:)``, programmatic point and edge requests remain in
/// the binding while the renderer clamps only the viewport it displays. User
/// and proxy scrolling replace the binding with the resulting concrete point.
public nonisolated struct ScrollPosition: Equatable, Sendable {

    private enum Storage: Equatable, Sendable {

        case automatic

        case point(ScrollPoint)

        case edge(Edge)
    }

    private var storage: Storage

    /// The concrete content point, or `nil` for automatic and edge positions.
    public var point: ScrollPoint? {
        guard case .point(let point) = storage else {
            return nil
        }

        return point
    }

    /// The horizontal content offset, or `nil` if no concrete point is stored.
    public var x: Int? {
        point?.x
    }

    /// The vertical content offset, or `nil` if no concrete point is stored.
    public var y: Int? {
        point?.y
    }

    /// The requested edge, or `nil` for automatic and concrete positions.
    public var edge: Edge? {
        guard case .edge(let edge) = storage else {
            return nil
        }

        return edge
    }

    /// Creates an automatic position with no explicit point or edge request.
    public init() {
        self.storage = .automatic
    }

    /// Creates a position at a concrete content point.
    ///
    /// - Parameter point: The nonnegative offsets to request. The scroll view
    ///   clamps its displayed viewport to enabled axes and the maximum content
    ///   extent without changing this stored request.
    public init(point: ScrollPoint) {
        self.storage = .point(point)
    }

    /// Creates a point position with a horizontal offset and zero vertical offset.
    ///
    /// - Parameter x: The requested column offset. Negative values become zero.
    public init(x: Int) {
        self.init(point: ScrollPoint(x: x))
    }

    /// Creates a point position with a vertical offset and zero horizontal offset.
    ///
    /// - Parameter y: The requested row offset. Negative values become zero.
    public init(y: Int) {
        self.init(point: ScrollPoint(y: y))
    }

    /// Creates a point position with horizontal and vertical content offsets.
    ///
    /// - Parameters:
    ///   - x: The requested column offset. Negative values become zero.
    ///   - y: The requested row offset. Negative values become zero.
    public init(x: Int, y: Int) {
        self.init(point: ScrollPoint(x: x, y: y))
    }

    /// Creates a position that requests an edge of the scrollable content.
    ///
    /// - Parameter edge: The edge to align with the corresponding viewport edge.
    public init(edge: Edge) {
        self.storage = .edge(edge)
    }

    /// Replaces the current state with a concrete content point.
    ///
    /// - Parameter point: The new nonnegative content offsets.
    public mutating func scrollTo(point: ScrollPoint) {
        storage = .point(point)
    }

    /// Replaces the current state with a horizontal offset and zero vertical offset.
    ///
    /// - Parameter x: The requested column offset. Negative values become zero.
    public mutating func scrollTo(x: Int) {
        storage = .point(ScrollPoint(x: x))
    }

    /// Replaces the current state with a vertical offset and zero horizontal offset.
    ///
    /// - Parameter y: The requested row offset. Negative values become zero.
    public mutating func scrollTo(y: Int) {
        storage = .point(ScrollPoint(y: y))
    }

    /// Replaces the current state with horizontal and vertical content offsets.
    ///
    /// - Parameters:
    ///   - x: The requested column offset. Negative values become zero.
    ///   - y: The requested row offset. Negative values become zero.
    public mutating func scrollTo(x: Int, y: Int) {
        storage = .point(ScrollPoint(x: x, y: y))
    }

    /// Replaces the current state with an edge request and clears its point.
    ///
    /// - Parameter edge: The edge to align with the corresponding viewport edge.
    public mutating func scrollTo(edge: Edge) {
        storage = .edge(edge)
    }
}

/// A preference that controls when a scroll indicator can be visible.
public nonisolated struct ScrollIndicatorVisibility: Equatable, Hashable, Sendable {

    private enum Storage: Equatable, Hashable, Sendable {

        case hidden

        case never

        case visible
    }

    private let storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    /// Shows the indicator temporarily over the scroll viewport.
    ///
    /// This is the default. The indicator appears after scrolling or an
    /// explicit flash request and doesn't reserve terminal cells.
    public static var hidden: ScrollIndicatorVisibility {
        ScrollIndicatorVisibility(.hidden)
    }

    /// Prevents the indicator from being created or shown.
    public static var never: ScrollIndicatorVisibility {
        ScrollIndicatorVisibility(.never)
    }

    /// Shows the indicator while its axis can scroll and reserves its cells.
    public static var visible: ScrollIndicatorVisibility {
        ScrollIndicatorVisibility(.visible)
    }

    var reservesSpace: Bool {
        storage == .visible
    }

    var permitsDisplay: Bool {
        storage != .never
    }
}

/// The current geometry and actions supplied to a scroll-indicator attachment.
///
/// A ``ScrollView`` creates this value for one enabled axis. Read the geometry
/// while building the attachment, and call the actions only from input or
/// other deferred callbacks. Retaining the value after its scroll view is
/// removed is safe, but its actions then do nothing.
///
/// ```swift
/// ScrollView {
///     Text("Scrollable content")
/// }
/// .viewAttachment(VerticalScrollIndicatorAttachmentKey.self) { configuration in
///     Text(configuration.isScrollable ? "|" : "")
/// }
/// .environment(\.verticalScrollIndicatorVisibility, .visible)
/// ```
public struct ScrollIndicatorConfiguration {

    /// The current content offset along the indicator's axis.
    public let offset: Int

    /// The greatest supported content offset along the indicator's axis.
    public let maximumOffset: Int

    /// The number of visible terminal cells along the indicator's axis.
    public let viewportLength: Int

    /// The full content length in terminal cells along the indicator's axis.
    public let contentLength: Int

    private let scrollAction: (Int) -> Void

    private let interactionAction: (Bool) -> Void

    /// Whether the content extends beyond the viewport on this axis.
    public var isScrollable: Bool {
        maximumOffset > 0
    }

    init(
        offset: Int,
        maximumOffset: Int,
        viewportLength: Int,
        contentLength: Int,
        scrollAction: @escaping (Int) -> Void,
        interactionAction: @escaping (Bool) -> Void
    ) {
        self.offset = offset
        self.maximumOffset = maximumOffset
        self.viewportLength = viewportLength
        self.contentLength = contentLength
        self.scrollAction = scrollAction
        self.interactionAction = interactionAction
    }

    /// Requests a clamped content offset along this indicator's axis.
    ///
    /// - Parameter offset: The requested offset. Values outside
    ///   `0...maximumOffset` are clamped before the scroll view is updated.
    public func scroll(to offset: Int) {
        scrollAction(min(max(offset, 0), maximumOffset))
    }

    /// Keeps a temporarily shown indicator visible during pointer interaction.
    public func beginInteraction() {
        interactionAction(true)
    }

    /// Ends pointer interaction and starts the indicator's hide delay.
    public func endInteraction() {
        interactionAction(false)
    }
}

/// The attachment point for a horizontal scroll indicator.
public enum HorizontalScrollIndicatorAttachmentKey: ViewAttachmentKey {

    /// Geometry and actions supplied by the consuming scroll view.
    public typealias Context = ScrollIndicatorConfiguration
}

/// The attachment point for a vertical scroll indicator.
public enum VerticalScrollIndicatorAttachmentKey: ViewAttachmentKey {

    /// Geometry and actions supplied by the consuming scroll view.
    public typealias Context = ScrollIndicatorConfiguration
}

extension EnvironmentValues {

    /// The visibility applied to horizontal scroll-indicator attachments.
    public nonisolated var horizontalScrollIndicatorVisibility: ScrollIndicatorVisibility {
        get {
            self[HorizontalScrollIndicatorVisibilityKey.self]
        }
        set {
            self[HorizontalScrollIndicatorVisibilityKey.self] = newValue
        }
    }

    /// The visibility applied to vertical scroll-indicator attachments.
    public nonisolated var verticalScrollIndicatorVisibility: ScrollIndicatorVisibility {
        get {
            self[VerticalScrollIndicatorVisibilityKey.self]
        }
        set {
            self[VerticalScrollIndicatorVisibilityKey.self] = newValue
        }
    }

    internal var scrollIndicatorFlashGeneration: Int? {
        get {
            self[ScrollIndicatorFlashGenerationKey.self]
        }
        set {
            self[ScrollIndicatorFlashGenerationKey.self] = newValue
        }
    }
}

private struct HorizontalScrollIndicatorVisibilityKey: EnvironmentKey {

    nonisolated static var defaultValue: ScrollIndicatorVisibility { .hidden }
}

private struct VerticalScrollIndicatorVisibilityKey: EnvironmentKey {

    nonisolated static var defaultValue: ScrollIndicatorVisibility { .hidden }
}

private struct ScrollIndicatorFlashGenerationKey: EnvironmentKey {

    nonisolated static var defaultValue: Int? { nil }
}

private struct ScrollIndicatorsFlashOnAppearView<Content: View>: View {

    let content: Content

    let flashes: Bool

    @State private var generation = 0

    var body: some View {
        content
            .environment(\.scrollIndicatorFlashGeneration, generation)
            .onAppear {
                if flashes {
                    generation &+= 1
                }
            }
    }
}

private struct ScrollIndicatorsFlashTriggerView<Content: View, Value: Equatable>: View {

    let content: Content

    let value: Value

    @State private var generation = 0

    var body: some View {
        content
            .environment(\.scrollIndicatorFlashGeneration, generation)
            .onChange(of: value) {
                generation &+= 1
            }
    }
}

/// A scrollable view.
///
/// `ScrollView` measures content without constraining the enabled scrolling
/// axes, then clips it to the terminal-cell viewport proposed by its parent.
/// Offsets on disabled axes are ignored. The view participates flexibly on its
/// scrolling axes; a vertical scroll view also accepts the available width so
/// its viewport can fill a containing stack.
///
/// Enabled scroll views register their visible frame for pointer-wheel input;
/// they do not need keyboard focus to scroll. Use ``View/scrollDisabled(_:)``
/// to suppress user input without suppressing bound or proxy-driven positions.
/// A wheel sample that changes the offset is handled, stopping later input
/// handlers for that sample. At an edge, a scroll view leaves an inapplicable
/// sample unhandled so an eligible outer scroll view or later handler can use
/// it; among overlapping scroll views, the innermost eligible view moves.
public nonisolated struct ScrollView<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let axes: Axis.Set

    let content: Content

    /// Creates a scroll view.
    ///
    /// - Parameters:
    ///   - axes: The axes along which content is measured without a finite
    ///     viewport proposal and can be offset. The default is vertical; an
    ///     empty set permits no scrolling.
    ///   - content: A builder that creates the single scrollable content region.
    public init(
        _ axes: Axis.Set = .vertical,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.content = content()
    }
}

/// A scoped action proxy for programmatically scrolling descendant scroll views.
///
/// Obtain a proxy from ``ScrollViewReader`` and call it from an action closure,
/// such as a button or pointer handler. The proxy searches descendant scroll
/// views in render order and acts on the first one containing the requested
/// ``View/id(_:)``. Missing identifiers and identifiers outside the reader's
/// subtree are ignored.
public struct ScrollViewProxy {

    private let context: StateActionContext?

    init(context: StateActionContext?) {
        self.context = context
    }

    /// Scrolls to the first in-scope descendant target with the given identifier.
    ///
    /// If `anchor` is `nil`, SwiftTUI scrolls by the minimum amount needed to
    /// reveal the identified view. If `anchor` is non-`nil`, SwiftTUI aligns the
    /// same unit point in the target view and scroll viewport. The resulting
    /// offset is limited to the scroll view's enabled axes and clamped to its
    /// content bounds. When the resolved point changes, a bound
    /// ``ScrollPosition`` is updated with the new point; a no-op reveal leaves
    /// an existing automatic binding unchanged.
    ///
    /// - Parameters:
    ///   - id: The hashable identifier attached to the target view.
    ///   - anchor: The relative target and viewport point to align, or `nil` to
    ///     perform the smallest reveal.
    /// - Precondition: Call this method from an action associated with rendered
    ///   reader content. Calling it while the reader's content builder is
    ///   rendering, or on a proxy created only for measurement, traps.
    public func scrollTo<ID>(_ id: ID, anchor: UnitPoint? = nil) where ID: Hashable {
        guard let context else {
            preconditionFailure(
                "ScrollViewProxy may not be used outside a ScrollViewReader action."
            )
        }

        context.scrollTo(id: AnyHashable(id), anchor: anchor)
    }
}

/// A view that scopes and supplies a proxy for programmatic scrolling.
///
/// Put the target ``ScrollView`` and the control that invokes
/// ``ScrollViewProxy/scrollTo(_:anchor:)`` inside the reader. The content
/// closure may run during measurement and rendering; use the proxy only from an
/// action closure, not while constructing the view tree.
///
/// ```swift
/// ScrollViewReader { proxy in
///     VStack {
///         Text("Show details")
///             .onTapGesture {
///                 proxy.scrollTo("details", anchor: .top)
///             }
///         ScrollView {
///             Text("Details").id("details")
///         }
///     }
/// }
/// ```
public struct ScrollViewReader<Content: View>: View {

    /// The body type for this primitive view.
    public typealias Body = Never

    let content: (ScrollViewProxy) -> Content

    let statePath: [Int]?

    /// Creates a scroll view reader around its content subtree.
    ///
    /// - Parameter content: A builder that receives the reader's scoped proxy.
    ///   SwiftTUI may evaluate the builder more than once; defer proxy calls to
    ///   actions created by the builder.
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.content = content
        self.statePath = StateContext.currentPath
    }
}

struct IdentifiedView<Content: View>: View, LayoutModifierRenderable, LayoutTraitRenderable {

    typealias Body = Never

    let content: Content

    let id: AnyHashable

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        guard case .block(let block) = renderedElement(
            in: proposal,
            path: path,
            runtime: runtime
        ) else {
            return nil
        }

        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        let childIndex = runtime?.explicitIDChildIndex(at: path, id: id) ?? 0
        let childPath = path + [childIndex]
        let element = ViewResolver.element(
            from: content,
            in: proposal,
            path: childPath,
            runtime: runtime
        )

        if runtime?.isSuppressingRenderRegistrations != true {
            runtime?.finishExplicitIDRender(at: path, activeID: id)
        }

        guard case .block(var block) = element else {
            return element
        }

        block.identifiedRegions.append(RenderedIdentifiedRegion(id: id, frame: block.bounds))
        return .block(block)
    }
}

struct ScrollPositionView<Content: View>: View, ScrollPositionModifierRenderable,
    LayoutTraitRenderable
{

    typealias Body = Never

    let content: Content

    let position: Binding<ScrollPosition>

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        ScrollPositionContext.withPosition(position) {
            ViewResolver.block(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        ScrollPositionContext.withPosition(position) {
            ViewResolver.element(
                from: content,
                in: proposal,
                path: path,
                runtime: runtime
            )
        }
    }
}

protocol ScrollRenderable {

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock?
}

protocol ScrollPositionModifierRenderable {

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

extension View {

    /// Flashes scroll indicators when scrollable descendants first appear.
    ///
    /// Only temporarily hidden indicators react to the request. Permanently
    /// visible indicators remain visible, and ``ScrollIndicatorVisibility/never``
    /// suppresses the request. Reappearing with a new rendered identity creates
    /// a new flash when `onAppear` is `true`.
    ///
    /// - Parameter onAppear: Whether descendant indicators flash after this
    ///   hierarchy first appears.
    /// - Returns: A view that supplies the appearance flash request.
    public func scrollIndicatorsFlash(onAppear: Bool) -> some View {
        ScrollIndicatorsFlashOnAppearView(content: self, flashes: onAppear)
    }

    /// Flashes scroll indicators when an equatable value changes.
    ///
    /// The initial value doesn't flash. Each later unequal value restarts the
    /// temporary display interval for scrollable descendants.
    ///
    /// - Parameter value: The value whose changes request a flash.
    /// - Returns: A view that supplies the value-driven flash request.
    public func scrollIndicatorsFlash<Value: Equatable>(trigger value: Value) -> some View {
        ScrollIndicatorsFlashTriggerView(content: self, value: value)
    }

    /// Binds this view's identity to a hashable value.
    ///
    /// SwiftTUI uses this identity for subtree state and as a scroll target for
    /// ``ScrollViewProxy/scrollTo(_:anchor:)``. The identifier is scoped by the
    /// surrounding view hierarchy and reader rather than forming a process-wide
    /// namespace.
    ///
    /// - Parameter id: The stable, hashable identity to assign to this subtree.
    /// - Returns: A view whose state path and rendered scroll-target region use
    ///   the supplied identity.
    public func id<ID>(_ id: ID) -> some View where ID: Hashable {
        IdentifiedView(content: self, id: AnyHashable(id))
    }

    /// Supplies a scroll-position binding to descendant scroll views.
    ///
    /// A descendant reads the binding as its requested position. Programmatic
    /// points and edges remain unchanged while the descendant resolves and
    /// clamps its displayed viewport; an edge therefore remains aligned as the
    /// content or viewport changes. User and proxy scrolling instead write the
    /// resulting concrete point to the binding, with disabled axes set to zero.
    /// Rendering a programmatic request doesn't invoke the binding setter. Scope
    /// this modifier close to the intended scroll view when multiple descendants
    /// should not share a position.
    ///
    /// - Parameter position: The semantic programmatic request, or the concrete
    ///   position most recently published by user or proxy scrolling.
    /// - Returns: A view that supplies the binding to scrollable descendants in
    ///   its modified subtree.
    public func scrollPosition(_ position: Binding<ScrollPosition>) -> some View {
        ScrollPositionView(content: self, position: position)
    }

    /// Disables or enables user scrolling in scrollable descendant views.
    ///
    /// Disabling removes descendant wheel-input regions but leaves their current
    /// offsets, ``View/scrollPosition(_:)`` bindings, and
    /// ``ScrollViewProxy/scrollTo(_:anchor:)`` actions effective. An inner
    /// `scrollDisabled(false)` cannot re-enable scrolling disabled by an outer
    /// ancestor.
    ///
    /// - Parameter disabled: `true` to block user wheel input in the subtree;
    ///   `false` to preserve the inherited setting.
    /// - Returns: A view with the transformed scrolling environment.
    public nonisolated func scrollDisabled(_ disabled: Bool) -> some View {
        TransformedEnvironmentView(
            content: self,
            keyPath: \.isScrollEnabled,
            transform: {
                $0 = $0 && !disabled
            }
        )
    }
}

extension ScrollView: ScrollRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        var flexibleAxes = axes
        if axes.contains(.vertical) {
            flexibleAxes.insert(.horizontal)
        }
        return LayoutTraits(flexibleAxes: flexibleAxes)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let binding = ScrollPositionContext.currentBinding
        let position = binding?.wrappedValue
            ?? runtime?.scrollPoint(at: path).map { ScrollPosition(point: $0) }
            ?? ScrollPosition()
        let environment = EnvironmentRenderContext.current
        let attachments = environment.viewAttachments
        let hasHorizontalIndicator = axes.contains(.horizontal)
            && attachments.contains(HorizontalScrollIndicatorAttachmentKey.self)
            && environment.horizontalScrollIndicatorVisibility.permitsDisplay
        let hasVerticalIndicator = axes.contains(.vertical)
            && attachments.contains(VerticalScrollIndicatorAttachmentKey.self)
            && environment.verticalScrollIndicatorVisibility.permitsDisplay
        let initialContentBlock = measuredContentBlock(
            in: contentProposal(from: proposal),
            path: path,
            runtime: runtime
        )
        let baseWidth = max(proposal?.columns ?? initialContentBlock.width, 0)
        let baseHeight = max(proposal?.rows ?? initialContentBlock.height, 0)
        var reservesHorizontal = false
        var reservesVertical = false
        for _ in 0..<4 {
            let viewportWidth = max(baseWidth - (reservesVertical ? 1 : 0), 0)
            let viewportHeight = max(baseHeight - (reservesHorizontal ? 1 : 0), 0)
            let measuredContent = measuredContentBlock(
                in: contentProposal(
                    from: proposal,
                    viewportWidth: viewportWidth,
                    viewportHeight: viewportHeight
                ),
                path: path,
                runtime: runtime
            )
            let horizontalOverflows = hasHorizontalIndicator
                && ScrollViewRenderer.maxHorizontalOffset(
                    for: measuredContent,
                    width: viewportWidth
                ) > 0
            let verticalOverflows = hasVerticalIndicator
                && measuredContent.height > viewportHeight
            let nextHorizontal = horizontalOverflows
                && environment.horizontalScrollIndicatorVisibility.reservesSpace
            let nextVertical = verticalOverflows
                && environment.verticalScrollIndicatorVisibility.reservesSpace
            guard nextHorizontal != reservesHorizontal
                || nextVertical != reservesVertical else {
                break
            }
            reservesHorizontal = nextHorizontal
            reservesVertical = nextVertical
        }
        let viewportWidth = max(baseWidth - (reservesVertical ? 1 : 0), 0)
        let viewportHeight = max(baseHeight - (reservesHorizontal ? 1 : 0), 0)
        let contentBlock = ViewResolver.block(
            from: content,
            in: contentProposal(
                from: proposal,
                viewportWidth: viewportWidth,
                viewportHeight: viewportHeight
            ),
            path: path + [0],
            runtime: runtime
        ) ?? RenderedBlock(lines: [])
        let viewportProposal = RenderProposal(
            columns: viewportWidth,
            rows: viewportHeight
        )
        let result = ScrollViewRenderer.render(
            contentBlock,
            axes: axes,
            position: position,
            proposal: viewportProposal
        )
        runtime?.registerScrollView(
            at: path,
            axes: axes,
            point: result.point,
            maximumPoint: result.maximumPoint,
            viewportSize: Size(columns: result.block.width, rows: result.block.height),
            identifiedRegions: contentBlock.identifiedRegions,
            binding: binding,
            flashGeneration: environment.scrollIndicatorFlashGeneration
        )
        let temporarilyVisible = runtime?.scrollIndicatorIsTemporarilyVisible(at: path) == true
        let showsHorizontal = hasHorizontalIndicator
            && result.maximumPoint.x > 0
            && (reservesHorizontal || temporarilyVisible)
        let showsVertical = hasVerticalIndicator
            && result.maximumPoint.y > 0
            && (reservesVertical || temporarilyVisible)
        let bounds = RenderedRect(width: baseWidth, height: baseHeight)
        var layers = [result.block.offsetBy(x: 0, y: 0, clippedTo: bounds)]
        if showsHorizontal, viewportWidth > 0, viewportHeight > 0 {
            let configuration = indicatorConfiguration(
                axis: .horizontal,
                result: result,
                content: contentBlock,
                path: path,
                runtime: runtime
            )
            let trackWidth = showsVertical && !reservesVertical
                ? max(viewportWidth - 1, 0)
                : viewportWidth
            if trackWidth > 0,
               let indicator = attachments.view(
                for: HorizontalScrollIndicatorAttachmentKey.self,
                context: configuration
               ),
               let indicatorBlock = ViewResolver.block(
                from: indicator.frame(width: viewportWidth, height: 1, alignment: .leading),
                in: RenderProposal(columns: viewportWidth, rows: 1),
                path: path + [1],
                runtime: runtime
               ) {
                let clipped = indicatorBlock.offsetBy(
                    x: 0,
                    y: reservesHorizontal ? viewportHeight : viewportHeight - 1,
                    clippedTo: bounds
                )
                layers.append(
                    trackWidth == viewportWidth
                        ? clipped
                        : clipped.offsetBy(
                            x: 0,
                            y: 0,
                            clippedTo: RenderedRect(width: trackWidth, height: baseHeight)
                        )
                )
            }
        }
        if showsVertical, viewportWidth > 0, viewportHeight > 0 {
            let configuration = indicatorConfiguration(
                axis: .vertical,
                result: result,
                content: contentBlock,
                path: path,
                runtime: runtime
            )
            let trackHeight = showsHorizontal && !reservesHorizontal
                ? max(viewportHeight - 1, 0)
                : viewportHeight
            if trackHeight > 0,
               let indicator = attachments.view(
                for: VerticalScrollIndicatorAttachmentKey.self,
                context: configuration
               ),
               let indicatorBlock = ViewResolver.block(
                from: indicator.frame(width: 1, height: viewportHeight, alignment: .top),
                in: RenderProposal(columns: 1, rows: viewportHeight),
                path: path + [2],
                runtime: runtime
               ) {
                let clipped = indicatorBlock.offsetBy(
                    x: reservesVertical ? viewportWidth : viewportWidth - 1,
                    y: 0,
                    clippedTo: bounds
                )
                layers.append(
                    trackHeight == viewportHeight
                        ? clipped
                        : clipped.offsetBy(
                            x: 0,
                            y: 0,
                            clippedTo: RenderedRect(width: baseWidth, height: trackHeight)
                        )
                )
            }
        }

        var block = RenderedBlock.composited(
            layers,
            width: baseWidth,
            height: baseHeight,
            paddedRows: Set(0..<baseHeight)
        )
        if EnvironmentRenderContext.current.isEnabled
            && EnvironmentRenderContext.current.isScrollEnabled {
            block.scrollRegions.append(RenderedScrollRegion(path: path, frame: block.bounds))
        }
        return block
    }

    private func indicatorConfiguration(
        axis: Axis,
        result: ScrollViewRenderer.Result,
        content: RenderedBlock,
        path: [Int],
        runtime: StateRuntime?
    ) -> ScrollIndicatorConfiguration {
        let offset = axis == .horizontal ? result.point.x : result.point.y
        let maximum = axis == .horizontal
            ? result.maximumPoint.x
            : result.maximumPoint.y
        let viewportLength = axis == .horizontal
            ? result.block.width
            : result.block.height
        let contentLength = axis == .horizontal ? content.width : content.height
        return ScrollIndicatorConfiguration(
            offset: offset,
            maximumOffset: maximum,
            viewportLength: viewportLength,
            contentLength: contentLength,
            scrollAction: {
                [weak runtime]
                in

                runtime?.scrollIndicatorScroll(to: $0, axis: axis, at: path)
            },
            interactionAction: {
                [weak runtime]
                in

                runtime?.setScrollIndicatorInteraction($0, at: path)
            }
        )
    }

    private func measuredContentBlock(
        in proposal: RenderProposal,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock {
        let render = {
            ViewResolver.block(
                from: content,
                in: proposal,
                path: path + [0],
                runtime: runtime
            ) ?? RenderedBlock(lines: [])
        }
        return LayoutMeasurementContext.withMeasurement {
            runtime?.withoutRenderRegistrations(render) ?? render()
        }
    }

    private func contentProposal(
        from proposal: RenderProposal?,
        viewportWidth: Int? = nil,
        viewportHeight: Int? = nil
    ) -> RenderProposal {
        RenderProposal(
            columns: axes.contains(.horizontal)
                ? nil
                : viewportWidth ?? proposal?.columns,
            rows: axes.contains(.vertical)
                ? nil
                : viewportHeight ?? proposal?.rows
        )
    }
}

extension ScrollViewReader: ScrollRenderable, LayoutTraitRenderable {

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content(ScrollViewProxy(context: nil)))
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let proxy = runtime.map {
            ScrollViewProxy(context: StateActionContext(runtime: $0, path: path))
        } ?? ScrollViewProxy(context: nil)
        let resolvedContent: Content
        if let statePath, let runtime {
            resolvedContent = runtime.withView(at: statePath, mode: .render) {
                content(proxy)
            }
        }
        else {
            resolvedContent = content(proxy)
        }

        return ViewResolver.block(
            from: resolvedContent,
            in: proposal,
            path: path + [0],
            runtime: runtime
        )
    }
}

private enum ScrollPositionContext {

    private struct TaskBinding: @unchecked Sendable {

        var binding: Binding<ScrollPosition>?
    }

    @TaskLocal
    private static var taskBinding = TaskBinding(binding: nil)

    static func withPosition<Value>(
        _ position: Binding<ScrollPosition>,
        perform operation: () -> Value
    ) -> Value {
        $taskBinding.withValue(TaskBinding(binding: position)) {
            return operation()
        }
    }

    static var currentBinding: Binding<ScrollPosition>? {
        taskBinding.binding
    }
}

enum ScrollViewRenderer {

    struct Result {

        var block: RenderedBlock

        var point: ScrollPoint

        var maximumPoint: ScrollPoint
    }

    static func render(
        _ content: RenderedBlock,
        axes: Axis.Set,
        position: ScrollPosition,
        proposal: RenderProposal?
    ) -> Result {
        let width = proposal?.columns ?? content.width
        let height = proposal?.rows ?? content.height
        guard width > 0, height > 0 else {
            return Result(
                block: RenderedBlock(lines: []),
                point: ScrollPoint(),
                maximumPoint: ScrollPoint()
            )
        }

        let maximumPoint = ScrollPoint(
            x: axes.contains(.horizontal) ? maxHorizontalOffset(for: content, width: width) : 0,
            y: axes.contains(.vertical) ? max(content.height - height, 0) : 0
        )
        let point = resolvedPoint(
            from: position,
            content: content,
            width: width,
            height: height
        )
        let x = axes.contains(.horizontal) ? point.x : 0
        let y = axes.contains(.vertical) ? point.y : 0
        let clampedX = min(x, maximumPoint.x)
        let clampedY = min(y, maximumPoint.y)
        let bounds = RenderedRect(width: width, height: height)
        let runs = content.runs.flatMap {
            $0.offsetBy(x: -clampedX, y: -clampedY).clipped(to: bounds)
        }

        return Result(
            block: RenderedBlock(
                runs: runs,
                width: width,
                height: height,
                paddedRows: Set(0..<height),
                caret: caret(
                    from: content.caret,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height,
                    constrainToBounds: proposal?.columns != nil
                ),
                hitRegions: hitRegions(
                    from: content.hitRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                scrollRegions: scrollRegions(
                    from: content.scrollRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                focusRegions: focusRegions(
                    from: content.focusRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                identifiedRegions: identifiedRegions(
                    from: content.identifiedRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                coordinateSpaceRegions: coordinateSpaceRegions(
                    from: content.coordinateSpaceRegions,
                    x: clampedX,
                    y: clampedY,
                    width: width,
                    height: height
                ),
                explicitAlignments: content.offsetExplicitAlignments(
                    x: -clampedX,
                    y: -clampedY
                )
            ),
            point: ScrollPoint(x: clampedX, y: clampedY),
            maximumPoint: maximumPoint
        )
    }

    private static func caret(
        from caret: RenderedCaret?,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        constrainToBounds: Bool
    ) -> RenderedCaret? {
        guard let caret else {
            return nil
        }

        let row = caret.row - y
        let column = caret.column - x
        guard row >= 0, row < height, column >= 0, column <= width else {
            return nil
        }

        return RenderedCaret(
            row: row,
            column: constrainToBounds ? min(column, width - 1) : column
        )
    }

    static func maxHorizontalOffset(for content: RenderedBlock, width: Int) -> Int {
        let caretAllowance = content.caret == nil || content.width < width ? 0 : 1
        var offset = max(content.width - width + caretAllowance, 0)
        let lines = content.lines.compactMap {
            RunGroup($0).layout().lines.first
        }
        while offset > 0 && lines.contains(where: { line in
            offset < line.columns && !line.isCharacterBoundary(atColumn: offset)
        }) {
            offset += 1
        }
        return offset
    }

    private static func hitRegions(
        from regions: [RenderedHitRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedHitRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func scrollRegions(
        from regions: [RenderedScrollRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedScrollRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func focusRegions(
        from regions: [RenderedFocusRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedFocusRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func identifiedRegions(
        from regions: [RenderedIdentifiedRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedIdentifiedRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func coordinateSpaceRegions(
        from regions: [RenderedCoordinateSpaceRegion],
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> [RenderedCoordinateSpaceRegion] {
        let bounds = RenderedRect(width: width, height: height)
        return regions.compactMap {
            $0.offsetBy(x: -x, y: -y).clipped(to: bounds)
        }
    }

    private static func resolvedPoint(
        from position: ScrollPosition,
        content: RenderedBlock,
        width: Int,
        height: Int
    ) -> ScrollPoint {
        if let point = position.point {
            return point
        }

        switch position.edge {
        case .top:
            return ScrollPoint(y: 0)
        case .bottom:
            return ScrollPoint(y: max(content.height - height, 0))
        case .leading:
            return ScrollPoint(x: 0)
        case .trailing:
            return ScrollPoint(x: max(content.width - width, 0))
        case nil:
            return ScrollPoint()
        }
    }
}
