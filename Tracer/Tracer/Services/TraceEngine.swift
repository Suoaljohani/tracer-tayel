import Foundation
import SwiftData

/// All state-changing operations on topics and sessions. Each one writes an audit event
/// and saves the context so nothing is lost if the app is closed or the connection drops.
@MainActor
struct TraceEngine {
    let context: ModelContext

    private var actor: String {
        let name = AppSettings.shared.evaluatorName
        return name.isEmpty ? L("Evaluator", "المقيِّم") : name
    }

    @discardableResult
    func save() -> Bool {
        do { try context.save(); return true } catch { return false }
    }

    func log(_ session: TraceSession, _ kind: AuditKind, _ message: String, detail: String = "", dept: String = "") {
        let e = AuditEvent(kind: kind, message: message, detail: detail, departmentCode: dept, actor: actor)
        context.insert(e)
        e.session = session
        session.lastActivityAt = .now
    }

    // MARK: Topics

    func nextTopicNumber() -> Int {
        let all = (try? context.fetch(FetchDescriptor<TraceTopic>())) ?? []
        return (all.map(\.number).max() ?? 0) + 1
    }

    // MARK: Sessions

    @discardableResult
    func startSession(topic: TraceTopic, organization: String, team: String, patientRecord: String, documents: String, date: Date, firstDepartment: String) -> TraceSession {
        let number = (topic.sessions.map(\.number).max() ?? 0) + 1
        let s = TraceSession(number: number, topic: topic, organization: organization, tracerTeam: team, evaluator: AppSettings.shared.evaluatorName)
        context.insert(s)
        s.topic = topic
        s.patientRecord = patientRecord
        s.documentsReviewed = documents
        s.tracerDate = date
        log(s, .sessionStarted, L("Session \(number) started", "بدء الجلسة \(number)"), detail: topic.title, dept: firstDepartment)
        let node = addNode(to: s, department: firstDepartment, seedQuestions: true)
        s.currentNodeID = node.id
        s.currentItemID = node.orderedItems.first?.id
        save()
        return s
    }

    @discardableResult
    func addNode(to session: TraceSession, department: String, seedQuestions: Bool) -> TraceNode {
        let order = (session.nodes.map(\.order).max() ?? -1) + 1
        let node = TraceNode(departmentCode: department, order: order)
        context.insert(node)
        node.session = session
        if seedQuestions, let topic = session.topic {
            let qs = topic.orderedQuestions.filter { $0.departmentCode == department }
            for (i, q) in qs.enumerated() {
                let item = TraceItem(questionText: q.text, clauseIDs: q.clauseIDs, expectedEvidence: q.expectedEvidence, order: i)
                context.insert(item)
                item.node = node
            }
        }
        log(session, .nodeCreated, L("Trace point added: \(dept(department).name)", "إضافة نقطة تتبع: \(dept(department).name)"), dept: department)
        return node
    }

    @discardableResult
    func addQuestion(to node: TraceNode, text: String, clauseIDs: [String] = [], expectedEvidence: String = "", personAsked: String = "") -> TraceItem {
        let order = (node.items.map(\.order).max() ?? -1) + 1
        let item = TraceItem(questionText: text, personAsked: personAsked, clauseIDs: clauseIDs, expectedEvidence: expectedEvidence, order: order)
        context.insert(item)
        item.node = node
        if let s = node.session {
            log(s, .questionAdded, L("Question added", "إضافة سؤال"), detail: text, dept: node.departmentCode)
        }
        save()
        return item
    }

