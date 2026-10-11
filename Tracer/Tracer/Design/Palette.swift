import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }

    /// Adaptive colour for light / dark appearance.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// The house palette: obsidian, ivory and champagne gold.
enum Palette {
    static let gold = Color(light: 0xA88850, dark: 0xC9A96E)
    static let goldBright = Color(hex: 0xE8D3A2)
    static let goldDeep = Color(hex: 0x8A6A38)

    static let canvas = Color(light: 0xF6F3EE, dark: 0x080B12)
    static let surface = Color(light: 0xFFFFFF, dark: 0x111622)
    static let surfaceRaised = Color(light: 0xFBF9F5, dark: 0x171D2B)
    static let hairline = Color(light: 0xE4DDD0, dark: 0x262D3D)

    static let ink = Color(light: 0x121620, dark: 0xF3EEE4)
    static let inkSecondary = Color(light: 0x5B6170, dark: 0xA6ABB8)
    static let inkTertiary = Color(light: 0x9097A3, dark: 0x6B7283)

    static let obsidian = Color(hex: 0x0B0F17)
    static let night = Color(hex: 0x18243C)

    static var goldGradient: LinearGradient {
        LinearGradient(colors: [goldBright, Color(hex: 0xC9A96E), goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
