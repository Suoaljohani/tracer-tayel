import Foundation

struct AnalysisResult: Codable, Equatable {
    struct Conflict: Codable, Equatable, Hashable {
        var description: String
        var clause_id: String
        var clause_excerpt: String
    }

    struct Route: Codable, Equatable, Hashable {
        var department_code: String
        var link_type: String
        var reason: String
        var question: String

        var linkType: LinkType { LinkType(rawValue: link_type) ?? .followAction }
    }

    var summary: String
    var completeness: String
    var correctness: String
    var compliance_suggestion: String
    var met_elements: [String]
    var missing_elements: [String]
    var conflicts: [Conflict]
    var evidence_status: String
    var likelihood: String
    var scope: String
    var immediate_threat: Bool
    var finding_exists: Bool
    var risk_rationale: String
    var risk_clause_id: String
    var follow_up_question: String
    var routes: [Route]
    var confidence: String
    var human_review_required: Bool
    var human_review_reasons: [String]
    var suggested_plan_of_action: String
    var risk_level: String
    var model_version: String?

    var riskLevel: RiskLevel { RiskLevel(rawValue: risk_level) ?? .undetermined }
    var likelihoodValue: Likelihood { Likelihood(rawValue: likelihood) ?? .unknown }
    var scopeValue: NoncomplianceScope { NoncomplianceScope(rawValue: scope) ?? .unknown }
    var complianceValue: Compliance { Compliance(rawValue: compliance_suggestion) ?? .unset }

    var completenessTitle: String {
        switch completeness {
        case "complete": return L("Complete", "مكتملة")
        case "partial": return L("Partial", "ناقصة جزئيًا")
        default: return L("Missing", "غير متوفرة")
        }
    }
    var completenessTone: VerdictTone {
        switch completeness {
        case "complete": return .positive
        case "partial": return .caution
        default: return .negative
        }
    }

    var correctnessTitle: String {
        switch correctness {
        case "correct": return L("Correct", "صحيحة")
        case "partially_correct": return L("Partly correct", "صحيحة جزئيًا")
        case "incorrect": return L("Incorrect", "غير صحيحة")
        default: return L("Can't determine", "يتعذر الحكم")
        }
    }
    var correctnessTone: VerdictTone {
        switch correctness {
        case "correct": return .positive
        case "partially_correct": return .caution
        case "incorrect": return .negative
        default: return .neutral
        }
    }

    var evidenceTitle: String {
        switch evidence_status {
        case "sufficient": return L("Sufficient", "كافية")
        case "insufficient": return L("Insufficient", "غير كافية")
        default: return L("Not provided", "لم تُقدّم")
        }
    }

    var confidenceTitle: String {
        switch confidence {
        case "high": return L("High certainty", "يقين مرتفع")
        case "medium": return L("Medium certainty", "يقين متوسط")
        case "low": return L("Low certainty", "يقين منخفض")
        default: return L("Insufficient information", "المعلومات غير كافية")
        }
    }
}

enum VerdictTone { case positive, caution, negative, neutral }

struct TopicDraft: Codable {
    struct Question: Codable, Hashable {
        var text: String
        var department_code: String
        var clause_ids: [String]
        var expected_evidence: String
    }
    var objective: String
    var description: String
    var tracer_type: String
    var department_codes: [String]
    var questions: [Question]
}

enum AnalysisError: LocalizedError {
    case offline, server(String), decoding

    var errorDescription: String? {
        switch self {
        case .offline: return L("No connection. Your answer is saved on this iPhone; run the analysis when you're back online.", "لا يوجد اتصال. الإجابة محفوظة على الجهاز، ويمكن تشغيل التحليل عند عودة الاتصال.")
        case .server: return L("The analysis service didn't respond. Please try again.", "تعذر الوصول إلى خدمة التحليل. حاول مرة أخرى.")
        case .decoding: return L("The analysis came back incomplete. Please try again.", "وصلت نتيجة التحليل غير مكتملة. حاول مرة أخرى.")
        }
    }
}

/// Client for the Tracer analysis service hosted on Supabase Edge Functions.
/// Only the public (anon) key is embedded; the provider key stays on the server.
@MainActor
struct AnalysisClient {
    static let endpoint = URL(string: "https://ljdyrdgfscjeiaohbitc.supabase.co/functions/v1/analyze")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxqZHlyZGdmc2NqZWlhb2hiaXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE3NDQwMjksImV4cCI6MjEwNzMyMDAyOX0.OlHDpofTCoTsoayjFmQVJG0ak7JTWVBq3zavBu82B0A"

    private struct Envelope<T: Decodable>: Decodable {
        var ok: Bool
        var result: T?
        var error: String?
    }

    private func post<T: Decodable>(_ body: [String: Any], as type: T.Type) async throws -> T {
        var req = URLRequest(url: Self.endpoint, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(Self.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            let offlineCodes: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost, .timedOut]
            throw offlineCodes.contains(e.code) ? AnalysisError.offline : AnalysisError.server(e.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AnalysisError.server(String(data: data, encoding: .utf8) ?? "")
        }
        guard let env = try? JSONDecoder().decode(Envelope<T>.self, from: data), env.ok, let result = env.result else {
            throw AnalysisError.decoding
        }
        return result
    }

    func analyze(item: TraceItem, session: TraceSession, departments: [Department], clauses: [Standard]) async throws -> (AnalysisResult, Data) {
        let node = item.node
        let dept = departments.first { $0.code == node?.departmentCode }
        let prior: [[String: String]] = session.allItems
            .filter { $0.id != item.id && $0.hasAnswer }
            .suffix(8)
            .map { other in
                let d = departments.first { $0.code == other.node?.departmentCode }
                return ["department": d?.englishName ?? "", "question": other.questionText, "answer": other.recordedAnswer]
            }
        let evidenceNotes = session.evidence
            .filter { $0.linkedItemIDs.contains(item.id) }
            .map { "\($0.kind.rawValue): \($0.title) \($0.note)" }

        let body: [String: Any] = [
            "mode": "analyze",
            "lang": AppSettings.shared.language.rawValue,
            "topic": [
                "title": session.topic?.title ?? "",
                "objective": session.topic?.objective ?? "",
                "tracer_type": session.topic?.tracerTypeRaw ?? "",
            ],
            "department": ["code": dept?.code ?? "", "name": dept?.englishName ?? ""],
            "staff_role": item.personAsked,
            "question": item.questionText,
            "answer": item.orderedResponses.first?.text ?? item.recordedAnswer,
            "addenda": item.orderedResponses.dropFirst().map(\.text),
            "evidence": evidenceNotes,
            "prior": prior,
            "clauses": clauses.prefix(10).map { ["id": $0.id, "statement": $0.statement, "elements": Array($0.elements.prefix(12))] },
            "departments": departments.map { ["code": $0.code, "name": $0.englishName] },
        ]
        let result = try await post(body, as: AnalysisResult.self)
        let stored = (try? JSONEncoder().encode(result)) ?? Data()
        return (result, stored)
    }

    func draftTopic(title: String, notes: String, departments: [Department], clauses: [Standard]) async throws -> TopicDraft {
        let body: [String: Any] = [
            "mode": "draft_topic",
            "lang": AppSettings.shared.language.rawValue,
            "title": title,
            "notes": notes,
            "clauses": clauses.prefix(12).map { ["id": $0.id, "statement": $0.statement, "elements": Array($0.elements.prefix(6))] },
            "departments": departments.map { ["code": $0.code, "name": $0.englishName] },
        ]
        let result = try await post(body, as: TopicDraft.self)
        return result
    }
}
