import AppKit

@MainActor
final class StatusBarController: NSObject {
    private static let customIdleIconName = "SleepLockStatus_36x36@2x"
    private static let customIdleIconExt = "png"

    private let statusItem: NSStatusItem
    private let sleepController: SleepController
    private let launchAtLoginManager = LaunchAtLoginManager()

    private let menuTitle = NSMenuItem(title: "SleepLock", action: nil, keyEquivalent: "")
    private var launchAtLoginItem: NSMenuItem?

    init(controller: SleepController) {
        self.sleepController = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusButton()
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

        showMenu()
    }

    private func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menuTitle.isEnabled = false
        menu.addItem(menuTitle)
        menu.addItem(.separator())

        menu.addItem(item(title: "Turn Off", action: #selector(turnOff)))

        menu.addItem(.separator())
        let keepAwakeHeader = NSMenuItem(title: "Keep a wake for:", action: nil, keyEquivalent: "")
        keepAwakeHeader.isEnabled = false
        menu.addItem(keepAwakeHeader)

        menu.addItem(durationItem(title: "1 hour", seconds: 60 * 60, selector: #selector(keepAwakeForDuration(_:))))
        menu.addItem(durationItem(title: "3 Hour", seconds: 3 * 60 * 60, selector: #selector(keepAwakeForDuration(_:))))
        menu.addItem(durationItem(title: "5 Hour", seconds: 5 * 60 * 60, selector: #selector(keepAwakeForDuration(_:))))
        menu.addItem(item(title: "Until manually turn off", action: #selector(keepAwakeIndefinitely)))

        menu.addItem(.separator())
        let allowSleepHeader = NSMenuItem(title: "Allow Sleep In:", action: nil, keyEquivalent: "")
        allowSleepHeader.isEnabled = false
        menu.addItem(allowSleepHeader)

        menu.addItem(durationItem(title: "30 min", seconds: 30 * 60, selector: #selector(allowSleepInDuration(_:))))
        menu.addItem(durationItem(title: "1 hour", seconds: 60 * 60, selector: #selector(allowSleepInDuration(_:))))
        menu.addItem(durationItem(title: "2 hour", seconds: 2 * 60 * 60, selector: #selector(allowSleepInDuration(_:))))

        menu.addItem(.separator())

        let launchItem = item(title: "Launch at login", action: #selector(toggleLaunchAtLogin))
        launchItem.state = launchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchItem)
        launchAtLoginItem = launchItem

        menu.addItem(item(title: "Quit", action: #selector(quitApp)))

        return menu
    }

    private func item(title: String, action: Selector?) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    private func durationItem(title: String, seconds: TimeInterval, selector: Selector) -> NSMenuItem {
        let menuItem = item(title: title, action: selector)
        menuItem.representedObject = seconds
        return menuItem
    }

    @objc private func turnOff() {
        sleepController.turnOff()
    }

    @objc private func keepAwakeIndefinitely() {
        sleepController.keepAwakeIndefinitely()
    }

    @objc private func keepAwakeForDuration(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        sleepController.keepAwake(for: seconds)
    }

    @objc private func allowSleepInDuration(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        sleepController.allowSleep(in: seconds)
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginManager.setEnabled(!launchAtLoginManager.isEnabled)
        launchAtLoginItem?.state = launchAtLoginManager.isEnabled ? .on : .off
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateUI() {
        updateStatusButtonTitle()
        updateTooltip()
        launchAtLoginItem?.state = launchAtLoginManager.isEnabled ? .on : .off
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

        let composite = NSImage(size: size, flipped: false) { rect in
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
            let imageURL = Bundle.module.url(
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
        rendered.isTemplate = false
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
