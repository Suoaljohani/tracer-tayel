import SwiftUI
import SwiftData

struct AnalysisPanel: View {
    @Bindable var item: TraceItem
    @Bindable var session: TraceSession
    let record: AnalysisRecord
    let result: AnalysisResult

    @Environment(\.modelContext) private var context
    @Environment(WorkspaceState.self) private var ws

    @State private var revealed = false
    @State private var deciding = false
    @State private var detail: Standard?
    @State private var resolving = false

    private var engine: TraceEngine { TraceEngine(context: context) }
    private var d: Department { dept(item.node?.departmentCode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section(0) { summaryCard }
            section(1) { verdicts }
            section(2) { riskCard }
            if !result.conflicts.isEmpty { section(3) { conflictsCard } }
            section(4) { elementsCard }
            if !result.routes.isEmpty { section(5) { routesCard } }
            if !result.follow_up_question.isEmpty { section(6) { followUpCard } }
            if !result.suggested_plan_of_action.isEmpty { section(7) { planCard } }
            section(8) { footer }
        }
        .onAppear { withAnimation(Motion.reveal) { revealed = true } }
        .sheet(isPresented: $deciding) {
            RiskDecisionSheet(item: item, result: result)
        }
        .sheet(item: $detail) { StandardDetailView(standard: $0) }
        .sheet(isPresented: $resolving) {
            ResolveSheet(item: item)
        }
    }

