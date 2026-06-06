import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private static let customIdleIconName = "IconBarLight"
    private static let customIdleIconExt = "png"

    private let statusItem: NSStatusItem
    private let sleepController: SleepController
    private let launchAtLoginManager = LaunchAtLoginManager()
    private let popover = NSPopover()
    private let popoverViewModel = SleepLockPopoverViewModel()

    init(controller: SleepController) {
        self.sleepController = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusButton()
        configurePopover()
        bindState()
        updateUI()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.font = .systemFont(ofSize: 11, weight: .medium)
        button.imagePosition = .imageLeading
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 220, height: 250)
        popover.contentViewController = NSHostingController(rootView: makePopoverView())
    }

    private func bindState() {
        sleepController.onModeChange = { [weak self] _ in
            self?.updateUI()
        }

        launchAtLoginManager.onChange = { [weak self] _ in
            self?.updateUI()
        }
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .leftMouseUp && event.modifierFlags.contains(.option) {
            sleepController.toggleQuick()
            return
        }

        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        updatePopoverContent()
        button.highlight(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updatePopoverContent() {
        popover.contentViewController = NSHostingController(rootView: makePopoverView())
    }

    private func makePopoverView() -> some View {
        SleepLockPopoverView(
            viewModel: popoverViewModel,
            onKeepAwake1Hour: { [weak self] in
                self?.keepAwake(for: 60 * 60, selection: .keepAwake1h)
            },
            onKeepAwake3Hours: { [weak self] in
                self?.keepAwake(for: 3 * 60 * 60, selection: .keepAwake3h)
            },
            onKeepAwake5Hours: { [weak self] in
                self?.keepAwake(for: 5 * 60 * 60, selection: .keepAwake5h)
            },
            onKeepAwakeUntilTurnedOff: { [weak self] in
                self?.keepAwakeIndefinitely()
            },
            onAllowSleep30Minutes: { [weak self] in
                self?.allowSleep(in: 30 * 60, selection: .allowSleep30m)
            },
            onAllowSleep1Hour: { [weak self] in
                self?.allowSleep(in: 60 * 60, selection: .allowSleep1h)
            },
            onAllowSleep2Hours: { [weak self] in
                self?.allowSleep(in: 2 * 60 * 60, selection: .allowSleep2h)
            },
            onDisable: { [weak self] in
                self?.turnOff()
            },
            onToggleLaunchAtLogin: { [weak self] in
                self?.toggleLaunchAtLogin()
            },
            onAbout: { [weak self] in
                self?.showAbout()
            },
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )
    }

    private func keepAwake(for duration: TimeInterval, selection: SleepController.ActiveSelection) {
        sleepController.keepAwake(for: duration, selection: selection)
        closePopover()
    }

    private func allowSleep(in duration: TimeInterval, selection: SleepController.ActiveSelection) {
        sleepController.allowSleep(in: duration, selection: selection)
        closePopover()
    }

    private func turnOff() {
        sleepController.turnOff()
        closePopover()
    }

    private func keepAwakeIndefinitely() {
        sleepController.keepAwakeIndefinitely()
        closePopover()
    }

    private func toggleLaunchAtLogin() {
        launchAtLoginManager.setEnabled(!launchAtLoginManager.isEnabled)
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showAbout() {
        closePopover()

        let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let buildVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? shortVersion
        let currentYear = Calendar.current.component(.year, from: Date())

        let description = "SleepLock is a native macOS menu bar utility that controls when your Mac is allowed to sleep & when your Mac stays awake."
        let aboutText = "\(description)\n\nVersion \(shortVersion) (\(buildVersion))\nCopyright \(currentYear)"
        let credits = NSAttributedString(
            string: aboutText,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.labelColor
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "SleepLock",
            .applicationIcon: NSApp.applicationIconImage as Any,
            .credits: credits,
            .version: shortVersion,
            .applicationVersion: "Version \(shortVersion) (\(buildVersion))"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateUI() {
        updateStatusButtonTitle()
        updateTooltip()
        popoverViewModel.update(
            mode: sleepController.mode,
            activeSelection: sleepController.activeSelection,
            isLaunchAtLoginEnabled: launchAtLoginManager.isEnabled
        )
    }

    private func updateStatusButtonTitle() {
        guard let button = statusItem.button else { return }

        let image: NSImage?
        let timeLabel: String?

        switch sleepController.mode {
        case .off:
            image = makeStartupCompositeIcon()
            timeLabel = nil
        case .keepAwakeInfinite:
            image = symbolImage(name: "sun.max.fill")
            timeLabel = nil
        case .keepAwakeUntil:
            image = symbolImage(name: "sun.max.fill")
            timeLabel = sleepController.remainingTimeShortText()
        case .allowSleepAfter:
            image = symbolImage(name: "moon.fill")
            timeLabel = sleepController.remainingTimeShortText()
        }

        button.image = image

        if let timeLabel {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium)
            ]
            button.attributedTitle = NSAttributedString(string: " \(timeLabel)", attributes: attributes)
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    private func symbolImage(name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "SleepLock status")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    private func makeStartupCompositeIcon() -> NSImage? {
        if let custom = makeCustomIdleIcon() {
            return custom
        }

        let size = NSSize(width: 19.4, height: 16.9)
        let moonConfig = NSImage.SymbolConfiguration(pointSize: 15.1, weight: .regular)
        let sunConfig = NSImage.SymbolConfiguration(pointSize: 9.7, weight: .regular)
        guard
            let moon = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "SleepLock startup moon")?
                .withSymbolConfiguration(moonConfig),
            let sun = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "SleepLock startup sun")?
                .withSymbolConfiguration(sunConfig)
        else {
            return symbolImage(name: "moon.fill")
        }

        moon.isTemplate = true
        sun.isTemplate = true

        let composite = NSImage(size: size, flipped: false) { _ in
            let moonRect = NSRect(x: 1.2, y: 1.2, width: 14.5, height: 14.5)
            let sunRect = NSRect(x: 8.5, y: 7.3, width: 9.4, height: 9.4)
            moon.draw(in: moonRect)
            sun.draw(in: sunRect)
            return true
        }
        composite.isTemplate = true
        return composite
    }

    private func makeCustomIdleIcon() -> NSImage? {
        guard
            let imageURL = Bundle.main.url(
                forResource: Self.customIdleIconName,
                withExtension: Self.customIdleIconExt
            ),
            let source = NSImage(contentsOf: imageURL)
        else {
            return nil
        }

        let size = NSSize(width: 19.4, height: 16.9)
        let rendered = NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        rendered.isTemplate = true
        return rendered
    }

    private func updateTooltip() {
        let tooltip: String

        switch sleepController.mode {
        case .off:
            tooltip = "SleepLock off — Mac sleeps normally"
        case .keepAwakeInfinite:
            tooltip = "SleepLock active — Mac will stay awake"
        case .keepAwakeUntil:
            tooltip = "Mac will stay awake for \(sleepController.remainingTimeDetailedText() ?? "1m")"
        case .allowSleepAfter:
            tooltip = "Mac will be allowed to sleep in \(sleepController.remainingTimeDetailedText() ?? "1m")"
        }

        statusItem.button?.toolTip = tooltip
    }
}
