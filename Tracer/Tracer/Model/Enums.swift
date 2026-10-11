import Foundation

enum RiskLevel: String, Codable, CaseIterable, Identifiable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case moderate = "MODERATE"
    case low = "LOW"
    case undetermined = "UNDETERMINED"
    case noFinding = "NO_FINDING"

    var id: String { rawValue }

    /// Ordering used to pick the highest unresolved risk.
    var weight: Int {
        switch self {
        case .critical: return 5
        case .high: return 4
        case .moderate: return 3
        case .low: return 2
        case .undetermined: return 1
        case .noFinding: return 0
        }
    }

    var title: String {
        switch self {
        case .critical: return L("Critical", "حرجة")
        case .high: return L("High", "عالية")
        case .moderate: return L("Moderate", "متوسطة")
        case .low: return L("Low", "منخفضة")
        case .undetermined: return L("Undetermined", "غير محددة")
        case .noFinding: return L("No finding", "لا توجد ملاحظة")
        }
    }

    var englishTitle: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .moderate: return "Moderate"
        case .low: return "Low"
        case .undetermined: return "Undetermined"
        case .noFinding: return "No finding"
        }
    }

    var isElevated: Bool { self == .critical || self == .high }

    static func highest(_ levels: [RiskLevel]) -> RiskLevel? {
        levels.max(by: { $0.weight < $1.weight })
    }

    static func from(likelihood: Likelihood, immediateThreat: Bool, findingExists: Bool) -> RiskLevel {
        if immediateThreat { return .critical }
        if !findingExists { return .noFinding }
        switch likelihood {
        case .high: return .high
        case .moderate: return .moderate
        case .low: return .low
        case .none: return .noFinding
        case .unknown: return .undetermined
        }
    }
}

enum Likelihood: String, Codable, CaseIterable, Identifiable {
    case high, moderate, low, none, unknown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .high: return L("High", "عالية")
        case .moderate: return L("Moderate", "متوسطة")
        case .low: return L("Low", "منخفضة")
        case .none: return L("None", "لا يوجد")
        case .unknown: return L("Unknown", "غير معروفة")
        }
    }
    static let matrix: [Likelihood] = [.high, .moderate, .low]
}

enum NoncomplianceScope: String, Codable, CaseIterable, Identifiable {
    case limited, pattern, widespread, none, unknown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .limited: return L("Limited", "محدود")
        case .pattern: return L("Pattern", "نمط متكرر")
        case .widespread: return L("Widespread", "واسع الانتشار")
        case .none: return L("None", "لا يوجد")
        case .unknown: return L("Unknown", "غير معروف")
        }
    }
    static let matrix: [NoncomplianceScope] = [.limited, .pattern, .widespread]
}

enum Compliance: String, Codable, CaseIterable, Identifiable {
    case unset, yes, no, notScored = "not_scored", notApplicable = "not_applicable"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unset: return L("Not recorded", "لم يُسجّل")
        case .yes: return L("Compliant", "ملتزم")
        case .no: return L("Not compliant", "غير ملتزم")
        case .notScored: return L("Not scored", "غير مُقيّم")
        case .notApplicable: return L("Not applicable", "لا ينطبق")
        }
    }
    var symbol: String {
        switch self {
        case .unset: return "circle.dashed"
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .notScored: return "minus.circle.fill"
        case .notApplicable: return "slash.circle.fill"
        }
    }
    static let choices: [Compliance] = [.yes, .no, .notScored, .notApplicable]
}

enum TracerType: String, Codable, CaseIterable, Identifiable {
    case individual, system, program
    case highRisk = "high_risk"
    case environmentOfCare = "environment_of_care"
    case lifeSafety = "life_safety"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .individual: return L("Individual", "فردي")
        case .system: return L("System", "نظام")
        case .program: return L("Program", "برنامج")
        case .highRisk: return L("High-Risk", "عالي الخطورة")
        case .environmentOfCare: return L("Environment of Care", "بيئة الرعاية")
        case .lifeSafety: return L("Life Safety Code", "سلامة الأرواح")
        }
    }
    var formTitle: String {
        switch self {
        case .individual: return "Individual"
        case .system: return "System"
        case .program: return "Program"
        case .highRisk: return "High-Risk"
        case .environmentOfCare: return "Environment of Care"
        case .lifeSafety: return "Life Safety Code®"
        }
    }
    var symbol: String {
        switch self {
        case .individual: return "person.crop.circle"
        case .system: return "point.3.connected.trianglepath.dotted"
        case .program: return "square.stack.3d.up"
        case .highRisk: return "exclamationmark.shield"
        case .environmentOfCare: return "building.columns"
        case .lifeSafety: return "flame"
        }
    }
}