    /// Staggered reveal of each block.
    private func section<C: View>(_ i: Int, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 18)
            .animation(Motion.reveal.delay(Double(i) * 0.06), value: revealed)
    }

    // MARK: Blocks

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: L("Answer summary", "ملخص الإجابة"), color: d.color)
                Spacer()
                Text(record.createdAt.relativeText).font(.trMicro).foregroundStyle(Palette.inkTertiary)
            }
            Text(result.summary)
                .font(.trBody)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Chip(text: result.confidenceTitle, symbol: "gauge.with.dots.needle.50percent", tint: Palette.inkSecondary)
                if result.human_review_required {
                    Chip(text: L("Needs human review", "تتطلب مراجعة بشرية"), symbol: "person.fill.checkmark", tint: RiskLevel.high.color)
                }
            }
            if !result.human_review_reasons.isEmpty && result.human_review_required {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.human_review_reasons, id: \.self) { r in
                        Label(r, systemImage: "arrow.turn.down.right").font(.trCaption).foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
        .luxCard(padding: 16)
    }

    private var verdicts: some View {
        HStack(spacing: 10) {
            VerdictTile(title: L("Completeness", "الاكتمال"), value: result.completenessTitle, tone: result.completenessTone, symbol: "circle.lefthalf.filled")
            VerdictTile(title: L("Correctness", "الصحة"), value: result.correctnessTitle, tone: result.correctnessTone, symbol: "checkmark.diamond")
            VerdictTile(title: L("Evidence", "الأدلة"), value: result.evidenceTitle, tone: result.evidence_status == "sufficient" ? .positive : result.evidence_status == "insufficient" ? .caution : .neutral, symbol: "paperclip")
        }
    }

    private var riskCard: some View {
        let suggested = result.riskLevel
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: L("Suggested risk", "الخطورة المقترحة"), color: suggested.color)
                    HStack(spacing: 10) {
                        RiskGlyph(level: suggested, size: 34)
                        Text(suggested.title).font(.trTitle).foregroundStyle(suggested.color)
                    }
                }
                Spacer()
                if item.riskApproved, let approved = item.approvedRisk {
                    VStack(alignment: .trailing, spacing: 4) {
                        Eyebrow(text: L("Approved", "المعتمدة"), color: Palette.inkSecondary)
                        RiskBadge(level: approved, approved: true, compact: true)
                    }
                }
            }

            SaferMatrix(likelihood: result.likelihoodValue, scope: result.scopeValue, immediateThreat: result.immediate_threat, approvedLikelihood: item.riskApproved ? item.approvedLikelihood : nil, approvedScope: item.riskApproved ? item.approvedScope : nil)

            if !result.risk_rationale.isEmpty {
                Text(result.risk_rationale)
                    .font(.trCallout)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !result.risk_clause_id.isEmpty, let s = StandardsLibrary.shared.standards(record.clauseSnapshot).first(where: { $0.id == result.risk_clause_id }) ?? StandardsLibrary.shared.standard(result.risk_clause_id) {
                Button { detail = s } label: {
                    Label(s.id, systemImage: "bookmark.fill")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.gold)
                }
            }

            if suggested.isElevated && !item.riskApproved {
                Label(L("Escalate now according to the approved hospital policy. This assessment does not replace immediate safety procedures.",
                        "صعّد الآن وفق السياسة المعتمدة في المستشفى. هذا التقييم لا يحل محل إجراءات السلامة الفورية."),
                      systemImage: "megaphone.fill")
                    .font(.trCaption.bold())
                    .foregroundStyle(suggested.color)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(suggested.color.opacity(0.08)))
            }

            if item.riskApproved {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Decision recorded", "تم تسجيل القرار")).font(.trFootnote.bold()).foregroundStyle(Palette.ink)
                        if let at = item.riskDecidedAt {
                            Text(at.formatted(dateStyle: .medium, timeStyle: .short)).font(.trCaption).foregroundStyle(Palette.inkTertiary)
                        }
                        if !item.riskDecisionReason.isEmpty {
                            Text(item.riskDecisionReason).font(.trCaption).foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    Spacer()
                    Button(L("Change", "تعديل")) { deciding = true }
                        .font(.trFootnote.bold())
                }
                Button {
                    resolving = true
                } label: {
                    Label(item.resolved ? L("Resolved — reopen", "تمت المعالجة — إعادة فتح") : L("Mark finding resolved", "اعتماد معالجة الملاحظة"),
                          systemImage: item.resolved ? "arrow.uturn.backward.circle" : "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(tint: item.resolved ? Palette.inkSecondary : RiskLevel.low.color))
            } else {
                HStack(spacing: 10) {
                    Button {
                        engine.approveSuggested(item)
                        Haptics.success()
                    } label: {
                        Label(L("Approve", "اعتماد"), systemImage: "checkmark.shield")
                    }
                    .buttonStyle(GoldButtonStyle(fill: suggested.color))
                    Button {
                        deciding = true
                    } label: {
                        Label(L("Modify", "تعديل"), systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GhostButtonStyle(tint: Palette.ink))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(suggested.color.opacity(suggested.isElevated ? 0.7 : 0.25), lineWidth: suggested.isElevated ? 1.5 : 0.75)
        )
        .shadow(color: suggested.color.opacity(suggested.isElevated ? 0.18 : 0.04), radius: 16, y: 8)
    }

    private var conflictsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: L("Conflicts with the reference", "تعارضات مع المرجع"), color: RiskLevel.high.color)
            ForEach(result.conflicts, id: \.self) { c in
                VStack(alignment: .leading, spacing: 8) {
                    Text(c.description).font(.trCallout).foregroundStyle(Palette.ink)
                    Button {
                        detail = StandardsLibrary.shared.standards(record.clauseSnapshot).first { $0.id == c.clause_id } ?? StandardsLibrary.shared.standard(c.clause_id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(c.clause_id, systemImage: "bookmark.fill")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Palette.gold)
                            Text("“\(c.clause_excerpt)”")
                                .font(.trCaption)
                                .italic()
                                .foregroundStyle(Palette.inkSecondary)
                                .multilineTextAlignment(.leading)
                                .environment(\.layoutDirection, .leftToRight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surfaceRaised))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .luxCard(padding: 16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(RiskLevel.high.color).frame(width: 3).padding(.vertical, 20)
        }
    }

    private var elementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !result.met_elements.isEmpty {
                Eyebrow(text: L("Elements met", "العناصر المستوفاة"), color: RiskLevel.low.color)
                ForEach(result.met_elements, id: \.self) { e in
                    Label { Text(e).font(.trCallout).foregroundStyle(Palette.ink) } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(RiskLevel.low.color)
                    }
                }
            }
            if !result.missing_elements.isEmpty {
                if !result.met_elements.isEmpty { GoldDivider().opacity(0.4) }
                Eyebrow(text: L("Missing elements", "العناصر المفقودة"), color: RiskLevel.moderate.color)
                ForEach(result.missing_elements, id: \.self) { e in
                    Label { Text(e).font(.trCallout).foregroundStyle(Palette.ink) } icon: {
                        Image(systemName: "circle.dashed").foregroundStyle(RiskLevel.moderate.color)
                    }
                }
            }
            if result.met_elements.isEmpty && result.missing_elements.isEmpty {
                Text(L("No element-level detail returned.", "لا توجد تفاصيل على مستوى العناصر.")).font(.trCaption).foregroundStyle(Palette.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .luxCard(padding: 16)
    }

    private var routesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: L("Suggested route", "مسار مقترح"), color: Palette.gold)
            ForEach(result.routes, id: \.self) { r in
                RouteSuggestion(route: r, item: item, session: session)
            }
        }
        .luxCard(padding: 16)
    }

    private var followUpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: L("Suggested follow-up question", "سؤال متابعة مقترح"), color: d.color)
            Text(result.follow_up_question).font(.trBodyBold).foregroundStyle(Palette.ink)
            Button {
                if let node = item.node {
                    let added = engine.addQuestion(to: node, text: result.follow_up_question, clauseIDs: item.clauseIDs, personAsked: item.personAsked)
                    withAnimation(Motion.luxe) {
                        session.currentItemID = added.id
                        ws.showAnalysis = false
                    }
                    Haptics.success()
                }
            } label: {
                Label(L("Ask this next", "اطرح هذا السؤال"), systemImage: "plus.bubble").frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle(tint: d.color))
        }
        .luxCard(padding: 16)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: L("Suggested plan of action", "خطة عمل مقترحة"), color: Palette.inkSecondary)
            Text(result.suggested_plan_of_action).font(.trCallout).foregroundStyle(Palette.ink)
            Button {
                item.planOfAction = result.suggested_plan_of_action
                engine.log(session, .fieldEdited, L("Plan of action set from suggestion", "اعتماد خطة العمل المقترحة"), dept: item.node?.departmentCode ?? "")
                engine.save()
                Haptics.success()
            } label: {
                Label(item.planOfAction == result.suggested_plan_of_action ? L("Added to the form", "أُضيفت إلى النموذج") : L("Use in tracer form", "استخدامها في النموذج"),
                      systemImage: item.planOfAction == result.suggested_plan_of_action ? "checkmark" : "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle(tint: Palette.gold))
            .disabled(item.planOfAction == result.suggested_plan_of_action)
        }
        .luxCard(padding: 16)
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(Palette.inkTertiary)
            Text(L("Suggestions are advisory and remain separate from approved decisions. The evaluator is responsible for final approval. Analysed answer version: \(record.answerSnapshot.count) characters.",
                   "المخرجات استشارية وتبقى منفصلة عن القرارات المعتمدة، والمقيِّم مسؤول عن الاعتماد النهائي. نسخة الإجابة المحللة: \(record.answerSnapshot.count) حرفًا."))
                .font(.trCaption)
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.horizontal, 4)
    }
}

