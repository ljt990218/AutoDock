import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var menuBar: MenuBarController?
    private var managementWindow: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installApplicationMenu()
        menuBar = MenuBarController(model: model) { [weak self] tab in
            self?.showManagement(tab: tab)
        }
        model.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.refreshReadOnly()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showManagement(tab: .rules)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        menuBar?.stop()
    }

    private func showManagement(tab: ManagementTab) {
        model.managementTab = tab
        if managementWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "AutoDock"
            window.minSize = NSSize(width: 680, height: 520)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ManagementView(model: model))
            window.center()
            managementWindow = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        managementWindow?.showWindow(nil)
        managementWindow?.window?.makeKeyAndOrderFront(nil)
        model.refreshReadOnly()
    }

    private func installApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "AutoDock")
        applicationMenu.addItem(ActionMenuItem(title: "关于 AutoDock") {
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        let settings = ActionMenuItem(title: "设置…") { [weak self] in
            self?.showManagement(tab: .settings)
        }
        settings.keyEquivalent = ","
        applicationMenu.addItem(settings)
        applicationMenu.addItem(.separator())
        let quit = ActionMenuItem(title: "退出 AutoDock") { NSApp.terminate(nil) }
        quit.keyEquivalent = "q"
        applicationMenu.addItem(quit)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        for (title, selector, key) in [
            ("撤销", "undo:", "z"),
            ("重做", "redo:", "Z"),
            ("剪切", "cut:", "x"),
            ("复制", "copy:", "c"),
            ("粘贴", "paste:", "v"),
            ("全选", "selectAll:", "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }
}
