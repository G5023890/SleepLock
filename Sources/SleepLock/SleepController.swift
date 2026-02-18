import Foundation

@MainActor
final class SleepController {
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

    var onModeChange: ((SleepMode) -> Void)?

    private var activityToken: NSObjectProtocol?
    private var timer: Timer?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreMode()
    }

    func turnOff() {
        apply(mode: .off)
    }

    func keepAwakeIndefinitely() {
        apply(mode: .keepAwakeInfinite)
    }

    func keepAwake(for duration: TimeInterval) {
        apply(mode: .keepAwakeUntil(Date().addingTimeInterval(duration)))
    }

    func allowSleep(in duration: TimeInterval) {
        apply(mode: .allowSleepAfter(Date().addingTimeInterval(duration)))
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

    private func apply(mode newMode: SleepMode) {
        // Always reset previous timer/activity before setting new mode to avoid token leaks.
        stopTimer()
        stopAwakeActivity()

        mode = newMode

        switch newMode {
        case .off:
            return
        case .keepAwakeInfinite:
            startAwakeActivity()
        case .keepAwakeUntil(let endDate), .allowSleepAfter(let endDate):
            guard endDate > Date() else {
                mode = .off
                return
            }
            startAwakeActivity()
            startTimerUpdates()
        }
    }

    private func startAwakeActivity() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled],
            reason: "SleepLock keeps the Mac awake"
        )
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
            apply(mode: .off)
        case .keepAwakeInfinite:
            apply(mode: .keepAwakeInfinite)
        case .keepAwakeUntil:
            restoreTimedMode(factory: SleepMode.keepAwakeUntil)
        case .allowSleepAfter:
            restoreTimedMode(factory: SleepMode.allowSleepAfter)
        }
    }

    private func restoreTimedMode(factory: (Date) -> SleepMode) {
        let endTime = defaults.double(forKey: DefaultsKeys.modeEnd)
        guard endTime > 0 else {
            apply(mode: .off)
            return
        }

        let endDate = Date(timeIntervalSince1970: endTime)
        guard endDate > Date() else {
            apply(mode: .off)
            return
        }

        apply(mode: factory(endDate))
    }
}
