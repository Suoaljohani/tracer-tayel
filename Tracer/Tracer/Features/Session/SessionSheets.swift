import SwiftUI
import SwiftData

/// Manually continue the trace into another department (creates a linked trace point in this session).
struct BranchSheet: View {
    let session: TraceSession
    let from: TraceNode
    let onCreate: (TraceNode) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var target: String = ""
    @State private var type: LinkType = .followAction
    @State private var reason = ""
    @State private var question = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        DeptMedallion(department: dept(from.departmentCode), size: 36)
                        Image(systemName: isArabic ? "arrow.left" : "arrow.right").foregroundStyle(Palette.gold)
                        if !target.isEmpty {
                            DeptMedallion(department: dept(target), size: 36)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Circle().strokeBorder(Palette.gold.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])).frame(width: 36, height: 36)
                        }
                        Spacer()
                    }
                    .animation(Motion.snappy, value: target)

                    FieldBlock(label: L("Department", "القسم"), symbol: "building.2") {
                        FlowLayout(spacing: 8) {
                            ForEach(DepartmentStore.shared.all) { d in
                                let on = target == d.code
                                Button {
                                    Haptics.selection(); target = d.code
                                } label: {
                                    Label(d.name, systemImage: d.symbol)
                                        .font(.trFootnote.bold())
                                        .padding(.horizontal, 12).frame(height: 36)
                                        .foregroundStyle(on ? .white : d.color)
                                        .background(Capsule().fill(on ? AnyShapeStyle(d.color.gradient) : AnyShapeStyle(d.color.opacity(0.1))))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    FieldBlock(label: L("Link type", "نوع الارتباط"), symbol: "link") {
                        VStack(spacing: 8) {
                            ForEach([LinkType.followAction, .verifyConflict, .requestEvidence]) { t in
                                Button {
                                    Haptics.selection(); type = t
                                } label: {
                                    HStack {
                                        Image(systemName: t.symbol).frame(width: 24)
                                        Text(t.title).font(.trCallout)
                                        Spacer()
                                        Image(systemName: type == t ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(type == t ? Palette.gold : Palette.hairline)
                                    }
                                    .foregroundStyle(Palette.ink)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surface))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    FieldBlock(label: L("Reason", "سبب الانتقال"), symbol: "text.quote") {
                        TextField(L("Why continue there?", "لماذا الانتقال إلى هناك؟"), text: $reason, axis: .vertical).lineLimit(2...4).inputBox()
                    }
                    FieldBlock(label: L("Question to ask there (optional)", "السؤال المطروح هناك (اختياري)"), symbol: "questionmark.bubble") {
                        TextField(L("e.g. How is the critical result documented?", "مثال: كيف يتم توثيق النتيجة الحرجة؟"), text: $question, axis: .vertical).lineLimit(2...4).inputBox()
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Continue trace", "استكمال التتبع"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Go", "انتقال")) {
                        let node = TraceEngine(context: context).branch(session: session, from: from, to: target, type: type,
                                                                        reason: reason, question: question, clauseIDs: [], focus: false)
                        dismiss()
                        onCreate(node)
                    }
                    .disabled(target.isEmpty)
                }
            }
        }
    }
}

/// Quick switch between open sessions. The current session stays open.
struct SessionSwitcherSheet: View {
    let currentID: UUID
    let onSelect: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TraceSession.lastActivityAt, order: .reverse) private var sessions: [TraceSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Your current work is saved before switching. Each session keeps its own answers, analysis and position.",
                           "يُحفظ عملك الحالي قبل الانتقال، وتحتفظ كل جلسة بإجاباتها وتحليلها وموضع توقفها."))
                        .font(.trCaption).foregroundStyle(Palette.inkSecondary)
                    ForEach(sessions.filter { $0.status != .completed }) { s in
                        Button {
                            Haptics.tap()
                            guard s.id != currentID else { dismiss(); return }
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect(s.id) }
                        } label: {
                            SessionCard(session: s)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(s.id == currentID ? Palette.gold : .clear, lineWidth: 1.5)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if s.id == currentID {
                                        Text(L("Current", "الحالية")).font(.trMicro).foregroundStyle(Palette.obsidian)
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Capsule().fill(Palette.goldGradient))
                                            .offset(x: -10, y: -8)
                                    }
                                }
                        }
                        .buttonStyle(PressableStyle(scale: 0.985))
                    }
                }
                .padding(20)
            }
            .navigationTitle(L("Open sessions", "الجلسات المفتوحة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Done", "تم")) { dismiss() } }
            }
        }
    }
}

