import Foundation
import OSLog

@MainActor
final class AppLogger {
    private let logger = Logger(subsystem: "com.autodock.AutoDock", category: "application")
    private(set) var entries: [String] = []
    private let formatter = ISO8601DateFormatter()

    func info(_ message: String) {
        append(message)
        logger.info("\(message, privacy: .private)")
    }

    func error(_ message: String) {
        append("错误：\(message)")
        logger.error("\(message, privacy: .private)")
    }

    private func append(_ message: String) {
        entries.append("\(formatter.string(from: Date())) \(message)")
        if entries.count > 200 {
            entries.removeFirst(entries.count - 200)
        }
    }
}
