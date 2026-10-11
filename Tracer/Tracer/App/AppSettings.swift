import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }
    var isRTL: Bool { self == .arabic }
    var locale: Locale { Locale(identifier: self == .arabic ? "ar_SA@numbers=latn" : "en_US") }
    var displayName: String { self == .arabic ? "العربية" : "English" }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var title: String {
        switch self {
        case .system: return L("Automatic", "تلقائي")
        case .light: return L("Light", "فاتح")
        case .dark: return L("Dark", "داكن")
        }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "lang") }
    }
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }
    var organization: String {
        didSet { defaults.set(organization, forKey: "organization") }
    }
    var evaluatorName: String {
        didSet { defaults.set(evaluatorName, forKey: "evaluator") }
    }
    var defaultTeam: String {
        didSet { defaults.set(defaultTeam, forKey: "team") }
    }
    var hasSeeded: Bool {
        didSet { defaults.set(hasSeeded, forKey: "seeded.v1") }
    }

    private init() {
        language = AppLanguage(rawValue: defaults.string(forKey: "lang") ?? "ar") ?? .arabic
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "system") ?? .system
        organization = defaults.string(forKey: "organization") ?? ""
        evaluatorName = defaults.string(forKey: "evaluator") ?? ""
        defaultTeam = defaults.string(forKey: "team") ?? ""
        hasSeeded = defaults.bool(forKey: "seeded.v1")
    }
}

/// Bilingual string helper. Reading the language through the observable settings
/// makes every view that calls it refresh when the language changes.
func L(_ en: String, _ ar: String) -> String {
    AppSettings.shared.language == .arabic ? ar : en
}

var isArabic: Bool { AppSettings.shared.language == .arabic }
