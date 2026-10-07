import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var monitoringEnabled: Bool = true
    var noExternalDisplayAction: NoExternalDisplayAction = .keep
    var launchAtLogin: Bool = false
}
