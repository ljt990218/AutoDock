import ServiceManagement

@MainActor
struct LaunchAtLoginService {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    var isRegistered: Bool {
        status == .enabled || status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if status == .notRegistered || status == .notFound {
                try SMAppService.mainApp.register()
            }
        } else if isRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
