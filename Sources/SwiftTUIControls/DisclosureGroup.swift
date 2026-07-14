public import SwiftTUIEssentials

/// A control that reveals or hides content beneath a labeled disclosure row.
///
/// A disclosure group fills a finite proposed width. Its header places a
/// right-pointing or downward-pointing filled triangle in the leading column,
/// followed by one blank terminal column and the label. The label determines
/// the header height, and expanded content begins on the next row at the
/// group's leading edge without padding, indentation, or an intervening blank
/// row.
///
/// Only a completed primary-pointer tap on the triangle changes the expansion
/// state. The label and unused header columns do not toggle the group, and the
/// group adds no focus or keyboard interaction. An initializer without an
/// expansion binding stores local state and starts collapsed. An initializer
/// with a binding reads and writes that binding as its source of truth.
///
/// ```swift
/// import SwiftTUIControls
///
/// struct NetworkDetails: View {
///     @State private var isExpanded = false
///
///     var body: some View {
///         DisclosureGroup("Network", isExpanded: $isExpanded) {
///             Text("Connected")
///         }
///     }
/// }
/// ```
public nonisolated struct DisclosureGroup<Label: View, Content: View>: View {

    let label: Label

    let content: () -> Content

    let isExpanded: Binding<Bool>?

    /// Creates a disclosure group that stores its expansion state internally.
    ///
    /// The group starts collapsed. A completed primary-pointer tap on its
    /// triangle toggles the stored state and conditionally renders `content`.
    ///
    /// - Parameters:
    ///   - content: A view builder that creates the content rendered while the
    ///     group is expanded.
    ///   - label: A view builder that creates the label displayed after the
    ///     disclosure triangle and one blank terminal column.
    public init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.content = content
        self.isExpanded = nil
    }

    /// Creates a disclosure group controlled by an expansion binding.
    ///
    /// The group reads its visible state from `isExpanded`. A completed
    /// primary-pointer tap on its triangle writes the opposite value through
    /// the binding; external binding changes take effect on the next render.
    ///
    /// - Parameters:
    ///   - isExpanded: The binding that determines whether `content` is
    ///     visible and receives pointer-driven state changes.
    ///   - content: A view builder that creates the content rendered while the
    ///     group is expanded.
    ///   - label: A view builder that creates the label displayed after the
    ///     disclosure triangle and one blank terminal column.
    public init(
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.content = content
        self.isExpanded = isExpanded
    }

    /// The view that lays out the disclosure row and conditional content.
    ///
    /// SwiftTUI uses this view to retain local expansion state when needed,
    /// fill finite width proposals, and restrict pointer interaction to the
    /// rendered triangle.
    @MainActor
    public var body: some View {
        DisclosureGroupBody(
            label: label,
            content: content,
            isExpanded: isExpanded
        )
    }
}

extension DisclosureGroup where Label == Text {

    /// Creates a collapsed disclosure group with a plain string label.
    ///
    /// SwiftTUI renders `title` unchanged and does not perform localization.
    /// Localize it with `String.init(localized:...)` before calling this
    /// initializer when needed. Sanitize untrusted strings before rendering
    /// them because terminal control characters remain unchanged.
    ///
    /// - Parameters:
    ///   - title: The string displayed after the disclosure triangle and one
    ///     blank terminal column.
    ///   - content: A view builder that creates the content rendered while the
    ///     group is expanded.
    public init(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(content: content) {
            Text(title)
        }
    }

    /// Creates a disclosure group with a plain string label and bound state.
    ///
    /// SwiftTUI renders `title` unchanged and does not perform localization.
    /// Localize it with `String.init(localized:...)` before calling this
    /// initializer when needed. Sanitize untrusted strings before rendering
    /// them because terminal control characters remain unchanged.
    ///
    /// - Parameters:
    ///   - title: The string displayed after the disclosure triangle and one
    ///     blank terminal column.
    ///   - isExpanded: The binding that determines whether `content` is
    ///     visible and receives pointer-driven state changes.
    ///   - content: A view builder that creates the content rendered while the
    ///     group is expanded.
    public init(
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(isExpanded: isExpanded, content: content) {
            Text(title)
        }
    }
}

private struct DisclosureGroupBody<Label: View, Content: View>: View {

    let label: Label

    let content: () -> Content

    let isExpanded: Binding<Bool>?

    @State private var internalIsExpanded = false

    var body: some View {
        let expansion = isExpanded ?? $internalIsExpanded
        let expanded = expansion.wrappedValue

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 1) {
                Text(expanded ? "▼" : "▶")
                    .onTapGesture {
                        expansion.wrappedValue.toggle()
                    }
                label
                Spacer(minLength: 0)
            }
            if expanded {
                content()
            }
        }
    }
}
