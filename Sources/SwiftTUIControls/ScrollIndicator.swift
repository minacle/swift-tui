public import SwiftTUIEssentials

/// A one-row interactive indicator for horizontally scrollable content.
///
/// The indicator draws a light box-drawing track and a proportional heavy
/// thumb at half-cell resolution. Drag the thumb with the primary pointer
/// button, or press the track before or after it to move by one viewport.
public nonisolated struct HorizontalScrollIndicator: View {

    let configuration: ScrollIndicatorConfiguration

    /// Creates a horizontal indicator from geometry and actions supplied by a
    /// scrollable container.
    ///
    /// - Parameter configuration: The current horizontal scroll geometry and
    ///   synchronous interaction actions.
    public init(configuration: ScrollIndicatorConfiguration) {
        self.configuration = configuration
    }

    /// The interactive horizontal track and thumb.
    @MainActor
    public var body: some View {
        ScrollIndicatorBody(axis: .horizontal, configuration: configuration)
    }
}

/// A one-column interactive indicator for vertically scrollable content.
///
/// The indicator draws a light box-drawing track and a proportional heavy
/// thumb at half-cell resolution. Drag the thumb with the primary pointer
/// button, or press the track before or after it to move by one viewport.
public nonisolated struct VerticalScrollIndicator: View {

    let configuration: ScrollIndicatorConfiguration

    /// Creates a vertical indicator from geometry and actions supplied by a
    /// scrollable container.
    ///
    /// - Parameter configuration: The current vertical scroll geometry and
    ///   synchronous interaction actions.
    public init(configuration: ScrollIndicatorConfiguration) {
        self.configuration = configuration
    }

    /// The interactive vertical track and thumb.
    @MainActor
    public var body: some View {
        ScrollIndicatorBody(axis: .vertical, configuration: configuration)
    }
}

private struct ScrollIndicatorBody: View {

    private struct DragState: Equatable {

        var isActive = false

        var grabbedHalfOffset: Int?
    }

    let axis: Axis

    let configuration: ScrollIndicatorConfiguration

    @GestureState private var dragState = DragState()

    init(axis: Axis, configuration: ScrollIndicatorConfiguration) {
        self.axis = axis
        self.configuration = configuration
        _dragState = GestureState(wrappedValue: DragState()) { state, _ in
            if state.isActive {
                configuration.endInteraction()
            }
        }
    }

    var body: some View {
        let metrics = ScrollIndicatorMetrics(configuration: configuration)
        Text(metrics.text(for: axis))
            .frame(
                width: axis == .horizontal ? configuration.viewportLength : 1,
                height: axis == .vertical ? configuration.viewportLength : 1,
                alignment: .topLeading
            )
            .gesture(
                DragGesture().updating($dragState) { value, state, _ in
                    updateDrag(value, state: &state, metrics: metrics)
                }
            )
    }

    private func updateDrag(
        _ drag: DragGesture.Value,
        state: inout DragState,
        metrics: ScrollIndicatorMetrics
    ) {
        let cell = axis == .horizontal ? drag.location.column : drag.location.row
        let half = metrics.halfCoordinate(forCell: cell)
        if !state.isActive {
            state.isActive = true
            configuration.beginInteraction()
            if let thumbHalf = metrics.thumbHalfCoordinate(forCell: cell) {
                state.grabbedHalfOffset = thumbHalf - metrics.thumbStart
            }
            else {
                state.grabbedHalfOffset = nil
                configuration.scroll(
                    to: configuration.offset
                        + (half < metrics.thumbStart
                            ? -configuration.viewportLength
                            : configuration.viewportLength)
                )
            }
            return
        }

        guard let grabbedHalfOffset = state.grabbedHalfOffset else {
            return
        }
        configuration.scroll(
            to: metrics.scrollOffset(
                forThumbStart: half - grabbedHalfOffset,
                maximumOffset: configuration.maximumOffset
            )
        )
    }
}

private struct ScrollIndicatorMetrics {

    let length: Int

    let halfCount: Int

    let thumbLength: Int

    let thumbStart: Int

    init(configuration: ScrollIndicatorConfiguration) {
        length = max(configuration.viewportLength, 0)
        halfCount = max(length * 2 - 2, 0)
        if halfCount == 0 {
            thumbLength = length == 0 ? 0 : 1
            thumbStart = 0
            return
        }

        thumbLength = min(
            max(halfCount * configuration.viewportLength / max(configuration.contentLength, 1), 1),
            halfCount
        )
        let available = halfCount - thumbLength
        thumbStart = configuration.maximumOffset == 0
            ? 0
            : configuration.offset * available / configuration.maximumOffset
    }

