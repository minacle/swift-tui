/// The preferred terminal-cell spacing around a view.
public nonisolated struct ViewSpacing: Sendable {

    private var top: Int

    private var leading: Int

    private var bottom: Int

    private var trailing: Int

    /// A spacing value with no preferred distance on any edge.
    public static let zero = ViewSpacing(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )

    /// Creates the default terminal spacing preferences.
    ///
    /// The default is two columns on horizontal edges and one row on vertical
    /// edges.
    public init() {
        self.init(top: 1, leading: 2, bottom: 1, trailing: 2)
    }

    private init(top: Int, leading: Int, bottom: Int, trailing: Int) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    /// Merges another spacing value into this value on selected edges.
    ///
    /// - Parameters:
    ///   - other: The spacing preferences to merge.
    ///   - edges: The edges affected by the merge.
    public mutating func formUnion(
        _ other: ViewSpacing,
        edges: Edge.Set = .all
    ) {
        if edges.contains(.top) {
            top = min(top, other.top)
        }
        if edges.contains(.leading) {
            leading = min(leading, other.leading)
        }
        if edges.contains(.bottom) {
            bottom = min(bottom, other.bottom)
        }
        if edges.contains(.trailing) {
            trailing = min(trailing, other.trailing)
        }
    }

    /// Returns a copy that merges another spacing value on selected edges.
    ///
    /// - Parameters:
    ///   - other: The spacing preferences to merge.
    ///   - edges: The edges affected by the merge.
    /// - Returns: The merged spacing preferences.
    public func union(
        _ other: ViewSpacing,
        edges: Edge.Set = .all
    ) -> ViewSpacing {
        var result = self
        result.formUnion(other, edges: edges)
        return result
    }

    /// Returns the preferred distance to an adjacent view along an axis.
    ///
    /// A zero preference on either shared edge suppresses automatic spacing.
    ///
    /// - Parameters:
    ///   - next: The spacing preferences of the adjacent view.
    ///   - axis: The axis along which the views are arranged.
    /// - Returns: The preferred number of terminal columns or rows.
    public func distance(to next: ViewSpacing, along axis: Axis) -> Int {
        let current: Int
        let adjacent: Int
        switch axis {
        case .horizontal:
            current = trailing
            adjacent = next.leading
        case .vertical:
            current = bottom
            adjacent = next.top
        }
        guard current > 0, adjacent > 0 else {
            return 0
        }
        return max(current, adjacent)
    }

    func isEqual(to other: ViewSpacing) -> Bool {
        top == other.top
            && leading == other.leading
            && bottom == other.bottom
            && trailing == other.trailing
    }
}
