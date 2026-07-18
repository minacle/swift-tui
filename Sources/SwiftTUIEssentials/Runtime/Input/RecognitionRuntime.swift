import Foundation
import Terminal

enum RecognitionAttachmentTier: Int, CaseIterable, Comparable {

    case high

    case viewDefined

    case normal

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated enum RecognitionAttachmentKind: Hashable, Sendable {

    case inputEvent

    case gesture

    case shortcut
}

nonisolated struct RecognitionAttachmentID: Hashable, Sendable {

    var path: [Int]

    var kind: RecognitionAttachmentKind

    var slot: Int
}

struct AttachmentDispatchOutcome {

    var result: InputEventResult = .ignored

    var participated = false

    var recognitionEnded = false

    var recognitionClaimed = false

    var beginsCapture = false

    var endsCapture = false
}

@MainActor
class AnyRecognitionAttachment {

    let id: RecognitionAttachmentID

    let path: [Int]

    let tier: RecognitionAttachmentTier

    let environment: EnvironmentValues

    let actionPath: [Int]

    init(
        id: RecognitionAttachmentID,
        path: [Int],
        tier: RecognitionAttachmentTier,
        environment: EnvironmentValues,
        actionPath: [Int]
    ) {
        self.id = id
        self.path = path
        self.tier = tier
        self.environment = environment
        self.actionPath = actionPath
    }

    var kind: RecognitionAttachmentKind { preconditionFailure() }

    var configuration: AnyHashable { preconditionFailure() }

    var families: InputFamilies { [] }

    var stage: InputEventStage? { nil }

    var isActive: Bool { false }

    var acceptsNewPointerDownWhileActive: Bool { false }

    var acceptsNewKeyDownWhileActive: Bool { false }

    var nextDeadline: Date? { nil }

    var isSimultaneousRecognition: Bool { false }

    func process(
        _ sample: RecognitionSample,
        date: Date,
        isTargeted: Bool,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) -> AttachmentDispatchOutcome {
        AttachmentDispatchOutcome()
    }

    func advance(
        to date: Date,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) -> AttachmentDispatchOutcome {
        AttachmentDispatchOutcome()
    }

    func cancel(_ reason: RecognitionCancellationReason) {}

    func restoreState(from old: AnyRecognitionAttachment) {}
}

@MainActor
final class InputRecognitionAttachment<Value>: AnyRecognitionAttachment {

    let definition: _InputEventDefinition<Value>

    let node: InputRecognitionNode<Value>

    init(
        id: RecognitionAttachmentID,
        path: [Int],
        tier: RecognitionAttachmentTier,
        environment: EnvironmentValues,
        actionPath: [Int],
        definition: _InputEventDefinition<Value>
    ) {
        self.definition = definition
        self.node = definition.makeNode()
        super.init(
            id: id,
            path: path,
            tier: tier,
            environment: environment,
            actionPath: actionPath
        )
    }

    override var kind: RecognitionAttachmentKind { .inputEvent }

    override var configuration: AnyHashable {
        AnyHashable(definition.configuration)
    }

    override var families: InputFamilies { definition.families }

    override var stage: InputEventStage? { definition.stage }

    override var isActive: Bool { node.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        node.acceptsNewPointerDownWhileActive
    }

    override func process(
        _ sample: RecognitionSample,
        date: Date,
        isTargeted: Bool,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) -> AttachmentDispatchOutcome {
        let context = InputRecognitionContext(
            convert: convert,
            isContinuingRecognition: node.isActive
        )
        let output = node.process(
            sample,
            context: context
        )
        if context.didLoseCoordinateSpace {
            node.cancel(.coordinateSpaceRemoved)
            return AttachmentDispatchOutcome()
        }
        return AttachmentDispatchOutcome(
            result: output.result,
            participated: output.matched,
            beginsCapture: output.beginsCapture,
            endsCapture: output.endsCapture
        )
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        node.cancel(reason)
    }

    override func restoreState(from old: AnyRecognitionAttachment) {
        guard let old = old as? InputRecognitionAttachment<Value> else {
            return
        }
        node.restoreState(from: old.node)
    }
}

@MainActor
final class GestureRecognitionAttachment<Value>: AnyRecognitionAttachment {

    let definition: _GestureDefinition<Value>

    let node: StatefulRecognitionNode<Value>

    let simultaneous: Bool

    init(
        id: RecognitionAttachmentID,
        path: [Int],
        tier: RecognitionAttachmentTier,
        environment: EnvironmentValues,
        actionPath: [Int],
        isSimultaneous: Bool,
        definition: _GestureDefinition<Value>
    ) {
        self.definition = definition
        self.node = definition.makeNode()
        self.simultaneous = isSimultaneous
        super.init(
            id: id,
            path: path,
            tier: tier,
            environment: environment,
            actionPath: actionPath
        )
    }

    override var kind: RecognitionAttachmentKind { .gesture }

    override var configuration: AnyHashable {
        AnyHashable(definition.configuration)
    }

    override var families: InputFamilies { .pointer }

    override var isActive: Bool { node.isActive }

