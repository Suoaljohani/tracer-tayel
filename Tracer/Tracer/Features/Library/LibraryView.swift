import SwiftUI

struct StandardRow: View {
    let standard: Standard
    var compact: Bool = false
    var selected: Bool? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(standard.chapter)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.obsidian)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Palette.goldGradient))
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(standard.id)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.gold)
                Text(standard.statement)
                    .font(compact ? .trFootnote : .trCallout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(compact ? 3 : 5)
                    .multilineTextAlignment(.leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !compact {
                    Text("\(standard.elements.count) " + L("measurable elements", "عناصر قابلة للقياس"))
                        .font(.trCaption)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            if let selected {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Palette.gold : Palette.hairline)
            }
        }
        .padding(compact ? 12 : 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected == true ? Palette.gold : Palette.hairline, lineWidth: selected == true ? 1.2 : 0.75))
    }
}

struct StandardDetailView: View {
    let standard: Standard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: StandardsLibrary.manualTitle(standard.manual))
                        Text(standard.id).font(.system(size: 28, weight: .light, design: .serif)).foregroundStyle(Palette.ink)
                        Text(standard.chapterTitle).font(.trFootnote).foregroundStyle(Palette.inkSecondary)
                        if !standard.group.isEmpty {
                            Text(standard.group).font(.trCaption).foregroundStyle(Palette.inkTertiary)
                        }
                    }
                    GoldDivider()
                    Text(standard.statement)
                        .font(.trHeadline)
                        .foregroundStyle(Palette.ink)
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: L("Measurable elements", "العناصر القابلة للقياس"), color: Palette.inkSecondary)
                        ForEach(Array(standard.elements.enumerated()), id: \.offset) { i, e in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .semibold, design: .serif))
                                    .foregroundStyle(Palette.gold)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().strokeBorder(Palette.gold.opacity(0.5), lineWidth: 0.75))
                                Text(e)
                                    .font(.trCallout)
                                    .foregroundStyle(Palette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .luxCard()
                    Text(L("Source: Saudi Health Holding Company Integrated Cluster Care Standards (2025).", "المصدر: معايير الرعاية المتكاملة للتجمعات الصحية — الشركة القابضة للصحة (٢٠٢٥)."))
                        .font(.trCaption).foregroundStyle(Palette.inkTertiary)
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Done", "تم")) { dismiss() } }
            }
        }
    }
}

struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manual = StandardsLibrary.hospitalManual
    @State private var query = ""
    @State private var detail: Standard?

    private var results: [Standard] {
        let lib = StandardsLibrary.shared
        if query.trimmingCharacters(in: .whitespaces).isEmpty { return lib.inManual(manual) }
        return lib.search(query, manual: manual, limit: 60)
    }

    private struct ChapterGroup: Identifiable {
        let chapter: String
        let items: [Standard]
        var id: String { chapter }
    }

    private var grouped: [ChapterGroup] {
        var order: [String] = []
        var dict: [String: [Standard]] = [:]
        for s in results {
            if dict[s.chapter] == nil { order.append(s.chapter) }
            dict[s.chapter, default: []].append(s)
        }
        return order.map { ChapterGroup(chapter: $0, items: dict[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        CircleIconButton(symbol: isArabic ? "chevron.right" : "chevron.left") { dismiss() }
                        Spacer()
                    }
                    Eyebrow(text: L("Reference library", "المكتبة المرجعية"))
                    Text(L("Standards", "المعايير")).font(.trHero).foregroundStyle(Palette.ink)
                    Text(L("\(StandardsLibrary.shared.all.count) standards across \(StandardsLibrary.shared.manuals.count) manuals", "\(StandardsLibrary.shared.all.count) معيارًا في \(StandardsLibrary.shared.manuals.count) أدلة"))
                        .font(.trSubhead).foregroundStyle(Palette.inkSecondary)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(StandardsLibrary.shared.manuals, id: \.self) { m in
                                Button {
                                    Haptics.selection(); withAnimation(Motion.snappy) { manual = m }
                                } label: {
                                    Text(StandardsLibrary.manualTitle(m))
                                        .font(.trFootnote.bold())
                                        .padding(.horizontal, 14).frame(height: 36)
                                        .foregroundStyle(manual == m ? Palette.obsidian : Palette.inkSecondary)
                                        .background(Capsule().fill(manual == m ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.surface)))
                                        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.75))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkTertiary)
                        TextField(L("Search: critical results, IPSG.02, hand hygiene…", "ابحث: نتائج حرجة، IPSG.02، نظافة الأيدي…"), text: $query)
                            .font(.trBody)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.75))
                }

                ForEach(grouped) { group in
                    let chapter = group.chapter
                    let items = group.items
                    Section {
                        ForEach(items) { s in
                            Button { detail = s } label: { StandardRow(standard: s) }
                                .buttonStyle(PressableStyle(scale: 0.985))
                        }
                    } header: {
                        HStack {
                            Text(chapter).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Palette.gold)
                            Text(StandardsLibrary.chapterNames[chapter] ?? "").font(.trCaptionBold).foregroundStyle(Palette.inkSecondary).lineLimit(1)
                            Spacer()
                            Text("\(items.count)").font(.trCaption).foregroundStyle(Palette.inkTertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(Palette.canvas.opacity(0.96))
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AmbientBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detail) { StandardDetailView(standard: $0) }
    }
}

/// Multi-select picker for linking standards to a topic or question.
struct StandardPickerView: View {
    @Binding var selection: [String]
    var seedQuery: String = ""

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var manual = StandardsLibrary.hospitalManual
    @State private var detail: Standard?

    private var results: [Standard] {
        StandardsLibrary.shared.search(query.isEmpty ? seedQuery : query, manual: manual, limit: 60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if !selection.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(selection, id: \.self) { key in
                                Button {
                                    withAnimation(Motion.snappy) { selection.removeAll { $0 == key } }
                                } label: {
                                    Chip(text: StandardsLibrary.shared.standard(key)?.id ?? key, symbol: "xmark", tint: Palette.gold, filled: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Picker("", selection: $manual) {
                        ForEach(StandardsLibrary.shared.manuals, id: \.self) { Text(StandardsLibrary.manualTitle($0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(results) { s in
                        let on = selection.contains(s.key)
                        StandardRow(standard: s, compact: true, selected: on)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.selection()
                                withAnimation(Motion.snappy) {
                                    if on { selection.removeAll { $0 == s.key } } else { selection.append(s.key) }
                                }
                            }
                            .onLongPressGesture { detail = s }
                    }
                }
                .padding(20)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L("Search standards", "ابحث في المعايير"))
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Link standards", "ربط المعايير"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Done", "تم")) { dismiss() } }
            }
            .sheet(item: $detail) { StandardDetailView(standard: $0) }
        }
    }
}
