import AppKit
import Combine
import ServiceManagement
import UniformTypeIdentifiers

enum ManagementTab: Hashable {
    case rules
    case settings
    case diagnostics
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var displays: [DetectedDisplay] = []
    @Published private(set) var rules: [DisplayRule] = []
    @Published private(set) var settings = AppSettings()
    @Published private(set) var currentDockPosition: DockPosition?
    @Published private(set) var currentRuleID: UUID?
    @Published private(set) var statusText = "正在读取显示器…"
    @Published private(set) var operationError: String?
    @Published private(set) var storageError: String?
    @Published private(set) var monitorWarning: String?
    @Published private(set) var isBusy = false
    @Published private(set) var loginStatus = SMAppService.Status.notRegistered
    @Published var managementTab = ManagementTab.rules

    private let provider = DisplayIdentityProvider()
    private let monitor = DisplayMonitor()
    private let dock = DockController()
    private let engine = RuleEngine()
    private let store = SettingsStore()
    private let login = LaunchAtLoginService()
    private let logger = AppLogger()
    private var debounceTask: Task<Void, Never>?
    private var worker: Task<Void, Never>?
    private var pendingJob: Job?
    private var revision = 0
    private var isSleeping = false
    private var isStopped = false
    private var refreshInProgress = false
    private var ownReloadSnapshot: [DetectedDisplay]?
    private var ownReloadDeadline = Date.distantPast
    private var failedAutomatic: (displays: [DetectedDisplay], decision: RuleDecision)?
    private var lastDecision: RuleDecision?
    private var retryOperation = RetryOperation.automatic

    private enum Request {
        case automatic(ignoreOwnReload: Bool)
        case manual(DockPosition)
    }

    private struct Job {
        let revision: Int
        let request: Request
    }

    private enum RetryOperation {
        case automatic
        case manual(DockPosition)
        case refresh
        case login(Bool)
        case export
    }

