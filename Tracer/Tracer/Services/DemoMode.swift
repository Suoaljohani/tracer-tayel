#if DEBUG
import Foundation
import SwiftData

/// Debug-only launch arguments used by CI to capture screenshots:
///   -uiDemo                 seed a realistic session
///   -screen <name>          hub | topic | assess | analysis | path | log | library | settings | report
///   -lang ar|en             interface language
enum DemoMode {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var isOn: Bool { args.contains("-uiDemo") }

    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var screen: String { value("-screen") ?? "hub" }

    @MainActor
    static func prepare(_ context: ModelContext, router: Router) {
        guard isOn else { return }
        if let lang = value("-lang"), let l = AppLanguage(rawValue: lang) {
            AppSettings.shared.language = l
        }
        let s = AppSettings.shared
        if s.evaluatorName.isEmpty { s.evaluatorName = isArabic ? "د. سارة" : "Dr. Sarah" }
        if s.organization.isEmpty { s.organization = isArabic ? "مستشفى الملك فهد العام" : "King Fahad General Hospital" }
        Seeder.seedIfNeeded(context)
        DepartmentStore.shared.refresh(context)

        let topics = (try? context.fetch(FetchDescriptor<TraceTopic>(sortBy: [SortDescriptor(\.number)]))) ?? []
        guard let t1 = topics.first else { return }
        let session: TraceSession
        if let existing = t1.sessions.first {
            session = existing
        } else {
            session = seedSession(context, topic: t1)
            if topics.count > 1 {
                let e = TraceEngine(context: context)
                _ = e.startSession(topic: topics[1], organization: s.organization, team: s.defaultTeam, patientRecord: "", documents: "", date: .now, firstDepartment: "PHA")
            }
        }

        switch screen {
        case "topic": router.path = [.topic(t1.id)]
        case "assess", "analysis", "path", "log", "report":
            session.lastTabRaw = screen == "path" ? "path" : screen == "log" ? "log" : "assess"
            if screen == "analysis" || screen == "report" {
                if let er = session.orderedNodes.first {
                    session.currentNodeID = er.id
                    session.currentItemID = er.orderedItems.first?.id
                }
            }
            try? context.save()
            router.path = [.session(session.id)]
            if screen == "report" {
                let url = ReportBuilder(session: session).write()
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let dest = docs.appendingPathComponent("demo-report-\(AppSettings.shared.language.rawValue).pdf")
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: url, to: dest)
            }
        case "library": router.path = [.library]
        case "settings": router.path = [.settings]
        default: break
        }
    }

    static var showAnalysisOnOpen: Bool { isOn && (screen == "analysis") }

    @MainActor
    private static func seedSession(_ context: ModelContext, topic: TraceTopic) -> TraceSession {
        let e = TraceEngine(context: context)
        let s = AppSettings.shared
        let session = e.startSession(topic: topic, organization: s.organization, team: isArabic ? "فريق الجودة" : "Quality team",
                                     patientRecord: "MRN-204118", documents: isArabic ? "سياسة النتائج الحرجة (إصدار ٣)" : "Critical results policy v3",
                                     date: .now, firstDepartment: "ER")
        guard let er = session.orderedNodes.first, let item = er.orderedItems.first else { return session }
        item.personAsked = isArabic ? "ممرضة طوارئ" : "ER staff nurse"
        e.recordAnswer(item, text: isArabic
                       ? "المختبر يتصل علينا عند وجود نتيجة حرجة، وبعدها نبلغ الطبيب. عادة ما نكتب شي بالملف."
                       : "The lab calls us when there is a critical result, then we tell the doctor. We usually don't write anything in the file.")

        let result = AnalysisResult(
            summary: isArabic ? "الإجابة تصف آلية الإبلاغ الهاتفي لكنها تُغفل التوثيق في الملف الطبي والقراءة مرة أخرى والإطار الزمني."
                              : "The answer describes phone notification but omits documentation in the record, read-back and the reporting time frame.",
            completeness: "partial", correctness: "partially_correct", compliance_suggestion: "no",
            met_elements: isArabic ? ["تحديد الطرف المُبلَّغ (الطبيب)", "وسيلة الإبلاغ (الهاتف)"] : ["Notified party identified (physician)", "Means of communication (phone)"],
            missing_elements: isArabic ? ["التوثيق في الملف الطبي", "القراءة مرة أخرى", "إطار زمني لا يتجاوز ٣٠ دقيقة"] : ["Documentation in the medical record", "Read-back", "Time frame not exceeding 30 minutes"],
            conflicts: [.init(description: isArabic ? "الإفادة بعدم التوثيق تتعارض مع متطلبات التوثيق." : "Stating that nothing is documented contradicts the documentation requirement.",
                              clause_id: "IPSG.02.00",
                              clause_excerpt: "The hospital identifies what critical result information is documented in the medical record, including date and time of notification, documentation of read-back…")],
            evidence_status: "insufficient", likelihood: "high", scope: "pattern", immediate_threat: false, finding_exists: true,
            risk_rationale: isArabic ? "غياب التوثيق والقراءة مرة أخرى قد يؤخر علاج المريض ويزيد احتمال الضرر." : "Missing documentation and read-back can delay treatment and increase the likelihood of harm.",
            risk_clause_id: "IPSG.02.00",
            follow_up_question: isArabic ? "هل يمكنك أن تريني آخر نتيجة حرجة مسجلة وكيف وُثقت؟" : "Can you show me the last critical result received and how it was documented?",
            routes: [.init(department_code: "LAB", link_type: "follow_action",
                           reason: isArabic ? "التحقق من آلية الإبلاغ وتوثيقها في المختبر" : "Verify how the laboratory reports and documents critical results",
                           question: isArabic ? "كيف توثقون إبلاغ النتيجة الحرجة ومن استلمها؟" : "How do you document who received the critical result and when?")],
            confidence: "high", human_review_required: true,
            human_review_reasons: isArabic ? ["خطورة عالية مقترحة", "تعارض مع المرجع"] : ["High suggested risk", "Conflict with the reference"],
            suggested_plan_of_action: isArabic ? "تدريب الطاقم على توثيق النتائج الحرجة والقراءة مرة أخرى، وتدقيق شهري للالتزام." : "Train staff on documenting critical results with read-back; monthly compliance audit.",
            risk_level: "HIGH", model_version: "demo")
        let payload = (try? JSONEncoder().encode(result)) ?? Data()
        e.storeAnalysis(result, payload: payload, for: item, clauses: item.clauseIDs)
        e.setCompliance(item, .no)
        item.evidenceOfCompliance = isArabic ? "لا يوجد توثيق في ملفين تمت مراجعتهما." : "No documentation found in two records reviewed."
        e.addEvidence(EvidenceItem(kind: .record, title: isArabic ? "مراجعة ملفين" : "Two records reviewed", note: "", departmentCode: "ER"), to: session, linking: item)

        let lab = e.branch(session: session, from: er, to: "LAB", type: .followAction,
                           reason: result.routes[0].reason, question: result.routes[0].question, clauseIDs: item.clauseIDs, focus: true)
        if let labItem = lab.orderedItems.first {
            labItem.personAsked = isArabic ? "أخصائي مختبر" : "Lab technologist"
            e.recordAnswer(labItem, text: isArabic ? "نسجل في نظام المختبر اسم المستلم والوقت ونطلب القراءة مرة أخرى." : "We log the receiver's name and time in the LIS and ask for read-back.")
            e.setCompliance(labItem, .yes)
        }
        _ = e.branch(session: session, from: er, to: "IPD", type: .verifyConflict,
                     reason: isArabic ? "التحقق من التسليم بين المناوبات" : "Verify handover between shifts", question: "", clauseIDs: [], focus: false)
        e.save()
        return session
    }
}
#endif
