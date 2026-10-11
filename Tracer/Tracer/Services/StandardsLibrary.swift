import Foundation

/// One reference clause from the bundled HHC Integrated Cluster Care Standards manual.
struct Standard: Codable, Identifiable, Hashable {
    let id: String
    let manual: String
    let chapter: String
    let group: String
    let statement: String
    let intent: String
    let elements: [String]

    /// Stable key across manuals (the same id can appear in several manuals).
    var key: String { "\(manualCode):\(id)" }

    var manualCode: String { StandardsLibrary.manualCode(manual) }

    var chapterTitle: String { StandardsLibrary.chapterNames[chapter] ?? chapter }
}

final class StandardsLibrary {
    static let shared = StandardsLibrary()

    let all: [Standard]
    let manuals: [String]
    private var byKey: [String: Standard] = [:]
    private var tokens: [String: [String]] = [:]

    /// Default manual for hospital tracers.
    static let hospitalManual = "Hospitals and Academic Medical Centers Standards"

    private init() {
        var loaded: [Standard] = []
        if let url = Bundle.main.url(forResource: "standards", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Standard].self, from: data) {
            loaded = decoded
        }
        all = loaded
        var seen: [String] = []
        for s in loaded where !seen.contains(s.manual) { seen.append(s.manual) }
        manuals = seen
        for s in loaded {
            byKey[s.key] = s
            tokens[s.key] = Self.tokenize("\(s.id) \(s.group) \(s.statement) \(s.elements.joined(separator: " "))")
        }
    }

    /// Clause ids are stored as "MANUAL:ID" keys; plain ids resolve against the hospital manual first.
    func standard(_ ref: String) -> Standard? {
        if let s = byKey[ref] { return s }
        let hosp = "\(Self.manualCode(Self.hospitalManual)):\(ref)"
        if let s = byKey[hosp] { return s }
        return all.first { $0.id == ref }
    }

    func standards(_ refs: [String]) -> [Standard] { refs.compactMap { standard($0) } }

    func inManual(_ manual: String) -> [Standard] { all.filter { $0.manual == manual } }

    func search(_ query: String, manual: String? = nil, limit: Int = 40) -> [Standard] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = manual.map { m in all.filter { $0.manual == m } } ?? all
        guard !q.isEmpty else { return Array(pool.prefix(limit)) }
        let upper = q.uppercased()
        if upper.contains("."), let exact = pool.first(where: { $0.id.uppercased() == upper }) {
            return [exact] + pool.filter { $0.id.uppercased().hasPrefix(upper) && $0 != exact }.prefix(limit - 1)
        }
        let qTokens = Self.expand(Self.tokenize(q))
        guard !qTokens.isEmpty else { return [] }
        var scored: [(Standard, Double)] = []
        for s in pool {
            let t = tokens[s.key] ?? []
            var score = 0.0
            for qt in qTokens {
                if s.id.uppercased().hasPrefix(qt.uppercased()) { score += 6 }
                let hits = t.filter { $0.hasPrefix(qt) }.count
                if hits > 0 { score += 1.5 + log(Double(hits) + 1) }
            }
            if s.statement.localizedCaseInsensitiveContains(q) { score += 5 }
            if score > 0 { scored.append((s, score)) }
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) }
    }

    /// Arabic → English keyword bridge so Arabic topic titles still find the English manual.
    static func expand(_ words: [String]) -> [String] {
        var out = Set(words)
        for w in words {
            for (ar, en) in arabicBridge where w.contains(ar) { en.split(separator: " ").forEach { out.insert(String($0)) } }
        }
        return Array(out)
    }

    static func manualCode(_ manual: String) -> String {
        switch manual {
        case "Hospitals and Academic Medical Centers Standards": return "HOSP"
        case "Ambulatory Care Standards": return "AMB"
        case "Primary Care Standards": return "PC"
        case "Home Care Standards": return "HC"
        case "Long-Term Care Standards": return "LTC"
        case "Global Health Impact Standards": return "GHI"
        default: return "ICC"
        }
    }

    static func manualTitle(_ manual: String) -> String {
        switch manualCode(manual) {
        case "HOSP": return L("Hospitals & Academic Medical Centers", "المستشفيات والمراكز الطبية الأكاديمية")
        case "AMB": return L("Ambulatory Care", "الرعاية الإسعافية والعيادات")
        case "PC": return L("Primary Care", "الرعاية الأولية")
        case "HC": return L("Home Care", "الرعاية المنزلية")
        case "LTC": return L("Long-Term Care", "الرعاية طويلة الأمد")
        case "GHI": return L("Global Health Impact", "الأثر الصحي العالمي")
        default: return L("Integrated Cluster Care", "الرعاية المتكاملة للتجمعات")
        }
    }

    static let chapterNames: [String: String] = [
        "IPSG": "International Patient Safety Goals", "ACC": "Access to Care and Continuity of Care",
        "PCC": "Patient-Centered Care", "AOP": "Assessment of Patients", "COP": "Care of Patients",
        "ASC": "Anesthesia and Surgical Care", "MMU": "Medication Management and Use", "MM": "Medication Management",
        "QPS": "Quality Improvement and Patient Safety", "PCI": "Prevention and Control of Infections",
        "GLD": "Governance, Leadership, and Direction", "FMS": "Facility Management and Safety",
        "SQE": "Staff Qualifications and Education", "MOI": "Management of Information",
        "HCT": "Health Care Technology", "HRP": "Human Subjects Research Programs", "MPE": "Medical Professional Education",
        "SCS": "Specialty Clinical Services", "GLS": "Governance and Leadership Structure", "QPI": "Quality and Performance Improvement",
        "CSA": "Cluster System Alignment", "HRC": "Human Resources Coordination", "ICPA": "Integrated Care Program Alignment",
        "ICPC": "Integrated Cluster Care Program Coordination", "PFR": "Patient and Family Rights", "PFE": "Patient and Family Education",
        "QRS": "Quality and Resident Safety", "RCC": "Resident-Centered Care", "GHI": "Global Health Impact",
    ]

    private static let stopwords: Set<String> = ["the", "and", "for", "with", "that", "are", "this", "from", "its", "has", "have", "which", "into", "such", "all", "not", "but", "any", "each", "when", "how", "who", "what"]

    private static let arabicBridge: [(String, String)] = [
        ("حرج", "critical results"), ("نتائج", "results test"), ("مختبر", "laboratory"), ("دواء", "medication"),
        ("ادوية", "medication"), ("أدوية", "medication"), ("صيدل", "pharmacy medication dispensing"), ("عدوى", "infection prevention control"),
        ("تعقيم", "sterilization"), ("نظافة", "hand hygiene"), ("الأيدي", "hand hygiene"), ("سقوط", "falls"),
        ("هوية", "identification identify"), ("تعريف", "identification"), ("تسليم", "handover communication"),
        ("جراح", "surgery surgical"), ("عمليات", "surgical procedure"), ("تخدير", "anesthesia sedation"),
        ("دم", "blood transfusion"), ("حريق", "fire safety"), ("سلامة", "safety"), ("ألم", "pain"),
        ("تثقيف", "education"), ("حقوق", "rights"), ("سجل", "record documentation"), ("توثيق", "documentation record"),
        ("طوارئ", "emergency"), ("إنعاش", "resuscitation"), ("أشعة", "radiology imaging"), ("تغذية", "nutrition"),
        ("موافقة", "consent"), ("نقل", "transfer"), ("خروج", "discharge"), ("تقييم", "assessment"),
        ("جودة", "quality improvement"), ("مخاطر", "risk"), ("معدات", "equipment"), ("كوارث", "disaster emergency"),
        ("تمريض", "nursing"), ("كفاءة", "competency"), ("تدريب", "training education"), ("مضاد", "antimicrobial"),
    ]
}
