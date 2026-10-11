import Foundation
import SwiftData

/// First-launch content: three ready-to-use trace topics tied to the hospital manual.
@MainActor
enum Seeder {
    static func seedIfNeeded(_ context: ModelContext) {
        let settings = AppSettings.shared
        guard !settings.hasSeeded else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<TraceTopic>())) ?? 0
        guard existing == 0 else { settings.hasSeeded = true; return }

        let ar = settings.language == .arabic
        func t(_ en: String, _ arText: String) -> String { ar ? arText : en }
        func h(_ ids: String...) -> [String] { ids.map { "HOSP:\($0)" } }

        // 1. Critical results
        let t1 = TraceTopic(
            number: 1,
            title: t("Critical Results Reporting", "تتبع النتائج الحرجة"),
            objective: t("Verify that critical diagnostic results are communicated, read back and documented within 30 minutes.",
                         "التحقق من إبلاغ النتائج الحرجة للفحوصات وقراءتها مرة أخرى وتوثيقها خلال ٣٠ دقيقة."),
            summary: t("From the laboratory bench to the treating physician.", "من منصة المختبر حتى الطبيب المعالج."),
            symbol: "bell.badge",
            tracerType: .system,
            departmentCodes: ["ER", "LAB", "IPD"],
            clauseIDs: h("IPSG.02.00", "AOP.03.03", "IPSG.02.01")
        )
        context.insert(t1)
        add(context, t1, [
            (t("How are you notified of a critical result, and what do you do next?", "كيف يتم إبلاغكم بالنتيجة الحرجة؟ وما الإجراء التالي؟"), "ER", h("IPSG.02.00"), t("Critical results log, read-back entry in the record", "سجل النتائج الحرجة، توثيق القراءة مرة أخرى في الملف")),
            (t("Show me where the notification is documented in the patient record.", "أرني أين يتم توثيق الإبلاغ في ملف المريض."), "ER", h("IPSG.02.00"), t("Date/time, notifier, receiver, result, read-back", "التاريخ والوقت، المبلِّغ، المستلم، النتيجة، القراءة مرة أخرى")),
            (t("Which results are defined as critical, and what is the reporting time frame?", "ما النتائج المعرفة كنتائج حرجة؟ وما الإطار الزمني للإبلاغ؟"), "LAB", h("IPSG.02.00", "AOP.03.03"), t("Approved critical values list, policy", "قائمة القيم الحرجة المعتمدة، السياسة")),
            (t("If the physician cannot be reached, what is the escalation process?", "إذا تعذر الوصول إلى الطبيب، ما آلية التصعيد؟"), "LAB", h("IPSG.02.00"), t("Escalation chain in policy", "سلسلة التصعيد في السياسة")),
            (t("How is a critical result handed over at shift change?", "كيف يتم تسليم النتيجة الحرجة عند تغيير المناوبة؟"), "IPD", h("IPSG.02.01"), t("Handover tool (e.g. SBAR)", "أداة التسليم (مثل SBAR)")),
        ])

        // 2. Medication safety
        let t2 = TraceTopic(
            number: 2,
            title: t("Medication Administration Safety", "تتبع سلامة إعطاء الأدوية"),
            objective: t("Trace a high-alert medication from prescribing to administration and monitoring.",
                         "تتبع دواء عالي الخطورة من الوصف حتى الإعطاء والمتابعة."),
            summary: t("Prescribing, dispensing, storage and administration.", "الوصف والصرف والتخزين والإعطاء."),
            symbol: "pills",
            tracerType: .highRisk,
            departmentCodes: ["PHA", "IPD", "ICU"],
            clauseIDs: h("IPSG.03.00", "MMU.05.02", "MMU.05.03", "MMU.06.00", "MMU.03.00")
        )
        context.insert(t2)
        add(context, t2, [
            (t("How are medication orders reviewed for appropriateness before dispensing?", "كيف تتم مراجعة الوصفات للتحقق من ملاءمتها قبل الصرف؟"), "PHA", h("MMU.05.02"), t("Order review checklist, pharmacist interventions", "قائمة مراجعة الوصفة، تدخلات الصيدلي")),
            (t("How are high-alert medications identified, stored and dispensed?", "كيف يتم تمييز الأدوية عالية الخطورة وتخزينها وصرفها؟"), "PHA", h("IPSG.03.00", "MMU.03.00"), t("High-alert list, labels, segregated storage", "قائمة الأدوية عالية الخطورة، الملصقات، التخزين المنفصل")),
            (t("Walk me through an independent double-check before giving a high-alert medication.", "اشرح لي التحقق المزدوج المستقل قبل إعطاء دواء عالي الخطورة."), "IPD", h("IPSG.03.00", "MMU.06.00"), t("Double-check documentation in MAR", "توثيق التحقق المزدوج في سجل إعطاء الأدوية")),
            (t("How are concentrated electrolytes controlled in this unit?", "كيف يتم التحكم في المحاليل المركزة في هذه الوحدة؟"), "ICU", h("IPSG.03.02"), t("Storage location, access control", "موقع التخزين، التحكم في الوصول")),
            (t("How do you report a medication error or near miss?", "كيف تبلغون عن خطأ دوائي أو حدث وشيك؟"), "IPD", h("MMU.07.01"), t("Incident reports, feedback", "تقارير الحوادث، التغذية الراجعة")),
        ])

        // 3. Infection control
        let t3 = TraceTopic(
            number: 3,
            title: t("Infection Prevention & Control", "تتبع مكافحة العدوى"),
            objective: t("Assess hand hygiene, device reprocessing and isolation practices across units.",
                         "تقييم نظافة الأيدي وإعادة معالجة الأدوات وممارسات العزل بين الأقسام."),
            summary: t("Hand hygiene, isolation, cleaning and disinfection.", "نظافة الأيدي، العزل، التنظيف والتطهير."),
            symbol: "hands.and.sparkles",
            tracerType: .program,
            departmentCodes: ["IPD", "IPC", "OR"],
            clauseIDs: h("IPSG.05.00", "PCI.03.00", "PCI.04.00", "PCI.07.00")
        )
        context.insert(t3)
        add(context, t3, [
            (t("When do you perform hand hygiene, and how is compliance monitored?", "متى تقوم بنظافة الأيدي؟ وكيف تتم مراقبة الالتزام؟"), "IPD", h("IPSG.05.00"), t("Observation audits, feedback to staff", "تدقيق المشاهدة، التغذية الراجعة")),
            (t("How do you decide which isolation precautions a patient needs?", "كيف تحدد احتياطات العزل التي يحتاجها المريض؟"), "IPD", h("PCI.07.00"), t("Isolation signage, PPE availability", "لافتات العزل، توفر معدات الوقاية")),
            (t("How are surveillance data analysed and shared with units?", "كيف يتم تحليل بيانات الترصد ومشاركتها مع الأقسام؟"), "IPC", h("PCI.02.00", "PCI.08.00"), t("Surveillance reports, committee minutes", "تقارير الترصد، محاضر اللجنة")),
            (t("Show me how reusable instruments are cleaned and sterilised.", "أرني كيف يتم تنظيف الأدوات القابلة لإعادة الاستخدام وتعقيمها."), "OR", h("PCI.03.00"), t("Sterilisation logs, indicators", "سجلات التعقيم، المؤشرات")),
        ])

        try? context.save()
        settings.hasSeeded = true
    }

    private static func add(_ context: ModelContext, _ topic: TraceTopic, _ items: [(String, String, [String], String)]) {
        for (i, q) in items.enumerated() {
            let tq = TopicQuestion(text: q.0, departmentCode: q.1, clauseIDs: q.2, expectedEvidence: q.3, order: i)
            context.insert(tq)
            tq.topic = topic
        }
    }
}
