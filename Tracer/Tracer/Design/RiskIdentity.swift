import SwiftUI

extension RiskLevel {
    var color: Color {
        switch self {
        case .critical: return Color(light: 0xC0262D, dark: 0xF0545A)
        case .high: return Color(light: 0xC4510F, dark: 0xF07F3C)
        case .moderate: return Color(light: 0xB27A00, dark: 0xF1B53A)
        case .low: return Color(light: 0x2D7A4F, dark: 0x5BC48A)
        case .undetermined: return Color(light: 0x7D8391, dark: 0x8D93A1)
        case .noFinding: return Color(light: 0x3F6E8C, dark: 0x7FB0CF)
        }
    }

    var uiHex: UInt {
        switch self {
        case .critical: return 0xC0262D
        case .high: return 0xC4510F
        case .moderate: return 0xB27A00
        case .low: return 0x2D7A4F
        case .undetermined: return 0x7D8391
        case .noFinding: return 0x3F6E8C
        }
    }

    var innerSymbol: String {
        switch self {
        case .critical, .high: return "exclamationmark"
        case .moderate: return "minus"
        case .low: return "arrow.down"
        case .undetermined: return "questionmark"
        case .noFinding: return "checkmark"
        }
    }
}

/// Distinct silhouette per risk level so meaning never depends on colour alone.
struct RiskShape: Shape {
    let level: RiskLevel

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        switch level {
        case .critical:
            // Octagon
            let r = min(w, h) / 2
            for i in 0..<8 {
                let a = (CGFloat(i) * 45 + 22.5) * CGFloat.pi / 180
                let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        case .high:
            // Rounded triangle
            p.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.04))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - h * 0.06))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.06))
            p.closeSubpath()
        case .moderate:
            // Diamond
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        case .low:
            p.addEllipse(in: rect.insetBy(dx: w * 0.04, dy: h * 0.04))
        case .undetermined:
            p.addEllipse(in: rect.insetBy(dx: w * 0.06, dy: h * 0.06))
        case .noFinding:
            // Rounded square / seal
            p.addRoundedRect(in: rect.insetBy(dx: w * 0.06, dy: h * 0.06), cornerSize: CGSize(width: w * 0.3, height: h * 0.3), style: .continuous)
        }
        return p
    }
}

struct RiskGlyph: View {
    let level: RiskLevel
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            if level == .undetermined {
                RiskShape(level: level)
                    .stroke(level.color, style: StrokeStyle(lineWidth: max(1.5, size * 0.09), dash: [size * 0.16, size * 0.1]))
            } else {
                RiskShape(level: level)
                    .fill(level.color.gradient)
            }
            Image(systemName: level.innerSymbol)
                .font(.system(size: size * (level == .high ? 0.38 : 0.44), weight: .heavy))
                .foregroundStyle(level == .undetermined ? level.color : .white)
                .offset(y: level == .high ? size * 0.1 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(L("Risk: \(level.title)", "الخطورة: \(level.title)"))
    }
}

/// Glyph + name + suggested / approved state.
struct RiskBadge: View {
    let level: RiskLevel
    var approved: Bool? = nil
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            RiskGlyph(level: level, size: compact ? 14 : 17)
            Text(level.title)
                .font(compact ? .trCaptionBold : .trFootnote.bold())
                .foregroundStyle(level.color)
            if let approved {
                Text(approved ? L("Approved", "معتمدة") : L("Suggested", "مقترحة"))
                    .font(.trMicro)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().strokeBorder(level.color.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: approved ? [] : [3, 2])))
                    .foregroundStyle(level.color)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(Capsule().fill(level.color.opacity(0.11)))
    }
}

/// Persistent, calm banner for critical findings pending review — no flashing.
struct CriticalBanner: View {
    let text: String
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            RiskGlyph(level: .critical, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Critical — awaiting review", "حرجة — بانتظار المراجعة"))
                    .font(.trBodyBold)
                    .foregroundStyle(.white)
                Text(text)
                    .font(.trCaption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let action {
                Button(action: action) {
                    Text(L("Review", "مراجعة"))
                        .font(.trCaptionBold)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(.white))
                        .foregroundStyle(RiskLevel.critical.color)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xA51C24), Color(hex: 0x7A1218)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: Color(hex: 0xA51C24).opacity(0.3), radius: 14, y: 6)
    }
}
