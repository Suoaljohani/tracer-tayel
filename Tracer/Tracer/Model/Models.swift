import Foundation
import SwiftData

// MARK: - Topic

@Model
final class TraceTopic {
    @Attribute(.unique) var id: UUID
    var number: Int
    var title: String
    var objective: String
    var summary: String
    var symbol: String
    var tracerTypeRaw: String
    var departmentCodes: [String]
    var clauseIDs: [String]
    var archived: Bool
    var version: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TopicQuestion.topic)
    var questions: [TopicQuestion] = []

    @Relationship(deleteRule: .cascade, inverse: \TraceSession.topic)
    var sessions: [TraceSession] = []

    init(number: Int, title: String, objective: String = "", summary: String = "", symbol: String = "point.3.filled.connected.trianglepath.dotted", tracerType: TracerType = .system, departmentCodes: [String] = [], clauseIDs: [String] = []) {
        self.id = UUID()
        self.number = number
        self.title = title
        self.objective = objective
        self.summary = summary
        self.symbol = symbol
        self.tracerTypeRaw = tracerType.rawValue
        self.departmentCodes = departmentCodes
        self.clauseIDs = clauseIDs
        self.archived = false
        self.version = 1
        self.createdAt = .now
        self.updatedAt = .now
    }

    var tracerType: TracerType {
        get { TracerType(rawValue: tracerTypeRaw) ?? .system }
        set { tracerTypeRaw = newValue.rawValue }
    }

    var code: String { String(format: "TR-%03d", number) }

    var orderedQuestions: [TopicQuestion] { questions.sorted { $0.order < $1.order } }

    var activeSessions: [TraceSession] { sessions.filter { $0.status == .active || $0.status == .onHold } }
    var completedSessions: [TraceSession] { sessions.filter { $0.status == .completed } }

    var lastActivity: Date {
        sessions.map(\.lastActivityAt).max() ?? updatedAt
    }

    var latestSession: TraceSession? {
        sessions.max(by: { $0.lastActivityAt < $1.lastActivityAt })
    }

    /// Highest unresolved risk across open sessions, and whether it is still only suggested.
    var topRisk: (level: RiskLevel, approved: Bool)? {
        let candidates = sessions.filter { $0.status != .completed }.compactMap { $0.topRisk }
        return candidates.max(by: { $0.level.weight < $1.level.weight })
    }
}

@Model
final class TopicQuestion {
    @Attribute(.unique) var id: UUID
    var text: String
    var departmentCode: String
    var clauseIDs: [String]
    var expectedEvidence: String
    var order: Int
    var topic: TraceTopic?

    init(text: String, departmentCode: String, clauseIDs: [String] = [], expectedEvidence: String = "", order: Int) {
        self.id = UUID()
        self.text = text
        self.departmentCode = departmentCode
        self.clauseIDs = clauseIDs
        self.expectedEvidence = expectedEvidence
        self.order = order
    }
}

// MARK: - Session

@Model
final class TraceSession {
    @Attribute(.unique) var id: UUID
    var number: Int
    var statusRaw: String
    var topicVersion: Int
    var organization: String
    var tracerTeam: String
    var evaluator: String
    var patientRecord: String
    var documentsReviewed: String
    var tracerDate: Date
    var createdAt: Date
    var lastActivityAt: Date
    var currentNodeID: UUID?
    var currentItemID: UUID?
    var lastTabRaw: String
    var closedAt: Date?
    var closeOverrideReason: String
    var topic: TraceTopic?

    @Relationship(deleteRule: .cascade, inverse: \TraceNode.session)
    var nodes: [TraceNode] = []

    @Relationship(deleteRule: .cascade, inverse: \TraceEdge.session)
    var edges: [TraceEdge] = []

    @Relationship(deleteRule: .cascade, inverse: \EvidenceItem.session)
    var evidence: [EvidenceItem] = []

    @Relationship(deleteRule: .cascade, inverse: \AuditEvent.session)
    var events: [AuditEvent] = []