    override var acceptsNewPointerDownWhileActive: Bool {
        node.acceptsNewPointerDownWhileActive
    }

    override var nextDeadline: Date? { node.nextDeadline }

    override var isSimultaneousRecognition: Bool { simultaneous }

    override func process(
        _ sample: RecognitionSample,
        date: Date,
        isTargeted: Bool,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) -> AttachmentDispatchOutcome {
        let context = StatefulRecognitionContext(
            date: date,
            isTargeted: isTargeted,
            convert: convert,
            invalidate: invalidate
        )
        let output = node.process(sample, context: context)
        context.flush()
        return outcome(from: output)
    }

    override func advance(
        to date: Date,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) -> AttachmentDispatchOutcome {
        let context = StatefulRecognitionContext(
            date: date,
            isTargeted: true,
            convert: convert,
            invalidate: invalidate
        )
        let output = node.advance(to: date, context: context)
        context.flush()
        return outcome(from: output)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        node.cancel(reason)
    }

    override func restoreState(from old: AnyRecognitionAttachment) {
        guard let old = old as? GestureRecognitionAttachment<Value> else {
            return
        }
        node.restoreState(from: old.node)
    }

    private func outcome(
        from output: StatefulRecognitionOutput<Value>
    ) -> AttachmentDispatchOutcome {
        let ended: Bool
        switch output.phase {
        case .ended:
            ended = true
        case .none, .changed, .failed:
            ended = false
        }
        return AttachmentDispatchOutcome(
            participated: output.participated,
            recognitionEnded: ended,
            recognitionClaimed: output.claimsCompetition,
            beginsCapture: output.beginsCapture,
            endsCapture: output.endsCapture
        )
    }
}

@MainActor
final class ShortcutRecognitionAttachment<Value>: AnyRecognitionAttachment {

    let definition: _ShortcutDefinition<Value>

    let node: StatefulRecognitionNode<Value>

    let simultaneous: Bool

    init(
        id: RecognitionAttachmentID,
        path: [Int],
        tier: RecognitionAttachmentTier,
        environment: EnvironmentValues,
        actionPath: [Int],
        isSimultaneous: Bool,
        definition: _ShortcutDefinition<Value>
    ) {
        self.definition = definition
        self.node = definition.makeNode()
        self.simultaneous = isSimultaneous
        super.init(
            id: id,
            path: path,
            tier: tier,
            environment: environment,
            actionPath: actionPath
        )
    }

    override var kind: RecognitionAttachmentKind { .shortcut }

    override var configuration: AnyHashable {
        AnyHashable(definition.configuration)
    }

    override var families: InputFamilies { .key }

    override var isActive: Bool { node.isActive }

    override var acceptsNewKeyDownWhileActive: Bool {
        node.acceptsNewKeyDownWhileActive
    }

    override var nextDeadline: Date? { node.nextDeadline }

    override var isSimultaneousRecognition: Bool { simultaneous }

    override func process(
        _ sample: RecognitionSample,
        date: Date,
        isTargeted: Bool,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) -> AttachmentDispatchOutcome {
        let context = StatefulRecognitionContext(
            date: date,
            isTargeted: isTargeted,
            convert: convert,
            invalidate: invalidate
        )
        let output = node.process(sample, context: context)
        context.flush()
        return outcome(from: output)
    }

    override func advance(
        to date: Date,
        convert: @escaping (Point, CoordinateSpace) -> Point?,
        invalidate: @escaping () -> Void
    ) -> AttachmentDispatchOutcome {
        let context = StatefulRecognitionContext(
            date: date,
            isTargeted: true,
            convert: convert,
            invalidate: invalidate
        )
        let output = node.advance(to: date, context: context)
        context.flush()
        return outcome(from: output)
    }

    override func cancel(_ reason: RecognitionCancellationReason) {
        node.cancel(reason)
    }

    override func restoreState(from old: AnyRecognitionAttachment) {
        guard let old = old as? ShortcutRecognitionAttachment<Value> else {
            return
        }
        node.restoreState(from: old.node)
    }

    private func outcome(
        from output: StatefulRecognitionOutput<Value>
    ) -> AttachmentDispatchOutcome {
        let ended: Bool
        switch output.phase {
        case .ended:
            ended = true
        case .none, .changed, .failed:
            ended = false
        }
        return AttachmentDispatchOutcome(
            participated: output.participated,
            recognitionEnded: ended,
            recognitionClaimed: output.claimsCompetition
        )
    }
}

@MainActor
final class RecognitionRuntime {

    typealias Perform = (
        _ attachment: AnyRecognitionAttachment,
        _ operation: () -> AttachmentDispatchOutcome
    ) -> AttachmentDispatchOutcome

    private var attachments: [RecognitionAttachmentID: AnyRecognitionAttachment] = [:]

    private var orderedAttachments: [AnyRecognitionAttachment] = []

    private var pendingAttachments: [AnyRecognitionAttachment] = []

    private var nextSlots: [[Int]: [RecognitionAttachmentKind: Int]] = [:]

    private var hitRegions: [RenderedHitRegion] = []

