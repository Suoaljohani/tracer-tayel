import SwiftUI
import SwiftData

struct PathLayout {
    struct Placed: Identifiable {
        let node: TraceNode
        let lane: Int
        let row: Int
        var id: UUID { node.id }
    }

    let placed: [Placed]
    let maxLane: Int

    init(session: TraceSession) {
        let nodes = session.orderedNodes
        var lanes: [UUID: Int] = [:]
        var childCount: [UUID: Int] = [:]
        var nextLane = 1
        var result: [Placed] = []
        for (row, n) in nodes.enumerated() {
            var lane = 0
            if let edge = session.edges.filter({ $0.toNodeID == n.id }).min(by: { $0.createdAt < $1.createdAt }),
               let parentLane = lanes[edge.fromNodeID] {
                let siblings = childCount[edge.fromNodeID, default: 0]
                childCount[edge.fromNodeID] = siblings + 1
                if siblings == 0 {
                    lane = parentLane
                } else {
                    lane = nextLane
                    nextLane += 1
                }
            } else if row > 0, let prev = result.last {
                lane = prev.lane
            }
            lanes[n.id] = lane
            result.append(Placed(node: n, lane: lane, row: row))
        }
        placed = result
        maxLane = result.map(\.lane).max() ?? 0
    }
}

struct EdgeShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: from)
        let midY = (from.y + to.y) / 2
        p.addCurve(to: to, control1: CGPoint(x: from.x, y: midY), control2: CGPoint(x: to.x, y: midY))
        return p
    }
}

struct PathMapView: View {
    let session: TraceSession

    @Environment(\.modelContext) private var context
    @Environment(WorkspaceState.self) private var ws

    @State private var drawn: CGFloat = 0
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let rowHeight: CGFloat = 132
    private let laneWidth: CGFloat = 120

    var body: some View {
        let layout = PathLayout(session: session)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: L("Trace map", "خريطة التتبع"))
                        Text(L("\(session.nodes.count) points · \(session.visitedDepartmentCodes.count) departments · \(session.edges.count) links",
                               "\(session.nodes.count) نقاط · \(session.visitedDepartmentCodes.count) أقسام · \(session.edges.count) روابط"))
                            .font(.trFootnote).foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer()
                }

                GeometryReader { geo in
                    let width = geo.size.width
                    let positions = Dictionary(uniqueKeysWithValues: layout.placed.map { p in
                        (p.node.id, point(lane: p.lane, row: p.row, maxLane: layout.maxLane, width: width))
                    })
                    ZStack {
                        // Spine guide
                        ForEach(session.edges) { e in
                            if let a = positions[e.fromNodeID], let b = positions[e.toNodeID] {
                                let fromD = dept(session.nodes.first { $0.id == e.fromNodeID }?.departmentCode)
                                let toD = dept(session.nodes.first { $0.id == e.toNodeID }?.departmentCode)
                                EdgeShape(from: CGPoint(x: a.x, y: a.y + 50), to: CGPoint(x: b.x, y: b.y - 40))
                                    .trim(from: 0, to: drawn)
                                    .stroke(LinearGradient(colors: [fromD.color, toD.color], startPoint: .top, endPoint: .bottom),
                                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: e.linkType.dash))
                                Image(systemName: e.linkType.symbol)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(toD.color)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Palette.surface))
                                    .overlay(Circle().strokeBorder(toD.color.opacity(0.4), lineWidth: 1))
                                    .position(x: (a.x + b.x) / 2, y: (a.y + 50 + b.y - 40) / 2)
                                    .opacity(drawn)
                            }
                        }
                        // Unlinked sequence (e.g. first point to manually added ones)
                        ForEach(layout.placed.filter { p in p.row > 0 && !session.edges.contains { $0.toNodeID == p.node.id } }) { p in
                            if let b = positions[p.node.id], let prev = layout.placed.first(where: { $0.row == p.row - 1 }), let a = positions[prev.node.id] {
                                EdgeShape(from: CGPoint(x: a.x, y: a.y + 50), to: CGPoint(x: b.x, y: b.y - 40))
                                    .trim(from: 0, to: drawn)
                                    .stroke(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [2, 5]))
                            }
                        }
                        ForEach(layout.placed) { p in
                            if let pos = positions[p.node.id] {
                                nodeView(p.node)
                                    .position(pos)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(max(layout.placed.count, 1)) * rowHeight + 20)

                legend
                linkList
                Color.clear.frame(height: 90)
            }
            .padding(16)
        }
        .onAppear {
            if reduceMotion { drawn = 1 } else {
                drawn = 0
                withAnimation(.easeInOut(duration: 1.1).delay(0.15)) { drawn = 1 }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }

    private func point(lane: Int, row: Int, maxLane: Int, width: CGFloat) -> CGPoint {
        let span = CGFloat(maxLane) * laneWidth
        let startX = width / 2 - span / 2
        let x = maxLane == 0 ? width / 2 : startX + CGFloat(lane) * laneWidth
        return CGPoint(x: min(max(x, 50), width - 50), y: 50 + CGFloat(row) * rowHeight)
    }

    private func nodeView(_ n: TraceNode) -> some View {
        let d = dept(n.departmentCode)
        let isCurrent = n.id == session.currentNode?.id
        return Button {
            Haptics.selection()
            withAnimation(Motion.theme) {
                session.currentNodeID = n.id
                session.currentItemID = n.orderedItems.first?.id
            }
            try? context.save()
            withAnimation(Motion.luxe) { ws.tab = .assess }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isCurrent {
                        Circle().fill(d.color.opacity(0.18)).frame(width: 74, height: 74)
                            .scaleEffect(pulse ? 1.12 : 0.95)
                        Circle().strokeBorder(Palette.gold, lineWidth: 2).frame(width: 62, height: 62)
                    }
                    DeptMedallion(department: d, size: 52)
                    if let r = n.topRisk {
                        RiskGlyph(level: r, size: 18).offset(x: 20, y: -20)
                    }
                    if n.closed {
                        Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 18, height: 18).background(Circle().fill(Palette.inkSecondary)).offset(x: -20, y: 20)
                    }
                }
                Text(d.name).font(.trCaptionBold).foregroundStyle(isCurrent ? d.color : Palette.ink).lineLimit(1)
                HStack(spacing: 4) {
                    Text(L("Point \(n.order + 1)", "النقطة \(n.order + 1)"))
                    Text("·")
                    Image(systemName: "text.bubble").font(.system(size: 8))
                    Text(verbatim: "\(n.items.filter(\.hasAnswer).count)/\(n.items.count)")
                        .environment(\.layoutDirection, .leftToRight)
                }
                .font(.trMicro).foregroundStyle(Palette.inkTertiary)
            }
            .frame(width: 110)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([LinkType.followAction, .verifyConflict, .requestEvidence]) { t in
                HStack(spacing: 6) {
                    Path { p in p.move(to: .init(x: 0, y: 5)); p.addLine(to: .init(x: 24, y: 5)) }
                        .stroke(Palette.inkSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: t.dash))
                        .frame(width: 24, height: 10)
                    Text(t.title).font(.trMicro).foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
    }

    private var linkList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !session.edges.isEmpty {
                Eyebrow(text: L("Transitions", "الانتقالات"), color: Palette.inkSecondary)
            }
            ForEach(session.edges.sorted { $0.createdAt < $1.createdAt }) { e in
                let a = dept(session.nodes.first { $0.id == e.fromNodeID }?.departmentCode)
                let b = dept(session.nodes.first { $0.id == e.toNodeID }?.departmentCode)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        DeptMedallion(department: a, size: 24)
                        Image(systemName: isArabic ? "arrow.left" : "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.gold)
                        DeptMedallion(department: b, size: 24)
                        Text("\(a.name) — \(b.name)").font(.trFootnote.bold()).foregroundStyle(Palette.ink).lineLimit(1)
                        Spacer()
                        Text(e.createdAt.formatted(dateStyle: .none, timeStyle: .short)).font(.trMicro).foregroundStyle(Palette.inkTertiary)
                    }
                    Label(e.linkType.title, systemImage: e.linkType.symbol).font(.trCaption).foregroundStyle(b.color)
                    if !e.reason.isEmpty { Text(e.reason).font(.trCaption).foregroundStyle(Palette.inkSecondary) }
                    if !e.triggerQuestion.isEmpty { Text("“\(e.triggerQuestion)”").font(.trCaption).italic().foregroundStyle(Palette.inkTertiary) }
                }
                .luxCard(padding: 12, radius: 16)
            }
        }
    }
}