    init(number: Int, topic: TraceTopic, organization: String, tracerTeam: String, evaluator: String) {
        self.id = UUID()
        self.number = number
        self.statusRaw = SessionStatus.active.rawValue
        self.topicVersion = topic.version
        self.organization = organization
        self.tracerTeam = tracerTeam
        self.evaluator = evaluator
        self.patientRecord = ""
        self.documentsReviewed = ""
        self.tracerDate = .now
        self.createdAt = .now
        self.lastActivityAt = .now
        self.lastTabRaw = "assess"
        self.closeOverrideReason = ""
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var orderedNodes: [TraceNode] { nodes.sorted { $0.order < $1.order } }
    var orderedEvents: [AuditEvent] { events.sorted { $0.date > $1.date } }

    var currentNode: TraceNode? {
        if let id = currentNodeID, let n = nodes.first(where: { $0.id == id }) { return n }
        return orderedNodes.last
    }

    var allItems: [TraceItem] { orderedNodes.flatMap(\.orderedItems) }

    var visitedDepartmentCodes: [String] {
        var seen: [String] = []
        for n in orderedNodes where !seen.contains(n.departmentCode) { seen.append(n.departmentCode) }
        return seen
    }

    /// Fixed rule: highest unresolved risk across all nodes. Not produced by the model.
    var topRisk: (level: RiskLevel, approved: Bool)? {
        let items = allItems.filter { !$0.resolved }
        let pairs: [(RiskLevel, Bool)] = items.compactMap { item in
            guard let r = item.effectiveRisk else { return nil }
            return (r, item.riskApproved)
        }
        guard let top = pairs.max(by: { $0.0.weight < $1.0.weight }) else { return nil }
        // If any item at the top level is still unapproved, show it as suggested.
        let approved = !pairs.contains { $0.0 == top.0 && !$0.1 }
        return (top.0, approved)
    }

    var criticalPendingReview: Bool {
        allItems.contains { !$0.resolved && !$0.riskApproved && $0.suggestedRisk == .critical }
    }

    var needsReview: Bool {
        allItems.contains { !$0.resolved && !$0.riskApproved && ($0.suggestedRisk?.isElevated ?? false) }
    }

    var displayTitle: String {
        L("Session \(number)", "الجلسة \(number)")
    }
}

// MARK: - Node / Item

@Model
final class TraceNode {
    @Attribute(.unique) var id: UUID
    var departmentCode: String
    var order: Int
    var createdAt: Date
    var mandatory: Bool
    var closed: Bool
    var closedAt: Date?
    var note: String
    var session: TraceSession?

    @Relationship(deleteRule: .cascade, inverse: \TraceItem.node)
    var items: [TraceItem] = []

    init(departmentCode: String, order: Int, mandatory: Bool = true) {
        self.id = UUID()
        self.departmentCode = departmentCode
        self.order = order
        self.createdAt = .now
        self.mandatory = mandatory
        self.closed = false
        self.note = ""
    }

    var orderedItems: [TraceItem] { items.sorted { $0.order < $1.order } }

    var topRisk: RiskLevel? {
        RiskLevel.highest(items.filter { !$0.resolved }.compactMap(\.effectiveRisk))
    }

    var openRequiredWork: Bool {
        mandatory && !closed && items.contains { $0.compliance == .unset }
    }
}

@Model
final class TraceItem {
    @Attribute(.unique) var id: UUID
    var questionText: String
    var personAsked: String
    var clauseIDs: [String]
    var expectedEvidence: String
    var draftAnswer: String
    var order: Int
    var createdAt: Date

    var complianceRaw: String
    var evidenceOfCompliance: String
    var planOfAction: String
    var dueDate: Date?

    // Human decision on risk (SAFER)
    var riskApproved: Bool
    var approvedLikelihoodRaw: String
    var approvedScopeRaw: String
    var approvedImmediateThreat: Bool
    var approvedFindingExists: Bool
    var riskDecisionReason: String
    var riskDecidedAt: Date?

    var resolved: Bool
    var resolvedAt: Date?
    var resolutionNote: String

    var node: TraceNode?

    @Relationship(deleteRule: .cascade, inverse: \StaffResponse.item)
    var responses: [StaffResponse] = []

    @Relationship(deleteRule: .cascade, inverse: \AnalysisRecord.item)
    var analyses: [AnalysisRecord] = []

    init(questionText: String, personAsked: String = "", clauseIDs: [String] = [], expectedEvidence: String = "", order: Int) {
        self.id = UUID()
        self.questionText = questionText
        self.personAsked = personAsked
        self.clauseIDs = clauseIDs
        self.expectedEvidence = expectedEvidence
        self.draftAnswer = ""
        self.order = order
        self.createdAt = .now
        self.complianceRaw = Compliance.unset.rawValue
        self.evidenceOfCompliance = ""
        self.planOfAction = ""
        self.riskApproved = false
        self.approvedLikelihoodRaw = Likelihood.unknown.rawValue
        self.approvedScopeRaw = NoncomplianceScope.unknown.rawValue
        self.approvedImmediateThreat = false
        self.approvedFindingExists = true
        self.riskDecisionReason = ""
        self.resolved = false
        self.resolutionNote = ""
    }

    var compliance: Compliance {
        get { Compliance(rawValue: complianceRaw) ?? .unset }
        set { complianceRaw = newValue.rawValue }
    }

    var approvedLikelihood: Likelihood {
        get { Likelihood(rawValue: approvedLikelihoodRaw) ?? .unknown }
        set { approvedLikelihoodRaw = newValue.rawValue }
    }

    var approvedScope: NoncomplianceScope {
        get { NoncomplianceScope(rawValue: approvedScopeRaw) ?? .unknown }
        set { approvedScopeRaw = newValue.rawValue }
    }