struct VerdictTile: View {
    let title: String
    let value: String
    let tone: VerdictTone
    let symbol: String

    private var color: Color {
        switch tone {
        case .positive: return RiskLevel.low.color
        case .caution: return RiskLevel.moderate.color
        case .negative: return RiskLevel.high.color
        case .neutral: return RiskLevel.undetermined.color
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(Circle().fill(color.opacity(0.12)))
            Text(title).font(.trMicro).foregroundStyle(Palette.inkTertiary)
            Text(value).font(.trFootnote.bold()).foregroundStyle(color).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.75))
    }
}

/// SAFER matrix (likelihood × scope) mirroring the tracer form.
struct SaferMatrix: View {
    let likelihood: Likelihood
    let scope: NoncomplianceScope
    let immediateThreat: Bool
    var approvedLikelihood: Likelihood? = nil
    var approvedScope: NoncomplianceScope? = nil
    var onSelect: ((Likelihood, NoncomplianceScope) -> Void)? = nil

    static func cellColor(_ l: Likelihood, _ s: NoncomplianceScope) -> Color {
        // Mirrors the form's heat map.
        switch (l, s) {
        case (.high, _): return Color(hex: 0xE53935)
        case (.moderate, .limited): return Color(hex: 0xF5B400)
        case (.moderate, _): return Color(hex: 0xEF7D22)
        case (.low, .limited): return Color(hex: 0xF7DC2E)
        default: return Color(hex: 0xF5B400)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: immediateThreat ? "checkmark.square.fill" : "square")
                Text(L("Immediate threat to life", "تهديد فوري للحياة"))
                Spacer()
            }
            .font(.trCaptionBold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: immediateThreat ? 0xB71C1C : 0x8E2A2A).opacity(immediateThreat ? 1 : 0.55)))

            ForEach(Likelihood.matrix) { l in
                HStack(spacing: 4) {
                    Text(l.title).font(.trMicro).foregroundStyle(Palette.inkSecondary).frame(width: 62, alignment: .leading)
                    ForEach(NoncomplianceScope.matrix) { s in
                        let suggested = l == likelihood && s == scope
                        let approved = l == approvedLikelihood && s == approvedScope
                        Button {
                            onSelect?(l, s)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Self.cellColor(l, s).opacity(suggested || approved ? 1 : 0.28))
                                if approved {
                                    Image(systemName: "checkmark.seal.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                } else if suggested {
                                    Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 18, height: 18)
                                }
                            }
                            .frame(height: 34)
                        }
                        .buttonStyle(.plain)
                        .disabled(onSelect == nil)
                    }
                }
            }
            HStack(spacing: 4) {
                Color.clear.frame(width: 62, height: 1)
                ForEach(NoncomplianceScope.matrix) { s in
                    Text(s.title).font(.trMicro).foregroundStyle(Palette.inkSecondary).frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 12) {
                Label(L("Suggested", "مقترح"), systemImage: "circle.dashed")
                Label(L("Approved", "معتمد"), systemImage: "checkmark.seal.fill")
                Spacer()
                Text(L("Scope of noncompliance", "نطاق عدم الالتزام")).foregroundStyle(Palette.inkTertiary)
            }
            .font(.trMicro)
            .foregroundStyle(Palette.inkSecondary)
            .padding(.top, 2)
        }
    }
}