    private var focusRegions: [RenderedFocusRegion] = []

    private var scrollRegions: [RenderedScrollRegion] = []

    private var coordinateSpaceRegions: [RenderedCoordinateSpaceRegion] = []

    private var rootFrame = RenderedTerminalFrame(text: "", row: 1, column: 1)

    private var capturedAttachmentID: RecognitionAttachmentID?

    private var capturedPath: [Int]?

    var nextDeadline: Date? {
        orderedAttachments.compactMap(\.nextDeadline).min()
    }

    var hasGestureCapture: Bool {
        guard let capturedAttachmentID else {
            return false
        }
        return attachments[capturedAttachmentID]?.kind == .gesture
    }

    func beginRender() {
        pendingAttachments = []
        nextSlots = [:]
    }

    func register<Event: InputEvent>(
        _ event: Event,
        at path: [Int],
        actionPath: [Int],
        tier: RecognitionAttachmentTier,
        environment: EnvironmentValues
    ) -> RecognitionAttachmentID? {
        let definition = event._makeInputEvent()
        let id = nextID(path: path, kind: .inputEvent)
        pendingAttachments.append(
            InputRecognitionAttachment(
                id: id,
                path: path,
                tier: tier,
                environment: environment,
                actionPath: actionPath,
                definition: definition
            )
        )
        return definition.families.intersection(.pointer).isEmpty ? nil : id
    }

    func register<G: Gesture>(
        _ gesture: G,
        at path: [Int],
        actionPath: [Int],
        tier: RecognitionAttachmentTier,
        environment: EnvironmentValues,
        isSimultaneous: Bool = false
    ) -> RecognitionAttachmentID {
        let definition = gesture._makeGesture()
        let id = nextID(path: path, kind: .gesture)
        pendingAttachments.append(
            GestureRecognitionAttachment(
                id: id,
                path: path,
                tier: tier,
                environment: environment,
                actionPath: actionPath,
                isSimultaneous: isSimultaneous,
                definition: definition
            )
        )
        return id
    }

    func register<S: Shortcut>(
        _ shortcut: S,
        at path: [Int],
        actionPath: [Int],
        tier: RecognitionAttachmentTier,
        environment: EnvironmentValues,
        isSimultaneous: Bool = false
    ) {
        let definition = shortcut._makeShortcut()
        let id = nextID(path: path, kind: .shortcut)
        pendingAttachments.append(
            ShortcutRecognitionAttachment(
                id: id,
                path: path,
                tier: tier,
                environment: environment,
                actionPath: actionPath,
                isSimultaneous: isSimultaneous,
                definition: definition
            )
        )
    }

    func finishRender(perform: Perform) {
        let pendingIDs = Set(pendingAttachments.map(\.id))
        for old in orderedAttachments where !pendingIDs.contains(old.id) {
            _ = perform(old) {
                old.cancel(.removed)
                return AttachmentDispatchOutcome()
            }
            if capturedAttachmentID == old.id {
                clearCapture()
            }
        }

        var next: [RecognitionAttachmentID: AnyRecognitionAttachment] = [:]
        for attachment in pendingAttachments {
            if let old = attachments[attachment.id] {
                if old.kind == attachment.kind,
                   old.tier == attachment.tier,
                   old.configuration == attachment.configuration,
                   old.stage == attachment.stage {
                    attachment.restoreState(from: old)
                } else {
                    _ = perform(old) {
                        old.cancel(.identityChanged)
                        return AttachmentDispatchOutcome()
                    }
                    if capturedAttachmentID == old.id {
                        clearCapture()
                    }
                }
            }
            next[attachment.id] = attachment
        }
        attachments = next
        orderedAttachments = pendingAttachments
        pendingAttachments = []
    }

    func update(
        hitRegions: [RenderedHitRegion],
        focusRegions: [RenderedFocusRegion],
        scrollRegions: [RenderedScrollRegion],
        coordinateSpaceRegions: [RenderedCoordinateSpaceRegion]
    ) {
        self.hitRegions = hitRegions
        self.focusRegions = focusRegions
        self.scrollRegions = scrollRegions
        self.coordinateSpaceRegions = coordinateSpaceRegions
    }

    func updateRootFrame(_ frame: RenderedTerminalFrame) {
        rootFrame = frame
    }