    /// Creates (or reuses) a linked node in the same session. A repeated request with the same key
    /// never creates duplicate links.
    @discardableResult
    func branch(session: TraceSession, from: TraceNode, to department: String, type: LinkType, reason: String, question: String, clauseIDs: [String], focus: Bool = true) -> TraceNode {
        let key = "\(from.id.uuidString)|\(department)|\(type.rawValue)|\(question.prefix(80))"
        if let existing = session.edges.first(where: { $0.requestKey == key }),
           let node = session.nodes.first(where: { $0.id == existing.toNodeID }) {
            if focus { session.currentNodeID = node.id }
            return node
        }
        let node = addNode(to: session, department: department, seedQuestions: !session.nodes.contains { $0.departmentCode == department })
        if !question.isEmpty {
            let item = TraceItem(questionText: question, clauseIDs: clauseIDs, order: (node.items.map(\.order).max() ?? -1) + 1)
            context.insert(item)
            item.node = node
            if focus { session.currentItemID = item.id }
        } else if focus {
            session.currentItemID = node.orderedItems.first?.id
        }
        let edge = TraceEdge(from: from.id, to: node.id, type: type, reason: reason, triggerQuestion: question, requestKey: key)
        context.insert(edge)
        edge.session = session
        if focus { session.currentNodeID = node.id }
        log(session, .linkCreated,
            L("\(dept(from.departmentCode).name) → \(dept(department).name)", "\(dept(from.departmentCode).name) ← \(dept(department).name)"),
            detail: "\(type.title): \(reason)", dept: department)
        save()
        return node
    }

    // MARK: Answers

    func recordAnswer(_ item: TraceItem, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let kind: ResponseKind = item.responses.isEmpty ? .original : .addendum
        let r = StaffResponse(text: trimmed, kind: kind)
        context.insert(r)
        r.item = item
        item.draftAnswer = ""
        if let s = item.node?.session {
            log(s, kind == .original ? .answerRecorded : .answerAddendum, kind.title, detail: trimmed, dept: item.node?.departmentCode ?? "")
        }
        save()
    }

    func correct(_ response: StaffResponse, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != response.text, let item = response.item else { return }
        let r = StaffResponse(text: trimmed, kind: .correction, previousText: response.text)
        context.insert(r)
        r.item = item
        // Keep the original wording; the correction is stored as a new version.
        if let s = item.node?.session {
            log(s, .answerCorrected, L("Answer corrected", "تصحيح إجابة"), detail: "«\(response.text)» → «\(trimmed)»", dept: item.node?.departmentCode ?? "")
        }
        save()
    }

    func saveDraft(_ item: TraceItem) {
        item.node?.session?.lastActivityAt = .now
        save()
    }

    // MARK: Analysis

    func storeAnalysis(_ result: AnalysisResult, payload: Data, for item: TraceItem, clauses: [String]) {
        let rec = AnalysisRecord(result: result, payload: payload, answer: item.recordedAnswer, question: item.questionText, clauses: clauses)
        context.insert(rec)
        rec.item = item
        // A new analysis supersedes an earlier unapproved decision; approved decisions remain until changed.
        if let s = item.node?.session {
            log(s, .analysisRun, L("Analysis completed — suggested risk: \(result.riskLevel.title)", "اكتمل التحليل — الخطورة المقترحة: \(result.riskLevel.title)"),
                detail: result.summary, dept: item.node?.departmentCode ?? "")
            if result.riskLevel.isElevated && s.status == .active { s.status = .review }
        }
        save()
    }

    // MARK: Risk decisions

    func approveSuggested(_ item: TraceItem) {
        guard let r = item.latestAnalysis?.result else { return }
        decide(item, likelihood: r.likelihoodValue, scope: r.scopeValue, immediateThreat: r.immediate_threat, findingExists: r.finding_exists, reason: "", modified: false)
    }

