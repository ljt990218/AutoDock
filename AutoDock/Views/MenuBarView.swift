import AppKit
import Combine
import ServiceManagement

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let onManage: (ManagementTab) -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var subscription: AnyCancellable?
    private var isOpen = false
    private var dockItem: NSMenuItem?
    private var stateItem: NSMenuItem?
    private var errorItem: NSMenuItem?

    init(model: AppModel, onManage: @escaping (ManagementTab) -> Void) {
        self.model = model
        self.onManage = onManage
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "AutoDock")
        statusItem.button?.image?.isTemplate = true
        subscription = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.modelDidChange() }
        }
        rebuild()
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isOpen = true
        rebuild()
        model.refreshReadOnly()
    }

    func menuDidClose(_ menu: NSMenu) {
        isOpen = false
    }

    private func modelDidChange() {
        statusItem.button?.toolTip = "AutoDock：\(model.errorMessage ?? model.statusText)"
        if isOpen {
            dockItem?.title = "当前 Dock：\(model.currentDockPosition?.title ?? "正在读取或不可用")"
            stateItem?.title = compact(model.statusText)
            stateItem?.toolTip = model.statusText
            errorItem?.title = compact(model.errorMessage ?? "")
            errorItem?.toolTip = model.errorMessage
            errorItem?.isHidden = model.errorMessage == nil
        } else {
            rebuild()
        }
    }

    private func rebuild() {
        menu.removeAllItems()
        menu.addItem(header("AutoDock"))
        menu.addItem(.separator())
        menu.addItem(header("当前显示器"))
        if model.displays.isEmpty {
            menu.addItem(header("尚未取得显示器信息"))
        }
        for display in model.displays {
            let type = display.isBuiltIn ? "（内建）" : ""
            let mirror = display.mirrorsDisplayID == nil ? "" : "（镜像）"
            let matched = model.matchingRule(for: display)
            let rule = matched.map { " → \($0.dockPosition.title)\($0.enabled ? "" : "（已禁用）")" } ?? ""
            let item = header("\(display.name)\(type)\(mirror)\(rule)")
            item.toolTip = "\(display.identity.summary)\n\(display.identity.reliabilityDescription)"
            menu.addItem(item)
        }

        dockItem = header("当前 Dock：\(model.currentDockPosition?.title ?? "正在读取或不可用")")
        stateItem = header(compact(model.statusText))
        errorItem = header(compact(model.errorMessage ?? ""))
        if let dockItem { menu.addItem(dockItem) }
        if let stateItem {
            stateItem.toolTip = model.statusText
            menu.addItem(stateItem)
        }
        if let errorItem {
            errorItem.isHidden = model.errorMessage == nil
            errorItem.toolTip = model.errorMessage
            menu.addItem(errorItem)
        }
        if model.operationError != nil || model.monitorWarning != nil {
            menu.addItem(ActionMenuItem(title: "重试") { [weak model] in model?.retry() })
        }
        if model.storageError != nil {
            menu.addItem(ActionMenuItem(title: "查看数据恢复选项…") { [weak self] in self?.onManage(.settings) })
        }

        menu.addItem(.separator())
        menu.addItem(header("快速切换"))
        for position in DockPosition.allCases {
            let item = ActionMenuItem(title: position.title) { [weak model] in
                model?.switchManually(to: position)
            }
            item.state = model.currentDockPosition == position ? .on : .off
            item.isEnabled = !model.isBusy
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(header("自动规则"))
        if model.rules.isEmpty { menu.addItem(header("尚未添加规则")) }
        for rule in model.rules.sorted(by: { $0.priority > $1.priority }) {
            let suffix = rule.enabled ? "" : "（已禁用）"
            let item = ActionMenuItem(title: "\(rule.displayName) → \(rule.dockPosition.title)\(suffix)") { [weak self] in
                self?.onManage(.rules)
            }
            item.state = model.currentRuleID == rule.id ? .on : .off
            item.toolTip = "优先级：\(rule.priority)\n\(rule.displayIdentity.summary)"
            menu.addItem(item)
        }

        let external = model.externalDisplays
        if external.count == 1, let display = external.first {
            menu.addItem(addRuleItem(for: display))
        } else if external.count > 1 {
            let item = NSMenuItem(title: "为当前显示器添加规则", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            external.forEach { submenu.addItem(addRuleItem(for: $0)) }
            item.submenu = submenu
            menu.addItem(item)
        } else {
            menu.addItem(header("连接外接显示器后可添加规则"))
        }
        menu.addItem(ActionMenuItem(title: "管理规则…") { [weak self] in self?.onManage(.rules) })

        menu.addItem(.separator())
        let monitoring = ActionMenuItem(title: "自动监听") { [weak model] in
            guard let model else { return }
            model.setMonitoringEnabled(!model.settings.monitoringEnabled)
        }
        monitoring.state = model.settings.monitoringEnabled ? .on : .off
        monitoring.isEnabled = model.canEditData
        menu.addItem(monitoring)

        let login = ActionMenuItem(title: model.loginStatus == .requiresApproval ? "登录时启动（待批准）" : "登录时启动") { [weak model] in
            guard let model else { return }
            model.setLaunchAtLogin(!model.loginIsRegistered)
        }
        login.state = model.loginIsRegistered ? .on : .off
        login.isEnabled = model.canEditData
        login.toolTip = model.loginStatusText
        menu.addItem(login)
        if model.loginStatus == .requiresApproval {
            menu.addItem(ActionMenuItem(title: "打开系统登录项设置…") { [weak model] in model?.openLoginSettings() })
        }
        menu.addItem(ActionMenuItem(title: "设置…") { [weak self] in self?.onManage(.settings) })
        menu.addItem(ActionMenuItem(title: "导出诊断…") { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.model.exportDiagnostics()
        })
        menu.addItem(ActionMenuItem(title: "关于 AutoDock") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        let quit = ActionMenuItem(title: "退出 AutoDock") { NSApp.terminate(nil) }
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    private func addRuleItem(for display: DetectedDisplay) -> NSMenuItem {
        if model.matchingRule(for: display) != nil {
            return ActionMenuItem(title: "编辑 \(display.name) 的规则…") { [weak self] in self?.onManage(.rules) }
        }
        guard let position = model.currentDockPosition else {
            return ActionMenuItem(title: "为 \(display.name) 添加规则…") { [weak self] in self?.onManage(.rules) }
        }
        let item = ActionMenuItem(title: "＋ 为 \(display.name) 创建\(position.title)规则") { [weak model] in
            guard let model else { return }
            do {
                try model.createRule(for: display, position: position)
            } catch {
                model.showError(error)
            }
        }
        item.isEnabled = model.canEditData && display.identity.matchKey != nil && !model.isAmbiguous(display)
        item.toolTip = display.identity.reliabilityDescription
        return item
    }

    private func header(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func compact(_ text: String) -> String {
        let line = text.replacingOccurrences(of: "\n", with: " ")
        return line.count > 65 ? String(line.prefix(65)) + "…" : line
    }
}

@MainActor
final class ActionMenuItem: NSMenuItem {
    private var handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("ActionMenuItem 仅通过 init(title:handler:) 创建")
    }

    @objc private func invoke() {
        handler()
    }
}
