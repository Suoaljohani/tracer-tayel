import SwiftUI
import SwiftData
import Observation

enum WorkspaceTab: String, CaseIterable {
    case assess, path, log
}

@Observable
final class WorkspaceState {
    var tab: WorkspaceTab = .assess
    var showAnalysis = false
    var saveState: SaveState = .saved(.now)
    /// Department currently shown by the full-screen transition, if any.
    var transitionDept: Department?
    var highlightNodeID: UUID?
}

struct SessionWorkspaceView: View {
    let sessionID: UUID

    @Query private var sessions: [TraceSession]

    init(sessionID: UUID) {
        self.sessionID = sessionID
        _sessions = Query(filter: #Predicate<TraceSession> { $0.id == sessionID })
    }

    var body: some View {
        if let session = sessions.first {
            WorkspaceContent(session: session)
                .id(session.id)
        } else {
            EmptyState(symbol: "exclamationmark.lock", title: L("Session unavailable", "الجلسة غير متاحة"),
                       message: L("It may have been deleted.", "ربما تم حذفها."))
        }
    }
}

private struct WorkspaceContent: View {
    @Bindable var session: TraceSession

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ws = WorkspaceState()
    @State private var showSwitcher = false
    @State private var showDetails = false
    @State private var showClose = false
    @State private var reportURL: URL?
    @State private var exporting = false

    private var engine: TraceEngine { TraceEngine(context: context) }
    private var current: Department { dept(session.currentNode?.departmentCode) }

