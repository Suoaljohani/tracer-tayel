import SwiftUI
import UIKit
import CoreText

enum Typography {
    static let regularName = "JannaLT-Regular"
    static let boldName = "JannaLT-Bold"

    /// Fonts are declared in Info.plist; this is a safety net for previews and tests.
    static func registerIfNeeded() {
        guard UIFont(name: regularName, size: 12) == nil else { return }
        for file in ["JannaLT-Regular", "JannaLT-Bold"] {
            if let url = Bundle.main.url(forResource: file, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    static func uiFont(_ size: CGFloat, bold: Bool = false) -> UIFont {
        UIFont(name: bold ? boldName : regularName, size: size)
            ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }
}

extension Font {
    static func janna(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bold ? Typography.boldName : Typography.regularName, size: size, relativeTo: style)
    }

    static let trHero = janna(34, bold: true, relativeTo: .largeTitle)
    static let trTitle = janna(24, bold: true, relativeTo: .title)
    static let trTitle2 = janna(20, bold: true, relativeTo: .title2)
    static let trHeadline = janna(17, bold: true, relativeTo: .headline)
    static let trBody = janna(16, relativeTo: .body)
    static let trBodyBold = janna(16, bold: true, relativeTo: .body)
    static let trCallout = janna(15, relativeTo: .callout)
    static let trSubhead = janna(14, relativeTo: .subheadline)
    static let trFootnote = janna(13, relativeTo: .footnote)
    static let trCaption = janna(12, relativeTo: .caption)
    static let trCaptionBold = janna(12, bold: true, relativeTo: .caption)
    static let trMicro = janna(10.5, bold: true, relativeTo: .caption2)
    static let trNumber = Font.system(size: 30, weight: .light, design: .serif)
    static let trNumberSmall = Font.system(size: 20, weight: .regular, design: .serif)
}

/// Small uppercase eyebrow label used across the house style.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.gold
    var body: some View {
        Text(isArabic ? text : text.uppercased())
            .font(.trMicro)
            .tracking(isArabic ? 0 : 1.6)
            .foregroundStyle(color)
    }
}
