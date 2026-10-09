import SwiftUI

@MainActor
struct RuleListView: View {
    @ObservedObject var model: AppModel
    @State private var editingRule: DisplayRule?
    @State private var deletingRule: DisplayRule?

    var body: some View {
        Form {
            Section("当前显示器") {
                if model.displays.isEmpty {
                    Text("尚未取得显示器信息。请等待显示器连接稳定，或从菜单重试。")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.displays) { display in
                    displayRow(display)
                }
            }

            Section {
                if model.rules.isEmpty {
                    Text("连接外接显示器后，在上方对应显示器旁点击“添加规则…”。")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.rules.sorted { $0.priority > $1.priority }) { rule in
                    ruleRow(rule)
                }
            } header: {
                HStack {
                    Text("自动规则").font(.headline)
                    Spacer()
                    Text("数字越大越优先；最高优先级相同则保持当前位置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingRule) { rule in
            RuleEditorView(model: model, rule: rule)
        }
        .alert("删除这条规则？", isPresented: deletionPresented, presenting: deletingRule) { rule in
            Button("删除", role: .destructive) {
                model.deleteRule(rule)
                deletingRule = nil
            }
            Button("取消", role: .cancel) { deletingRule = nil }
        } message: { rule in
            Text("删除“\(rule.displayName)”的自动规则。系统当前 Dock 位置不会因删除而恢复。")
        }
    }

    private var deletionPresented: Binding<Bool> {
        Binding(
            get: { deletingRule != nil },
            set: { if !$0 { deletingRule = nil } }
        )
    }

    private func displayRow(_ display: DetectedDisplay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(display.name, systemImage: display.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.headline)
                if display.isBuiltIn {
                    Text("内建").foregroundStyle(.secondary)
                }
                if display.mirrorsDisplayID != nil {
                    Text("镜像输出").foregroundStyle(.secondary)
                }
                Spacer()
                if !display.isBuiltIn {
                    Button(model.matchingRule(for: display) == nil ? "添加规则…" : "编辑规则…") {
                        editingRule = model.matchingRule(for: display) ?? DisplayRule(
                            displayIdentity: display.identity,
                            displayName: display.name,
                            dockPosition: model.currentDockPosition ?? .bottom
                        )
                    }
                    .disabled(!model.canEditData || display.identity.matchKey == nil || model.isAmbiguous(display))
                }
            }
            Text(display.identity.summary)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if model.isAmbiguous(display) {
                Text("当前多个显示器提供相同硬件身份，自动匹配已暂停。备注名称无法解决这一限制。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !display.isBuiltIn {
                Text(display.identity.reliabilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func ruleRow(_ rule: DisplayRule) -> some View {
        HStack(spacing: 12) {
            Toggle("启用 \(rule.displayName)", isOn: Binding(
                get: { rule.enabled },
                set: { model.setRuleEnabled(rule, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(!model.canEditData)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.displayName).font(.headline)
                    Text("→ \(rule.dockPosition.title)")
                    if model.currentRuleID == rule.id {
                        Label("已生效", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                let connected = model.externalDisplays.contains { rule.displayIdentity.matches($0.identity) }
                Text("优先级 \(rule.priority) · \(connected ? "已连接" : "未连接")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("编辑…") { editingRule = rule }
                .disabled(!model.canEditData)
            Button(role: .destructive) { deletingRule = rule } label: {
                Image(systemName: "trash")
            }
            .help("删除规则")
            .disabled(!model.canEditData)
        }
        .padding(.vertical, 6)
    }
}
