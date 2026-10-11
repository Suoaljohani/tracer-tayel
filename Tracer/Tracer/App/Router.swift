import SwiftUI
import Observation

enum Route: Hashable {
    case topic(UUID)
    case session(UUID)
    case library
    case settings
}

@Observable
final class Router {
    var path: [Route] = []
    /// Shared namespace id prefix for zoom transitions.
    var lastSessionOpened: UUID?

    func openSession(_ id: UUID) {
        lastSessionOpened = id
        if let last = path.last, case .session = last {
            path[path.count - 1] = .session(id)
        } else {
            path.append(.session(id))
        }
    }

    func openTopic(_ id: UUID) { path.append(.topic(id)) }

    func home() { path.removeAll() }
}
