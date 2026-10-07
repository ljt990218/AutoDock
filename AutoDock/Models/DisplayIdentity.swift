import Foundation

// 仅使用 PRD 6.3 指定的字段，当前会话 ID 不编码到持久化数据中。
struct DisplayIdentity: Codable, Equatable, Sendable {
    var cgDisplayID: UInt32? = nil
    var vendorID: UInt32
    var productID: UInt32
    var serialNumber: UInt32?
    var displayUUID: String?
    var displayName: String?

    enum CodingKeys: String, CodingKey {
        case vendorID, productID, serialNumber, displayUUID, displayName
    }

    enum MatchKey: Hashable, Sendable {
        case serial(vendor: UInt32, product: UInt32, serial: UInt32)
        case uuid(String)
        case name(vendor: UInt32, product: UInt32, name: String)
    }

    var matchKey: MatchKey? {
        let hasHardwareIDs = vendorID != 0 && vendorID != UInt32.max
            && productID != 0 && productID != UInt32.max

        if hasHardwareIDs, let serialNumber,
           serialNumber != 0, serialNumber != UInt32.max {
            return .serial(vendor: vendorID, product: productID, serial: serialNumber)
        }

        if let displayUUID, let uuid = UUID(uuidString: displayUUID),
           uuid.uuidString != "00000000-0000-0000-0000-000000000000" {
            return .uuid(uuid.uuidString)
        }

        if hasHardwareIDs, let displayName, !displayName.isEmpty {
            return .name(vendor: vendorID, product: productID, name: displayName)
        }

        return nil
    }

    var reliabilityDescription: String {
        guard let key = matchKey else { return "缺少可用硬件标识，无法创建自动规则" }
        switch key {
        case .serial: return "通过厂商、型号和序列号识别"
        case .uuid: return "通过显示器 UUID 识别；更换转接器后标识可能变化"
        case .name: return "仅通过厂商、型号和名称识别，无法可靠区分同型号设备"
        }
    }

    var summary: String {
        let serial = serialNumber.map { String($0) } ?? "不可用"
        return "Vendor: \(vendorID) · Product: \(productID)\nSerial: \(serial)\nUUID: \(displayUUID ?? "不可用")"
    }

    func matches(_ other: DisplayIdentity) -> Bool {
        guard let key = matchKey else { return false }
        return key == other.matchKey
    }
}

struct DetectedDisplay: Identifiable, Equatable, Sendable {
    let id: UInt32
    let identity: DisplayIdentity
    let isBuiltIn: Bool
    let mirrorsDisplayID: UInt32?
    var configurationSignature: String = ""

    var name: String {
        identity.displayName ?? (isBuiltIn ? "内建显示器" : "未提供名称的外接显示器")
    }
}
