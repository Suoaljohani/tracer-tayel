import SwiftUI
import SwiftData

enum HubTab: String, CaseIterable, Identifiable {
    case topics, active, review, completed, archived
    var id: String { rawValue }
    var title: String {
        switch self {
        case .topics: return L("All topics", "جميع المواضيع")
        case .active: return L("Active", "النشطة")
        case .review: return L("Needs review", "تحتاج مراجعة")
        case .completed: return L("Completed", "المكتملة")
        case .archived: return L("Archived", "المؤرشفة")
        }
    }
}

enum ActivityWindow: String, CaseIterable, Identifiable {
    case any, today, week, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .any: return L("Any time", "أي وقت")
        case .today: return L("Today", "اليوم")
        case .week: return L("Last 7 days", "آخر ٧ أيام")
        case .month: return L("Last 30 days", "آخر ٣٠ يومًا")
        }
    }
    func includes(_ d: Date) -> Bool {
        switch self {
        case .any: return true
        case .today: return Calendar.current.isDateInToday(d)
        case .week: return d > Date.now.addingTimeInterval(-7 * 86400)
        case .month: return d > Date.now.addingTimeInterval(-30 * 86400)
        }
    }
}

enum HubSort: String, CaseIterable, Identifiable {
    case recent, risk, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent: return L("Last activity", "آخر نشاط")
        case .risk: return L("Highest risk", "الأعلى خطورة")
        case .name: return L("Name", "الاسم")
        }
    }
}

struct HubFilters: Equatable {
    var department: String? = nil
    var risk: RiskLevel? = nil
    var evaluator: String? = nil
    var window: ActivityWindow = .any
    var status: SessionStatus? = nil
    var sort: HubSort = .recent

    var isActive: Bool { department != nil || risk != nil || evaluator != nil || window != .any || status != nil }
}

struct HubView: View {
    let zoom: Namespace.ID

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    @Query(sort: \TraceTopic.number) private var topics: [TraceTopic]
    @Query(sort: \TraceSession.lastActivityAt, order: .reverse) private var sessions: [TraceSession]