    func dispatch(
        _ incomingSample: RecognitionSample,
        toward keyTargetPath: [Int]? = nil,
        at date: Date,
        perform: Perform,
        performViewDefinedGesture: (_ isEligible: Bool) -> Bool = { _ in false },
        performViewDefinedShortcut: (_ isEligible: Bool) -> Bool = { _ in false },
        invalidate: @escaping () -> Void
    ) -> InputEventResult {
        let sample = rootSample(from: incomingSample)

        if case .pointerPress(let press) = sample,
           press.phase == .down {
            cancelIncompatiblePointerRecognition(
                reason: .superseded,
                perform: perform
            )
        }
        if case .keyPress(let press) = sample,
           press.phase == .down {
            cancelIncompatibleShortcutRecognition(
                reason: .superseded,
                perform: perform
            )
        }

        let targetPath = targetPath(for: sample, keyTargetPath: keyTargetPath)
        let candidates = orderedAttachments.filter { attachment in
            attachment.families.contains(sample.families)
                && isEligible(
                    attachment,
                    targetPath: targetPath,
                    sample: sample
                )
        }
        var visited: Set<RecognitionAttachmentID> = []
        let statefulKind: RecognitionAttachmentKind = sample.families.contains(.key)
            ? .shortcut
            : .gesture
        var lowerStatefulTiersAreBlocked = false
        for tier in RecognitionAttachmentTier.allCases {
            if dispatchInput(
                sample,
                candidates: candidates,
                tier: tier,
                stage: .immediate,
                date: date,
                visited: &visited,
                perform: perform,
                invalidate: invalidate
            ) == .handled {
                cancelRemaining(
                    for: sample,
                    excluding: visited,
                    reason: .consumed,
                    perform: perform
                )
                return .handled
            }
            if dispatchInput(
                sample,
                candidates: candidates,
                tier: tier,
                stage: .eager,
                date: date,
                visited: &visited,
                perform: perform,
                invalidate: invalidate
            ) == .handled {
                cancelRemaining(
                    for: sample,
                    excluding: visited,
                    reason: .consumed,
                    perform: perform
                )
                return .handled
            }

            if !lowerStatefulTiersAreBlocked {
                lowerStatefulTiersAreBlocked = dispatchStatefulRecognizers(
                    sample,
                    candidates: candidates,
                    kind: statefulKind,
                    tier: tier,
                    date: date,
                    targetPath: targetPath,
                    visited: &visited,
                    perform: perform,
                    invalidate: invalidate
                )
            }

            if tier == .viewDefined {
                let performViewDefined = statefulKind == .shortcut
                    ? performViewDefinedShortcut
                    : performViewDefinedGesture
                if lowerStatefulTiersAreBlocked {
                    _ = performViewDefined(false)
                } else if performViewDefined(true) {
                    lowerStatefulTiersAreBlocked = true
                    cancelNormalRecognizers(
                        kind: statefulKind,
                        reason: .consumed,
                        perform: perform
                    )
                }
            }

            if dispatchInput(
                sample,
                candidates: candidates,
                tier: tier,
                stage: .lazy,
                date: date,
                visited: &visited,
                perform: perform,
                invalidate: invalidate
            ) == .handled {
                cancelRemaining(
                    for: sample,
                    excluding: visited,
                    reason: .consumed,
                    perform: perform
                )
                return .handled
            }
        }

        if case .pointerPress(let press) = sample, press.phase == .up {
            let candidateIDs = Set(candidates.map(\.id))
            cancelUntargetedPointerInput(
                candidateIDs: candidateIDs,
                perform: perform
            )
            clearCapture()
        }
        return .ignored
    }

    func advance(
        to date: Date,
        perform: Perform,
        performViewDefinedGesture: (_ isEligible: Bool) -> Bool = { _ in false },
        performViewDefinedShortcut: (_ isEligible: Bool) -> Bool = { _ in false },
        invalidate: @escaping () -> Void
    ) {
        advance(
            to: date,
            kind: .gesture,
            perform: perform,
            performViewDefined: performViewDefinedGesture,
            invalidate: invalidate
        )
        advance(
            to: date,
            kind: .shortcut,
            perform: perform,
            performViewDefined: performViewDefinedShortcut,
            invalidate: invalidate
        )
    }

    private func advance(
        to date: Date,
        kind: RecognitionAttachmentKind,
        perform: Perform,
        performViewDefined: (_ isEligible: Bool) -> Bool,
        invalidate: @escaping () -> Void
    ) {
        var lowerTiersAreBlocked = false
        for tier in RecognitionAttachmentTier.allCases {
            let candidates = orderedAttachments
                .filter {
                    $0.tier == tier
                        && $0.kind == kind
                        && $0.nextDeadline.map({ $0 <= date }) == true
                }
                .sorted(by: statefulPrecedes)
            for attachment in candidates {
                if lowerTiersAreBlocked {
                    continue
                }
                let outcome = perform(attachment) {
                    attachment.advance(
                        to: date,
                        convert: coordinateConverter(for: attachment),
                        invalidate: invalidate
                    )
                }
                if outcome.recognitionClaimed {
                    cancelCompetingRecognizers(
                        after: attachment,
                        kind: kind,
                        reason: .consumed,
                        perform: perform
                    )
                    if !attachment.isSimultaneousRecognition {
                        lowerTiersAreBlocked = true
                    }
                }
            }

            if tier == .viewDefined {
                if lowerTiersAreBlocked {
                    _ = performViewDefined(false)
                } else if performViewDefined(true) {
                    lowerTiersAreBlocked = true
                    cancelNormalRecognizers(
                        kind: kind,
                        reason: .consumed,
                        perform: perform
                    )
                }
            }
        }
    }

    func cancelAll(
        _ reason: RecognitionCancellationReason,
        perform: Perform
    ) {
        for attachment in orderedAttachments where attachment.isActive {
            _ = perform(attachment) {
                attachment.cancel(reason)
                return AttachmentDispatchOutcome()
            }
        }
        clearCapture()
    }

