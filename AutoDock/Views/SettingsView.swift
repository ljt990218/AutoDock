import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmsReset = false

    var body: some View {
        Form {
            Section("自动切换") {
                Toggle("自动监听显示器变化", isOn: Binding(
                    get: { model.settings.monitoringEnabled },
                    set: { model.setMonitoringEnabled($0) }
                ))
                .disabled(!model.canEditData)
                Picker("无外接显示器时", selection: Binding(
                    get: { model.settings.noExternalDisplayAction },
                    set: { model.setNoExternalAction($0) }
                )) {
                    ForEach(NoExternalDisplayAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                .disabled(!model.canEditData)
                Text("手动切换或在系统设置中更改 Dock 后，下一次显示器变化会重新应用自动规则。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("登录启动") {
                Toggle("登录时启动 AutoDock", isOn: Binding(
                    get: { model.loginIsRegistered },
                    set: { model.setLaunchAtLogin($0) }
                ))
                .disabled(!model.canEditData)
                Text(model.loginStatusText).font(.callout).foregroundStyle(.secondary)
                Button("打开系统登录项设置…") { model.openLoginSettings() }
                Text("建议先将 AutoDock 安装到“应用程序”。登录项是否允许运行以系统实际状态为准。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("本地数据") {
                Text("规则仅保存在当前 Mac 用户的本地偏好中，不使用网络服务。")
                    .font(.callout)
                Button("导出诊断和原始数据…") { model.exportDiagnostics() }
                if model.storageError != nil {
                    Text("原始数据已保留且不会被覆盖。建议先导出诊断，再重置规则和设置。")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                Button("重置本地规则和设置…", role: .destructive) { confirmsReset = true }
                    .disabled(model.isBusy)
            }
        }
        .formStyle(.grouped)
        .alert("重置本地规则和设置？", isPresented: $confirmsReset) {
            Button("重置", role: .destructive) { model.resetStoredData() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除所有显示器规则，并恢复自动监听和“无外接显示器时保持当前位置”。系统登录项注册状态保持不变。请先导出需要保留的数据。")
        }
    }
}
