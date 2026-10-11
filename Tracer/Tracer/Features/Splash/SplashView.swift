import SwiftUI

/// The trace monogram: a crossbar of two stations, a path descending to the destination ring.
struct BrandMarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let ox = rect.midX - s / 2, oy = rect.midY - s / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var path = Path()
        path.move(to: p(0.12, 0.2))
        path.addLine(to: p(0.88, 0.2))
        path.move(to: p(0.5, 0.2))
        path.addCurve(to: p(0.5, 0.72), control1: p(0.66, 0.36), control2: p(0.34, 0.56))
        return path
    }
}

struct BrandMark: View {
    var size: CGFloat = 120
    var progress: CGFloat = 1
    var lineWidth: CGFloat? = nil

    var body: some View {
        let lw = lineWidth ?? max(2, size * 0.045)
        ZStack {
            BrandMarkPath()
                .trim(from: 0, to: progress)
                .stroke(Palette.goldGradient, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            // Stations
            Group {
                Circle().fill(Palette.goldGradient).frame(width: size * 0.11).position(x: size * 0.12, y: size * 0.2)
                Circle().fill(Palette.goldGradient).frame(width: size * 0.11).position(x: size * 0.88, y: size * 0.2)
                Circle().fill(Palette.goldGradient).frame(width: size * 0.08).position(x: size * 0.5, y: size * 0.2)
            }
            .opacity(progress > 0.15 ? 1 : 0)
            .scaleEffect(progress > 0.15 ? 1 : 0.2)
            // Destination
            ZStack {
                Circle().fill(Palette.goldGradient).frame(width: size * 0.13)
                Circle().strokeBorder(Palette.goldGradient, lineWidth: lw * 0.8).frame(width: size * 0.26)
                Circle().strokeBorder(Palette.gold.opacity(0.35), lineWidth: lw * 0.35).frame(width: size * 0.4)
            }
            .position(x: size * 0.5, y: size * 0.78)
            .opacity(progress > 0.95 ? 1 : 0)
            .scaleEffect(progress > 0.95 ? 1 : 0.4)
        }
        .frame(width: size, height: size)
    }
}

struct SplashView: View {
    var onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var progress: CGFloat = 0
    @State private var wordmark = false
    @State private var tagline = false
    @State private var glow = false

    var body: some View {
        ZStack {
            Palette.obsidian.ignoresSafeArea()
            RadialGradient(colors: [Palette.night.opacity(glow ? 0.9 : 0.4), .clear], center: .center, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                BrandMark(size: 132, progress: progress)
                    .shadow(color: Palette.gold.opacity(glow ? 0.45 : 0), radius: 24)
                VStack(spacing: 10) {
                    Text("TRACER")
                        .font(.system(size: 30, weight: .light, design: .serif))
                        .tracking(wordmark ? 12 : 2)
                        .foregroundStyle(Palette.goldGradient)
                        .opacity(wordmark ? 1 : 0)
                    Text(L("INTELLIGENCE", "ذكاء التتبع"))
                        .font(.janna(12, bold: true))
                        .tracking(isArabic ? 0 : 5)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .opacity(tagline ? 1 : 0)
                        .offset(y: tagline ? 0 : 6)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .task {
            if reduceMotion {
                progress = 1; wordmark = true; tagline = true
                try? await Task.sleep(for: .milliseconds(500))
                onFinish()
                return
            }
            withAnimation(.easeInOut(duration: 1.1)) { progress = 1 }
            withAnimation(.easeInOut(duration: 1.4)) { glow = true }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.spring(response: 1.1, dampingFraction: 0.9)) { wordmark = true }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.6)) { tagline = true }
            try? await Task.sleep(for: .milliseconds(900))
            Haptics.soft()
            onFinish()
        }
    }
}
