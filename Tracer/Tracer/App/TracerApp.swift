import SwiftUI
import SwiftData

@main
struct TracerApp: App {
    @State private var settings = AppSettings.shared
    @State private var router = Router()

    let container: ModelContainer = {
        let schema = Schema([
            TraceTopic.self, TopicQuestion.self, TraceSession.self, TraceNode.self,
            TraceItem.self, StaffResponse.self, AnalysisRecord.self, TraceEdge.self,
            EvidenceItem.self, AuditEvent.self, CustomDepartment.self,
        ])
        let config = ModelConfiguration("Tracer", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Unable to open the on-device store: \(error)")
        }
    }()

    init() {
        Typography.registerIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
                .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
                .environment(\.locale, settings.language.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Palette.gold)
        }
        .modelContainer(container)
    }
}