enum SessionStatus: String, Codable, CaseIterable, Identifiable {
    case active, review, completed, onHold = "on_hold"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .active: return L("Active", "نشطة")
        case .review: return L("Needs review", "بانتظار المراجعة")
        case .completed: return L("Completed", "مكتملة")
        case .onHold: return L("On hold", "معلقة")
        }
    }
    var symbol: String {
        switch self {
        case .active: return "dot.radiowaves.left.and.right"
        case .review: return "eye"
        case .completed: return "checkmark.seal"
        case .onHold: return "pause.circle"
        }
    }
}

enum LinkType: String, Codable, CaseIterable, Identifiable {
    case followAction = "follow_action"
    case verifyConflict = "verify_conflict"
    case requestEvidence = "request_evidence"
    case manual

    var id: String { rawValue }
    var title: String {
        switch self {
        case .followAction: return L("Follow the process", "متابعة إجراء")
        case .verifyConflict: return L("Verify a conflict", "التحقق من تعارض")
        case .requestEvidence: return L("Request evidence", "طلب دليل")
        case .manual: return L("Continue trace", "استكمال التتبع")
        }
    }
    var symbol: String {
        switch self {
        case .followAction: return "arrow.triangle.turn.up.right.diamond"
        case .verifyConflict: return "arrow.triangle.2.circlepath"
        case .requestEvidence: return "doc.text.magnifyingglass"
        case .manual: return "arrow.right"
        }
    }
    /// Dash pattern so link types are distinguishable without colour.
    var dash: [CGFloat] {
        switch self {
        case .followAction, .manual: return []
        case .verifyConflict: return [6, 4]
        case .requestEvidence: return [2, 4]
        }
    }
}

enum ResponseKind: String, Codable {
    case original, addendum, correction
    var title: String {
        switch self {
        case .original: return L("Original answer", "الإجابة الأصلية")
        case .addendum: return L("Addendum", "استكمال")
        case .correction: return L("Correction", "تصحيح")
        }
    }
}

enum EvidenceKind: String, Codable, CaseIterable, Identifiable {
    case photo, document, observation, record
    var id: String { rawValue }
    var title: String {
        switch self {
        case .photo: return L("Photo", "صورة")
        case .document: return L("Document", "مستند")
        case .observation: return L("Direct observation", "مشاهدة مباشرة")
        case .record: return L("Record check", "مراجعة سجل")
        }
    }
    var symbol: String {
        switch self {
        case .photo: return "camera.aperture"
        case .document: return "doc.richtext"
        case .observation: return "eye.circle"
        case .record: return "list.clipboard"
        }
    }
}

enum AuditKind: String, Codable {
    case sessionStarted, nodeCreated, linkCreated, questionAdded, answerRecorded, answerAddendum, answerCorrected
    case analysisRun, riskApproved, riskModified, complianceSet, evidenceAdded, findingResolved, findingReopened
    case statusChanged, sessionClosed, closeOverride, reportExported, fieldEdited

    var symbol: String {
        switch self {
        case .sessionStarted: return "play.circle"
        case .nodeCreated: return "mappin.circle"
        case .linkCreated: return "point.topleft.down.to.point.bottomright.curvepath"
        case .questionAdded: return "questionmark.bubble"
        case .answerRecorded: return "text.bubble"
        case .answerAddendum: return "text.badge.plus"
        case .answerCorrected: return "pencil.and.outline"
        case .analysisRun: return "sparkle.magnifyingglass"
        case .riskApproved: return "checkmark.shield"
        case .riskModified: return "slider.horizontal.3"
        case .complianceSet: return "checklist"
        case .evidenceAdded: return "paperclip"
        case .findingResolved: return "checkmark.circle"
        case .findingReopened: return "arrow.uturn.backward.circle"
        case .statusChanged: return "arrow.left.arrow.right.circle"
        case .sessionClosed: return "lock.circle"
        case .closeOverride: return "exclamationmark.lock"
        case .reportExported: return "doc.badge.arrow.up"
        case .fieldEdited: return "square.and.pencil"
        }
    }
}
