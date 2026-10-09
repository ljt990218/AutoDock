import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let onManage: (ManagementTab) -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var subscription: AnyCancellable?
    private var isOpen = false
    private var positionItems: [DockPosition: NSMenuItem] = [:]
    private var ruleItem: NSMenuItem?
    private var monitoringItem: NSMenuItem?
    private var errorItem: NSMenuItem?
    private var retryItem: NSMenuItem?
    private var recoveryItem: NSMenuItem?
    private var errorSeparator: NSMenuItem?

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
        if isOpen {
            updateMenuItems()
        } else {
            rebuild()
        }
    }

    private func rebuild() {
        menu.removeAllItems()
        positionItems.removeAll()

        let error = header("")
        errorItem = error
        menu.addItem(error)
        let retry = ActionMenuItem(title: "重试") { [weak model] in model?.retry() }
        retryItem = retry
        menu.addItem(retry)
        let recovery = ActionMenuItem(title: "查看数据恢复选项…") { [weak self] in self?.onManage(.settings) }
        recoveryItem = recovery
        menu.addItem(recovery)
        let separator = NSMenuItem.separator()
        errorSeparator = separator
        menu.addItem(separator)

        menu.addItem(header("快速切换"))
        for position in DockPosition.allCases {
            let item = ActionMenuItem(title: position.title) { [weak model] in
                model?.switchManually(to: position)
            }
            positionItems[position] = item
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(header("自动规则"))
        let rule = ActionMenuItem(title: "暂无生效规则") { [weak self] in
            self?.onManage(.rules)
        }
        ruleItem = rule
        menu.addItem(rule)
        menu.addItem(ActionMenuItem(title: "管理规则…") { [weak self] in self?.onManage(.rules) })

        menu.addItem(.separator())
        let monitoring = ActionMenuItem(title: "自动监听") { [weak model] in
            guard let model else { return }
            model.setMonitoringEnabled(!model.settings.monitoringEnabled)
        }
        monitoringItem = monitoring
        menu.addItem(monitoring)

        menu.addItem(ActionMenuItem(title: "设置…") { [weak self] in self?.onManage(.settings) })
        menu.addItem(ActionMenuItem(title: "关于 AutoDock") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        let quit = ActionMenuItem(title: "退出 AutoDock") { NSApp.terminate(nil) }
        quit.keyEquivalent = "q"
        menu.addItem(quit)
        updateMenuItems()
    }

    private func updateMenuItems() {
        var toolTip = "AutoDock：\(model.statusText)"
        if let error = model.errorMessage {
            toolTip += "\n\(error)"
        }
        statusItem.button?.toolTip = toolTip

        for (position, item) in positionItems {
            item.state = model.currentDockPosition == position ? .on : .off
            item.isEnabled = !model.isBusy
        }

        let rule = model.rules.first { $0.id == model.currentRuleID }
        ruleItem?.title = rule.map { "\($0.displayName) → \($0.dockPosition.title)" } ?? "暂无生效规则"
        ruleItem?.state = rule == nil ? .off : .on
        ruleItem?.isEnabled = rule != nil
        ruleItem?.toolTip = rule.map { "优先级：\($0.priority)\n\($0.displayIdentity.summary)" }

        monitoringItem?.state = model.settings.monitoringEnabled ? .on : .off
        monitoringItem?.isEnabled = model.canEditData

        errorItem?.title = compact(model.errorMessage ?? "")
        errorItem?.toolTip = model.errorMessage
        errorItem?.isHidden = model.errorMessage == nil
        retryItem?.isHidden = model.operationError == nil && model.monitorWarning == nil
        retryItem?.isEnabled = !model.isBusy
        recoveryItem?.isHidden = model.storageError == nil
        errorSeparator?.isHidden = model.errorMessage == nil
    }

    private func header(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func compact(_ text: String) -> String {
        let line = text.replacingOccurrences(of: "\n", with: " ")
        return line.count > 40 ? String(line.prefix(40)) + "…" : line
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
