import AppKit
import ColorSync
import CoreGraphics

@MainActor
struct DisplayIdentityProvider {
    func scan() throws -> [DetectedDisplay] {
        var count: UInt32 = 0
        try requireSuccess(CGGetOnlineDisplayList(0, nil, &count))
        guard count > 0 else { throw DisplayScanError.noDisplays }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let capacity = count
        let result = ids.withUnsafeMutableBufferPointer { buffer in
            CGGetOnlineDisplayList(capacity, buffer.baseAddress, &count)
        }
        try requireSuccess(result)
        guard count > 0 else { throw DisplayScanError.noDisplays }
        ids = Array(ids.prefix(Int(count)))

        var names: [UInt32: String] = [:]
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                if !screen.localizedName.isEmpty { names[number.uint32Value] = screen.localizedName }
            }
        }

        return Set(ids).sorted().map { id in
            let serial = CGDisplaySerialNumber(id)
            let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
            let uuidString: String?
            if let uuid, let string = CFUUIDCreateString(nil, uuid) {
                uuidString = string as String
            } else {
                uuidString = nil
            }
            let identity = DisplayIdentity(
                cgDisplayID: id,
                vendorID: CGDisplayVendorNumber(id),
                productID: CGDisplayModelNumber(id),
                serialNumber: serial == 0 || serial == UInt32.max ? nil : serial,
                displayUUID: uuidString,
                displayName: names[id]
            )
            let mirror = CGDisplayMirrorsDisplay(id)
            let bounds = CGDisplayBounds(id)
            let configuration = "\(CGDisplayIsActive(id)):\(bounds.origin.x):\(bounds.origin.y):\(bounds.width):\(bounds.height)"

            return DetectedDisplay(
                id: id,
                identity: identity,
                isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                mirrorsDisplayID: mirror == kCGNullDirectDisplay ? nil : mirror,
                configurationSignature: configuration
            )
        }
    }

    private func requireSuccess(_ result: CGError) throws {
        guard result == .success else { throw DisplayScanError.system(result.rawValue) }
    }
}

enum DisplayScanError: LocalizedError {
    case noDisplays
    case system(Int32)

    var errorDescription: String? {
        switch self {
        case .noDisplays:
            return "系统尚未提供稳定的显示器列表，已保留当前 Dock。请等待显示器恢复后重试。"
        case .system(let code):
            return "读取显示器失败（系统错误 \(code)），已保留当前 Dock。"
        }
    }
}
