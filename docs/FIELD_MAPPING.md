# PRD 字段映射

业务字段白名单来源为 `AutoDock_PRD_v1.0.docx` 的 6.3、6.4、6.5、6.7 和第 7 节。下表定义代码使用的字段，不增加名称别名、端口标识、屏幕索引或历史项目兼容字段。

## 显示器身份

| PRD 含义 | Swift 字段 | 数据来源 | 持久化 |
| --- | --- | --- | --- |
| 当前会话 CGDirectDisplayID | `cgDisplayID` | `CGGetOnlineDisplayList` | 否 |
| Vendor ID | `vendorID` | `CGDisplayVendorNumber` | 是 |
| Product / Model ID | `productID` | `CGDisplayModelNumber` | 是 |
| Serial Number | `serialNumber` | `CGDisplaySerialNumber` | 是 |
| Display UUID / ColorSync UUID | `displayUUID` | ColorSync `CGDisplayCreateUUIDFromDisplayID` | 是 |
| 人类可读名称 | `displayName` | 对应 `NSScreen.localizedName` | 是 |

使用 `NSScreen.deviceDescription` 中系统定义的 `NSScreenNumber` 将名称关联到会话 ID。镜像输出可能没有对应 NSScreen；此时原始名称保存为 `nil`，界面可显示“未提供名称的外接显示器”，该提示文本不参与身份匹配。未使用已经弃用的 `CGDisplayIOServicePort`，也不自行解析 EDID 或猜测 IOKit 字段。

Serial 的 `0`、`UInt32.max` 不作为有效序列号；空 UUID 和全零 UUID 不作为标识。序列号必须与有效的 Vendor、Product 组合使用。[Apple 序列号说明](https://developer.apple.com/documentation/coregraphics/cgdisplayserialnumber(_:))

PRD 允许的身份降级在本实现中固定为：

1. 有效 Vendor + Product + Serial
2. Display UUID
3. 有效 Vendor + Product + 真实系统名称

规则和当前显示器都按这一顺序产生唯一匹配键，然后比较键。强身份字段暂时不可用时，不把已有强身份规则降级为名称匹配。规则中的显示名称可修改为备注，但硬件身份中的原始名称不随备注变动。

同一会话 ID 只枚举一次；两个不同输出提供相同匹配键且命中规则时，暂停此次自动应用并提示歧义。只有名称组合可用时，不承诺能够区分同型号的两台物理设备，即使它们分别在不同时间连接。

## 规则和设置

| 模型 | 允许的字段 | PRD 来源 |
| --- | --- | --- |
| DisplayRule | `id`, `displayIdentity`, `displayName`, `dockPosition`, `priority`, `enabled`, `createdAt`, `updatedAt` | 6.7 |
| AppSettings | `monitoringEnabled`, `noExternalDisplayAction`, `launchAtLogin` | 6.7 |
| DockPosition | `left`, `bottom`, `right` | 6.4、6.5 |
| 无外接显示器行为 | `keep`, `left`, `bottom`, `right` | 6.4、6.7 |

UserDefaults 中 `displayRules` 和 `appSettings` 是本项目定义的存储键，各自保存 Codable JSON，不读取旧键或别名。诊断报告、菜单状态、镜像关系及配置签名属于运行时信息，不扩展上述持久化模型。

## Dock 偏好

只读取和写入 `com.apple.dock` 的 `orientation` 字段。通过 `defaults export` 读取该域的 plist，仅使用其中的 `orientation`，不会修改其他 Dock 设置。字段未设置时使用 Apple 定义的系统默认位置 `bottom`；导出失败、字段类型错误或值不在枚举内时停止修改，不猜测其他字段。[Apple 默认 Dock 位置说明](https://support.apple.com/en-gb/guide/mac-help/mh35859/mac)
