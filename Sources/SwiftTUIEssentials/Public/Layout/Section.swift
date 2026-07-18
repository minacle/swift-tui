/// A structural group with optional header and footer content.
///
/// Ordinary containers flatten a section in header, content, footer order.
/// ``LazyHStack`` and ``LazyVStack`` additionally preserve the boundary so a
/// same-axis ``ScrollView`` can pin selected headers or footers. A section does
/// not add terminal cells, styling, disclosure state, or interaction behavior
/// of its own.
public nonisolated struct Section<Parent: View, Content: View, Footer: View>: View {

    /// The body type for this primitive structural view.
    public typealias Body = Never

    let parent: Parent

    let content: Content

    let footer: Footer

    /// Creates a section with content, a header, and a footer.
    ///
    /// - Parameters:
    ///   - content: A builder that creates the section's primary content.
    ///   - header: A builder that creates the supplementary header.
    ///   - footer: A builder that creates the supplementary footer.
    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Parent,
        @ViewBuilder footer: () -> Footer
    ) {
        self.parent = header()
        self.content = content()
        self.footer = footer()
    }
}

extension Section where Footer == EmptyView {

    /// Creates a section with content and a header.
    ///
    /// - Parameters:
    ///   - content: A builder that creates the section's primary content.
    ///   - header: A builder that creates the supplementary header.
    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Parent
    ) {
        self.init(content: content, header: header, footer: EmptyView.init)
    }
}

extension Section where Parent == EmptyView {

    /// Creates a section with content and a footer.
    ///
    /// - Parameters:
    ///   - content: A builder that creates the section's primary content.
    ///   - footer: A builder that creates the supplementary footer.
    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(content: content, header: EmptyView.init, footer: footer)
    }
}

extension Section where Parent == EmptyView, Footer == EmptyView {

    /// Creates a section containing only primary content.
    ///
    /// - Parameter content: A builder that creates the section's content.
    public init(@ViewBuilder content: () -> Content) {
        self.init(content: content, header: EmptyView.init, footer: EmptyView.init)
    }
}

extension Section where Parent == Text, Footer == EmptyView {

    /// Creates a section with a text header.
    ///
    /// The title is rendered verbatim. Sanitize untrusted strings before
    /// passing them because SwiftTUI does not escape terminal control
    /// characters or sequences.
    ///
    /// - Parameters:
    ///   - title: The text displayed as the section header.
    ///   - content: A builder that creates the section's primary content.
    public init(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.init(content: content, header: {Text(title)})
    }
}