    var orderedResponses: [StaffResponse] { responses.sorted { $0.createdAt < $1.createdAt } }
    var latestAnalysis: AnalysisRecord? { analyses.max(by: { $0.createdAt < $1.createdAt }) }

    /// The combined answer text as recorded (original + addenda + corrections in order).
    var recordedAnswer: String {
        orderedResponses.map(\.text).joined(separator: "\n")
    }

    var hasAnswer: Bool { !responses.isEmpty }

    var suggestedRisk: RiskLevel? { latestAnalysis?.riskLevel }

    var approvedRisk: RiskLevel? {
        guard riskApproved else { return nil }
        return RiskLevel.from(likelihood: approvedLikelihood, immediateThreat: approvedImmediateThreat, findingExists: approvedFindingExists)
    }

    var effectiveRisk: RiskLevel? { approvedRisk ?? suggestedRisk }

    /// Historical risk is kept even after resolution.
    var historicalRisk: RiskLevel? { effectiveRisk }
}

@Model
final class StaffResponse {
    @Attribute(.unique) var id: UUID
    var text: String
    var kindRaw: String
    var createdAt: Date
    var previousText: String
    var item: TraceItem?

    init(text: String, kind: ResponseKind, previousText: String = "") {
        self.id = UUID()
        self.text = text
        self.kindRaw = kind.rawValue
        self.createdAt = .now
        self.previousText = previousText
    }

    var kind: ResponseKind { ResponseKind(rawValue: kindRaw) ?? .original }
}

@Model
final class AnalysisRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var payload: Data
    var answerSnapshot: String
    var questionSnapshot: String
    var clauseSnapshot: [String]
    var riskRaw: String
    var item: TraceItem?

    init(result: AnalysisResult, payload: Data, answer: String, question: String, clauses: [String]) {
        self.id = UUID()
        self.createdAt = .now
        self.payload = payload
        self.answerSnapshot = answer
        self.questionSnapshot = question
        self.clauseSnapshot = clauses
        self.riskRaw = result.riskLevel.rawValue
    }

    var riskLevel: RiskLevel { RiskLevel(rawValue: riskRaw) ?? .undetermined }

    var result: AnalysisResult? {
        try? JSONDecoder().decode(AnalysisResult.self, from: payload)
    }
}

// MARK: - Links, evidence, audit

@Model
final class TraceEdge {
    @Attribute(.unique) var id: UUID
    var fromNodeID: UUID
    var toNodeID: UUID
    var linkTypeRaw: String
    var reason: String
    var triggerQuestion: String
    var requestKey: String
    var createdAt: Date
    var session: TraceSession?

    init(from: UUID, to: UUID, type: LinkType, reason: String, triggerQuestion: String, requestKey: String) {
        self.id = UUID()
        self.fromNodeID = from
        self.toNodeID = to
        self.linkTypeRaw = type.rawValue
        self.reason = reason
        self.triggerQuestion = triggerQuestion
        self.requestKey = requestKey
        self.createdAt = .now
    }

    var linkType: LinkType { LinkType(rawValue: linkTypeRaw) ?? .manual }
}

@Model
final class EvidenceItem {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var title: String
    var note: String
    var departmentCode: String
    var createdAt: Date
    var verified: Bool
    var linkedItemIDs: [UUID]
    var fileName: String
    @Attribute(.externalStorage) var data: Data?
    var session: TraceSession?

    init(kind: EvidenceKind, title: String, note: String = "", departmentCode: String, data: Data? = nil, fileName: String = "") {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.title = title
        self.note = note
        self.departmentCode = departmentCode
        self.createdAt = .now
        self.verified = false
        self.linkedItemIDs = []
        self.fileName = fileName
        self.data = data
    }

    var kind: EvidenceKind { EvidenceKind(rawValue: kindRaw) ?? .observation }
}

@Model
final class AuditEvent {
    @Attribute(.unique) var id: UUID
    var date: Date
    var kindRaw: String
    var message: String
    var detail: String
    var departmentCode: String
    var actor: String
    var session: TraceSession?

    init(kind: AuditKind, message: String, detail: String = "", departmentCode: String = "", actor: String = "") {
        self.id = UUID()
        self.date = .now
        self.kindRaw = kind.rawValue
        self.message = message
        self.detail = detail
        self.departmentCode = departmentCode
        self.actor = actor
    }

    var kind: AuditKind { AuditKind(rawValue: kindRaw) ?? .fieldEdited }
}

@Model
final class CustomDepartment {
    @Attribute(.unique) var code: String
    var nameEN: String
    var nameAR: String
    var symbol: String
    var colorHex: Int
    var createdAt: Date

    init(code: String, nameEN: String, nameAR: String, symbol: String, colorHex: Int) {
        self.code = code
        self.nameEN = nameEN
        self.nameAR = nameAR
        self.symbol = symbol
        self.colorHex = colorHex
        self.createdAt = .now
    }
}
