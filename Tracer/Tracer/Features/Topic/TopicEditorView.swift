import SwiftUI
import SwiftData

struct QuestionDraft: Identifiable, Hashable {
    var id = UUID()
    var text: String
    var departmentCode: String
    var clauseIDs: [String]
    var expectedEvidence: String
}

struct TopicEditorView: View {
    let topic: TraceTopic?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var summary = ""
    @State private var objective = ""
    @State private var symbol = "point.3.filled.connected.trianglepath.dotted"
    @State private var tracerType: TracerType = .system
    @State private var departments: [String] = []
    @State private var clauseIDs: [String] = []
    @State private var questions: [QuestionDraft] = []

    @State private var drafting = false
    @State private var draftError: String?
    @State private var pickingStandardsForTopic = false
    @State private var editingQuestion: QuestionDraft?
    @State private var loaded = false

    static let symbols = [
        "point.3.filled.connected.trianglepath.dotted", "bell.badge", "pills", "hands.and.sparkles", "drop", "heart.text.square",
        "lungs", "brain.head.profile", "cross.case", "syringe", "bandage", "person.badge.shield.checkmark", "figure.fall",
        "flame", "bolt.shield", "building.columns", "doc.text.magnifyingglass", "list.clipboard", "thermometer.medium",
        "bed.double", "fork.knife", "staroflife", "allergens", "scissors",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    identitySection
                    draftButton
                    typeSection
                    departmentsSection
                    questionsSection
                    standardsSection
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(topic == nil ? L("New topic", "موضوع تتبع جديد") : L("Edit topic", "تعديل الموضوع"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "إلغاء")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save", "حفظ")) { commit() }
                        .font(.trBodyBold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $pickingStandardsForTopic) {
                StandardPickerView(selection: $clauseIDs, seedQuery: title)
            }
            .sheet(item: $editingQuestion) { q in
                QuestionEditorSheet(draft: q, departments: departments.isEmpty ? DepartmentStore.shared.all.map(\.code) : departments) { updated in
                    if let i = questions.firstIndex(where: { $0.id == updated.id }) {
                        questions[i] = updated
                    } else {
                        questions.append(updated)
                    }
                    if !departments.contains(updated.departmentCode) { departments.append(updated.departmentCode) }
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Sections

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                TopicMedallion(symbol: symbol, size: 60)
                VStack(alignment: .leading, spacing: 6) {
                    TextField(L("Topic name", "اسم الموضوع"), text: $title, axis: .vertical)
                        .font(.trTitle2)
                    TextField(L("One-line description", "وصف مختصر"), text: $summary, axis: .vertical)
                        .font(.trSubhead)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Self.symbols, id: \.self) { s in
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.snappy) { symbol = s }
                        } label: {
                            Image(systemName: s)
                                .font(.system(size: 18))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(symbol == s ? Palette.obsidian : Palette.ink)
                                .background(Circle().fill(symbol == s ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.surfaceRaised)))
                                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 0.75))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            FieldBlock(label: L("Objective", "الهدف"), symbol: "scope") {
                TextField(L("What must this trace confirm?", "ما الذي يجب أن يؤكده هذا التتبع؟"), text: $objective, axis: .vertical)
                    .lineLimit(2...6)
                    .inputBox()
            }
        }
        .luxCard()
    }

    private var draftButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await suggest() }
            } label: {
                HStack(spacing: 10) {
                    if drafting {
                        ProgressView().tint(Palette.obsidian)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(drafting ? L("Preparing a suggested structure…", "جارٍ إعداد هيكل مقترح…") : L("Suggest questions & departments", "اقترح الأسئلة والأقسام"))
                }
            }
            .buttonStyle(GoldButtonStyle())
            .disabled(drafting || title.trimmingCharacters(in: .whitespaces).count < 3)
            Text(L("Uses the reference manual to propose objective, route and questions. You review everything before saving.",
                   "يعتمد على الدليل المرجعي لاقتراح الهدف والمسار والأسئلة، وتراجع كل شيء قبل الحفظ."))
                .font(.trCaption)
                .foregroundStyle(Palette.inkTertiary)
            if let draftError {
                Text(draftError).font(.trCaption).foregroundStyle(RiskLevel.high.color)
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: L("Type of tracer", "نوع التتبع"), color: Palette.inkSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TracerType.allCases) { t in
                    Button {
                        Haptics.selection(); tracerType = t
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: t.symbol).font(.system(size: 14))
                            Text(t.title).font(.trFootnote.bold()).lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .foregroundStyle(tracerType == t ? Palette.obsidian : Palette.ink)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tracerType == t ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.surface)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var departmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: L("Expected route", "الأقسام المتوقعة"), color: Palette.inkSecondary)
            FlowLayout(spacing: 8) {
                ForEach(DepartmentStore.shared.all) { d in
                    let on = departments.contains(d.code)
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.snappy) {
                            if on { departments.removeAll { $0 == d.code } } else { departments.append(d.code) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: d.symbol).font(.system(size: 12, weight: .semibold))
                            Text(d.name).font(.trFootnote.bold())
                            if on, let i = departments.firstIndex(of: d.code) {
                                Text("\(i + 1)").font(.trMicro)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(.white.opacity(0.25)))
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .foregroundStyle(on ? .white : d.color)
                        .background(Capsule().fill(on ? AnyShapeStyle(d.color.gradient) : AnyShapeStyle(d.color.opacity(0.1))))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: L("Questions & checkpoints", "الأسئلة ونقاط التحقق"), color: Palette.inkSecondary)
                Spacer()
                Button {
                    editingQuestion = QuestionDraft(text: "", departmentCode: departments.first ?? "ER", clauseIDs: [], expectedEvidence: "")
                } label: {
                    Label(L("Add", "إضافة"), systemImage: "plus.circle.fill").font(.trFootnote.bold())
                }
            }
            if questions.isEmpty {
                Text(L("Add the questions you will ask staff in each department.", "أضف الأسئلة التي ستطرحها على الموظفين في كل قسم."))
                    .font(.trSubhead).foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .luxCard()
            }
            ForEach(questions) { q in
                let d = dept(q.departmentCode)
                HStack(alignment: .top, spacing: 12) {
                    DeptMedallion(department: d, size: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(q.text).font(.trCallout).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            Text(d.name).font(.trCaption.bold()).foregroundStyle(d.color)
                            ForEach(q.clauseIDs.prefix(3), id: \.self) { c in
                                Text(StandardsLibrary.shared.standard(c)?.id ?? c).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.gold)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button { editingQuestion = q } label: { Label(L("Edit", "تعديل"), systemImage: "pencil") }
                        Button(role: .destructive) {
                            withAnimation { questions.removeAll { $0.id == q.id } }
                        } label: { Label(L("Remove", "حذف"), systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 30, height: 30).foregroundStyle(Palette.inkSecondary)
                    }
                }
                .luxCard(padding: 14, radius: 18)
                .onTapGesture { editingQuestion = q }
            }
        }
    }

    private var standardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: L("Linked standards", "المعايير المرتبطة"), color: Palette.inkSecondary)
                Spacer()
                Button { pickingStandardsForTopic = true } label: {
                    Label(L("Choose", "اختيار"), systemImage: "books.vertical").font(.trFootnote.bold())
                }
            }
            FlowLayout(spacing: 6) {
                ForEach(clauseIDs, id: \.self) { c in
                    Chip(text: StandardsLibrary.shared.standard(c)?.id ?? c, symbol: "bookmark.fill", tint: Palette.gold)
                }
            }
        }
    }

    // MARK: Logic

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let topic else { return }
        title = topic.title
        summary = topic.summary
        objective = topic.objective
        symbol = topic.symbol
        tracerType = topic.tracerType
        departments = topic.departmentCodes
        clauseIDs = topic.clauseIDs
        questions = topic.orderedQuestions.map {
            QuestionDraft(text: $0.text, departmentCode: $0.departmentCode, clauseIDs: $0.clauseIDs, expectedEvidence: $0.expectedEvidence)
        }
    }

    private func suggest() async {
        drafting = true
        draftError = nil
        defer { drafting = false }
        let lib = StandardsLibrary.shared
        let candidates = lib.search("\(title) \(objective) \(summary)", manual: StandardsLibrary.hospitalManual, limit: 12)
        do {
            let draft = try await AnalysisClient().draftTopic(title: title, notes: "\(summary)\n\(objective)", departments: DepartmentStore.shared.all, clauses: candidates)
            let keyFor: (String) -> String = { id in
                candidates.first { $0.id == id }?.key ?? id
            }
            withAnimation(Motion.luxe) {
                if objective.isEmpty { objective = draft.objective }
                if summary.isEmpty { summary = draft.description }
                tracerType = TracerType(rawValue: draft.tracer_type) ?? tracerType
                for code in draft.department_codes where !departments.contains(code) { departments.append(code) }
                for q in draft.questions {
                    questions.append(QuestionDraft(text: q.text, departmentCode: q.department_code, clauseIDs: q.clause_ids.map(keyFor), expectedEvidence: q.expected_evidence))
                }
                for c in draft.questions.flatMap(\.clause_ids).map(keyFor) where !clauseIDs.contains(c) { clauseIDs.append(c) }
            }
            Haptics.success()
        } catch {
            draftError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            Haptics.warning()
        }
    }

    private func commit() {
        let engine = TraceEngine(context: context)
        let target: TraceTopic
        if let topic {
            target = topic
            target.version += 1
        } else {
            target = TraceTopic(number: engine.nextTopicNumber(), title: title)
            context.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.summary = summary
        target.objective = objective
        target.symbol = symbol
        target.tracerType = tracerType
        target.departmentCodes = departments
        target.clauseIDs = clauseIDs
        target.updatedAt = .now
        for q in target.questions { context.delete(q) }
        for (i, q) in questions.enumerated() {
            let tq = TopicQuestion(text: q.text, departmentCode: q.departmentCode, clauseIDs: q.clauseIDs, expectedEvidence: q.expectedEvidence, order: i)
            context.insert(tq)
            tq.topic = target
        }
        engine.save()
        Haptics.success()
        dismiss()
    }
}

