import SwiftUI
import SwiftData

struct AssessView: View {
    @Bindable var session: TraceSession

    @Environment(\.modelContext) private var context
    @Environment(WorkspaceState.self) private var ws

    @State private var showBranch = false
    @State private var showAddQuestion = false

    private var engine: TraceEngine { TraceEngine(context: context) }

    private var node: TraceNode? { session.currentNode }

    private var item: TraceItem? {
        guard let node else { return nil }
        if let id = session.currentItemID, let it = node.items.first(where: { $0.id == id }) { return it }
        return node.orderedItems.first
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if session.criticalPendingReview {
                        CriticalBanner(text: L("A critical finding is pending your review. Apply the hospital's immediate safety procedure now.",
                                               "توجد ملاحظة حرجة بانتظار مراجعتك. طبّق إجراء السلامة الفوري المعتمد في المستشفى الآن.")) {
                            if let crit = session.allItems.first(where: { !$0.resolved && !$0.riskApproved && $0.suggestedRisk == .critical }) {
                                focus(crit)
                                withAnimation(Motion.luxe) { ws.showAnalysis = true }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    nodeStrip

                    if let node {
                        nodeHeader(node)
                        questionPager(node)
                        if let item {
                            EvaluationCard(item: item, session: session)
                                .id(item.id)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: isArabic ? -24 : 24)), removal: .opacity))
                        } else {
                            EmptyState(symbol: "questionmark.bubble", title: L("No questions at this point", "لا توجد أسئلة في هذه النقطة"),
                                       message: L("Add a question to start assessing.", "أضف سؤالًا لبدء التقييم."))
                        }
                        actions(node)
                    }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .animation(Motion.luxe, value: session.currentItemID)
                .animation(Motion.luxe, value: session.currentNodeID)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.currentNodeID) { _, _ in
                withAnimation(Motion.luxe) { proxy.scrollTo("top", anchor: .top) }
            }
        }
        .sheet(isPresented: $showBranch) {
            if let node {
                BranchSheet(session: session, from: node) { newNode in
                    transition(to: newNode)
                }
            }
        }
        .sheet(isPresented: $showAddQuestion) {
            if let node {
                AddQuestionSheet(node: node) { newItem in
                    focus(newItem)
                }
            }
        }
    }

    // MARK: Node strip

    private var nodeStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Array(session.orderedNodes.enumerated()), id: \.element.id) { idx, n in
                    let d = dept(n.departmentCode)
                    let isCurrent = n.id == node?.id
                    if idx > 0 {
                        Rectangle()
                            .fill(LinearGradient(colors: [dept(session.orderedNodes[idx - 1].departmentCode).color.opacity(0.6), d.color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 22, height: 2)
                    }
                    Button {
                        Haptics.selection()
                        goTo(n)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                DeptMedallion(department: d, size: isCurrent ? 46 : 36)
                                    .overlay(Circle().strokeBorder(Palette.gold, lineWidth: isCurrent ? 2 : 0).padding(-4))
                                if let r = n.topRisk {
                                    RiskGlyph(level: r, size: 15).offset(x: 4, y: -4)
                                }
                            }
                            Text(d.name)
                                .font(isCurrent ? .trCaptionBold : .trCaption)
                                .foregroundStyle(isCurrent ? d.color : Palette.inkSecondary)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 64)
                        .opacity(n.closed ? 0.55 : 1)
                    }
                    .buttonStyle(.plain)
                    .id(n.id)
                }
                Button {
                    Haptics.tap(); showBranch = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(Palette.gold)
                            .background(Circle().strokeBorder(Palette.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
                        Text(L("Continue", "متابعة")).font(.trCaption).foregroundStyle(Palette.gold)
                    }
                    .frame(minWidth: 64)
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .id("top")
    }

    private func nodeHeader(_ node: TraceNode) -> some View {
        let d = dept(node.departmentCode)
        let answered = node.items.filter(\.hasAnswer).count
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: L("Trace point \(node.order + 1)", "نقطة التتبع \(node.order + 1)"), color: d.color)
                Text(L("\(answered) of \(node.items.count) questions answered", "\(answered) من \(node.items.count) أسئلة مُجابة"))
                    .font(.trFootnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
            if let edge = session.edges.first(where: { $0.toNodeID == node.id }) {
                Chip(text: edge.linkType.title, symbol: edge.linkType.symbol, tint: d.color)
            }
            Button {
                node.closed.toggle()
                node.closedAt = node.closed ? .now : nil
                engine.log(session, .fieldEdited, node.closed ? L("Trace point closed", "إغلاق نقطة التتبع") : L("Trace point reopened", "إعادة فتح نقطة التتبع"), dept: node.departmentCode)
                engine.save()
                Haptics.tap()
            } label: {
                Image(systemName: node.closed ? "lock.fill" : "lock.open")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(node.closed ? d.color : Palette.inkTertiary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.surface))
            }
            .accessibilityLabel(node.closed ? L("Reopen trace point", "إعادة فتح النقطة") : L("Close trace point", "إغلاق النقطة"))
        }
    }

    private func questionPager(_ node: TraceNode) -> some View {
        let d = dept(node.departmentCode)
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(node.orderedItems.enumerated()), id: \.element.id) { idx, it in
                    let selected = it.id == item?.id
                    Button {
                        Haptics.selection(); focus(it)
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            if let r = it.effectiveRisk, r != .noFinding {
                                RiskGlyph(level: r, size: 12)
                            } else if it.compliance != .unset {
                                Image(systemName: it.compliance.symbol).font(.system(size: 11))
                            } else if it.hasAnswer {
                                Image(systemName: "text.bubble.fill").font(.system(size: 10))
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .foregroundStyle(selected ? .white : Palette.ink)
                        .background(Capsule().fill(selected ? AnyShapeStyle(d.color.gradient) : AnyShapeStyle(Palette.surface)))
                        .overlay(Capsule().strokeBorder(selected ? .clear : Palette.hairline, lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showAddQuestion = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(d.color)
                        .background(Circle().fill(d.color.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func actions(_ node: TraceNode) -> some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap(); showBranch = true
            } label: {
                Label(L("Continue trace in another department", "استكمال التتبع في قسم آخر"), systemImage: "arrow.triangle.branch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle(tint: dept(node.departmentCode).color))
        }
        .padding(.top, 4)
    }

    // MARK: Navigation within the session

    private func focus(_ it: TraceItem) {
        if let n = it.node, n.id != session.currentNodeID {
            goTo(n, item: it)
        } else {
            withAnimation(Motion.luxe) {
                session.currentItemID = it.id
                ws.showAnalysis = false
            }
            engine.save()
        }
    }

    private func goTo(_ n: TraceNode, item: TraceItem? = nil) {
        // Department identity changes with a calm cross-fade (~250ms).
        withAnimation(Motion.theme) {
            session.currentNodeID = n.id
            session.currentItemID = item?.id ?? n.orderedItems.first?.id
            ws.showAnalysis = false
        }
        engine.save()
    }

    private func transition(to newNode: TraceNode) {
        ws.transitionDept = dept(newNode.departmentCode)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            session.currentNodeID = newNode.id
            session.currentItemID = newNode.orderedItems.last(where: { !$0.hasAnswer })?.id ?? newNode.orderedItems.first?.id
            ws.showAnalysis = false
            ws.tab = .assess
            engine.save()
        }
    }
}

// MARK: - Evaluation card

struct EvaluationCard: View {
    @Bindable var item: TraceItem
    @Bindable var session: TraceSession

    @Environment(\.modelContext) private var context
    @Environment(WorkspaceState.self) private var ws
    @FocusState private var answerFocused: Bool

    @State private var analyzing = false
    @State private var errorText: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var detail: Standard?
    @State private var correcting: StaffResponse?
    @State private var showStandards = false

    private var engine: TraceEngine { TraceEngine(context: context) }
    private var d: Department { dept(item.node?.departmentCode) }

    var body: some View {
        @Bindable var ws = ws
        VStack(alignment: .leading, spacing: 16) {
            questionBlock
            modeSwitch
            if ws.showAnalysis, let rec = item.latestAnalysis, let result = rec.result {
                AnalysisPanel(item: item, session: session, record: rec, result: result)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 20)), removal: .opacity))
            } else {
                responseBlock
                    .transition(.opacity)
            }
        }
        .sheet(item: $detail) { StandardDetailView(standard: $0) }
        .sheet(item: $correcting) { r in
            CorrectionSheet(response: r) { text in engine.correct(r, newText: text) }
        }
        .sheet(isPresented: $showStandards) {
            StandardPickerView(selection: $item.clauseIDs, seedQuery: item.questionText)
        }
    }

    // MARK: Question

    private var questionBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Eyebrow(text: L("Tracer question", "سؤال التتبع"), color: d.color)
                Spacer()
                if let r = item.effectiveRisk {
                    RiskBadge(level: r, approved: item.riskApproved, compact: true)
                }
            }
            Text(item.questionText)
                .font(.trTitle2)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle").foregroundStyle(d.color)
                TextField(L("Person asked (role / title)", "الموظف (المسمى الوظيفي)"), text: $item.personAsked)
                    .font(.trCallout)
                    .onSubmit { engine.save() }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(d.wash))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Eyebrow(text: L("Relevant standards", "المعايير ذات الصلة"), color: Palette.inkSecondary)
                    Spacer()
                    Button { showStandards = true } label: {
                        Image(systemName: "plus.circle").foregroundStyle(Palette.gold)
                    }
                }
                let refs = StandardsLibrary.shared.standards(item.clauseIDs)
                if refs.isEmpty {
                    Text(L("No standard linked — analysis will use the closest matches.", "لا يوجد معيار مرتبط — سيستخدم التحليل أقرب المعايير."))
                        .font(.trCaption).foregroundStyle(Palette.inkTertiary)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(refs) { s in
                                Button { detail = s } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(s.id).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Palette.gold)
                                        Text(s.statement).font(.trCaption).foregroundStyle(Palette.inkSecondary).lineLimit(2)
                                            .environment(\.layoutDirection, .leftToRight)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(width: 210, alignment: .leading)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surfaceRaised))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.gold.opacity(0.3), lineWidth: 0.75))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            if !item.expectedEvidence.isEmpty {
                Label {
                    Text(item.expectedEvidence).font(.trCaption).foregroundStyle(Palette.inkSecondary)
                } icon: {
                    Image(systemName: "doc.text.magnifyingglass").foregroundStyle(d.color)
                }
            }
        }
        .luxCard(padding: 16, radius: 22)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(d.color.gradient).frame(width: 3).padding(.vertical, 22)
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            modeButton(L("Response", "الإجابة"), symbol: "text.bubble", active: !ws.showAnalysis) {
                withAnimation(Motion.luxe) { ws.showAnalysis = false }
            }
            modeButton(L("Analysis", "التحليل"), symbol: "doc.text.magnifyingglass", active: ws.showAnalysis, badge: item.latestAnalysis != nil && !ws.showAnalysis) {
                guard item.latestAnalysis != nil else { return }
                withAnimation(Motion.luxe) { ws.showAnalysis = true }
            }
            .opacity(item.latestAnalysis == nil ? 0.45 : 1)
        }
        .padding(4)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.75))
    }

    private func modeButton(_ title: String, symbol: String, active: Bool, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection(); action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title).font(.trFootnote.bold())
                if badge { Circle().fill(Palette.gold).frame(width: 7, height: 7) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .foregroundStyle(active ? .white : Palette.inkSecondary)
            .background(Capsule().fill(active ? AnyShapeStyle(d.color.gradient) : AnyShapeStyle(Color.clear)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Response

    private var responseBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !item.responses.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: L("Recorded answer — verbatim", "الإجابة المسجلة — كما وردت"), color: Palette.inkSecondary)
                    ForEach(item.orderedResponses) { r in
                        ResponseBubble(response: r, tint: d.color)
                            .contextMenu {
                                Button { correcting = r } label: { Label(L("Correct transcription", "تصحيح النص"), systemImage: "pencil") }
                            }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(text: item.responses.isEmpty ? L("Staff answer", "إجابة الموظف") : L("Additional answer", "إجابة إضافية"), color: Palette.inkSecondary)
                    Spacer()
                    DictationButton(text: $item.draftAnswer, tint: d.color)
                }
                ZStack(alignment: .topLeading) {
                    if item.draftAnswer.isEmpty {
                        Text(L("Type or dictate exactly what the staff member said…", "اكتب أو أملِ ما قاله الموظف كما هو…"))
                            .font(.trBody)
                            .foregroundStyle(Palette.inkTertiary)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $item.draftAnswer)
                        .font(.trBody)
                        .scrollContentBackground(.hidden)
                        .focused($answerFocused)
                        .frame(minHeight: 130)
                        .padding(8)
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(answerFocused ? d.color : Palette.hairline, lineWidth: answerFocused ? 1.3 : 0.75))
                .onChange(of: item.draftAnswer) { _, _ in scheduleSave() }

                HStack(spacing: 10) {
                    Button {
                        answerFocused = false
                        engine.recordAnswer(item, text: item.draftAnswer)
                        ws.saveState = .saved(.now)
                        Haptics.success()
                    } label: {
                        Label(item.responses.isEmpty ? L("Record", "تسجيل") : L("Add", "إضافة"), systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GhostButtonStyle(tint: d.color))
                    .disabled(item.draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        Task { await analyze() }
                    } label: {
                        HStack(spacing: 8) {
                            if analyzing { ProgressView().tint(.white) } else { Image(systemName: "doc.text.magnifyingglass") }
                            Text(analyzing ? L("Analysing…", "جارٍ التحليل…") : L("Analyse", "تحليل"))
                        }
                    }
                    .buttonStyle(GoldButtonStyle(fill: d.color))
                    .disabled(analyzing || (!item.hasAnswer && item.draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
                if let errorText {
                    Label(errorText, systemImage: "wifi.exclamationmark")
                        .font(.trCaption)
                        .foregroundStyle(RiskLevel.high.color)
                        .transition(.opacity)
                }
            }
            .luxCard(padding: 16, radius: 22)

            EvidenceStrip(session: session, item: item)

            FormFieldsCard(item: item, session: session)
        }
    }

    private func scheduleSave() {
        ws.saveState = .unsynced
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            ws.saveState = .saving
            let ok = engine.save()
            try? await Task.sleep(for: .milliseconds(250))
            ws.saveState = ok ? .saved(.now) : .failed
        }
    }

    private func analyze() async {
        answerFocused = false
        if !item.draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            engine.recordAnswer(item, text: item.draftAnswer)
        }
        guard item.hasAnswer else { return }
        analyzing = true
        errorText = nil
        defer { analyzing = false }
        var clauses = StandardsLibrary.shared.standards(item.clauseIDs)
        if clauses.isEmpty {
            clauses = StandardsLibrary.shared.search("\(item.questionText) \(session.topic?.title ?? "")", manual: StandardsLibrary.hospitalManual, limit: 4)
        }
        do {
            let (result, payload) = try await AnalysisClient().analyze(item: item, session: session, departments: DepartmentStore.shared.all, clauses: clauses)
            engine.storeAnalysis(result, payload: payload, for: item, clauses: clauses.map(\.key))
            if result.riskLevel.isElevated { Haptics.warning() } else { Haptics.success() }
            withAnimation(Motion.luxe) { ws.showAnalysis = true }
        } catch {
            withAnimation { errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
            Haptics.warning()
        }
    }
}

struct ResponseBubble: View {
    let response: StaffResponse
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: response.kind == .original ? "quote.opening" : response.kind == .addendum ? "text.badge.plus" : "pencil.line")
                    .font(.system(size: 10, weight: .bold))
                Text(response.kind.title).font(.trMicro)
                Spacer()
                Text(response.createdAt.formatted(dateStyle: .none, timeStyle: .short)).font(.trMicro)
            }
            .foregroundStyle(tint)
            Text(response.text)
                .font(.trBody)
                .foregroundStyle(Palette.ink)
                .textSelection(.enabled)
            if response.kind == .correction, !response.previousText.isEmpty {
                Text(L("Previously: ", "سابقًا: ") + response.previousText)
                    .font(.trCaption)
                    .strikethrough()
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.18), lineWidth: 0.75))
    }
}