    @State private var tab: HubTab = .topics
    @State private var search = ""
    @State private var filters = HubFilters()
    @State private var showNewTopic = false
    @State private var showStartSession = false
    @State private var appeared = false
    @Namespace private var tabNS

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                    .padding(.horizontal, 20)
                statsRow
                actionRow
                    .padding(.horizontal, 20)
                if !recentSessions.isEmpty {
                    continueStrip
                }
                VStack(alignment: .leading, spacing: 14) {
                    searchField
                    tabBar
                    filterRow
                }
                .padding(.horizontal, 20)
                listContent
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNewTopic) {
            TopicEditorView(topic: nil)
        }
        .sheet(isPresented: $showStartSession) {
            StartSessionSheet(preselected: nil) { s in
                router.openSession(s.id)
            }
        }
        .onAppear {
            withAnimation(Motion.reveal.delay(0.1)) { appeared = true }
        }
    }

    // MARK: Header

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 12 { return L("Good morning", "صباح الخير") }
        if h < 18 { return L("Good afternoon", "طاب يومك") }
        return L("Good evening", "مساء الخير")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                BrandMark(size: 34, lineWidth: 2.2)
                    .environment(\.layoutDirection, .leftToRight)
                VStack(alignment: .leading, spacing: 0) {
                    Text("TRACER")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .tracking(5)
                        .foregroundStyle(Palette.ink)
                    Text(L("INTELLIGENCE", "ذكاء التتبع"))
                        .font(.trMicro)
                        .tracking(isArabic ? 0 : 2.5)
                        .foregroundStyle(Palette.gold)
                }
                Spacer()
                CircleIconButton(symbol: "books.vertical") { router.path.append(.library) }
                CircleIconButton(symbol: "gearshape") { router.path.append(.settings) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(dateStyle: .full))
                    .font(.trCaption)
                    .foregroundStyle(Palette.inkSecondary)
                Text(settings.evaluatorName.isEmpty ? greeting : "\(greeting)، \(settings.evaluatorName)")
                    .font(.trHero)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(L("Your trace topics and live sessions.", "مواضيع التتبع وجلساتك الجارية."))
                    .font(.trCallout)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        let active = sessions.filter { $0.status == .active }.count
        let review = sessions.filter { $0.status == .review || ($0.status != .completed && $0.needsReview) }.count
        let closed = sessions.filter { $0.status == .completed }.count
        let hold = sessions.filter { $0.status == .onHold }.count
        let critical = sessions.filter { $0.status != .completed && $0.criticalPendingReview }.count
        return ScrollView(.horizontal) {
            HStack(spacing: 12) {
                StatTile(value: active, label: L("Active sessions", "جلسات نشطة"), symbol: "dot.radiowaves.left.and.right")
                StatTile(value: critical, label: L("Critical, unresolved", "حرجة غير محسومة"), symbol: "exclamationmark.octagon", tint: RiskLevel.critical.color)
                StatTile(value: review, label: L("Awaiting review", "بانتظار المراجعة"), symbol: "eye", tint: RiskLevel.high.color)
                StatTile(value: hold, label: L("On hold", "معلقة"), symbol: "pause.circle", tint: Palette.inkSecondary)
                StatTile(value: closed, label: L("Closed", "مغلقة"), symbol: "checkmark.seal", tint: RiskLevel.low.color)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap(); showStartSession = true
            } label: {
                Label(L("Start session", "بدء جلسة تتبع"), systemImage: "play.fill")
            }
            .buttonStyle(GoldButtonStyle())
            .disabled(topics.filter { !$0.archived }.isEmpty)

            Button {
                Haptics.tap(); showNewTopic = true
            } label: {
                Label(L("New topic", "موضوع جديد"), systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    // MARK: Continue

    private var recentSessions: [TraceSession] {
        Array(sessions.filter { $0.status != .completed }.prefix(8))
    }

    private var continueStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L("Continue", "تابع من حيث توقفت"), eyebrow: L("Quick resume", "متابعة سريعة"))
                .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(recentSessions) { s in
                        Button {
                            Haptics.tap(); router.openSession(s.id)
                        } label: {
                            ResumeCard(session: s)
                                .matchedTransitionSource(id: s.id, in: zoom)
                        }
                        .buttonStyle(PressableStyle())
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                .opacity(phase.isIdentity ? 1 : 0.75)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // MARK: Search / tabs / filters

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkTertiary)
            TextField(L("Search by topic name or number", "ابحث باسم الموضوع أو رقمه"), text: $search)
                .font(.trBody)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.75))
    }

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(HubTab.allCases) { t in
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.snappy) { tab = t }
                    } label: {
                        HStack(spacing: 6) {
                            Text(t.title).font(.trFootnote.bold())
                            let n = count(for: t)
                            if n > 0 {
                                Text("\(n)")
                                    .font(.trMicro)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(tab == t ? Palette.obsidian.opacity(0.15) : Palette.ink.opacity(0.07)))
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .foregroundStyle(tab == t ? Palette.obsidian : Palette.inkSecondary)
                        .background {
                            if tab == t {
                                Capsule().fill(Palette.goldGradient).matchedGeometryEffect(id: "tab", in: tabNS)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Capsule().fill(Palette.surface))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.75))
        }
        .scrollIndicators(.hidden)
    }

    private var evaluators: [String] {
        Array(Set(sessions.map(\.evaluator).filter { !$0.isEmpty })).sorted()
    }

    private var filterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Menu {
                    Picker(L("Sort", "الفرز"), selection: $filters.sort) {
                        ForEach(HubSort.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Chip(text: filters.sort.title, symbol: "arrow.up.arrow.down", tint: Palette.ink)
                }
                Menu {
                    Button(L("All departments", "كل الأقسام")) { filters.department = nil }
                    ForEach(DepartmentStore.shared.all) { d in
                        Button { filters.department = d.code } label: { Label(d.name, systemImage: d.symbol) }
                    }
                } label: {
                    Chip(text: filters.department.map { dept($0).name } ?? L("Department", "القسم"), symbol: "building.2",
                         tint: filters.department.map { dept($0).color } ?? Palette.inkSecondary, filled: filters.department != nil)
                }
                Menu {
                    Button(L("Any risk", "أي خطورة")) { filters.risk = nil }
                    ForEach(RiskLevel.allCases) { r in
                        Button(r.title) { filters.risk = r }
                    }
                } label: {
                    Chip(text: filters.risk?.title ?? L("Risk", "الخطورة"), symbol: "exclamationmark.triangle",
                         tint: filters.risk?.color ?? Palette.inkSecondary, filled: filters.risk != nil)
                }
                Menu {
                    Button(L("Any status", "أي حالة")) { filters.status = nil }
                    ForEach(SessionStatus.allCases) { s in
                        Button { filters.status = s } label: { Label(s.title, systemImage: s.symbol) }
                    }
                } label: {
                    Chip(text: filters.status?.title ?? L("Status", "الحالة"), symbol: "circle.dashed", tint: Palette.inkSecondary, filled: filters.status != nil)
                }
                if !evaluators.isEmpty {
                    Menu {
                        Button(L("Any evaluator", "أي مقيِّم")) { filters.evaluator = nil }
                        ForEach(evaluators, id: \.self) { e in Button(e) { filters.evaluator = e } }
                    } label: {
                        Chip(text: filters.evaluator ?? L("Evaluator", "المقيِّم"), symbol: "person", tint: Palette.inkSecondary, filled: filters.evaluator != nil)
                    }
                }
                Menu {
                    ForEach(ActivityWindow.allCases) { w in Button(w.title) { filters.window = w } }
                } label: {
                    Chip(text: filters.window.title, symbol: "calendar", tint: Palette.inkSecondary, filled: filters.window != .any)
                }
                if filters.isActive {
                    Button {
                        withAnimation(Motion.snappy) { filters = HubFilters(sort: filters.sort) }
                    } label: {
                        Chip(text: L("Clear", "مسح"), symbol: "xmark", tint: Palette.gold)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Data

    private func matchesSearch(_ topic: TraceTopic?) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        guard let topic else { return false }
        return topic.title.localizedCaseInsensitiveContains(q)
            || topic.code.localizedCaseInsensitiveContains(q)
            || "\(topic.number)" == q.filter(\.isNumber)
    }

    private func matches(_ s: TraceSession) -> Bool {
        guard matchesSearch(s.topic) else { return false }
        if let d = filters.department, s.currentNode?.departmentCode != d { return false }
        if let r = filters.risk, s.topRisk?.level != r { return false }
        if let e = filters.evaluator, s.evaluator != e { return false }
        if let st = filters.status, s.status != st { return false }
        return filters.window.includes(s.lastActivityAt)
    }

    private func matches(_ t: TraceTopic) -> Bool {
        guard matchesSearch(t) else { return false }
        if let d = filters.department {
            let cur = t.latestSession?.currentNode?.departmentCode
            if cur != d && !t.departmentCodes.contains(d) { return false }
        }
        if let r = filters.risk, t.topRisk?.level != r { return false }
        if let e = filters.evaluator, !t.sessions.contains(where: { $0.evaluator == e }) { return false }
        if let st = filters.status, !t.sessions.contains(where: { $0.status == st }) { return false }
        return filters.window.includes(t.lastActivity)
    }

    private func sessionsFor(_ tab: HubTab) -> [TraceSession] {
        let base: [TraceSession]
        switch tab {
        case .active: base = sessions.filter { $0.status == .active || $0.status == .onHold }
        case .review: base = sessions.filter { $0.status != .completed && ($0.status == .review || $0.needsReview) }
        case .completed: base = sessions.filter { $0.status == .completed }
        default: base = []
        }
        let filtered = base.filter { matches($0) }
        switch filters.sort {
        case .recent: return filtered
        case .risk: return filtered.sorted { ($0.topRisk?.level.weight ?? -1) > ($1.topRisk?.level.weight ?? -1) }
        case .name: return filtered.sorted { ($0.topic?.title ?? "") < ($1.topic?.title ?? "") }
        }
    }

    private var visibleTopics: [TraceTopic] {
        let base = topics.filter { tab == .archived ? $0.archived : !$0.archived }.filter { matches($0) }
        switch filters.sort {
        case .recent: return base.sorted { $0.lastActivity > $1.lastActivity }
        case .risk: return base.sorted { ($0.topRisk?.level.weight ?? -1) > ($1.topRisk?.level.weight ?? -1) }
        case .name: return base.sorted { $0.title < $1.title }
        }
    }

    private func count(for tab: HubTab) -> Int {
        switch tab {
        case .topics: return topics.filter { !$0.archived }.count
        case .archived: return topics.filter(\.archived).count
        default: return sessionsFor(tab).count
        }
    }

    @ViewBuilder
    private var listContent: some View {
        switch tab {
        case .topics, .archived:
            let list = visibleTopics
            if list.isEmpty {
                EmptyState(symbol: tab == .archived ? "archivebox" : "point.3.filled.connected.trianglepath.dotted",
                           title: tab == .archived ? L("No archived topics", "لا توجد مواضيع مؤرشفة") : L("No topics found", "لا توجد مواضيع"),
                           message: L("Create a trace topic to begin.", "أنشئ موضوع تتبع للبدء."))
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(list) { t in
                        Button {
                            Haptics.tap(); router.openTopic(t.id)
                        } label: {
                            TopicCard(topic: t)
                                .matchedTransitionSource(id: t.id, in: zoom)
                        }
                        .buttonStyle(PressableStyle(scale: 0.985))
                        .scrollTransition(.animated(Motion.luxe)) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.4)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                .offset(y: phase.value * 12)
                        }
                    }
                }
            }
        default:
            let list = sessionsFor(tab)
            if list.isEmpty {
                EmptyState(symbol: "tray", title: L("Nothing here", "لا توجد جلسات"),
                           message: L("Sessions will appear here as you trace.", "ستظهر الجلسات هنا أثناء التتبع."))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(list) { s in
                        Button {
                            Haptics.tap(); router.openSession(s.id)
                        } label: {
                            SessionCard(session: s)
                                .matchedTransitionSource(id: s.id, in: zoom)
                        }
                        .buttonStyle(PressableStyle(scale: 0.985))
                        .scrollTransition(.animated(Motion.luxe)) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.4)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                    }
                }
            }
        }
    }
}