    func focusDidChange(
        from previousPath: [Int]?,
        to currentPath: [Int]?,
        perform: Perform
    ) {
        guard previousPath != currentPath, let previousPath else {
            return
        }
        for attachment in orderedAttachments
        where attachment.isActive
            && attachment.families.contains(.key)
            && isKeyTargeted(attachment, targetPath: previousPath) {
            _ = perform(attachment) {
                attachment.cancel(.focusLost)
                return AttachmentDispatchOutcome()
            }
        }
    }

    private func dispatchInput(
        _ sample: RecognitionSample,
        candidates: [AnyRecognitionAttachment],
        tier: RecognitionAttachmentTier,
        stage: InputEventStage,
        date: Date,
        visited: inout Set<RecognitionAttachmentID>,
        perform: Perform,
        invalidate: @escaping () -> Void
    ) -> InputEventResult {
        for attachment in candidates
        where attachment.tier == tier
            && attachment.kind == .inputEvent
            && attachment.stage == stage {
            visited.insert(attachment.id)
            let outcome = perform(attachment) {
                attachment.process(
                    sample,
                    date: date,
                    isTargeted: true,
                    convert: coordinateConverter(for: attachment),
                    invalidate: invalidate
                )
            }
            if outcome.beginsCapture {
                capturedAttachmentID = attachment.id
                capturedPath = attachment.path
            }
            if outcome.endsCapture, capturedAttachmentID == attachment.id {
                clearCapture()
            }
            if outcome.result == .handled {
                return .handled
            }
        }
        return .ignored
    }

    private func dispatchStatefulRecognizers(
        _ sample: RecognitionSample,
        candidates: [AnyRecognitionAttachment],
        kind: RecognitionAttachmentKind,
        tier: RecognitionAttachmentTier,
        date: Date,
        targetPath: [Int]?,
        visited: inout Set<RecognitionAttachmentID>,
        perform: Perform,
        invalidate: @escaping () -> Void
    ) -> Bool {
        var hasWinner = false
        let statefulCandidates = candidates
            .filter { $0.tier == tier && $0.kind == kind }
            .sorted(by: statefulPrecedes)
        for attachment in statefulCandidates {
            if hasWinner && !attachment.isSimultaneousRecognition {
                continue
            }
            visited.insert(attachment.id)
            let outcome = perform(attachment) {
                attachment.process(
                    sample,
                    date: date,
                    isTargeted: isTargeted(
                        attachment,
                        targetPath: targetPath,
                        sample: sample
                    ) || (kind == .shortcut
                        && targetPath == nil
                        && attachment.path.isEmpty),
                    convert: coordinateConverter(for: attachment),
                    invalidate: invalidate
                )
            }
            if outcome.beginsCapture {
                capturedAttachmentID = attachment.id
                capturedPath = attachment.path
            }
            if outcome.endsCapture, capturedAttachmentID == attachment.id {
                clearCapture()
            }
            if outcome.recognitionClaimed {
                cancelCompetingRecognizers(
                    after: attachment,
                    kind: kind,
                    reason: .consumed,
                    perform: perform
                )
                if !attachment.isSimultaneousRecognition {
                    hasWinner = true
                }
            }
        }
        return hasWinner
    }

    /// Orders competing stateful recognizers from the deepest receiver toward its
    /// ancestors. At one path, the source-innermost modifier has the larger
    /// registration slot and receives the first opportunity to recognize.
    /// Simultaneous attachments remain observational and preserve render order.
    private func statefulPrecedes(
        _ lhs: AnyRecognitionAttachment,
        _ rhs: AnyRecognitionAttachment
    ) -> Bool {
        if lhs.isSimultaneousRecognition || rhs.isSimultaneousRecognition {
            if lhs.isSimultaneousRecognition != rhs.isSimultaneousRecognition {
                return lhs.isSimultaneousRecognition
            }
            if lhs.path.count != rhs.path.count {
                return lhs.path.count < rhs.path.count
            }
            return lhs.id.slot < rhs.id.slot
        }
        if lhs.path.count != rhs.path.count {
            return lhs.path.count > rhs.path.count
        }
        return lhs.id.slot > rhs.id.slot
    }

    private func cancelNormalRecognizers(
        kind: RecognitionAttachmentKind,
        reason: RecognitionCancellationReason,
        perform: Perform
    ) {
        for attachment in orderedAttachments
        where attachment.kind == kind
            && attachment.tier == .normal
            && attachment.isActive {
            _ = perform(attachment) {
                attachment.cancel(reason)
                return AttachmentDispatchOutcome()
            }
            if capturedAttachmentID == attachment.id {
                clearCapture()
            }
        }
    }

