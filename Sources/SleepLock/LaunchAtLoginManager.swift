import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    private enum DefaultsKeys {
        static let lastLaunchAtLoginValue = "launchAtLogin.lastKnownValue"
    }

    private let defaults: UserDefaults

    private(set) var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: DefaultsKeys.lastLaunchAtLoginValue)
            onChange?(isEnabled)
        }
    }

    var onChange: ((Bool) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = false

        let desiredEnabled = defaults.bool(forKey: DefaultsKeys.lastLaunchAtLoginValue)
        if desiredEnabled, SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
        refreshFromSystemState()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
        } catch {
            refreshFromSystemState()
        }
    }

    func refreshFromSystemState() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
        case .notRegistered, .requiresApproval, .notFound:
            isEnabled = false
        @unknown default:
            isEnabled = false
        }
    }
}
