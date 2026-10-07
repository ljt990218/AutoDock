import Foundation

enum KeepReason: Equatable {
    case monitoringDisabled
    case noExternalDisplays
    case unknownDisplay
    case priorityConflict([UUID])
    case ambiguousIdentity
}

enum RuleDecision: Equatable {
    case apply(position: DockPosition, ruleID: UUID?)
    case keep(KeepReason)
}

struct RuleEngine {
    func evaluate(
        displays: [DetectedDisplay],
        rules: [DisplayRule],
        settings: AppSettings
    ) -> RuleDecision {
        guard settings.monitoringEnabled else {
            return .keep(.monitoringDisabled)
        }

        let external = displays.filter { !$0.isBuiltIn }
        guard !external.isEmpty else {
            if let position = settings.noExternalDisplayAction.position {
                return .apply(position: position, ruleID: nil)
            }
            return .keep(.noExternalDisplays)
        }

        let matches = rules.filter { rule in
            rule.enabled && external.contains { rule.displayIdentity.matches($0.identity) }
        }

        guard !matches.isEmpty else { return .keep(.unknownDisplay) }

        // 同一身份对应多个物理输出时，不用会话 ID 或用户备注猜测设备。
        let counts = Dictionary(grouping: external.compactMap { $0.identity.matchKey }) { $0 }
        if matches.contains(where: { rule in
            guard let key = rule.displayIdentity.matchKey else { return false }
            return (counts[key]?.count ?? 0) > 1
        }) {
            return .keep(.ambiguousIdentity)
        }

        guard let highest = matches.map(\.priority).max() else { return .keep(.unknownDisplay) }
        let winners = matches.filter { $0.priority == highest }
        guard winners.count == 1 else {
            let ids = winners.map(\.id).sorted { $0.uuidString < $1.uuidString }
            return .keep(.priorityConflict(ids))
        }

        return .apply(position: winners[0].dockPosition, ruleID: winners[0].id)
    }
}
