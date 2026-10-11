import SwiftUI
import SwiftData

struct StartSessionSheet: View {
    let preselected: TraceTopic?
    let onStart: (TraceSession) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \TraceTopic.number) private var topics: [TraceTopic]

    @State private var topicID: UUID?
    @State private var organization = ""
    @State private var team = ""
    @State private var patientRecord = ""
    @State private var documents = ""
    @State private var date = Date.now
    @State private var firstDept = ""

    private var topic: TraceTopic? { topics.first { $0.id == topicID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if preselected == nil {
                        FieldBlock(label: L("Trace topic", "موضوع التتبع"), symbol: "point.3.filled.connected.trianglepath.dotted") {
                            VStack(spacing: 8) {
                                ForEach(topics.filter { !$0.archived }) { t in
                                    Button {
                                        Haptics.selection()
                                        withAnimation(Motion.snappy) {
                                            topicID = t.id
                                            firstDept = t.departmentCodes.first ?? firstDept
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            TopicMedallion(symbol: t.symbol, size: 36)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(t.title).font(.trBodyBold).foregroundStyle(Palette.ink)
                                                Text(t.code).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.gold)
                                            }
                                            Spacer()
                                            Image(systemName: topicID == t.id ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundStyle(topicID == t.id ? Palette.gold : Palette.hairline)
                                        }
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
                                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(topicID == t.id ? Palette.gold : Palette.hairline, lineWidth: topicID == t.id ? 1.2 : 0.75))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else if let topic {
                        HStack(spacing: 14) {
                            TopicMedallion(symbol: topic.symbol, size: 48)
                            VStack(alignment: .leading) {
                                Eyebrow(text: L("New session for", "جلسة جديدة لموضوع"))
                                Text(topic.title).font(.trTitle2).foregroundStyle(Palette.ink)
                            }
                        }
                    }

                    FieldBlock(label: L("Starting department", "القسم الذي يبدأ منه التتبع"), symbol: "location") {
                        FlowLayout(spacing: 8) {
                            ForEach(orderedDepartments) { d in
                                let on = firstDept == d.code
                                Button {
                                    Haptics.selection(); withAnimation(Motion.theme) { firstDept = d.code }
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

                    VStack(spacing: 14) {
                        labeled(L("Organization", "المنشأة"), "building.columns", $organization)
                        labeled(L("Tracer team", "فريق التتبع"), "person.3", $team)
                        labeled(L("Documents reviewed", "المستندات التي رُوجعت"), "doc.on.doc", $documents)
                        FieldBlock(label: L("Patient record # (optional)", "رقم ملف المريض (اختياري)"), symbol: "lock.doc") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("—", text: $patientRecord).inputBox()
                                Text(L("Stays on this iPhone and in the exported form only. It is never sent for analysis.",
                                       "يبقى على هذا الجهاز وفي النموذج المُصدَّر فقط، ولا يُرسل للتحليل إطلاقًا."))
                                    .font(.trCaption).foregroundStyle(Palette.inkTertiary)
                            }
                        }
                        FieldBlock(label: L("Date & time of tracer", "تاريخ ووقت التتبع"), symbol: "calendar") {
                            DatePicker("", selection: $date)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .luxCard()

                    Button {
                        start()
                    } label: {
                        Label(L("Begin trace", "ابدأ التتبع"), systemImage: "arrow.forward.circle.fill")
                    }
                    .buttonStyle(GoldButtonStyle(fill: firstDept.isEmpty ? nil : dept(firstDept).color))
                    .disabled(topic == nil || firstDept.isEmpty)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("New session", "جلسة تتبع جديدة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
            }
        }
        .onAppear {
            organization = settings.organization
            team = settings.defaultTeam
            if let preselected {
                topicID = preselected.id
                firstDept = preselected.departmentCodes.first ?? ""
            }
        }
    }

    private var orderedDepartments: [Department] {
        let preferred = topic?.departmentCodes ?? []
        let all = DepartmentStore.shared.all
        return preferred.compactMap { c in all.first { $0.code == c } } + all.filter { !preferred.contains($0.code) }
    }

    private func labeled(_ label: String, _ symbol: String, _ binding: Binding<String>) -> some View {
        FieldBlock(label: label, symbol: symbol) {
            TextField("—", text: binding).inputBox()
        }
    }

    private func start() {
        guard let topic else { return }
        if settings.organization.isEmpty { settings.organization = organization }
        if settings.defaultTeam.isEmpty { settings.defaultTeam = team }
        let s = TraceEngine(context: context).startSession(topic: topic, organization: organization, team: team, patientRecord: patientRecord, documents: documents, date: date, firstDepartment: firstDept)
        Haptics.success()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onStart(s) }
    }
}
