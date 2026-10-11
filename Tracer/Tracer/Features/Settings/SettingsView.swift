import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showAddDept = false

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    CircleIconButton(symbol: isArabic ? "chevron.right" : "chevron.left") { dismiss() }
                    Spacer()
                }
                Eyebrow(text: L("Preferences", "التفضيلات"))
                Text(L("Settings", "الإعدادات")).font(.trHero).foregroundStyle(Palette.ink)

                group(L("Language", "اللغة"), symbol: "globe") {
                    HStack(spacing: 8) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button {
                                Haptics.selection()
                                withAnimation(Motion.luxe) { settings.language = lang }
                            } label: {
                                Text(lang.displayName)
                                    .font(.trBodyBold)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .foregroundStyle(settings.language == lang ? Palette.obsidian : Palette.ink)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(settings.language == lang ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.surfaceRaised)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                group(L("Appearance", "المظهر"), symbol: "circle.lefthalf.filled") {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                group(L("Evaluator profile", "ملف المقيِّم"), symbol: "person.badge.shield.checkmark") {
                    VStack(spacing: 12) {
                        TextField(L("Your name", "اسمك"), text: $settings.evaluatorName).inputBox()
                        TextField(L("Organization", "المنشأة"), text: $settings.organization).inputBox()
                        TextField(L("Default tracer team", "فريق التتبع الافتراضي"), text: $settings.defaultTeam).inputBox()
                    }
                }

                group(L("Departments", "الأقسام"), symbol: "building.2") {
                    VStack(alignment: .leading, spacing: 12) {
                        FlowLayout(spacing: 8) {
                            ForEach(DepartmentStore.shared.all) { d in
                                HStack(spacing: 6) {
                                    Image(systemName: d.symbol).font(.system(size: 11, weight: .semibold))
                                    Text(d.name).font(.trCaptionBold)
                                    if d.isCustom {
                                        Button {
                                            if let c = try? context.fetch(FetchDescriptor<CustomDepartment>()).first(where: { $0.code == d.code }) {
                                                context.delete(c)
                                                try? context.save()
                                                DepartmentStore.shared.refresh(context)
                                            }
                                        } label: { Image(systemName: "xmark.circle.fill") }
                                    }
                                }
                                .padding(.horizontal, 10).frame(height: 30)
                                .foregroundStyle(.white)
                                .background(Capsule().fill(d.color.gradient))
                            }
                        }
                        Button { showAddDept = true } label: {
                            Label(L("Add department", "إضافة قسم"), systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GhostButtonStyle(tint: Palette.gold))
                    }
                }

                group(L("Privacy & data", "الخصوصية والبيانات"), symbol: "lock.shield") {
                    VStack(alignment: .leading, spacing: 8) {
                        bullet(L("All topics, sessions, answers and evidence are stored only on this iPhone.", "تُحفظ جميع المواضيع والجلسات والإجابات والأدلة على هذا الجهاز فقط."))
                        bullet(L("Only the question, the verbatim answer and the selected standards are sent for analysis — never patient record numbers, photos or files.", "يُرسل للتحليل السؤال والإجابة كما هي والمعايير المختارة فقط — دون أرقام ملفات المرضى أو الصور أو الملفات."))
                        bullet(L("Avoid entering patient-identifying details in answers.", "تجنّب إدخال بيانات تعريفية للمرضى في الإجابات."))
                    }
                }

                group(L("Reference", "المرجع"), symbol: "books.vertical") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Saudi Health Holding Company — Integrated Cluster Care Standards (effective 1 Aug 2025).", "الشركة القابضة للصحة — معايير الرعاية المتكاملة للتجمعات (سارية من ١ أغسطس ٢٠٢٥)."))
                            .font(.trCallout).foregroundStyle(Palette.ink)
                        Text(L("\(StandardsLibrary.shared.all.count) standards bundled for offline use.", "\(StandardsLibrary.shared.all.count) معيارًا متاحة دون اتصال."))
                            .font(.trCaption).foregroundStyle(Palette.inkSecondary)
                    }
                }

                VStack(spacing: 6) {
                    BrandMark(size: 40, lineWidth: 2).environment(\.layoutDirection, .leftToRight)
                    Text("TRACER INTELLIGENCE").font(.system(size: 11, weight: .regular, design: .serif)).tracking(3).foregroundStyle(Palette.gold)
                    Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")").font(.trMicro).foregroundStyle(Palette.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AmbientBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddDept) { AddDepartmentSheet() }
    }

    private func group<C: View>(_ title: String, symbol: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.trHeadline).foregroundStyle(Palette.ink)
            content()
        }
        .luxCard()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Palette.gold).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).font(.trSubhead).foregroundStyle(Palette.inkSecondary)
        }
    }
}

struct AddDepartmentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var nameEN = ""
    @State private var nameAR = ""
    @State private var code = ""
    @State private var symbol = Department.customSymbols[0]
    @State private var color = Department.customPalette[0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let preview = Department(code: code, nameEN: nameEN.isEmpty ? "Department" : nameEN, nameAR: nameAR.isEmpty ? "قسم" : nameAR, symbol: symbol, primaryHex: color, backgroundHex: Department.mix(color, 0xFFFFFF, 0.09))
                    HStack(spacing: 14) {
                        DeptMedallion(department: preview, size: 60)
                        Text(preview.name).font(.trTitle2).foregroundStyle(preview.color)
                    }
                    TextField(L("Name (English)", "الاسم (إنجليزي)"), text: $nameEN).inputBox()
                    TextField(L("Name (Arabic)", "الاسم (عربي)"), text: $nameAR).inputBox()
                    TextField(L("Short code (e.g. NICU)", "رمز مختصر (مثل NICU)"), text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled().inputBox()
                    Eyebrow(text: L("Colour", "اللون"), color: Palette.inkSecondary)
                    FlowLayout(spacing: 10) {
                        ForEach(Department.customPalette, id: \.self) { c in
                            Circle().fill(Color(hex: c)).frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(Palette.gold, lineWidth: color == c ? 2.5 : 0).padding(-4))
                                .onTapGesture { Haptics.selection(); color = c }
                        }
                    }
                    Eyebrow(text: L("Icon", "الأيقونة"), color: Palette.inkSecondary)
                    FlowLayout(spacing: 10) {
                        ForEach(Department.customSymbols, id: \.self) { s in
                            Image(systemName: s).font(.system(size: 17))
                                .frame(width: 42, height: 42)
                                .foregroundStyle(symbol == s ? .white : Color(hex: color))
                                .background(Circle().fill(symbol == s ? Color(hex: color) : Color(hex: color).opacity(0.1)))
                                .onTapGesture { Haptics.selection(); symbol = s }
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("New department", "قسم جديد"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Add", "إضافة")) {
                        let c = code.uppercased().trimmingCharacters(in: .whitespaces)
                        context.insert(CustomDepartment(code: c, nameEN: nameEN, nameAR: nameAR.isEmpty ? nameEN : nameAR, symbol: symbol, colorHex: Int(color)))
                        try? context.save()
                        DepartmentStore.shared.refresh(context)
                        dismiss()
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || nameEN.isEmpty || DepartmentStore.shared.all.contains { $0.code == code.uppercased() })
                }
            }
        }
    }
}