    var externalDisplays: [DetectedDisplay] { displays.filter { !$0.isBuiltIn } }
    var errorMessage: String? { storageError ?? operationError ?? monitorWarning }
    var canEditData: Bool { storageError == nil }
    var loginIsRegistered: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }

    var loginStatusText: String {
        switch loginStatus {
        case .enabled: return "已开启"
        case .notRegistered: return "未开启"
        case .requiresApproval: return "等待系统批准，请在系统设置中允许 AutoDock"
        case .notFound: return "系统未找到可注册的应用，请安装到“应用程序”后重试"
        @unknown default: return "未知登录项状态"
        }
    }

    func start() {
        do {
            let saved = try store.load()
            rules = saved.rules
            settings = saved.settings
        } catch {
            storageError = error.localizedDescription
            settings.monitoringEnabled = false
            logger.error(error.localizedDescription)
        }

        monitor.onEvent = { [weak self] event in self?.handle(event) }
        refreshLoginStatus()
        configureMonitoring()
        logger.info("AutoDock 启动，已加载 \(rules.count) 条规则")
        if settings.monitoringEnabled && canEditData {
            scheduleAutomatic(ignoreOwnReload: false)
        } else {
            statusText = "自动监听已暂停"
            refreshReadOnly()
        }
    }

    func stop() {
        isStopped = true
        invalidatePendingWork()
        monitor.stop()
        logger.info("AutoDock 退出，保留系统当前 Dock 位置")
    }

    func refreshLoginStatus() {
        loginStatus = login.status
        settings.launchAtLogin = loginIsRegistered
    }

    // 打开菜单、激活窗口只读取状态，不触发规则或覆盖用户手动位置。
    func refreshReadOnly() {
        refreshLoginStatus()
        guard !isStopped, !isSleeping else { return }
        do {
            displays = try provider.scan()
        } catch {
            report(error, retry: .refresh)
            return
        }
        guard !isBusy, !refreshInProgress else { return }
        refreshInProgress = true
        let capturedRevision = revision
        Task { [weak self] in
            guard let self else { return }
            defer { self.refreshInProgress = false }
            do {
                let position = try await self.dock.readPosition()
                guard self.revision == capturedRevision, !self.isBusy, !self.isStopped else { return }
                self.currentDockPosition = position
            } catch {
                guard self.revision == capturedRevision, !self.isBusy, !self.isStopped else { return }
                self.currentDockPosition = nil
                self.report(error, retry: .refresh)
            }
        }
    }

    func matchingRule(for display: DetectedDisplay) -> DisplayRule? {
        rules.first { $0.displayIdentity.matches(display.identity) }
    }

    func isAmbiguous(_ display: DetectedDisplay) -> Bool {
        guard let key = display.identity.matchKey else { return false }
        return externalDisplays.filter { $0.identity.matchKey == key }.count > 1
    }

    func createRule(for display: DetectedDisplay, position: DockPosition) throws {
        guard !display.isBuiltIn, !isAmbiguous(display) else { throw RuleEditError.ambiguous }
        try saveRule(DisplayRule(
            displayIdentity: display.identity,
            displayName: display.name,
            dockPosition: position
        ))
    }

    func saveRule(_ draft: DisplayRule) throws {
        guard canEditData else { throw StoreError.invalidData }
        guard draft.displayIdentity.matchKey != nil else { throw RuleEditError.noIdentity }
        guard !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuleEditError.emptyName
        }
        guard !rules.contains(where: {
            $0.id != draft.id && $0.displayIdentity.matches(draft.displayIdentity)
        }) else { throw RuleEditError.duplicate }

        var updated = draft
        updated.displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date()
        var next = rules
        if let index = next.firstIndex(where: { $0.id == draft.id }) {
            updated.createdAt = next[index].createdAt
            next[index] = updated
        } else {
            next.append(updated)
        }
        try store.save(rules: next, settings: settings)
        rules = next
        logger.info("已保存规则：\(updated.displayName) → \(updated.dockPosition.rawValue)，优先级 \(updated.priority)")
        rulesDidChange()
    }

    func setRuleEnabled(_ rule: DisplayRule, enabled: Bool) {
        var draft = rule
        draft.enabled = enabled
        do {
            try saveRule(draft)
        } catch {
            report(error, retry: .automatic)
        }
    }

    func deleteRule(_ rule: DisplayRule) {
        do {
            let next = rules.filter { $0.id != rule.id }
            try store.save(rules: next, settings: settings)
            rules = next
            logger.info("已删除规则：\(rule.displayName)")
            rulesDidChange()
        } catch {
            report(error, retry: .automatic)
        }
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        var next = settings
        next.monitoringEnabled = enabled
        do {
            try store.save(rules: rules, settings: next)
            settings = next
            invalidatePendingWork()
            failedAutomatic = nil
            configureMonitoring()
            if enabled {
                scheduleAutomatic(ignoreOwnReload: false)
            } else {
                currentRuleID = nil
                statusText = "自动监听已暂停，仍可手动切换"
            }
        } catch {
            report(error, retry: .automatic)
        }
    }

    func setNoExternalAction(_ action: NoExternalDisplayAction) {
        var next = settings
        next.noExternalDisplayAction = action
        do {
            try store.save(rules: rules, settings: next)
            settings = next
            rulesDidChange()
        } catch {
            report(error, retry: .automatic)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard canEditData else { return }
        do {
            try login.setEnabled(enabled)
            refreshLoginStatus()
            try store.save(rules: rules, settings: settings)
            logger.info("登录启动状态：\(loginStatusText)")
        } catch {
            refreshLoginStatus()
            report(error, retry: .login(enabled))
        }
    }

    func openLoginSettings() {
        login.openSystemSettings()
    }

    func switchManually(to position: DockPosition) {
        guard !isStopped, !isSleeping else { return }
        invalidatePendingWork()
        failedAutomatic = nil
        pendingJob = Job(revision: revision, request: .manual(position))
        startWorker()
    }

    func retry() {
        operationError = nil
        failedAutomatic = nil
        switch retryOperation {
        case .automatic:
            if settings.monitoringEnabled && canEditData {
                configureMonitoring()
                scheduleAutomatic(ignoreOwnReload: false)
            } else {
                refreshReadOnly()
            }
        case .manual(let position): switchManually(to: position)
        case .refresh: refreshReadOnly()
        case .login(let enabled): setLaunchAtLogin(enabled)
        case .export: exportDiagnostics()
        }
    }

    func showError(_ error: Error) {
        report(error, retry: .automatic)
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "导出 AutoDock 诊断"
        panel.message = "文件包含显示器序列号、UUID、规则和最近日志。分享前请检查内容。"
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "AutoDock-diagnostics.txt"
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                guard let self else { return }
                do {
                    try self.diagnosticText().write(to: url, atomically: true, encoding: .utf8)
                    self.logger.info("已按用户请求导出诊断")
                } catch {
                    self.report(error, retry: .export)
                }
            }
        }
    }

    func resetStoredData() {
        invalidatePendingWork()
        store.reset()
        rules = []
        settings = AppSettings()
        storageError = nil
        operationError = nil
        failedAutomatic = nil
        refreshLoginStatus()
        configureMonitoring()
        logger.info("用户已确认重置本地规则和设置")
        scheduleAutomatic(ignoreOwnReload: false)
    }

    func diagnosticText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let rulesJSON: String
        do {
            let data = try encoder.encode(rules)
            rulesJSON = String(decoding: data, as: UTF8.self)
        } catch {
            rulesJSON = "规则编码失败：\(error.localizedDescription)"
        }
        let devices = displays.map { display in
            "\(display.name)\nSession ID: \(display.id) · 内建: \(display.isBuiltIn) · 镜像源: \(display.mirrorsDisplayID.map { String($0) } ?? "无")\n\(display.identity.summary)\n\(display.identity.reliabilityDescription)"
        }.joined(separator: "\n\n")

        return """
        AutoDock \(version) 诊断
        导出时间：\(ISO8601DateFormatter().string(from: Date()))
        系统：\(ProcessInfo.processInfo.operatingSystemVersionString)
        状态：\(statusText)
        当前 Dock：\(currentDockPosition?.rawValue ?? "未知")
        自动监听：\(settings.monitoringEnabled)
        无外接显示器：\(settings.noExternalDisplayAction.rawValue)
        登录启动：\(loginStatusText)
        错误：\(errorMessage ?? "无")
        匹配结果：\(String(describing: lastDecision))

        当前显示器
        \(devices)

        当前规则
        \(rulesJSON)

        本地原始数据（重置前可用此部分保留备份）
        \(store.rawDataDescription())

        最近日志（最多 200 条，仅本次应用会话）
        \(logger.entries.joined(separator: "\n"))
        """
    }

    private func configureMonitoring() {
        monitor.stop()
        monitorWarning = nil
        guard settings.monitoringEnabled, canEditData else { return }
        do {
            try monitor.start()
        } catch {
            monitorWarning = "CoreGraphics 增强监听无法注册，仍使用系统屏幕通知。\(error.localizedDescription)"
            logger.error(monitorWarning ?? error.localizedDescription)
        }
    }

    private func handle(_ event: DisplayEvent) {
        switch event {
        case .sleep:
            isSleeping = true
            invalidatePendingWork()
            statusText = "系统休眠中，自动切换已暂停"
            logger.info("系统准备休眠")
        case .wake:
            isSleeping = false
            ownReloadSnapshot = nil
            failedAutomatic = nil
            logger.info("系统唤醒，等待显示器重新枚举")
            scheduleAutomatic(ignoreOwnReload: false)
        case .screensChanged:
            guard !isSleeping else { return }
            scheduleAutomatic(ignoreOwnReload: true)
        }
    }

    private func rulesDidChange() {
        operationError = nil
        failedAutomatic = nil
        currentRuleID = nil
        invalidatePendingWork()
        if settings.monitoringEnabled { scheduleAutomatic(ignoreOwnReload: false) }
    }

    private func invalidatePendingWork() {
        revision += 1
        debounceTask?.cancel()
        debounceTask = nil
        pendingJob = nil
    }

    private func scheduleAutomatic(ignoreOwnReload: Bool) {
        guard settings.monitoringEnabled, canEditData, !isSleeping, !isStopped else { return }
        invalidatePendingWork()
        let capturedRevision = revision
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, self.revision == capturedRevision,
                  !self.isSleeping, !self.isStopped else { return }
            self.pendingJob = Job(
                revision: capturedRevision,
                request: .automatic(ignoreOwnReload: ignoreOwnReload)
            )
            self.startWorker()
        }
    }

    private func startWorker() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            self.isBusy = true
            while let job = self.pendingJob, !self.isStopped {
                self.pendingJob = nil
                await self.perform(job)
            }
            self.isBusy = false
            self.worker = nil
        }
    }

    private func perform(_ job: Job) async {
        guard job.revision == revision, !isSleeping, !isStopped else { return }
        var automaticDecision: RuleDecision?
        var automaticSnapshot: [DetectedDisplay]?
        do {
            let target: DockPosition
            let ruleID: UUID?
            let retry: RetryOperation
            switch job.request {
            case .manual(let position):
                target = position
                ruleID = nil
                retry = .manual(position)
                statusText = "正在手动切换到\(position.title)…"
            case .automatic(let ignoreOwnReload):
                guard settings.monitoringEnabled, canEditData else { return }
                let snapshot = try provider.scan()
                displays = snapshot
                if ignoreOwnReload, Date() < ownReloadDeadline, snapshot == ownReloadSnapshot {
                    logger.info("忽略本应用重载 Dock 后未改变显示器集合的通知")
                    return
                }
                let decision = engine.evaluate(displays: snapshot, rules: rules, settings: settings)
                lastDecision = decision
                automaticDecision = decision
                automaticSnapshot = snapshot
                if let failedAutomatic, failedAutomatic.displays == snapshot,
                   failedAutomatic.decision == decision {
                    return
                }
                guard case .apply(let position, let matchedID) = decision else {
                    currentRuleID = nil
                    statusText = describe(decision)
                    logger.info(statusText)
                    let current = try await dock.readPosition()
                    if job.revision == revision && !isStopped { currentDockPosition = current }
                    return
                }
                target = position
                ruleID = matchedID
                retry = .automatic
                statusText = "正在应用\(position.title)规则…"
            }

            retryOperation = retry
            operationError = nil
            let before = displays
            let result = try await dock.apply(target) { [weak self] in
                guard let self else { return false }
                return self.revision == job.revision && !self.isSleeping && !self.isStopped
            }
            guard !isStopped else { return }
            switch result {
            case .cancelled:
                return
            case .changed(let position):
                ownReloadSnapshot = before
                ownReloadDeadline = Date().addingTimeInterval(3)
                currentDockPosition = position
                logger.info("Dock 已切换到 \(position.rawValue)，已重载一次")
            case .unchanged(let position):
                currentDockPosition = position
                logger.info("Dock 已在 \(position.rawValue)，无需写入或重载")
            }

            // 更新实际执行结果；新的配置已经入队时，由下一次匹配更新规则状态。
            if job.revision == revision {
                currentRuleID = ruleID
                if case .manual = job.request {
                    statusText = "已手动切换到\(target.title)，下一次显示器变化时恢复自动规则"
                } else if let ruleID, let rule = rules.first(where: { $0.id == ruleID }) {
                    statusText = "已应用：\(rule.displayName) → \(target.title)"
                } else {
                    statusText = "已应用无外接显示器设置：\(target.title)"
                }
            } else {
                currentRuleID = nil
                if !settings.monitoringEnabled {
                    statusText = "自动监听已暂停，Dock 当前为\(target.title)"
                } else if case .manual = job.request {
                    statusText = "已手动切换到\(target.title)，下一次显示器变化时恢复自动规则"
                } else {
                    statusText = "Dock 当前为\(target.title)，正在等待最新显示器状态"
                }
            }
        } catch {
            guard !isStopped else { return }
            currentDockPosition = nil
            currentRuleID = nil
            if let automaticDecision, let automaticSnapshot {
                failedAutomatic = (automaticSnapshot, automaticDecision)
            }
            let retry: RetryOperation
            if case .manual(let position) = job.request { retry = .manual(position) }
            else { retry = .automatic }
            statusText = "执行失败，等待手动重试或新的显示器配置"
            report(error, retry: retry)
        }
    }

    private func describe(_ decision: RuleDecision) -> String {
        guard case .keep(let reason) = decision else { return "已匹配自动规则" }
        switch reason {
        case .monitoringDisabled: return "自动监听已暂停"
        case .noExternalDisplays: return "无外接显示器，保持当前位置"
        case .unknownDisplay: return "当前外接显示器没有可用规则，保持当前位置"
        case .priorityConflict(let ids):
            let names = rules.filter { ids.contains($0.id) }.map(\.displayName).joined(separator: "、")
            return "最高优先级冲突：\(names)，保持当前位置"
        case .ambiguousIdentity: return "多个显示器提供相同身份，无法可靠区分，保持当前位置"
        }
    }

    private func report(_ error: Error, retry: RetryOperation) {
        operationError = error.localizedDescription
        retryOperation = retry
        logger.error(error.localizedDescription)
    }
}

enum RuleEditError: LocalizedError {
    case noIdentity
    case ambiguous
    case duplicate
    case emptyName

    var errorDescription: String? {
        switch self {
        case .noIdentity: return "该显示器缺少可用身份，无法保存自动规则。"
        case .ambiguous: return "当前有多个显示器提供相同身份，无法为其中一台单独建立规则。"
        case .duplicate: return "该显示器已有规则，请编辑现有规则。用户备注不能用于区分相同硬件身份。"
        case .emptyName: return "请填写显示器显示名称。"
        }
    }
}