    func text(for axis: Axis) -> String {
        guard length > 0 else {
            return ""
        }
        guard length > 1 else {
            return axis == .horizontal ? "━" : "┃"
        }

        let heavy = Set(thumbStart..<(thumbStart + thumbLength))
        let characters = (0..<length).map { cell -> Character in
            let halves = Self.halfIndices(forCell: cell, length: length)
            let first = halves.first.map(heavy.contains)
            let last = halves.last.map(heavy.contains)
            if axis == .horizontal {
                return horizontalCharacter(
                    cell: cell,
                    firstHeavy: first,
                    lastHeavy: last
                )
            }
            return verticalCharacter(
                cell: cell,
                firstHeavy: first,
                lastHeavy: last
            )
        }
        if axis == .horizontal {
            return String(characters)
        }
        return characters.map(String.init).joined(separator: "\n")
    }

    func halfCoordinate(forCell cell: Int) -> Int {
        guard halfCount > 0 else {
            return 0
        }
        return min(max(cell * 2, 0), halfCount - 1)
    }

    func thumbHalfCoordinate(forCell cell: Int) -> Int? {
        let thumbRange = thumbStart..<(thumbStart + thumbLength)
        return Self.halfIndices(forCell: cell, length: length).first {
            thumbRange.contains($0)
        }
    }

    func scrollOffset(forThumbStart start: Int, maximumOffset: Int) -> Int {
        let available = halfCount - thumbLength
        guard available > 0 else {
            return 0
        }
        let clamped = min(max(start, 0), available)
        return (clamped * maximumOffset + available / 2) / available
    }

    private static func halfIndices(forCell cell: Int, length: Int) -> [Int] {
        guard length > 1 else {
            return []
        }
        var result: [Int] = []
        if cell > 0 {
            result.append(cell * 2 - 1)
        }
        if cell < length - 1 {
            result.append(cell * 2)
        }
        return result
    }

    private func horizontalCharacter(
        cell: Int,
        firstHeavy: Bool?,
        lastHeavy: Bool?
    ) -> Character {
        if cell == 0 {
            return lastHeavy == true ? "╺" : "╶"
        }
        if cell == length - 1 {
            return firstHeavy == true ? "╸" : "╴"
        }
        return switch (firstHeavy, lastHeavy) {
        case (false, false): "─"
        case (true, true): "━"
        case (false, true): "╼"
        default: "╾"
        }
    }

    private func verticalCharacter(
        cell: Int,
        firstHeavy: Bool?,
        lastHeavy: Bool?
    ) -> Character {
        if cell == 0 {
            return lastHeavy == true ? "╻" : "╷"
        }
        if cell == length - 1 {
            return firstHeavy == true ? "╹" : "╵"
        }
        return switch (firstHeavy, lastHeavy) {
        case (false, false): "│"
        case (true, true): "┃"
        case (false, true): "╽"
        default: "╿"
        }
    }
}

private struct ScrollIndicatorsView<Content: View>: View {

    let content: Content

    let visibility: ScrollIndicatorVisibility

    let axes: Axis.Set

    @ViewBuilder
    var body: some View {
        if axes.contains(.horizontal) && axes.contains(.vertical) {
            content
                .viewAttachment(HorizontalScrollIndicatorAttachmentKey.self) {
                    HorizontalScrollIndicator(configuration: $0)
                }
                .viewAttachment(VerticalScrollIndicatorAttachmentKey.self) {
                    VerticalScrollIndicator(configuration: $0)
                }
                .environment(\.horizontalScrollIndicatorVisibility, visibility)
                .environment(\.verticalScrollIndicatorVisibility, visibility)
        }
        else if axes.contains(.horizontal) {
            content
                .viewAttachment(HorizontalScrollIndicatorAttachmentKey.self) {
                    HorizontalScrollIndicator(configuration: $0)
                }
                .environment(\.horizontalScrollIndicatorVisibility, visibility)
        }
        else if axes.contains(.vertical) {
            content
                .viewAttachment(VerticalScrollIndicatorAttachmentKey.self) {
                    VerticalScrollIndicator(configuration: $0)
                }
                .environment(\.verticalScrollIndicatorVisibility, visibility)
        }
        else {
            content
        }
    }
}

extension View {

    /// Installs the standard scroll indicators on selected scrollable axes.
    ///
    /// The modifier supplies ``HorizontalScrollIndicator`` and
    /// ``VerticalScrollIndicator`` attachments to scrollable descendants. A
    /// closer custom `viewAttachment(_:content:)` for the corresponding
    /// attachment key replaces the standard view.
    ///
    /// ```swift
    /// ScrollView {
    ///     VStack {
    ///         Text("First")
    ///         Text("Second")
    ///     }
    /// }
    /// .scrollIndicators(.visible, axes: .vertical)
    /// ```
    ///
    /// - Parameters:
    ///   - visibility: When the installed indicators appear and whether they
    ///     reserve terminal cells.
    ///   - axes: The scrollable axes to configure. The default configures both.
    /// - Returns: A view with standard indicator attachments and visibility.
    public func scrollIndicators(
        _ visibility: ScrollIndicatorVisibility,
        axes: Axis.Set = [.vertical, .horizontal]
    ) -> some View {
        ScrollIndicatorsView(content: self, visibility: visibility, axes: axes)
    }
}
