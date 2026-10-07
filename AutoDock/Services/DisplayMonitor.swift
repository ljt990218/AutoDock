import AppKit
import CoreGraphics

enum DisplayEvent {
    case screensChanged
    case sleep
    case wake
}

private func displayReconfigured(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ context: UnsafeMutableRawPointer?
) {
    guard !flags.contains(.beginConfigurationFlag), let context else { return }
    let monitor = Unmanaged<DisplayMonitor>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor [weak monitor] in
        monitor?.deliver(.screensChanged)
    }
}

@MainActor
final class DisplayMonitor {
    var onEvent: ((DisplayEvent) -> Void)?
    private var applicationObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var callbackRegistered = false
    private(set) var isRunning = false

    func start() throws {
        guard !isRunning else { return }
        isRunning = true
        applicationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.deliver(.screensChanged) }
        }

        observeWorkspace(NSWorkspace.willSleepNotification, event: .sleep)
        observeWorkspace(NSWorkspace.didWakeNotification, event: .wake)
        observeWorkspace(NSWorkspace.screensDidWakeNotification, event: .wake)

        let result = CGDisplayRegisterReconfigurationCallback(
            displayReconfigured,
            Unmanaged.passUnretained(self).toOpaque()
        )
        if result == .success {
            callbackRegistered = true
        } else {
            // AppKit 通知仍然有效；调用方展示增强监听注册失败的状态。
            throw DisplayScanError.system(result.rawValue)
        }
    }

    func stop() {
        isRunning = false
        if let applicationObserver {
            NotificationCenter.default.removeObserver(applicationObserver)
        }
        applicationObserver = nil
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()

        if callbackRegistered {
            CGDisplayRemoveReconfigurationCallback(
                displayReconfigured,
                Unmanaged.passUnretained(self).toOpaque()
            )
            callbackRegistered = false
        }
    }

    fileprivate func deliver(_ event: DisplayEvent) {
        guard isRunning else { return }
        onEvent?(event)
    }

    private func observeWorkspace(_ name: Notification.Name, event: DisplayEvent) {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.deliver(event) }
        }
        workspaceObservers.append(observer)
    }
}