/// Fields that map one-to-one onto the Mock Tracer Form.
struct FormFieldsCard: View {
    @Bindable var item: TraceItem
    @Bindable var session: TraceSession
    @Environment(\.modelContext) private var context
    @State private var hasDue = false

    private var engine: TraceEngine { TraceEngine(context: context) }

    var body: some View {
        let d = dept(item.node?.departmentCode)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Eyebrow(text: L("Tracer form", "نموذج التتبع"), color: d.color)
                Spacer()
                Image(systemName: "doc.richtext").foregroundStyle(Palette.inkTertiary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Compliant?", "هل يوجد التزام؟")).font(.trFootnote.bold()).foregroundStyle(Palette.inkSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Compliance.choices) { c in
                        let on = item.compliance == c
                        Button {
                            Haptics.selection()
                            engine.setCompliance(item, on ? .unset : c)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: c.symbol).font(.system(size: 13))
                                Text(c.title).font(.trFootnote.bold()).lineLimit(1).minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .foregroundStyle(on ? .white : Palette.ink)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? AnyShapeStyle(d.color.gradient) : AnyShapeStyle(Palette.surfaceRaised)))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairline, lineWidth: on ? 0 : 0.75))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let s = item.latestAnalysis?.result?.complianceValue, s != .unset, item.compliance == .unset {
                    Text(L("Suggested: \(s.title)", "المقترح: \(s.title)")).font(.trCaption).foregroundStyle(Palette.inkTertiary)
                }
            }
            FieldBlock(label: L("Evidence of compliance", "دليل الالتزام"), symbol: "checkmark.seal") {
                TextField(L("What did you see or verify?", "ما الذي شاهدته أو تحققت منه؟"), text: $item.evidenceOfCompliance, axis: .vertical)
                    .lineLimit(2...6)
                    .inputBox()
                    .onSubmit { engine.save() }
            }
            FieldBlock(label: L("Plan of action", "خطة العمل"), symbol: "list.bullet.clipboard") {
                TextField(L("Corrective action, owner…", "الإجراء التصحيحي، المسؤول…"), text: $item.planOfAction, axis: .vertical)
                    .lineLimit(2...6)
                    .inputBox()
            }
            Toggle(isOn: $hasDue.animation(Motion.snappy)) {
                Label(L("Due date", "تاريخ الاستحقاق"), systemImage: "calendar.badge.clock").font(.trCallout)
            }
            .tint(d.color)
            .onChange(of: hasDue) { _, on in
                item.dueDate = on ? (item.dueDate ?? Calendar.current.date(byAdding: .day, value: 30, to: .now)) : nil
                engine.save()
            }
            if hasDue {
                DatePicker("", selection: Binding(get: { item.dueDate ?? .now }, set: { item.dueDate = $0; engine.save() }), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
        .luxCard(padding: 16, radius: 22)
        .onAppear { hasDue = item.dueDate != nil }
        .onDisappear { engine.save() }
    }
}