struct RouteSuggestion: View {
    let route: AnalysisResult.Route
    let item: TraceItem
    let session: TraceSession

    @Environment(\.modelContext) private var context
    @Environment(WorkspaceState.self) private var ws

    var body: some View {
        let target = dept(route.department_code)
        let existing = session.edges.first { e in
            e.fromNodeID == item.node?.id && session.nodes.first { $0.id == e.toNodeID }?.departmentCode == route.department_code
        }
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DeptMedallion(department: target, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name).font(.trBodyBold).foregroundStyle(target.color)
                    Label(route.linkType.title, systemImage: route.linkType.symbol).font(.trCaption).foregroundStyle(Palette.inkSecondary)
                }
                Spacer()
            }
            Text(route.reason).font(.trCallout).foregroundStyle(Palette.ink)
            if !route.question.isEmpty {
                Text("“\(route.question)”").font(.trCallout).italic().foregroundStyle(Palette.inkSecondary)
            }
            Button {
                guard let from = item.node else { return }
                let node = TraceEngine(context: context).branch(session: session, from: from, to: route.department_code, type: route.linkType,
                                                                reason: route.reason, question: route.question, clauseIDs: item.clauseIDs, focus: false)
                ws.transitionDept = target
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    session.currentNodeID = node.id
                    session.currentItemID = node.orderedItems.last(where: { !$0.hasAnswer })?.id ?? node.orderedItems.first?.id
                    ws.showAnalysis = false
                    try? context.save()
                }
            } label: {
                Label(existing == nil ? L("Continue trace in \(target.name)", "استكمال التتبع في \(target.name)") : L("Open \(target.name) trace point", "فتح نقطة \(target.name)"),
                      systemImage: isArabic ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
            }
            .buttonStyle(GoldButtonStyle(fill: target.color))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(target.wash))
    }
}

struct RiskDecisionSheet: View {
    @Bindable var item: TraceItem
    let result: AnalysisResult?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var likelihood: Likelihood = .unknown
    @State private var scope: NoncomplianceScope = .unknown
    @State private var itl = false
    @State private var finding = true
    @State private var reason = ""