struct LogView: View {
    let session: TraceSession

    private struct DayGroup: Identifiable {
        let day: Date
        let events: [AuditEvent]
        var id: Date { day }
    }

    private var grouped: [DayGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: session.orderedEvents) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { key in DayGroup(day: key, events: (dict[key] ?? []).sorted { $0.date > $1.date }) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: L("Activity log", "السجل الزمني"))
                    Text(L("\(session.events.count) recorded actions", "\(session.events.count) إجراءً مسجلًا"))
                        .font(.trFootnote).foregroundStyle(Palette.inkSecondary)
                }
                ForEach(grouped) { group in
                    let day = group.day
                    let events = group.events
                    VStack(alignment: .leading, spacing: 0) {
                        Text(day.formatted(dateStyle: .full))
                            .font(.trCaptionBold).foregroundStyle(Palette.gold)
                            .padding(.bottom, 10)
                        ForEach(Array(events.enumerated()), id: \.element.id) { idx, e in
                            LogRow(event: e, isLast: idx == events.count - 1)
                        }
                    }
                }
                Color.clear.frame(height: 90)
            }
            .padding(16)
        }
    }
}

struct LogRow: View {
    let event: AuditEvent
    let isLast: Bool

    var body: some View {
        let d = event.departmentCode.isEmpty ? nil : dept(event.departmentCode)
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: event.kind.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(d?.color ?? Palette.gold)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.surface))
                    .overlay(Circle().strokeBorder((d?.color ?? Palette.gold).opacity(0.35), lineWidth: 0.75))
                if !isLast {
                    Rectangle().fill(Palette.hairline).frame(width: 1).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.message).font(.trFootnote.bold()).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(event.date.formatted(dateStyle: .none, timeStyle: .short)).font(.trMicro).foregroundStyle(Palette.inkTertiary)
                }
                if !event.detail.isEmpty {
                    Text(event.detail).font(.trCaption).foregroundStyle(Palette.inkSecondary).lineLimit(4)
                }
                HStack(spacing: 6) {
                    if let d { Text(d.name).font(.trMicro).foregroundStyle(d.color) }
                    if !event.actor.isEmpty { Text(event.actor).font(.trMicro).foregroundStyle(Palette.inkTertiary) }
                }
            }
            .padding(.bottom, 16)
        }
    }
}
