import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.backgroundColor = UIColor(hex: 0x0B0F17)
        v.pageShadowsEnabled = true
        v.document = PDFDocument(url: url)
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct PDFFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { SentTransferredFile($0.url) }
    }
}

struct ReportPreview: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var saved = false
    @State private var exportCopy: URL?

    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(L("Tracer form", "نموذج التتبع"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("Close", "إغلاق")) { dismiss() } }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            exporting = true
                        } label: {
                            Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        }
                        .accessibilityLabel(L("Save to Files", "حفظ في الملفات"))
                        ShareLink(item: PDFFile(url: url), preview: SharePreview(url.deletingPathExtension().lastPathComponent, image: Image(systemName: "doc.richtext"))) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .fileMover(isPresented: $exporting, file: exportCopy) { result in
                    if case .success = result { saved = true; Haptics.success() }
                    exportCopy = copyForExport()
                }
                .onAppear { exportCopy = copyForExport() }
        }
    }

    /// fileMover moves the file, so hand it a copy and keep the preview intact.
    private func copyForExport() -> URL? {
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("export-" + url.lastPathComponent)
        try? FileManager.default.removeItem(at: copy)
        try? FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
}