    var body: some View {
        ZStack(alignment: .bottom) {
            current.wash
                .ignoresSafeArea()
                .animation(Motion.theme, value: current.code)

            VStack(spacing: 0) {
                header
                ZStack {
                    switch ws.tab {
                    case .assess:
                        AssessView(session: session)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 16)), removal: .opacity))
                    case .path:
                        PathMapView(session: session)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97)), removal: .opacity))
                    case .log:
                        LogView(session: session)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 16)), removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            tabBar
                .padding(.horizontal, 18)
                .padding(.bottom, 6)

            if let d = ws.transitionDept {
                DepartmentTransitionOverlay(department: d, reduceMotion: reduceMotion) {
                    ws.transitionDept = nil
                }
                .zIndex(20)
            }
        }
        .environment(ws)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSwitcher) {
            SessionSwitcherSheet(currentID: session.id) { id in
                ws.saveState = .saving
                if engine.save() {
                    ws.saveState = .saved(.now)
                    router.openSession(id)
                } else {
                    ws.saveState = .failed
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $showDetails) { SessionDetailsSheet(session: session) }
        .sheet(isPresented: $showClose) { CloseSessionSheet(session: session) }
        .sheet(item: Binding(get: { reportURL.map(IdentifiedURL.init) }, set: { reportURL = $0?.url })) { item in
            ReportPreview(url: item.url)
        }
        .onAppear {
            if let raw = WorkspaceTab(rawValue: session.lastTabRaw) { ws.tab = raw }
        }
        .onChange(of: ws.tab) { _, new in
            session.lastTabRaw = new.rawValue
            engine.save()
        }
    }

    // MARK: Header

    private var header: some View {
        let risk = session.topRisk
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    CircleIconButton(symbol: "house", tint: .white, background: .white.opacity(0.12), size: 38) {
                        engine.save()
                        router.home()
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.topic?.title ?? "")
                            .font(.trBodyBold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(session.displayTitle).font(.trCaption).foregroundStyle(.white.opacity(0.7))
                            Text("·").foregroundStyle(.white.opacity(0.4))
                            SaveIndicator(state: ws.saveState)
                        }
                    }
                    Spacer(minLength: 4)
                    Button {
                        Haptics.tap(); showSwitcher = true
                    } label: {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(.white.opacity(0.12)))
                    }
                    .accessibilityLabel(L("Switch session", "تبديل الجلسة"))
                    Menu {
                        Button { Task { await exportReport() } } label: {
                            Label(L("Export tracer form (PDF)", "تصدير نموذج التتبع (PDF)"), systemImage: "doc.richtext")
                        }
                        Button { showDetails = true } label: {
                            Label(L("Session details", "بيانات الجلسة"), systemImage: "info.circle")
                        }
                        Divider()
                        if session.status != .completed {
                            Button { engine.setStatus(session, session.status == .onHold ? .active : .onHold) } label: {
                                Label(session.status == .onHold ? L("Resume", "استئناف") : L("Put on hold", "تعليق الجلسة"), systemImage: "pause.circle")
                            }
                            Button { showClose = true } label: {
                                Label(L("Close session", "إغلاق الجلسة"), systemImage: "lock")
                            }
                        } else {
                            Button { engine.reopen(session) } label: {
                                Label(L("Reopen session", "إعادة فتح الجلسة"), systemImage: "lock.open")
                            }
                        }
                    } label: {
                        Group {
                            if exporting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.white.opacity(0.12)))
                    }
                }

                HStack(spacing: 12) {
                    DeptMedallion(department: current, size: 46, onDark: true)
                        .id(current.code)
                        .transition(.scale.combined(with: .opacity))
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow(text: L("Current department", "القسم الحالي"), color: current.bright)
                        Text(current.name)
                            .font(.trTitle)
                            .foregroundStyle(.white)
                            .contentTransition(.opacity)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let risk {
                            RiskBadge(level: risk.level, approved: risk.approved, compact: true)
                                .background(Capsule().fill(.white))
                        } else {
                            RiskBadge(level: .undetermined, compact: true)
                                .background(Capsule().fill(.white))
                        }
                        Text(session.status.title).font(.trMicro).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 16)
            .background(
                ZStack {
                    LinearGradient(colors: [current.deep, current.color], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.white.opacity(0.08)).frame(width: 260).blur(radius: 50).offset(x: 140, y: -60)
                    Image(systemName: current.symbol)
                        .font(.system(size: 150, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.06))
                        .offset(x: isArabic ? -120 : 120, y: 20)
                }
                .ignoresSafeArea(edges: .top)
                .animation(Motion.theme, value: current.code)
            )
            // Semantic risk strip: layer two, independent of the department colour.
            Rectangle()
                .fill((risk?.level ?? .undetermined).color.gradient)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    if risk?.approved == false {
                        Rectangle().fill(.white.opacity(0.35)).frame(height: 1.5).padding(.horizontal, 0)
                    }
                }
        }
        .animation(Motion.theme, value: current.code)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(symbol: "house", title: L("Home", "الرئيسية"), selected: false) {
                engine.save()
                router.home()
            }
            tabButton(symbol: "checklist", title: L("Assess", "التقييم"), selected: ws.tab == .assess) { select(.assess) }
            tabButton(symbol: "point.topleft.down.to.point.bottomright.curvepath", title: L("Path", "المسار"), selected: ws.tab == .path) { select(.path) }
            tabButton(symbol: "clock.arrow.circlepath", title: L("Log", "السجل"), selected: ws.tab == .log) { select(.log) }
        }
        .padding(6)
        .background(Capsule().fill(.ultraThinMaterial))
        .background(Capsule().fill(Palette.obsidian.opacity(0.75)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    @Namespace private var tabNS

    private func tabButton(symbol: String, title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection(); action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                Text(title).font(.janna(10.5, bold: true))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(selected ? Palette.obsidian : .white.opacity(0.75))
            .background {
                if selected {
                    Capsule().fill(Palette.goldGradient).matchedGeometryEffect(id: "wsTab", in: tabNS)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func select(_ tab: WorkspaceTab) {
        withAnimation(Motion.luxe) { ws.tab = tab }
    }

    // MARK: Report

    private func exportReport() async {
        exporting = true
        defer { exporting = false }
        let url = ReportBuilder(session: session).write()
        engine.log(session, .reportExported, L("Tracer form exported", "تصدير نموذج التتبع"))
        engine.save()
        reportURL = url
    }
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Cinematic department change: a colour field sweeps across, the department mark rises,
/// then the new workspace is revealed. Falls back to a short cross-fade with Reduce Motion.
struct DepartmentTransitionOverlay: View {
    let department: Department
    let reduceMotion: Bool
    let onDone: () -> Void

    @State private var expand = false
    @State private var showMark = false
    @State private var fadeOut = false

    var body: some View {
        GeometryReader { geo in
            let diameter = hypot(geo.size.width, geo.size.height) * 2.2
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [department.color, department.deep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(expand || reduceMotion ? 1 : 0.02)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.62)
                VStack(spacing: 16) {
                    DeptMedallion(department: department, size: 92, onDark: true)
                        .scaleEffect(showMark ? 1 : 0.6)
                    Eyebrow(text: L("Trace continues in", "يستمر التتبع في"), color: .white.opacity(0.7))
                    Text(department.name)
                        .font(.trHero)
                        .foregroundStyle(.white)
                }
                .opacity(showMark ? 1 : 0)
                .offset(y: showMark ? 0 : 24)
                .blur(radius: showMark ? 0 : 6)
            }
            .opacity(fadeOut ? 0 : 1)
            .scaleEffect(fadeOut && !reduceMotion ? 1.08 : 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(!fadeOut)
        .task {
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.2)) { showMark = true }
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.easeInOut(duration: 0.25)) { fadeOut = true }
                try? await Task.sleep(for: .milliseconds(260))
                onDone()
                return
            }
            Haptics.soft()
            withAnimation(.easeInOut(duration: 0.55)) { expand = true }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { showMark = true }
            try? await Task.sleep(for: .milliseconds(850))
            withAnimation(.easeIn(duration: 0.4)) { fadeOut = true }
            try? await Task.sleep(for: .milliseconds(420))
            onDone()
        }
    }
}
