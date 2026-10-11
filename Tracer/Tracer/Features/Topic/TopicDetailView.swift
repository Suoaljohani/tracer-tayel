import SwiftUI
import SwiftData

struct TopicDetailView: View {
    let topicID: UUID
    let zoom: Namespace.ID

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Query private var topics: [TraceTopic]

    @State private var showEditor = false
    @State private var showStart = false
    @State private var confirmDelete = false
    @State private var appeared = false

    init(topicID: UUID, zoom: Namespace.ID) {
        self.topicID = topicID
        self.zoom = zoom
        _topics = Query(filter: #Predicate<TraceTopic> { $0.id == topicID })
    }

    var body: some View {
        if let topic = topics.first {
            content(topic)
        } else {
            EmptyState(symbol: "questionmark.folder", title: L("Topic not found", "الموضوع غير موجود"), message: "")
        }
    }

    private func content(_ topic: TraceTopic) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero(topic)
                VStack(alignment: .leading, spacing: 24) {
                    Button {
                        Haptics.tap(); showStart = true
                    } label: {
                        Label(L("Start a new session", "بدء جلسة جديدة"), systemImage: "play.fill")
                    }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(topic.archived)

                    sessionsSection(topic)
                    questionsSection(topic)
                    referencesSection(topic)
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground())
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditor) { TopicEditorView(topic: topic) }
        .sheet(isPresented: $showStart) {
            StartSessionSheet(preselected: topic) { s in router.openSession(s.id) }
        }
        .confirmationDialog(L("Delete this topic and all its sessions?", "حذف الموضوع وجميع جلساته؟"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("Delete", "حذف"), role: .destructive) {
                context.delete(topic)
                try? context.save()
                dismiss()
            }
        }
        .onAppear { withAnimation(Motion.reveal.delay(0.15)) { appeared = true } }
    }

    private func hero(_ topic: TraceTopic) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Palette.night, Palette.obsidian], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Palette.gold.opacity(0.18)).frame(width: 280).blur(radius: 70).offset(x: 180, y: -120)
            BrandMarkPath()
                .stroke(Palette.gold.opacity(0.08), lineWidth: 2)
                .frame(width: 320, height: 320)
                .offset(x: 160, y: -40)
                .environment(\.layoutDirection, .leftToRight)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CircleIconButton(symbol: isArabic ? "chevron.right" : "chevron.left", tint: .white, background: .white.opacity(0.1)) { dismiss() }
                    Spacer()
                    Menu {
                        Button { showEditor = true } label: { Label(L("Edit topic", "تعديل الموضوع"), systemImage: "pencil") }
                        Button {
                            topic.archived.toggle()
                            topic.updatedAt = .now
                            try? context.save()
                        } label: {
                            Label(topic.archived ? L("Restore", "استعادة") : L("Archive", "أرشفة"), systemImage: "archivebox")
                        }
                        Button(role: .destructive) { confirmDelete = true } label: { Label(L("Delete", "حذف"), systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                }
                .padding(.top, 58)

                Spacer(minLength: 20)
                TopicMedallion(symbol: topic.symbol, size: 64)
                HStack(spacing: 8) {
                    Text(topic.code).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.goldBright)
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text(topic.tracerType.title).font(.trCaption).foregroundStyle(.white.opacity(0.7))
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text(L("v\(topic.version)", "إصدار \(topic.version)")).font(.trCaption).foregroundStyle(.white.opacity(0.7))
                }
                Text(topic.title).font(.trHero).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                if !topic.objective.isEmpty {
                    Text(topic.objective).font(.trCallout).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: -6) {
                    ForEach(topic.departmentCodes, id: \.self) { code in
                        DeptMedallion(department: dept(code), size: 30, onDark: true)
                            .overlay(Circle().strokeBorder(Palette.obsidian, lineWidth: 2))
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
        .frame(minHeight: 380)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34, style: .continuous))
    }

    private func sessionsSection(_ topic: TraceTopic) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L("Sessions", "الجلسات"), eyebrow: L("\(topic.sessions.count) total", "\(topic.sessions.count) جلسة"))
            if topic.sessions.isEmpty {
                Text(L("No sessions yet. Each session is an independent evaluation of this topic.", "لا توجد جلسات بعد. كل جلسة تقييم مستقل لهذا الموضوع."))
                    .font(.trSubhead).foregroundStyle(Palette.inkSecondary)
                    .luxCard()
            } else {
                ForEach(topic.sessions.sorted { $0.lastActivityAt > $1.lastActivityAt }) { s in
                    Button {
                        Haptics.tap(); router.openSession(s.id)
                    } label: {
                        SessionCard(session: s).matchedTransitionSource(id: s.id, in: zoom)
                    }
                    .buttonStyle(PressableStyle(scale: 0.985))
                }
            }
        }
    }

    private func questionsSection(_ topic: TraceTopic) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L("Questions & checkpoints", "الأسئلة ونقاط التحقق"), eyebrow: L("Definition", "تعريف الموضوع"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(topic.orderedQuestions.enumerated()), id: \.element.id) { idx, q in
                    let d = dept(q.departmentCode)
                    HStack(alignment: .top, spacing: 12) {
                        DeptMedallion(department: d, size: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(q.text).font(.trCallout).foregroundStyle(Palette.ink)
                            HStack(spacing: 6) {
                                Text(d.name).font(.trCaption.bold()).foregroundStyle(d.color)
                                ForEach(q.clauseIDs.prefix(3), id: \.self) { c in
                                    Text(StandardsLibrary.shared.standard(c)?.id ?? c)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Palette.gold)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    if idx < topic.questions.count - 1 { Divider().overlay(Palette.hairline) }
                }
                if topic.questions.isEmpty {
                    Text(L("No questions defined.", "لا توجد أسئلة معرفة.")).font(.trSubhead).foregroundStyle(Palette.inkSecondary)
                }
            }
            .luxCard(padding: 16)
        }
    }

    private func referencesSection(_ topic: TraceTopic) -> some View {
        let refs = StandardsLibrary.shared.standards(topic.clauseIDs)
        return Group {
            if !refs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(L("Linked standards", "المعايير المرتبطة"), eyebrow: L("Reference", "المرجع"))
                    ForEach(refs) { s in
                        StandardRow(standard: s)
                    }
                }
            }
        }
    }
}