    private func cancelCompetingRecognizers(
        after winner: AnyRecognitionAttachment,
        kind: RecognitionAttachmentKind,
        reason: RecognitionCancellationReason,
        perform: Perform
    ) {
        guard !winner.isSimultaneousRecognition else {
            return
        }
        for attachment in orderedAttachments
        where attachment.id != winner.id
            && attachment.kind == kind
            && !attachment.isSimultaneousRecognition
            && attachment.tier >= winner.tier
            && attachment.isActive {
            _ = perform(attachment) {
                attachment.cancel(reason)
                return AttachmentDispatchOutcome()
            }
            if capturedAttachmentID == attachment.id {
                clearCapture()
            }
        }
    }

    private func cancelRemaining(
        for sample: RecognitionSample,
        excluding visited: Set<RecognitionAttachmentID>,
        reason: RecognitionCancellationReason,
        perform: Perform
    ) {
        for attachment in orderedAttachments
        where attachment.isActive
            && attachment.families.contains(sample.families)
            && !visited.contains(attachment.id) {
            _ = perform(attachment) {
                attachment.cancel(reason)
                return AttachmentDispatchOutcome()
            }
            if capturedAttachmentID == attachment.id {
                clearCapture()
            }
        }
    }

    private func cancelIncompatiblePointerRecognition(
        reason: RecognitionCancellationReason,
        perform: Perform
    ) {
        for attachment in orderedAttachments
        where attachment.isActive
            && !attachment.families.intersection(.pointer).isEmpty
            && !attachment.acceptsNewPointerDownWhileActive {
            _ = perform(attachment) {
                attachment.cancel(reason)
                return AttachmentDispatchOutcome()
            }
            if capturedAttachmentID == attachment.id {
                clearCapture()
            }
        }
    }

    private func cancelIncompatibleShortcutRecognition(
        reason: RecognitionCancellationReason,
        perform: Perform
    ) {
        for attachment in orderedAttachments
        where attachment.kind == .shortcut
            && attachment.isActive
            && !attachment.acceptsNewKeyDownWhileActive {
            _ = perform(attachment) {
                attachment.cancel(reason)
                return AttachmentDispatchOutcome()
            }
        }
    }

    private func cancelUntargetedPointerInput(
        candidateIDs: Set<RecognitionAttachmentID>,
        perform: Perform
    ) {
        for attachment in orderedAttachments
        where attachment.kind == .inputEvent
            && attachment.isActive
            && !attachment.families.intersection(.pointer).isEmpty
            && !candidateIDs.contains(attachment.id) {
            _ = perform(attachment) {
                attachment.cancel(.superseded)
                return AttachmentDispatchOutcome()
            }
        }
    }

    private func cancelCapture(
        reason: RecognitionCancellationReason,
        perform: Perform
    ) {
        guard let capturedAttachmentID,
              let attachment = attachments[capturedAttachmentID] else {
            clearCapture()
            return
        }
        _ = perform(attachment) {
            attachment.cancel(reason)
            return AttachmentDispatchOutcome()
        }
        clearCapture()
    }

    private func nextID(
        path: [Int],
        kind: RecognitionAttachmentKind
    ) -> RecognitionAttachmentID {
        let slot = nextSlots[path, default: [:]][kind, default: 0]
        nextSlots[path, default: [:]][kind] = slot + 1
        return RecognitionAttachmentID(path: path, kind: kind, slot: slot)
    }

    private func targetPath(
        for sample: RecognitionSample,
        keyTargetPath: [Int]?
    ) -> [Int]? {
        switch sample {
        case .keyPress:
            return keyTargetPath
        case .pointerPress(let press):
            if press.phase == .up, let capturedPath {
                return capturedPath
            }
            return hitTarget(at: press.location)
        case .pointerMotion(let motion):
            if motion.button != nil, let capturedPath {
                return capturedPath
            }
            return hitTarget(at: motion.location)
        case .pointerScroll(let scroll):
            return hitTarget(at: scroll.location)
        }
    }

    private func isEligible(
        _ attachment: AnyRecognitionAttachment,
        targetPath: [Int]?,
        sample: RecognitionSample
    ) -> Bool {
        if isTargeted(
            attachment,
            targetPath: targetPath,
            sample: sample
        ) {
            return true
        }
        if attachment.kind == .shortcut,
           targetPath == nil,
           attachment.path.isEmpty,
           sample.families.contains(.key) {
            return true
        }
        if attachment.kind == .gesture,
           attachment.isActive,
           sample.families.intersection(.pointer).isEmpty == false {
            return true
        }
        return false
    }

    private func isTargeted(
        _ attachment: AnyRecognitionAttachment,
        targetPath: [Int]?,
        sample: RecognitionSample
    ) -> Bool {
        switch sample {
        case .keyPress:
            return isKeyTargeted(
                attachment,
                targetPath: targetPath
            )
        case .pointerPress(let press):
            return isPointerTargeted(
                attachment,
                targetPath: targetPath,
                point: press.location
            )
        case .pointerMotion(let motion):
            return isPointerTargeted(
                attachment,
                targetPath: targetPath,
                point: motion.location
            )
        case .pointerScroll(let scroll):
            return isPointerTargeted(
                attachment,
                targetPath: targetPath,
                point: scroll.location
            )
        }
    }

