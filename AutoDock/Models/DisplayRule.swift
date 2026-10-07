import Foundation

struct DisplayRule: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var displayIdentity: DisplayIdentity
    var displayName: String
    var dockPosition: DockPosition
    var priority: Int = 0
    var enabled: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
