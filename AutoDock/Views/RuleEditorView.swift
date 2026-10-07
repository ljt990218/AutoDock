import SwiftUI

@MainActor
struct RuleEditorView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DisplayRule
    @State private var priorityText: String
    @State private var errorText: String?

    init(model: AppModel, rule: DisplayRule) {
        self.model = model
        _draft = State(initialValue: rule)
        _priorityText = State(initialValue: String(rule.priority))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("显示器规则").font(.title2.bold())
            GroupBox("硬件身份") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.displayIdentity.displayName ?? "系统未提供显示器名称")
                        .font(.headline)
                    Text(draft.displayIdentity.summary)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                    Text(draft.displayIdentity.reliabilityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            Form {
                TextField("显示名称", text: $draft.displayName)
                Picker("Dock 位置", selection: $draft.dockPosition) {
                    ForEach(DockPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                TextField("优先级", text: $priorityText)
                Toggle("启用这条规则", isOn: $draft.enabled)
            }
            Text("显示名称仅作为备注，不改变硬件匹配。优先级必须是整数，数字越大越优先。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let errorText {
                Text(errorText).foregroundStyle(.red).font(.callout)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canEditData)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func save() {
        guard let priority = Int(priorityText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorText = "优先级必须是有效整数。"
            return
        }
        draft.priority = priority
        do {
            try model.saveRule(draft)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