    func decide(_ item: TraceItem, likelihood: Likelihood, scope: NoncomplianceScope, immediateThreat: Bool, findingExists: Bool, reason: String, modified: Bool) {
        let before = item.suggestedRisk
        item.approvedLikelihood = likelihood
        item.approvedScope = scope
        item.approvedImmediateThreat = immediateThreat
        item.approvedFindingExists = findingExists
        item.riskApproved = true
        item.riskDecisionReason = reason
        item.riskDecidedAt = .now
        if let s = item.node?.session {
            let level = item.approvedRisk ?? .undetermined
            if modified {
                log(s, .riskModified, L("Risk set to \(level.title)", "تعديل الخطورة إلى \(level.title)"),
                    detail: L("Suggested: \(before?.title ?? "—"). Reason: \(reason)", "المقترحة: \(before?.title ?? "—"). السبب: \(reason)"), dept: item.node?.departmentCode ?? "")
            } else {
                log(s, .riskApproved, L("Risk approved: \(level.title)", "اعتماد الخطورة: \(level.title)"), dept: item.node?.departmentCode ?? "")
            }
            if s.status == .review && !s.needsReview { s.status = .active }
        }
        save()
    }

    func setCompliance(_ item: TraceItem, _ value: Compliance) {
        item.compliance = value
        if let s = item.node?.session {
            log(s, .complianceSet, L("Compliance: \(value.title)", "الالتزام: \(value.title)"), detail: item.questionText, dept: item.node?.departmentCode ?? "")
        }
        save()
    }

    func setResolved(_ item: TraceItem, _ resolved: Bool, note: String) {
        item.resolved = resolved
        item.resolvedAt = resolved ? .now : nil
        item.resolutionNote = note
        if let s = item.node?.session {
            log(s, resolved ? .findingResolved : .findingReopened,
                resolved ? L("Finding resolved", "معالجة الملاحظة") : L("Finding reopened", "إعادة فتح الملاحظة"),
                detail: note, dept: item.node?.departmentCode ?? "")
        }
        save()
    }

    // MARK: Evidence

    func addEvidence(_ ev: EvidenceItem, to session: TraceSession, linking item: TraceItem?) {
        context.insert(ev)
        ev.session = session
        if let item { ev.linkedItemIDs = [item.id] }
        log(session, .evidenceAdded, L("Evidence added: \(ev.title)", "إرفاق دليل: \(ev.title)"), detail: ev.kind.title, dept: ev.departmentCode)
        save()
    }

    func toggleLink(_ ev: EvidenceItem, item: TraceItem) {
        if ev.linkedItemIDs.contains(item.id) {
            ev.linkedItemIDs.removeAll { $0 == item.id }
        } else {
            ev.linkedItemIDs.append(item.id)
        }
        save()
    }

    // MARK: Session lifecycle

    struct CloseCheck {
        var openNodes: [TraceNode]
        var unapprovedFindings: [TraceItem]
        var canClose: Bool { openNodes.isEmpty && unapprovedFindings.isEmpty }
    }

    func closeCheck(_ session: TraceSession) -> CloseCheck {
        let open = session.orderedNodes.filter { $0.openRequiredWork }
        let pending = session.allItems.filter { item in
            guard !item.resolved, !item.riskApproved, let r = item.suggestedRisk else { return false }
            return r != .noFinding
        }
        return CloseCheck(openNodes: open, unapprovedFindings: pending)
    }

    func setStatus(_ session: TraceSession, _ status: SessionStatus) {
        let old = session.status
        session.status = status
        log(session, .statusChanged, L("Status: \(old.title) → \(status.title)", "الحالة: \(old.title) ← \(status.title)"))
        save()
    }

    func close(_ session: TraceSession, overrideReason: String?) {
        if let reason = overrideReason, !reason.isEmpty {
            session.closeOverrideReason = reason
            log(session, .closeOverride, L("Closed with authorised override", "إغلاق بتجاوز مصرح به"), detail: reason)
        }
        for n in session.nodes where !n.closed { n.closed = true; n.closedAt = .now }
        session.status = .completed
        session.closedAt = .now
        log(session, .sessionClosed, L("Session closed", "إغلاق الجلسة"))
        save()
    }

    func reopen(_ session: TraceSession) {
        session.status = .active
        session.closedAt = nil
        log(session, .statusChanged, L("Session reopened", "إعادة فتح الجلسة"))
        save()
    }
}
