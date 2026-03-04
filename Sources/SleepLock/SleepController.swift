import Foundation
import IOKit.pwr_mgt

@MainActor
final class SleepController {
    enum ActiveSelection: String {
        case none
        case keepAwake1h
        case keepAwake3h
        case keepAwake5h
        case keepAwakeInfinite
        case allowSleep30m
        case allowSleep1h
        case allowSleep2h
    }

    enum SleepMode: Equatable {
        case off
        case keepAwakeInfinite
        case keepAwakeUntil(Date)
        case allowSleepAfter(Date)

        var endDate: Date? {
            switch self {
            case .keepAwakeUntil(let date), .allowSleepAfter(let date):
                return date
            case .off, .keepAwakeInfinite:
                return nil
            }
        }

        var isTimed: Bool {
            endDate != nil
        }
    }

    private enum DefaultsKeys {
        static let modeKind = "sleepMode.kind"
        static let modeEnd = "sleepMode.end"
        static let activeSelection = "sleepMode.activeSelection"
    }

    enum PersistedModeKind: String {
        case off
        case keepAwakeInfinite
        case keepAwakeUntil
        case allowSleepAfter
    }

    private(set) var mode: SleepMode = .off {
        didSet {
            persistMode()
            onModeChange?(mode)
        }
    }

    private(set) var activeSelection: ActiveSelection = .none {
        didSet {
            defaults.set(activeSelection.rawValue, forKey: DefaultsKeys.activeSelection)
        }
    }

    var onModeChange: ((SleepMode) -> Void)?

    private var activityToken: NSObjectProtocol?
    private var timer: Timer?
    private var userActivityTimer: Timer?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreMode()
    }

    func turnOff() {
        apply(mode: .off, selection: .none)
    }

    func keepAwakeIndefinitely() {
        apply(mode: .keepAwakeInfinite, selection: .keepAwakeInfinite)
    }

    func keepAwake(for duration: TimeInterval, selection: ActiveSelection = .none) {
        apply(mode: .keepAwakeUntil(Date().addingTimeInterval(duration)), selection: selection)
    }

    func allowSleep(in duration: TimeInterval, selection: ActiveSelection = .none) {
        apply(mode: .allowSleepAfter(Date().addingTimeInterval(duration)), selection: selection)
    }

    func toggleQuick() {
        switch mode {
        case .off:
            keepAwakeIndefinitely()
        case .keepAwakeInfinite, .keepAwakeUntil, .allowSleepAfter:
            turnOff()
        }
    }

    func remainingTime() -> TimeInterval? {
        guard let endDate = mode.endDate else { return nil }
        return SleepTimeFormatter.remainingInterval(until: endDate)
    }

    func remainingTimeShortText() -> String? {
        guard let endDate = mode.endDate else { return nil }
        return SleepTimeFormatter.shortLabel(until: endDate)
    }

    func remainingTimeDetailedText() -> String? {
        guard let endDate = mode.endDate else { return nil }
        return SleepTimeFormatter.detailedLabel(until: endDate)
    }

    private func apply(mode newMode: SleepMode, selection newSelection: ActiveSelection) {
        // Always reset previous timer/activity before setting new mode to avoid token leaks.
        stopTimer()
        stopUserActivityUpdates()
        stopAwakeActivity()

        activeSelection = newSelection
        mode = newMode

        switch newMode {
        case .off:
            return
        case .keepAwakeInfinite:
            startAwakeActivity()
            startUserActivityUpdates()
        case .keepAwakeUntil(let endDate), .allowSleepAfter(let endDate):
            guard endDate > Date() else {
                activeSelection = .none
                mode = .off
                return
            }
            startAwakeActivity()
            startUserActivityUpdates()
            startTimerUpdates()
        }
    }

    private func startAwakeActivity() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled],
            reason: "SleepLock keeps the Mac awake"
        )
        pulseUserActivity()
    }

    private func stopAwakeActivity() {
        guard let token = activityToken else { return }
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
    }

    private func startTimerUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimerTick()
            }
        }
        timer?.tolerance = 2
        handleTimerTick()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startUserActivityUpdates() {
        userActivityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pulseUserActivity()
            }
        }
        userActivityTimer?.tolerance = 2
    }

    private func stopUserActivityUpdates() {
        userActivityTimer?.invalidate()
        userActivityTimer = nil
    }

    private func pulseUserActivity() {
        var assertionID: IOPMAssertionID = 0
        _ = IOPMAssertionDeclareUserActivity(
            "SleepLock keeps display active" as CFString,
            kIOPMUserActiveLocal,
            &assertionID
        )
    }

    private func handleTimerTick() {
        guard let endDate = mode.endDate else {
            stopTimer()
            return
        }

        if Date() >= endDate {
            let expiredMode = mode
            turnOff()
            if case .allowSleepAfter = expiredMode {
                SleepSystemController.requestSystemSleep()
            }
            return
        }

        onModeChange?(mode)
    }

    private func persistMode() {
        switch mode {
        case .off:
            defaults.set(PersistedModeKind.off.rawValue, forKey: DefaultsKeys.modeKind)
            defaults.removeObject(forKey: DefaultsKeys.modeEnd)
        case .keepAwakeInfinite:
            defaults.set(PersistedModeKind.keepAwakeInfinite.rawValue, forKey: DefaultsKeys.modeKind)
            defaults.removeObject(forKey: DefaultsKeys.modeEnd)
        case .keepAwakeUntil(let endDate):
            defaults.set(PersistedModeKind.keepAwakeUntil.rawValue, forKey: DefaultsKeys.modeKind)
            defaults.set(endDate.timeIntervalSince1970, forKey: DefaultsKeys.modeEnd)
        case .allowSleepAfter(let endDate):
            defaults.set(PersistedModeKind.allowSleepAfter.rawValue, forKey: DefaultsKeys.modeKind)
            defaults.set(endDate.timeIntervalSince1970, forKey: DefaultsKeys.modeEnd)
        }
    }

    private func restoreMode() {
        let raw = defaults.string(forKey: DefaultsKeys.modeKind)
        let kind = raw.flatMap(PersistedModeKind.init(rawValue:)) ?? .off

        switch kind {
        case .off:
            apply(mode: .off, selection: .none)
        case .keepAwakeInfinite:
            apply(mode: .keepAwakeInfinite, selection: restoreActiveSelection())
        case .keepAwakeUntil:
            restoreTimedMode(factory: SleepMode.keepAwakeUntil, selection: restoreActiveSelection())
        case .allowSleepAfter:
            restoreTimedMode(factory: SleepMode.allowSleepAfter, selection: restoreActiveSelection())
        }
    }

    private func restoreTimedMode(factory: (Date) -> SleepMode, selection: ActiveSelection) {
        let endTime = defaults.double(forKey: DefaultsKeys.modeEnd)
        guard endTime > 0 else {
            apply(mode: .off, selection: .none)
            return
        }

        let endDate = Date(timeIntervalSince1970: endTime)
        guard endDate > Date() else {
            apply(mode: .off, selection: .none)
            return
        }

        apply(mode: factory(endDate), selection: selection)
    }

    private func restoreActiveSelection() -> ActiveSelection {
        let raw = defaults.string(forKey: DefaultsKeys.activeSelection)
        return raw.flatMap(ActiveSelection.init(rawValue:)) ?? .none
    }
}
