import SwiftUI
import SwiftData
import Observation

/// Visual identity of a department. The workspace theme is derived from these
/// variables rather than designed per department.
struct Department: Identifiable, Hashable {
    let code: String
    let nameEN: String
    let nameAR: String
    let symbol: String
    let primaryHex: UInt
    let backgroundHex: UInt
    var isCustom: Bool = false

    var id: String { code }
    var name: String { isArabic ? nameAR : nameEN }
    var englishName: String { nameEN }

    var color: Color { Color(hex: primaryHex) }
    /// Soft tinted surface: the light background in light mode, a deep tinted tone in dark mode.
    var wash: Color { Color(light: backgroundHex, dark: Department.mix(primaryHex, 0x080B12, 0.18)) }
    /// Deep variant for hero headers.
    var deep: Color { Color(hex: Department.mix(primaryHex, 0x05070C, 0.55)) }
    var bright: Color { Color(hex: Department.mix(primaryHex, 0xFFFFFF, 0.78)) }

    static func mix(_ a: UInt, _ b: UInt, _ amountOfA: Double) -> UInt {
        func ch(_ v: UInt, _ s: UInt) -> Double { Double((v >> s) & 0xFF) }
        func blend(_ s: UInt) -> UInt { UInt((ch(a, s) * amountOfA + ch(b, s) * (1 - amountOfA)).rounded()) }
        return (blend(16) << 16) | (blend(8) << 8) | blend(0)
    }

    static let builtIn: [Department] = [
        Department(code: "ER", nameEN: "Emergency", nameAR: "الطوارئ", symbol: "staroflife.fill", primaryHex: 0x0D5E78, backgroundHex: 0xEAF4F7),
        Department(code: "LAB", nameEN: "Laboratory", nameAR: "المختبر", symbol: "testtube.2", primaryHex: 0x6753A5, backgroundHex: 0xF2F0FB),
        Department(code: "PHA", nameEN: "Pharmacy", nameAR: "الصيدلية", symbol: "pills.fill", primaryHex: 0x246E5D, backgroundHex: 0xEAF6F2),
        Department(code: "IPD", nameEN: "Inpatient Ward", nameAR: "التنويم", symbol: "bed.double.fill", primaryHex: 0x365A9A, backgroundHex: 0xEEF3FC),
        Department(code: "ICU", nameEN: "Intensive Care", nameAR: "العناية المركزة", symbol: "waveform.path.ecg", primaryHex: 0x8C3B4A, backgroundHex: 0xFAEFF1),
        Department(code: "OR", nameEN: "Operating Room", nameAR: "غرف العمليات", symbol: "scissors", primaryHex: 0x2F5D6E, backgroundHex: 0xEBF3F5),
        Department(code: "RAD", nameEN: "Radiology", nameAR: "الأشعة", symbol: "rays", primaryHex: 0x4A4E8F, backgroundHex: 0xF0F0FA),
        Department(code: "OPD", nameEN: "Outpatient Clinics", nameAR: "العيادات الخارجية", symbol: "stethoscope", primaryHex: 0x2E7D8C, backgroundHex: 0xEBF6F8),
        Department(code: "IPC", nameEN: "Infection Control", nameAR: "مكافحة العدوى", symbol: "shield.lefthalf.filled", primaryHex: 0x56752B, backgroundHex: 0xF2F7EA),
        Department(code: "BLD", nameEN: "Blood Bank", nameAR: "بنك الدم", symbol: "drop.fill", primaryHex: 0x9E3535, backgroundHex: 0xFBEEEE),
        Department(code: "NUR", nameEN: "Nursing Administration", nameAR: "إدارة التمريض", symbol: "person.2.fill", primaryHex: 0x6E4A82, backgroundHex: 0xF6F0F9),
        Department(code: "HIM", nameEN: "Medical Records", nameAR: "السجلات الطبية", symbol: "folder.fill", primaryHex: 0x50586A, backgroundHex: 0xF2F3F5),
        Department(code: "QM", nameEN: "Quality & Patient Safety", nameAR: "الجودة وسلامة المرضى", symbol: "rosette", primaryHex: 0x8A6A38, backgroundHex: 0xF8F3EA),
        Department(code: "FMS", nameEN: "Facility & Safety", nameAR: "المرافق والسلامة", symbol: "building.2.fill", primaryHex: 0x91562B, backgroundHex: 0xFAF1EA),
    ]

    static let unknown = Department(code: "?", nameEN: "Department", nameAR: "قسم", symbol: "square.dashed", primaryHex: 0x50586A, backgroundHex: 0xF2F3F5)

    static let customPalette: [UInt] = [0x1F6F8B, 0x7B4FA0, 0x2C7A5B, 0xA0522D, 0x3F51B5, 0x8E2C48, 0x00796B, 0x5D6D2B, 0x6D4C41, 0x37474F]
    static let customSymbols: [String] = [
        "cross.case.fill", "heart.text.square.fill", "brain.head.profile", "lungs.fill", "figure.and.child.holdinghands",
        "syringe.fill", "bandage.fill", "ear.fill", "eye.fill", "fork.knife", "washer.fill", "bolt.heart.fill",
        "building.columns.fill", "person.badge.shield.checkmark.fill", "shippingbox.fill", "wrench.and.screwdriver.fill",
    ]
}

@Observable
final class DepartmentStore {
    static let shared = DepartmentStore()
    private(set) var all: [Department] = Department.builtIn

    func refresh(_ context: ModelContext) {
        let customs = (try? context.fetch(FetchDescriptor<CustomDepartment>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        all = Department.builtIn + customs.map {
            Department(code: $0.code, nameEN: $0.nameEN, nameAR: $0.nameAR, symbol: $0.symbol,
                       primaryHex: UInt($0.colorHex), backgroundHex: Department.mix(UInt($0.colorHex), 0xFFFFFF, 0.09), isCustom: true)
        }
    }

    func department(_ code: String?) -> Department {
        guard let code else { return .unknown }
        return all.first { $0.code == code } ?? .unknown
    }
}

func dept(_ code: String?) -> Department { DepartmentStore.shared.department(code) }
