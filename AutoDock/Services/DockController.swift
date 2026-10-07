import Foundation

@MainActor
final class DockController {
    enum Result {
        case unchanged(DockPosition)
        case changed(DockPosition)
        case cancelled
    }

    private let runner = CommandRunner()
    private var reloadRequired = false

    func readPosition() async throws -> DockPosition {
        let data = try await runner.run(.readPreferences)
        guard let preferences = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw DockError.invalidPreferences
        }

        // Apple 定义的系统默认位置为底部，未设置 orientation 时不写入偏好。
        guard let value = preferences["orientation"] else { return .bottom }
        guard let raw = value as? String, let position = DockPosition(rawValue: raw) else {
            throw DockError.invalidPreferences
        }
        return position
    }

    func apply(_ position: DockPosition, isCurrent: () -> Bool) async throws -> Result {
        let current = try await readPosition()
        guard isCurrent() else { return .cancelled }
        if current == position && !reloadRequired { return .unchanged(current) }

        if current != position {
            _ = try await runner.run(.writePosition(position))
            reloadRequired = true
        }

        // 写入成功后必须完成 reload。若此处失败，手动重试仍会 reload，
        // 不会因为偏好值已经变更就错误地宣告成功。
        do {
            _ = try await runner.run(.reload)
            reloadRequired = false
        } catch {
            throw DockError.reloadFailed(error.localizedDescription)
        }
        return .changed(position)
    }
}

enum DockError: LocalizedError {
    case invalidPreferences
    case reloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPreferences:
            return "无法识别系统 Dock 偏好，已停止修改。请在系统设置中检查 Dock 位置后重试。"
        case .reloadFailed(let message):
            return "Dock 偏好已更新，但重新加载失败；显示位置可能尚未改变。\(message)"
        }
    }
}
