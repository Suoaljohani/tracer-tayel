import SwiftUI
import UIKit

// MARK: - Motion

enum Motion {
    /// Signature spring: unhurried, settles without bounce.
    static let luxe = Animation.spring(response: 0.55, dampingFraction: 0.88)
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Department identity cross-fade (~250ms per spec).
    static let theme = Animation.easeInOut(duration: 0.25)
    static let reveal = Animation.spring(response: 0.7, dampingFraction: 0.9)
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Surfaces

struct LuxCard: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 22
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint?.opacity(0.06) ?? .clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.hairline.opacity(0.9), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func luxCard(padding: CGFloat = 18, radius: CGFloat = 22, tint: Color? = nil) -> some View {
        modifier(LuxCard(padding: padding, radius: radius, tint: tint))
    }
}

/// Quiet ambient backdrop with slowly drifting light. Static when Reduce Motion is on.
struct AmbientBackground: View {
    var accent: Color = Palette.gold
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                let o1 = CGPoint(x: size.width * (0.2 + 0.08 * sin(t / 9)), y: size.height * (0.08 + 0.04 * cos(t / 11)))
                let o2 = CGPoint(x: size.width * (0.9 + 0.06 * cos(t / 13)), y: size.height * (0.35 + 0.05 * sin(t / 10)))
                let r = max(size.width, 320) * 0.9
                gc.addFilter(.blur(radius: 60))
                gc.fill(Path(ellipseIn: CGRect(x: o1.x - r / 2, y: o1.y - r / 2, width: r, height: r)),
                        with: .color(accent.opacity(scheme == .dark ? 0.16 : 0.10)))
                gc.fill(Path(ellipseIn: CGRect(x: o2.x - r / 3, y: o2.y - r / 3, width: r * 0.66, height: r * 0.66)),
                        with: .color(Color(hex: 0x365A9A).opacity(scheme == .dark ? 0.14 : 0.06)))
            }
        }
        .background(Palette.canvas)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Buttons

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

struct GoldButtonStyle: ButtonStyle {
    var fill: Color? = nil
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.trBodyBold)
            .foregroundStyle(fill == nil ? Palette.obsidian : .white)
            .padding(.horizontal, 22)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if let fill {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill.gradient)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.goldGradient)
                    }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 0.75))
            .shadow(color: (fill ?? Palette.gold).opacity(0.28), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(enabled ? 1 : 0.45)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Palette.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.trCallout.bold())
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.14), lineWidth: 0.75))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

struct CircleIconButton: View {
    let symbol: String
    var tint: Color = Palette.ink
    var background: Color = Palette.surface
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 0.75))
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }
}

// MARK: - Medallions

struct DeptMedallion: View {
    let department: Department
    var size: CGFloat = 44
    var onDark: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [department.color, department.deep], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Image(systemName: department.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: department.color.opacity(onDark ? 0 : 0.35), radius: size * 0.22, y: size * 0.1)
        .accessibilityLabel(department.name)
    }
}

struct TopicMedallion: View {
    let symbol: String
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            Circle().fill(Palette.obsidian)
            Circle().fill(RadialGradient(colors: [Palette.night, Palette.obsidian], center: .topLeading, startRadius: 2, endRadius: size))
            Circle().strokeBorder(Palette.goldGradient, lineWidth: 1.2)
            Circle().strokeBorder(Palette.gold.opacity(0.25), lineWidth: 0.6).padding(size * 0.1)
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .regular))
                .foregroundStyle(Palette.goldGradient)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}

// MARK: - Small pieces

struct Chip: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = Palette.inkSecondary
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
            Text(text).font(.trCaptionBold).lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(filled ? .white : tint)
        .background(Capsule().fill(filled ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.1))))
    }
}

struct SectionTitle: View {
    let eyebrow: String?
    let title: String
    var trailing: AnyView? = nil

    init(_ title: String, eyebrow: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.eyebrow = eyebrow
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow { Eyebrow(text: eyebrow) }
                Text(title).font(.trTitle2).foregroundStyle(Palette.ink)
            }
            Spacer()
            trailing
        }
    }
}

struct GoldDivider: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Palette.gold.opacity(0), Palette.gold.opacity(0.6), Palette.gold.opacity(0)], startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.75)
    }
}

enum SaveState: Equatable {
    case saved(Date), saving, unsynced, failed

    var title: String {
        switch self {
        case .saved: return L("Saved on device", "محفوظ على الجهاز")
        case .saving: return L("Saving…", "جارٍ الحفظ…")
        case .unsynced: return L("Not saved yet", "لم يُحفظ بعد")
        case .failed: return L("Save failed", "تعذر الحفظ")
        }
    }
    var symbol: String {
        switch self {
        case .saved: return "checkmark.icloud"
        case .saving: return "arrow.triangle.2.circlepath"
        case .unsynced: return "icloud.slash"
        case .failed: return "exclamationmark.icloud"
        }
    }
}

struct SaveIndicator: View {
    let state: SaveState
    var onDark: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.symbol)
                .font(.system(size: 11, weight: .semibold))
                .symbolEffect(.pulse, isActive: state == .saving)
            Text(state.title).font(.trMicro)
        }
        .foregroundStyle(onDark ? .white.opacity(0.8) : Palette.inkSecondary)
        .contentTransition(.opacity)
        .animation(Motion.snappy, value: state)
    }
}

struct StatTile: View {
    let value: Int
    let label: String
    let symbol: String
    var tint: Color = Palette.gold

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(tint.opacity(0.12)))
                Spacer()
            }
            Text("\(value)")
                .font(.trNumber)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.trCaption)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 128, alignment: .leading)
        .luxCard(padding: 14, radius: 20)
    }
}

/// Labelled multi-line field in house style.
struct FieldBlock<Content: View>: View {
    let label: String
    var symbol: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.gold) }
                Eyebrow(text: label, color: Palette.inkSecondary)
            }
            content
        }
    }
}

struct InputBox: ViewModifier {
    var focused: Bool = false
    func body(content: Content) -> some View {
        content
            .font(.trBody)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(focused ? Palette.gold : Palette.hairline, lineWidth: focused ? 1.2 : 0.75))
    }
}

extension View {
    func inputBox(focused: Bool = false) -> some View { modifier(InputBox(focused: focused)) }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().strokeBorder(Palette.gold.opacity(0.35), lineWidth: 0.75).frame(width: 84, height: 84)
                Circle().strokeBorder(Palette.gold.opacity(0.18), lineWidth: 0.75).frame(width: 112, height: 112)
                Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(Palette.goldGradient)
            }
            Text(title).font(.trHeadline).foregroundStyle(Palette.ink)
            Text(message).font(.trSubhead).foregroundStyle(Palette.inkSecondary).multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }
}

extension Date {
    var relativeText: String {
        let f = RelativeDateTimeFormatter()
        f.locale = AppSettings.shared.language.locale
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: .now)
    }

    func formatted(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style = .none) -> String {
        let f = DateFormatter()
        f.locale = AppSettings.shared.language.locale
        f.dateStyle = dateStyle
        f.timeStyle = timeStyle
        return f.string(from: self)
    }
}