    private func isKeyTargeted(
        _ attachment: AnyRecognitionAttachment,
        targetPath: [Int]?
    ) -> Bool {
        guard let targetPath else {
            return false
        }
        return targetPath.starts(with: attachment.path)
            || attachment.path.starts(with: targetPath)
    }

    /// Limits direct pointer delivery to the hit-tested branch, its ancestors,
    /// and descendant attachments whose own hit regions contain the pointer.
    /// The frame check excludes sibling branches when a common ancestor is the
    /// deepest selected target while preserving overlapping descendant input.
    private func isPointerTargeted(
        _ attachment: AnyRecognitionAttachment,
        targetPath: [Int]?,
        point: Point
    ) -> Bool {
        if capturedAttachmentID == attachment.id {
            return true
        }
        guard let targetPath else {
            return false
        }
        let attachmentRegions = hitRegions.filter {
            $0.recognitionAttachmentIDs.contains(attachment.id)
        }
        let isInsideAttachment = attachmentRegions.contains {
            $0.frame.contains(column: point.column, row: point.row)
        }
        if targetPath == attachment.path, !attachmentRegions.isEmpty {
            return isInsideAttachment
        }
        if targetPath.starts(with: attachment.path) {
            return true
        }
        guard attachment.path.starts(with: targetPath) else {
            return false
        }
        if !attachmentRegions.isEmpty {
            return isInsideAttachment
        }
        return hitRegions.contains {
            $0.path == attachment.path
                && $0.frame.contains(column: point.column, row: point.row)
        }
    }

    private func hitTarget(at point: Point) -> [Int]? {
        let pointerRegions = hitRegions.map { ($0.path, $0.frame) }
            + focusRegions.map { ($0.path, $0.frame) }
            + scrollRegions.map { ($0.path, $0.frame) }
        return pointerRegions
            .filter { $0.1.contains(column: point.column, row: point.row) }
            .max {
                if $0.0.count != $1.0.count {
                    return $0.0.count < $1.0.count
                }
                return $0.1.area > $1.1.area
            }?
            .0
    }

    private func coordinateConverter(
        for attachment: AnyRecognitionAttachment
    ) -> (Point, CoordinateSpace) -> Point? {
        let attachmentID = attachment.id
        let path = attachment.path
        return { [hitRegions, focusRegions, scrollRegions, coordinateSpaceRegions] point, coordinateSpace in
            switch coordinateSpace.storage {
            case .global:
                return point
            case .local:
                let attachmentFrames = hitRegions
                    .filter({
                        $0.recognitionAttachmentIDs.contains(attachmentID)
                    })
                    .map { $0.positionFrame ?? $0.frame }
                if let frame = attachmentFrames.min(by: { $0.area < $1.area }) {
                    return Point(
                        column: point.column - frame.x,
                        row: point.row - frame.y
                    )
                }
                let fallbackFrames = focusRegions
                    .filter({ $0.path == path })
                    .map { $0.positionFrame ?? $0.frame }
                    + scrollRegions
                    .filter({ $0.path == path })
                    .map(\.frame)
                guard let frame = fallbackFrames.min(by: { $0.area < $1.area }) else {
                    return Point(column: point.column, row: point.row)
                }
                return Point(
                    column: point.column - frame.x,
                    row: point.row - frame.y
                )
            case .named(let name):
                guard let region = coordinateSpaceRegions
                    .filter({ $0.name == name && path.starts(with: $0.path) })
                    .max(by: {
                        if $0.path.count != $1.path.count {
                            return $0.path.count < $1.path.count
                        }
                        return $0.frame.area > $1.frame.area
                    }) else {
                    return nil
                }
                return Point(
                    column: point.column - region.frame.x,
                    row: point.row - region.frame.y
                )
            }
        }
    }

    private func rootSample(from sample: RecognitionSample) -> RecognitionSample {
        let deltaColumn = rootFrame.column - 1
        let deltaRow = rootFrame.row - 1
        func point(_ point: Point) -> Point {
            Point(
                column: point.column - deltaColumn,
                row: point.row - deltaRow
            )
        }
        switch sample {
        case .keyPress:
            return sample
        case .pointerPress(let value):
            return .pointerPress(
                PointerPress(
                    button: value.button,
                    location: point(value.location),
                    modifiers: value.modifiers,
                    phase: value.phase
                )
            )
        case .pointerMotion(let value):
            return .pointerMotion(
                PointerMotion(
                    button: value.button,
                    location: point(value.location),
                    modifiers: value.modifiers
                )
            )
        case .pointerScroll(let value):
            return .pointerScroll(
                PointerScroll(
                    delta: value.delta,
                    location: point(value.location),
                    modifiers: value.modifiers
                )
            )
        }
    }

    private func clearCapture() {
        capturedAttachmentID = nil
        capturedPath = nil
    }
}

enum RecognitionRenderContext {

    struct Values: Sendable {

        var inputEventsEnabled = true

        var gesturesEnabled = true

        var shortcutsEnabled = true
    }

    @TaskLocal static var values = Values()

    static func withInputEvents<Value>(
        enabled: Bool,
        perform operation: () -> Value
    ) -> Value {
        var next = values
        next.inputEventsEnabled = values.inputEventsEnabled && enabled
        return $values.withValue(next, operation: operation)
    }

