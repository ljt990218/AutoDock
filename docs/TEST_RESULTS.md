# AutoDock 1.0.0 打包与测试记录

日期：2026-10-06（Asia/Shanghai）

## 结果

| 检查 | 结果 | 说明 |
| --- | --- | --- |
| Release 构建 | 通过 | 同时构建 arm64 和 x86_64，最低部署版本 macOS 13 |
| 核心单元测试 | 通过 | Xcode 标准测试流程，26 项通过、0 失败、0 跳过 |
| DMG 镜像校验 | 通过 | 镜像内置校验有效，能够只读挂载并复制应用 |
| ZIP 解压 | 通过 | 能够完整解出 AutoDock.app |
| 应用签名检查 | 通过 | DMG 和 ZIP 中应用均通过严格 ad-hoc 签名检查 |
| 安装包 SHA-256 | 通过 | 两个安装包均与生成的校验文件一致 |
| 应用启动 | 通过 | 启动从 DMG 复制的应用，运行数分钟未退出；采样时主线程等待事件，CPU 为 0.0% |
| Dock 状态保持 | 通过 | 启动检查前后 Dock 偏好均为 left，没有执行实际方向切换 |
| 菜单和设置点击 | 未完成 | 桌面自动化工具读取该应用时返回 native pipe closed，无法确认界面交互结果 |
| 显示器插拔、睡眠、登录启动 | 未执行 | 需真实硬件操作或重新登录 macOS |

测试机器为 Apple Silicon MacBook Pro，系统 macOS 27.0.1（26A434），使用本机 Xcode 27.0（27A5194q，Xcode-beta.app）和 macOS 27.0 SDK。x86_64 架构仅完成编译与架构检查，没有在 Intel Mac 实机运行；macOS 13 的运行兼容性尚未实机验证。

## 单元测试覆盖

- DisplayIdentityTests：10 项，覆盖序列号组合、同型号区分、会话 ID 变化、UUID、名称降级、强身份不降级及会话 ID 不持久化。
- RuleEngineTests：13 项，覆盖单规则、优先级、并列冲突、未知设备、禁用规则、内建屏幕、无外接显示器、歧义身份和镜像场景。
- SettingsStoreTests：3 项，覆盖规则设置往返存储、损坏数据保护及用户主动重置。

测试运行只使用独立的临时 UserDefaults 域，不修改真实应用规则，也不调用 Dock 写入或重载命令。

## 本次修复

打包脚本中的一次性多架构 lipo 校验在本机工具链中失败，改为分别检查 arm64 和 x86_64，两个检查均通过。原生窗口菜单动作改用 `#selector`，消除相关编译警告。

测试包在项目桌面目录中编译完整，但 Xcode 测试启动器无法加载；直接执行测试包时 26 项通过，将 Xcode 的 DerivedData 改到 `/tmp/autodock-test-build-20261006` 后，标准 `xcodebuild test` 流程也通过。未修改系统全局 Xcode 选择或系统权限。

## 交付文件

- `dist/AutoDock-1.0.0-universal.dmg`
- `dist/AutoDock-1.0.0-universal.zip`
- `dist/AutoDock-1.0.0-SHA256SUMS.txt`
- `dist/AutoDock-tests-summary.json`
- `dist/AutoDock-tests.log`
- `dist/tests-3.xcresult`

安装包使用 ad-hoc 签名，未进行 Developer ID 签名或 Apple 公证。本次验证本地产物，不代表从 GitHub 下载后的 Gatekeeper 行为已验证。发布前继续按 README 的 A01–A10 完成硬件和界面验收。