    private var level: RiskLevel { RiskLevel.from(likelihood: likelihood, immediateThreat: itl, findingExists: finding) }
    private var differs: Bool {
        guard let r = result else { return true }
        return level != r.riskLevel || (finding && scope != r.scopeValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        RiskGlyph(level: level, size: 40)
                        VStack(alignment: .leading) {
                            Eyebrow(text: L("Your decision", "قرارك"), color: level.color)
                            Text(level.title).font(.trTitle).foregroundStyle(level.color)
                                .contentTransition(.opacity)
                        }
                        Spacer()
                        if let r = result {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(L("Suggested", "المقترح")).font(.trMicro).foregroundStyle(Palette.inkTertiary)
                                RiskBadge(level: r.riskLevel, compact: true)
                            }
                        }
                    }
                    .animation(Motion.snappy, value: level)

                    Toggle(isOn: $finding.animation(Motion.snappy)) {
                        Label(L("A finding exists", "توجد ملاحظة"), systemImage: "exclamationmark.bubble").font(.trCallout)
                    }
                    .tint(Palette.gold)

                    if finding {
                        Toggle(isOn: $itl.animation(Motion.snappy)) {
                            Label(L("Immediate threat to life", "تهديد فوري للحياة"), systemImage: "cross.circle").font(.trCallout)
                        }
                        .tint(RiskLevel.critical.color)

                        SaferMatrix(likelihood: result?.likelihoodValue ?? .unknown, scope: result?.scopeValue ?? .unknown, immediateThreat: itl,
                                    approvedLikelihood: likelihood, approvedScope: scope) { l, s in
                            Haptics.selection()
                            withAnimation(Motion.snappy) { likelihood = l; scope = s }
                        }
                        Button {
                            withAnimation(Motion.snappy) { likelihood = .unknown; scope = .unknown }
                        } label: {
                            Label(L("Mark as undetermined (insufficient evidence)", "تحديدها غير محددة (أدلة غير كافية)"), systemImage: "questionmark.circle")
                                .font(.trFootnote.bold())
                        }
                    }

                    FieldBlock(label: differs ? L("Reason for change (required)", "سبب التعديل (إلزامي)") : L("Note (optional)", "ملاحظة (اختياري)"), symbol: "text.quote") {
                        TextField(L("Why does your judgement differ?", "لماذا يختلف تقديرك؟"), text: $reason, axis: .vertical)
                            .lineLimit(2...5)
                            .inputBox()
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Risk decision", "قرار الخطورة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Approve", "اعتماد")) {
                        TraceEngine(context: context).decide(item, likelihood: finding ? likelihood : .none, scope: finding ? scope : .none,
                                                             immediateThreat: finding && itl, findingExists: finding, reason: reason, modified: differs)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(differs && reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if item.riskApproved {
                likelihood = item.approvedLikelihood
                scope = item.approvedScope
                itl = item.approvedImmediateThreat
                finding = item.approvedFindingExists
            } else if let r = result {
                likelihood = r.likelihoodValue
                scope = r.scopeValue
                itl = r.immediate_threat
                finding = r.finding_exists
            }
        }
    }
}

struct ResolveSheet: View {
    @Bindable var item: TraceItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.resolved
                     ? L("Reopening returns this finding to the session's unresolved risk.", "إعادة الفتح تعيد هذه الملاحظة إلى الخطورة غير المحسومة للجلسة.")
                     : L("The finding stays in the history but no longer counts toward the current unresolved risk.", "تبقى الملاحظة في السجل التاريخي، لكنها لا تُحتسب ضمن الخطورة الحالية غير المحسومة."))
                    .font(.trCallout).foregroundStyle(Palette.inkSecondary)
                TextField(L("Resolution note", "ملاحظة المعالجة"), text: $note, axis: .vertical).lineLimit(3...6).inputBox()
                Spacer()
            }
            .padding(20)
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(item.resolved ? L("Reopen finding", "إعادة فتح الملاحظة") : L("Resolve finding", "معالجة الملاحظة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Confirm", "تأكيد")) {
                        TraceEngine(context: context).setResolved(item, !item.resolved, note: note)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