struct QuestionEditorSheet: View {
    @State var draft: QuestionDraft
    let departments: [String]
    let onSave: (QuestionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FieldBlock(label: L("Question", "السؤال"), symbol: "questionmark.bubble") {
                        TextField(L("What will you ask?", "ما السؤال الذي ستطرحه؟"), text: $draft.text, axis: .vertical)
                            .lineLimit(2...6)
                            .inputBox()
                    }
                    FieldBlock(label: L("Department", "القسم"), symbol: "building.2") {
                        FlowLayout(spacing: 8) {
                            ForEach(DepartmentStore.shared.all) { d in
                                let on = draft.departmentCode == d.code
                                Button {
                                    Haptics.selection(); draft.departmentCode = d.code
                                } label: {
                                    Label(d.name, systemImage: d.symbol)
                                        .font(.trFootnote.bold())
                                        .padding(.horizontal, 12).frame(height: 34)
                                        .foregroundStyle(on ? .white : d.color)
                                        .background(Capsule().fill(on ? AnyShapeStyle(d.color.gradient) : AnyShapeStyle(d.color.opacity(0.1))))
                                }
                                .buttonStyle(.plain)
                                .opacity(departments.contains(d.code) || on ? 1 : 0.55)
                            }
                        }
                    }
                    FieldBlock(label: L("Expected evidence", "الأدلة المتوقعة"), symbol: "doc.text.magnifyingglass") {
                        TextField(L("Records, logs, observations…", "سجلات، تقارير، مشاهدات…"), text: $draft.expectedEvidence, axis: .vertical)
                            .lineLimit(1...4)
                            .inputBox()
                    }
                    FieldBlock(label: L("Reference", "المرجع"), symbol: "bookmark") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(StandardsLibrary.shared.standards(draft.clauseIDs)) { s in
                                StandardRow(standard: s, compact: true)
                            }
                            Button { picking = true } label: {
                                Label(L("Link standards", "ربط معايير"), systemImage: "plus").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GhostButtonStyle(tint: Palette.gold))
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Question", "سؤال"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done", "تم")) { onSave(draft); dismiss() }
                        .disabled(draft.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $picking) {
                StandardPickerView(selection: $draft.clauseIDs, seedQuery: draft.text)
            }
        }
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                y += rowH + spacing
                x = 0; rowH = 0
            }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += rowH + spacing
                x = bounds.minX; rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
