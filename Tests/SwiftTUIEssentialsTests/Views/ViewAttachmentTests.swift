import Testing
@testable import SwiftTUIEssentials

@Suite("View Attachments")
struct ViewAttachmentTests {

    @Test
    func `an absent attachment produces no view`() {
        let block = ViewResolver.block(from: AttachmentReader<LabelAttachmentKey>(context: 0))

        #expect(block?.text == "missing")
    }

    @Test
    func `requesting an attachment passes context and evaluates its builder lazily`() {
        let probe = AttachmentProbe()
        let view = AttachmentReader<LabelAttachmentKey>(context: 7)
            .viewAttachment(LabelAttachmentKey.self) { value in
                probe.evaluations += 1
                return Text("value:\(value)")
            }

        #expect(probe.evaluations == 0)
        #expect(ViewResolver.block(from: view)?.text == "value:7")
        #expect(probe.evaluations > 0)
    }

    @Test
    func `the closest attachment replaces only the matching key`() {
        let view = VStack(spacing: 0) {
            AttachmentReader<LabelAttachmentKey>(context: 1)
                .viewAttachment(LabelAttachmentKey.self) { _ in Text("inner") }
            AttachmentReader<OtherAttachmentKey>()
        }
        .viewAttachment(LabelAttachmentKey.self) { _ in Text("outer") }
        .viewAttachment(OtherAttachmentKey.self) { Text("other") }

        #expect(ViewResolver.block(from: view)?.lines == ["inner", "other"])
    }

    @Test
    func `an attachment is resolved with the consumer environment`() {
        let view = AttachmentReader<OtherAttachmentKey>()
            .environment(\.attachmentMarker, "consumer")
            .viewAttachment(OtherAttachmentKey.self) {
                AttachmentEnvironmentText()
            }
            .environment(\.attachmentMarker, "provider")

        #expect(ViewResolver.block(from: view)?.text == "consumer")
    }
}

private enum LabelAttachmentKey: ViewAttachmentKey {
    typealias Context = Int
}

private enum OtherAttachmentKey: ViewAttachmentKey {}

private struct AttachmentReader<Key: ViewAttachmentKey>: View {

    @Environment(\.viewAttachments) private var attachments

    let context: Key.Context

    init(context: Key.Context) {
        self.context = context
    }

    var body: some View {
        attachments.view(for: Key.self, context: context) ?? AnyView(Text("missing"))
    }
}

private extension AttachmentReader where Key.Context == Void {

    init() {
        context = ()
    }
}

private final class AttachmentProbe {
    var evaluations = 0
}

private struct AttachmentMarkerKey: EnvironmentKey {
    nonisolated static let defaultValue = "default"
}

private extension EnvironmentValues {
    var attachmentMarker: String {
        get { self[AttachmentMarkerKey.self] }
        set { self[AttachmentMarkerKey.self] = newValue }
    }
}

private struct AttachmentEnvironmentText: View {
    @Environment(\.attachmentMarker) private var marker

    var body: some View {
        Text(marker)
    }
}
