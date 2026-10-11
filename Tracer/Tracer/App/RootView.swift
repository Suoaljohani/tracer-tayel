import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showSplash = true
    @State private var revealed = false
    @Namespace private var zoom

    var body: some View {
        @Bindable var router = router
        ZStack {
            NavigationStack(path: $router.path) {
                HubView(zoom: zoom)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .topic(let id):
                            TopicDetailView(topicID: id, zoom: zoom)
                                .navigationTransition(.zoom(sourceID: id, in: zoom))
                        case .session(let id):
                            SessionWorkspaceView(sessionID: id)
                                .navigationTransition(.zoom(sourceID: id, in: zoom))
                        case .library:
                            LibraryView()
                        case .settings:
                            SettingsView()
                        }
                    }
            }
            // Camera "dolly-in": the hub settles from a slight scale and blur as the splash lifts.
            .scaleEffect(revealed || reduceMotion ? 1 : 1.06)
            .blur(radius: revealed || reduceMotion ? 0 : 14)
            .opacity(revealed ? 1 : 0.001)

            if showSplash {
                SplashView {
                    withAnimation(.spring(response: 0.9, dampingFraction: 0.92)) { revealed = true }
                    withAnimation(.easeOut(duration: 0.55).delay(0.05)) { showSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.12)))
                .zIndex(10)
            }
        }
        .id(settings.language)
        .onAppear {
            Seeder.seedIfNeeded(context)
            DepartmentStore.shared.refresh(context)
        }
    }
}