struct SessionDetailsSheet: View {
    @Bindable var session: TraceSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field(L("Organization", "المنشأة"), "building.columns", $session.organization)
                    field(L("Tracer team", "فريق التتبع"), "person.3", $session.tracerTeam)
                    field(L("Evaluator", "المقيِّم"), "person.badge.shield.checkmark", $session.evaluator)
                    field(L("Documents reviewed", "المستندات التي رُوجعت"), "doc.on.doc", $session.documentsReviewed)
                    field(L("Patient record # (on device only)", "رقم ملف المريض (على الجهاز فقط)"), "lock.doc", $session.patientRecord)
                    FieldBlock(label: L("Date & time of tracer", "تاريخ ووقت التتبع"), symbol: "calendar") {
                        DatePicker("", selection: $session.tracerDate).labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: L("Topic version", "إصدار الموضوع"), color: Palette.inkSecondary)
                        Text("\(session.topic?.code ?? "") · v\(session.topicVersion)").font(.trCallout).foregroundStyle(Palette.ink)
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Session details", "بيانات الجلسة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done", "تم")) {
                        TraceEngine(context: context).log(session, .fieldEdited, L("Session details updated", "تحديث بيانات الجلسة"))
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func field(_ label: String, _ symbol: String, _ binding: Binding<String>) -> some View {
        FieldBlock(label: label, symbol: symbol) { TextField("—", text: binding, axis: .vertical).inputBox() }
    }
}

/// Close with checks: open mandatory trace points and unapproved findings block closure unless an
/// authorised, reasoned override is recorded.
struct CloseSessionSheet: View {
    let session: TraceSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var override = false
    @State private var reason = ""

    var body: some View {
        let engine = TraceEngine(context: context)
        let check = engine.closeCheck(session)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if check.canClose {
                        Label(L("All trace points are complete and every finding has a decision.", "اكتملت جميع نقاط التتبع ولكل ملاحظة قرار معتمد."), systemImage: "checkmark.seal.fill")
                            .font(.trCallout).foregroundStyle(RiskLevel.low.color)
                    } else {
                        Text(L("This session can't be closed yet:", "لا يمكن إغلاق الجلسة بعد:")).font(.trHeadline).foregroundStyle(Palette.ink)
                        ForEach(check.openNodes) { n in
                            Label(L("\(dept(n.departmentCode).name): questions without a compliance decision", "\(dept(n.departmentCode).name): أسئلة دون قرار التزام"), systemImage: "lock.open")
                                .font(.trCallout).foregroundStyle(Palette.ink)
                        }
                        ForEach(check.unapprovedFindings) { i in
                            HStack(alignment: .top) {
                                RiskGlyph(level: i.suggestedRisk ?? .undetermined, size: 18)
                                Text(i.questionText).font(.trCallout).foregroundStyle(Palette.ink).lineLimit(2)
                            }
                        }
                        Toggle(isOn: $override.animation()) {
                            Text(L("Authorised override", "تجاوز مصرح به")).font(.trCallout.bold())
                        }
                        .tint(RiskLevel.high.color)
                        if override {
                            TextField(L("Reason for override (recorded in the log)", "سبب التجاوز (يُسجَّل في السجل)"), text: $reason, axis: .vertical)
                                .lineLimit(2...5).inputBox()
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Close session", "إغلاق الجلسة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Close", "إغلاق")) {
                        engine.close(session, overrideReason: check.canClose ? nil : reason)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(!check.canClose && (!override || reason.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