    static func withGestures<Value>(
        enabled: Bool,
        perform operation: () -> Value
    ) -> Value {
        var next = values
        next.gesturesEnabled = values.gesturesEnabled && enabled
        return $values.withValue(next, operation: operation)
    }

    static func withShortcuts<Value>(
        enabled: Bool,
        perform operation: () -> Value
    ) -> Value {
        var next = values
        next.shortcutsEnabled = values.shortcutsEnabled && enabled
        return $values.withValue(next, operation: operation)
    }
}

struct InputEventAttachmentView<Content: View, Event: InputEvent>: View,
    InputModifierRenderable, LayoutTraitRenderable
{
    typealias Body = Never

    let content: Content

    let event: Event

    let tier: RecognitionAttachmentTier

    let mask: InputEventMask

    let actionPath: [Int]?

    init(
        content: Content,
        event: Event,
        tier: RecognitionAttachmentTier,
        mask: InputEventMask
    ) {
        self.content = content
        self.event = event
        self.tier = tier
        self.mask = mask
        self.actionPath = StateContext.currentPath
    }

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let canRegister = RecognitionRenderContext.values.inputEventsEnabled
            && mask.contains(.inputEvent)
        let attachmentID = canRegister
            ? runtime?.registerInputEvent(
                event,
                at: path,
                actionPath: actionPath,
                tier: tier
            )
            : nil
        guard var block = RecognitionRenderContext.withInputEvents(
            enabled: mask.contains(.subviews),
            perform: {
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
        if let attachmentID {
            block.hitRegions.append(
                RenderedHitRegion(
                    path: path,
                    frame: block.bounds,
                    recognitionAttachmentIDs: [attachmentID]
                )
            )
        }
        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map(RenderedElement.block)
    }
}

struct GestureAttachmentView<Content: View, AttachedGesture: Gesture>: View,
    InputModifierRenderable, LayoutTraitRenderable
{
    typealias Body = Never

    let content: Content

    let gesture: AttachedGesture

    let tier: RecognitionAttachmentTier

    let mask: GestureMask

    let isSimultaneous: Bool

    let actionPath: [Int]?

    init(
        content: Content,
        gesture: AttachedGesture,
        tier: RecognitionAttachmentTier,
        mask: GestureMask,
        isSimultaneous: Bool
    ) {
        self.content = content
        self.gesture = gesture
        self.tier = tier
        self.mask = mask
        self.isSimultaneous = isSimultaneous
        self.actionPath = StateContext.currentPath
    }

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let canRegister = RecognitionRenderContext.values.gesturesEnabled
            && mask.contains(.gesture)
        let attachmentID: RecognitionAttachmentID? = if canRegister {
            runtime?.registerGesture(
                gesture,
                at: path,
                actionPath: actionPath,
                tier: tier,
                isSimultaneous: isSimultaneous
            )
        }
        else {
            nil
        }
        guard var block = RecognitionRenderContext.withGestures(
            enabled: mask.contains(.subviews),
            perform: {
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
        if canRegister {
            block.hitRegions.append(
                RenderedHitRegion(
                    path: path,
                    frame: block.bounds,
                    recognitionAttachmentIDs: attachmentID.map { [$0] } ?? []
                )
            )
        }
        return block
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map(RenderedElement.block)
    }
}

struct ShortcutAttachmentView<Content: View, AttachedShortcut: Shortcut>: View,
    InputModifierRenderable, LayoutTraitRenderable
{
    typealias Body = Never

    let content: Content

    let shortcut: AttachedShortcut

    let tier: RecognitionAttachmentTier

    let mask: ShortcutMask

    let isSimultaneous: Bool

    let actionPath: [Int]?

    init(
        content: Content,
        shortcut: AttachedShortcut,
        tier: RecognitionAttachmentTier,
        mask: ShortcutMask,
        isSimultaneous: Bool
    ) {
        self.content = content
        self.shortcut = shortcut
        self.tier = tier
        self.mask = mask
        self.isSimultaneous = isSimultaneous
        self.actionPath = StateContext.currentPath
    }

    var layoutTraits: LayoutTraits {
        ViewResolver.layoutTraits(from: content)
    }

    func renderedBlock(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedBlock? {
        let canRegister = RecognitionRenderContext.values.shortcutsEnabled
            && mask.contains(.shortcut)
        if canRegister {
            runtime?.registerShortcut(
                shortcut,
                at: path,
                actionPath: actionPath,
                tier: tier,
                isSimultaneous: isSimultaneous
            )
        }
        return RecognitionRenderContext.withShortcuts(
            enabled: mask.contains(.subviews),
            perform: {
                ViewResolver.block(
                    from: content,
                    in: proposal,
                    path: path,
                    runtime: runtime
                )
            }
        )
    }

    func renderedElement(
        in proposal: RenderProposal?,
        path: [Int],
        runtime: StateRuntime?
    ) -> RenderedElement? {
        renderedBlock(in: proposal, path: path, runtime: runtime).map(RenderedElement.block)
    }
}