struct CorrectionSheet: View {
    let response: StaffResponse
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("The original wording is kept in the record. Your correction is stored as a new version with the time.",
                       "تُحفظ الصياغة الأصلية في السجل، ويُحفظ تصحيحك كنسخة جديدة مع وقتها."))
                    .font(.trCaption).foregroundStyle(Palette.inkSecondary)
                TextEditor(text: $text)
                    .font(.trBody)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.surface))
                Spacer()
            }
            .padding(20)
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Correct transcription", "تصحيح النص"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("Save", "حفظ")) { onSave(text); dismiss() } }
            }
        }
        .onAppear { text = response.text }
        .presentationDetents([.medium, .large])
    }
}

struct AddQuestionSheet: View {
    let node: TraceNode
    let onAdd: (TraceItem) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var person = ""
    @State private var clauses: [String] = []
    @State private var picking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FieldBlock(label: L("Question", "السؤال"), symbol: "questionmark.bubble") {
                        TextField(L("What will you ask?", "ما السؤال الذي ستطرحه؟"), text: $text, axis: .vertical).lineLimit(2...6).inputBox()
                    }
                    FieldBlock(label: L("Person asked", "الموظف"), symbol: "person") {
                        TextField(L("Role / title", "المسمى الوظيفي"), text: $person).inputBox()
                    }
                    FieldBlock(label: L("Reference", "المرجع"), symbol: "bookmark") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(StandardsLibrary.shared.standards(clauses)) { StandardRow(standard: $0, compact: true) }
                            Button { picking = true } label: { Label(L("Link standards", "ربط معايير"), systemImage: "plus").frame(maxWidth: .infinity) }
                                .buttonStyle(GhostButtonStyle(tint: Palette.gold))
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Add question", "إضافة سؤال"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Add", "إضافة")) {
                        let it = TraceEngine(context: context).addQuestion(to: node, text: text, clauseIDs: clauses, personAsked: person)
                        dismiss()
                        onAdd(it)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $picking) { StandardPickerView(selection: $clauses, seedQuery: text) }
        }
    }
}
