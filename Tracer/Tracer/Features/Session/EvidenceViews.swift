import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import QuickLook

struct EvidenceStrip: View {
    let session: TraceSession
    let item: TraceItem

    @Environment(\.modelContext) private var context
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var showFiles = false
    @State private var noteKind: EvidenceKind?
    @State private var showLinkExisting = false
    @State private var opened: EvidenceItem?

    private var engine: TraceEngine { TraceEngine(context: context) }
    private var linked: [EvidenceItem] { session.evidence.filter { $0.linkedItemIDs.contains(item.id) }.sorted { $0.createdAt < $1.createdAt } }
    private var d: Department { dept(item.node?.departmentCode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: L("Evidence", "الأدلة"), color: Palette.inkSecondary)
                Spacer()
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: { Label(L("Take photo", "التقاط صورة"), systemImage: "camera") }
                    }
                    Button { showPhotos = true } label: { Label(L("Photo library", "مكتبة الصور"), systemImage: "photo.on.rectangle") }
                    Button { showFiles = true } label: { Label(L("Document", "مستند"), systemImage: "doc") }
                    Button { noteKind = .observation } label: { Label(EvidenceKind.observation.title, systemImage: EvidenceKind.observation.symbol) }
                    Button { noteKind = .record } label: { Label(EvidenceKind.record.title, systemImage: EvidenceKind.record.symbol) }
                    if session.evidence.contains(where: { !$0.linkedItemIDs.contains(item.id) }) {
                        Divider()
                        Button { showLinkExisting = true } label: { Label(L("Link existing evidence", "ربط دليل موجود"), systemImage: "link") }
                    }
                } label: {
                    Label(L("Attach", "إرفاق"), systemImage: "paperclip")
                        .font(.trFootnote.bold())
                        .padding(.horizontal, 12).frame(height: 32)
                        .foregroundStyle(d.color)
                        .background(Capsule().fill(d.color.opacity(0.1)))
                }
            }
            if linked.isEmpty {
                Text(L("No evidence attached to this question.", "لا توجد أدلة مرفقة بهذا السؤال."))
                    .font(.trCaption).foregroundStyle(Palette.inkTertiary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(linked) { ev in
                            Button { opened = ev } label: { EvidenceTile(evidence: ev) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .luxCard(padding: 16, radius: 22)
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    addImage(data)
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) { addImage(data) }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image, .plainText, .data]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), data.count < 25_000_000 else { return }
            let ev = EvidenceItem(kind: .document, title: url.deletingPathExtension().lastPathComponent, departmentCode: item.node?.departmentCode ?? "", data: data, fileName: url.lastPathComponent)
            engine.addEvidence(ev, to: session, linking: item)
            Haptics.success()
        }
        .sheet(item: $noteKind) { kind in
            ObservationSheet(kind: kind) { title, note in
                let ev = EvidenceItem(kind: kind, title: title, note: note, departmentCode: item.node?.departmentCode ?? "")
                engine.addEvidence(ev, to: session, linking: item)
                Haptics.success()
            }
        }
        .sheet(isPresented: $showLinkExisting) {
            LinkEvidenceSheet(session: session, item: item)
        }
        .sheet(item: $opened) { ev in
            EvidenceDetailSheet(evidence: ev, session: session)
        }
    }

    private func addImage(_ data: Data) {
        let ev = EvidenceItem(kind: .photo, title: L("Photo", "صورة") + " " + Date.now.formatted(dateStyle: .none, timeStyle: .short),
                              departmentCode: item.node?.departmentCode ?? "", data: data, fileName: "photo.jpg")
        engine.addEvidence(ev, to: session, linking: item)
        Haptics.success()
    }
}

struct EvidenceTile: View {
    let evidence: EvidenceItem

    var body: some View {
        let d = dept(evidence.departmentCode)
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if evidence.kind == .photo, let data = evidence.data, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [d.color.opacity(0.18), d.color.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: evidence.kind.symbol).font(.system(size: 24, weight: .light)).foregroundStyle(d.color)
                }
            }
            .frame(width: 112, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if evidence.verified {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.white, RiskLevel.low.color).padding(5)
                }
            }
            Text(evidence.title).font(.trCaptionBold).foregroundStyle(Palette.ink).lineLimit(1)
            Text(d.name).font(.trMicro).foregroundStyle(d.color)
        }
        .frame(width: 112)
    }
}

