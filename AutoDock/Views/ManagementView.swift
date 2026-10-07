import SwiftUI

@MainActor
struct ManagementView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "display")
                Text(model.statusText)
                    .font(.callout)
                    .lineLimit(2)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
                Text("Dock：\(model.currentDockPosition?.title ?? "未知")")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            if let error = model.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.callout)
                        .textSelection(.enabled)
                    Spacer()
                    if model.storageError == nil {
                        Button("重试") { model.retry() }
                            .disabled(model.isBusy)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
            }

            TabView(selection: $model.managementTab) {
                RuleListView(model: model)
                    .tabItem { Label("规则", systemImage: "list.bullet") }
                    .tag(ManagementTab.rules)
                SettingsView(model: model)
                    .tabItem { Label("设置", systemImage: "gearshape") }
                    .tag(ManagementTab.settings)
                DiagnosticsView(model: model)
                    .tabItem { Label("诊断", systemImage: "doc.text") }
                    .tag(ManagementTab.diagnostics)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 16)
        .frame(minWidth: 640, minHeight: 480)
    }
}
