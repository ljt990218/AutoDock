import AppKit
import SwiftUI

@MainActor
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("AutoDock")
                            .font(.title2.bold())
                        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                            Text("版本 \(version)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Text("根据外接显示器，自动切换 macOS Dock 位置。")
                            .font(.callout)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Label("为不同显示器设置 Dock 位置，在左侧、底部和右侧之间自动切换。", systemImage: "display")
                Label("支持多显示器规则优先级、手动切换和登录启动。", systemImage: "slider.horizontal.3")
                Label("规则和设置保存在本机，无需账号或网络服务。", systemImage: "lock.shield")
            } header: {
                Text("功能简介")
                    .font(.headline)
            }
            .font(.callout)

            Section("开源项目") {
                if let repositoryURL = URL(string: "https://github.com/ljt990218/AutoDock") {
                    Link(destination: repositoryURL) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("喜欢 AutoDock？去 GitHub 点个 Star", systemImage: "star")
                            Text("https://github.com/ljt990218/AutoDock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("欢迎在仓库中反馈问题、提出建议或参与贡献。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LabeledContent("开源许可证", value: "MIT")
                if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String {
                    Text(copyright)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
