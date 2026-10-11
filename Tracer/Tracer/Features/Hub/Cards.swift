import SwiftUI

/// Topic card — the definition of a trace. Ivory/obsidian with a gold medallion.
struct TopicCard: View {
    let topic: TraceTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                TopicMedallion(symbol: topic.symbol, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(topic.code)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Palette.gold)
                        Text("·").foregroundStyle(Palette.inkTertiary)
                        Label(topic.tracerType.title, systemImage: topic.tracerType.symbol)
                            .font(.trCaption)
                            .foregroundStyle(Palette.inkSecondary)
                            .labelStyle(.titleAndIcon)
                    }
                    Text(topic.title)
                        .font(.trHeadline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !topic.summary.isEmpty {
                        Text(topic.summary)
                            .font(.trFootnote)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }

            GoldDivider().opacity(0.5)

            HStack(spacing: 10) {
                metric(value: topic.activeSessions.count, label: L("Active", "نشطة"), symbol: "dot.radiowaves.left.and.right")
                metric(value: topic.completedSessions.count, label: L("Completed", "مكتملة"), symbol: "checkmark.seal")
                Spacer()
                if let r = topic.topRisk {
                    RiskBadge(level: r.level, approved: r.approved, compact: true)
                } else {
                    Chip(text: L("No open risk", "لا خطورة مفتوحة"), symbol: "shield", tint: Palette.inkTertiary)
                }
            }

            HStack(spacing: 8) {
                if let node = topic.latestSession?.currentNode, topic.latestSession?.status != .completed {
                    let d = dept(node.departmentCode)
                    Image(systemName: d.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(d.color)
                    Text(L("Now at \(d.name)", "حاليًا في \(d.name)")).font(.trCaption).foregroundStyle(Palette.inkSecondary)
                } else {
                    deptStrip
                }
                Spacer()
                Text(topic.lastActivity.relativeText)
                    .font(.trCaption)
                    .foregroundStyle(Palette.inkTertiary)
                Image(systemName: isArabic ? "chevron.left" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.gold)
            }
        }
        .luxCard(padding: 18, radius: 24)
        .overlay(alignment: .topTrailing) {
            if topic.sessions.contains(where: { $0.status != .completed && $0.criticalPendingReview }) {
                RiskGlyph(level: .critical, size: 18).padding(12)
            }
        }
    }

    private var deptStrip: some View {
        HStack(spacing: -6) {
            ForEach(topic.departmentCodes.prefix(5), id: \.self) { code in
                DeptMedallion(department: dept(code), size: 22)
                    .overlay(Circle().strokeBorder(Palette.surface, lineWidth: 1.5))
            }
        }
    }

    private func metric(value: Int, label: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.gold)
            Text("\(value)").font(.trBodyBold).foregroundStyle(Palette.ink)
            Text(label).font(.trCaption).foregroundStyle(Palette.inkSecondary)
        }
    }
}

/// Session card — an actual evaluation. Carries its department colour as a spine.
struct SessionCard: View {
    let session: TraceSession

    var body: some View {
        let node = session.currentNode
        let d = dept(node?.departmentCode)
        HStack(spacing: 0) {
            Rectangle()
                .fill(LinearGradient(colors: [d.color, d.deep], startPoint: .top, endPoint: .bottom))
                .frame(width: 5)
            HStack(alignment: .top, spacing: 12) {
                DeptMedallion(department: d, size: 40)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(session.topic?.title ?? "—")
                            .font(.trBodyBold)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(session.displayTitle)
                            .font(.trCaption)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    HStack(spacing: 6) {
                        Label(session.status.title, systemImage: session.status.symbol)
                            .font(.trCaption)
                            .foregroundStyle(Palette.inkSecondary)
                        Text("·").foregroundStyle(Palette.inkTertiary)
                        Text(d.name).font(.trCaption.bold()).foregroundStyle(d.color)
                    }
                    HStack(spacing: 8) {
                        if session.criticalPendingReview {
                            Chip(text: L("Critical — awaiting review", "حرجة — بانتظار المراجعة"), symbol: "exclamationmark.octagon.fill", tint: RiskLevel.critical.color, filled: true)
                        } else if let r = session.topRisk {
                            RiskBadge(level: r.level, approved: r.approved, compact: true)
                        } else {
                            RiskBadge(level: .undetermined, compact: true)
                        }
                        Spacer()
                        Label(session.lastActivityAt.relativeText, systemImage: "checkmark.icloud")
                            .font(.trMicro)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }
            .padding(14)
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.75))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}

/// Compact dark card for the "continue" carousel.
struct ResumeCard: View {
    let session: TraceSession

    var body: some View {
        let d = dept(session.currentNode?.departmentCode)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DeptMedallion(department: d, size: 34, onDark: true)
                Spacer()
                if let r = session.topRisk {
                    RiskGlyph(level: r.level, size: 20)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(d.name)
                    .font(.trMicro)
                    .foregroundStyle(d.bright)
                Text(session.topic?.title ?? "—")
                    .font(.trBodyBold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            HStack {
                Text(session.displayTitle).font(.trCaption).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.goldGradient)
            }
        }
        .padding(16)
        .frame(width: 210, height: 176, alignment: .topLeading)
        .background(
            ZStack {
                LinearGradient(colors: [d.deep, Palette.obsidian], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(d.color.opacity(0.35)).blur(radius: 40).offset(x: 60, y: -50)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.75))
        .shadow(color: d.color.opacity(0.25), radius: 16, y: 8)
    }
}
