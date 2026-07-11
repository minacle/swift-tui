/// The preferred terminal-cell spacing around a view.
///
/// A spacing value is metadata consumed by containers when no explicit gap is
/// supplied. For two adjacent views, the resolved distance is the larger of
/// their preferences on the shared edges; preferences are not added together.
public nonisolated struct ViewSpacing: Sendable {

    private var top: Int

    private var leading: Int

    private var bottom: Int

    private var trailing: Int

    /// A spacing value with no preference on any edge.
    ///
    /// This does not force an adjacent view's preference to zero; distance
    /// resolution still uses the other view's shared-edge value.
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
    /// Each selected edge becomes the larger of the two preferences. Edges not
    /// in `edges` remain unchanged.
    ///
    /// - Parameters:
    ///   - other: The spacing preferences to merge.
    ///   - edges: The edges affected by the merge. The default is every edge.
    public mutating func formUnion(
        _ other: ViewSpacing,
        edges: Edge.Set = .all
    ) {
        if edges.contains(.top) {
            top = max(top, other.top)
        }
        if edges.contains(.leading) {
            leading = max(leading, other.leading)
        }
        if edges.contains(.bottom) {
            bottom = max(bottom, other.bottom)
        }
        if edges.contains(.trailing) {
            trailing = max(trailing, other.trailing)
        }
    }

    /// Returns a copy that merges another spacing value on selected edges.
    ///
    /// - Parameters:
    ///   - other: The spacing preferences to merge.
    ///   - edges: The edges affected by the merge. The default is every edge.
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
    /// The result is the smallest distance that satisfies the preferences of
    /// both views on their shared edges.
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
        return max(current, adjacent)
    }

    func isEqual(to other: ViewSpacing) -> Bool {
        top == other.top
            && leading == other.leading
            && bottom == other.bottom
            && trailing == other.trailing
    }
}
