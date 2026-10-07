import Foundation

@MainActor
final class SettingsStore {
    private let defaults: UserDefaults
    private let rulesKey = "displayRules"
    private let settingsKey = "appSettings"
    private(set) var isBlocked = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> (rules: [DisplayRule], settings: AppSettings) {
        do {
            let rules = try decode([DisplayRule].self, key: rulesKey) ?? []
            let settings = try decode(AppSettings.self, key: settingsKey) ?? AppSettings()
            guard Set(rules.map(\.id)).count == rules.count else {
                throw StoreError.invalidData
            }
            isBlocked = false
            return (rules, settings)
        } catch {
            isBlocked = true
            throw StoreError.invalidData
        }
    }

    func save(rules: [DisplayRule], settings: AppSettings) throws {
        guard !isBlocked else { throw StoreError.invalidData }
        let encoder = JSONEncoder()
        let ruleData = try encoder.encode(rules)
        let settingsData = try encoder.encode(settings)
        defaults.set(ruleData, forKey: rulesKey)
        defaults.set(settingsData, forKey: settingsKey)
    }

    func rawDataDescription() -> String {
        [rulesKey, settingsKey].map { key in
            guard let value = defaults.object(forKey: key) else { return "\(key): 未保存" }
            if let data = value as? Data {
                return "\(key):\n\(String(data: data, encoding: .utf8) ?? data.base64EncodedString())"
            }
            return "\(key):\n\(String(describing: value))"
        }.joined(separator: "\n\n")
    }

    // 仅由设置窗口中用户确认的重置动作调用。
    func reset() {
        defaults.removeObject(forKey: rulesKey)
        defaults.removeObject(forKey: settingsKey)
        isBlocked = false
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        guard defaults.object(forKey: key) != nil else { return nil }
        guard let data = defaults.data(forKey: key) else { throw StoreError.invalidData }
        return try JSONDecoder().decode(type, from: data)
    }
}

enum StoreError: LocalizedError {
    case invalidData

    var errorDescription: String? {
        "本地规则或设置无法读取。原始数据已保留，自动切换已暂停。请先导出诊断，再在设置中重置数据。"
    }
}