struct ObservationSheet: View {
    let kind: EvidenceKind
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(L("Title", "العنوان"), text: $title).inputBox()
                TextField(kind == .record ? L("Which record, what was found…", "أي سجل، وما الذي وُجد…") : L("What did you observe?", "ماذا شاهدت؟"), text: $note, axis: .vertical)
                    .lineLimit(4...10).inputBox()
                Spacer()
            }
            .padding(20)
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel", "إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save", "حفظ")) { onSave(title.isEmpty ? kind.title : title, note); dismiss() }
                        .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty && title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Link evidence captured elsewhere in the session (e.g. in another department) to this question
/// without duplicating the file.
struct LinkEvidenceSheet: View {
    let session: TraceSession
    let item: TraceItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(session.visitedDepartmentCodes, id: \.self) { code in
                        let evs = session.evidence.filter { $0.departmentCode == code }
                        if !evs.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(dept(code).name, systemImage: dept(code).symbol).font(.trFootnote.bold()).foregroundStyle(dept(code).color)
                                FlowLayout(spacing: 10) {
                                    ForEach(evs) { ev in
                                        let on = ev.linkedItemIDs.contains(item.id)
                                        Button {
                                            TraceEngine(context: context).toggleLink(ev, item: item)
                                            Haptics.selection()
                                        } label: {
                                            EvidenceTile(evidence: ev)
                                                .padding(6)
                                                .background(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? Palette.gold : .clear, lineWidth: 1.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(L("Session evidence", "أدلة الجلسة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done", "تم")) { dismiss() } } }
        }
    }
}

struct EvidenceDetailSheet: View {
    @Bindable var evidence: EvidenceItem
    let session: TraceSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if evidence.kind == .photo, let data = evidence.data, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else if evidence.kind == .document, evidence.data != nil {
                        Button {
                            previewURL = exportTemp()
                        } label: {
                            Label(L("Open document", "فتح المستند"), systemImage: "doc.viewfinder").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GhostButtonStyle(tint: Palette.gold))
                    }
                    FieldBlock(label: L("Title", "العنوان"), symbol: "textformat") {
                        TextField("", text: $evidence.title).inputBox()
                    }
                    FieldBlock(label: L("Note", "ملاحظة"), symbol: "text.quote") {
                        TextField("", text: $evidence.note, axis: .vertical).lineLimit(2...8).inputBox()
                    }
                    Toggle(isOn: $evidence.verified) {
                        Label(L("Verified by evaluator", "تم التحقق من المقيِّم"), systemImage: "checkmark.seal").font(.trCallout)
                    }
                    .tint(RiskLevel.low.color)
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: L("Source", "المصدر"), color: Palette.inkSecondary)
                        Text("\(evidence.kind.title) · \(dept(evidence.departmentCode).name) · \(evidence.createdAt.formatted(dateStyle: .medium, timeStyle: .short))")
                            .font(.trCaption).foregroundStyle(Palette.inkSecondary)
                        Text(L("Linked to \(evidence.linkedItemIDs.count) question(s)", "مرتبط بعدد \(evidence.linkedItemIDs.count) من الأسئلة"))
                            .font(.trCaption).foregroundStyle(Palette.inkSecondary)
                    }
                    Button(role: .destructive) {
                        context.delete(evidence)
                        try? context.save()
                        dismiss()
                    } label: {
                        Label(L("Remove evidence", "حذف الدليل"), systemImage: "trash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GhostButtonStyle(tint: RiskLevel.critical.color))
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(evidence.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done", "تم")) { try? context.save(); dismiss() }
                }
            }
            .quickLookPreview($previewURL)
        }
    }

    private func exportTemp() -> URL? {
        guard let data = evidence.data else { return nil }
        let name = evidence.fileName.isEmpty ? "evidence" : evidence.fileName
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
