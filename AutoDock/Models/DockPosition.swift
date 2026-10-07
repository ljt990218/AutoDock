import Foundation

enum DockPosition: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case left
    case bottom
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "左侧"
        case .bottom: return "底部"
        case .right: return "右侧"
        }
    }
}

enum NoExternalDisplayAction: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case keep
    case left
    case bottom
    case right

    var id: String { rawValue }

    var title: String {
        position?.title ?? "保持当前位置"
    }

    var position: DockPosition? {
        DockPosition(rawValue: rawValue)
    }
}
