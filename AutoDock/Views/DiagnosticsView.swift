import SwiftUI

@MainActor
struct DiagnosticsView: View {
    @ObservedObject var model: AppModel
    @State private var content = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前状态及本次会话最近 200 条日志")
                    .font(.callout)
                Spacer()
                Button("更新内容") { content = model.diagnosticText() }
                Button("导出…") { model.exportDiagnostics() }
            }
            Text("诊断包含显示器序列号、UUID 和本地规则。分享前请检查；AutoDock 不会自动上传。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView([.vertical, .horizontal]) {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .onAppear { content = model.diagnosticText() }
    }
}
