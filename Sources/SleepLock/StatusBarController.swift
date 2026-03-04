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
    
    private struct DurationPayload {
        let seconds: TimeInterval
        let selection: SleepController.ActiveSelection
    }

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
        menu.autoenablesItems = false

        menuTitle.target = nil
        menuTitle.action = nil
        menuTitle.isEnabled = false
        menu.addItem(menuTitle)
        menu.addItem(.separator())

        menu.addItem(sectionHeader(symbolName: "sun.max.fill", text: "Keep awake"))

        menu.addItem(
            durationItem(
                title: "1 hour",
                seconds: 60 * 60,
                selection: .keepAwake1h,
                selector: #selector(keepAwakeForDuration(_:)),
                checked: sleepController.activeSelection == .keepAwake1h
            )
        )
        menu.addItem(
            durationItem(
                title: "3 hours",
                seconds: 3 * 60 * 60,
                selection: .keepAwake3h,
                selector: #selector(keepAwakeForDuration(_:)),
                checked: sleepController.activeSelection == .keepAwake3h
            )
        )
        menu.addItem(
            durationItem(
                title: "5 hours",
                seconds: 5 * 60 * 60,
                selection: .keepAwake5h,
                selector: #selector(keepAwakeForDuration(_:)),
                checked: sleepController.activeSelection == .keepAwake5h
            )
        )
        let untilTurnedOff = indentedItem(title: "Until turned off", action: #selector(keepAwakeIndefinitely))
        untilTurnedOff.state = sleepController.activeSelection == .keepAwakeInfinite ? .on : .off
        menu.addItem(untilTurnedOff)

        menu.addItem(spacerItem())
        menu.addItem(sectionHeader(symbolName: "moon.fill", text: "Allow sleep in"))

        menu.addItem(
            durationItem(
                title: "30 min",
                seconds: 30 * 60,
                selection: .allowSleep30m,
                selector: #selector(allowSleepInDuration(_:)),
                checked: sleepController.activeSelection == .allowSleep30m
            )
        )
        menu.addItem(
            durationItem(
                title: "1 hour",
                seconds: 60 * 60,
                selection: .allowSleep1h,
                selector: #selector(allowSleepInDuration(_:)),
                checked: sleepController.activeSelection == .allowSleep1h
            )
        )
        menu.addItem(
            durationItem(
                title: "2 hours",
                seconds: 2 * 60 * 60,
                selection: .allowSleep2h,
                selector: #selector(allowSleepInDuration(_:)),
                checked: sleepController.activeSelection == .allowSleep2h
            )
        )

        menu.addItem(.separator())
        menu.addItem(item(title: "Disable SleepLock", action: #selector(turnOff)))
        menu.addItem(.separator())

        let launchItem = item(title: "Launch at login", action: #selector(toggleLaunchAtLogin))
        launchItem.state = launchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchItem)
        launchAtLoginItem = launchItem

        menu.addItem(item(title: "About SleepLock", action: #selector(showAbout)))
        menu.addItem(item(title: "Quit", action: #selector(quitApp)))

        return menu
    }

    private func item(title: String, action: Selector?) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    private func durationItem(
        title: String,
        seconds: TimeInterval,
        selection: SleepController.ActiveSelection,
        selector: Selector,
        checked: Bool
    ) -> NSMenuItem {
        let menuItem = indentedItem(title: title, action: selector)
        menuItem.representedObject = DurationPayload(seconds: seconds, selection: selection)
        menuItem.state = checked ? .on : .off
        return menuItem
    }

    private func sectionHeader(symbolName: String, text: String) -> NSMenuItem {
        let menuItem = NSMenuItem()
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        let color = NSColor.labelColor

        let title = NSMutableAttributedString()
        if let symbolImage = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: text
        )?.withSymbolConfiguration(.init(pointSize: 14, weight: .semibold)) {
            symbolImage.isTemplate = true
            let attachment = NSTextAttachment()
            attachment.image = symbolImage
            title.append(NSAttributedString(attachment: attachment))
            title.append(NSAttributedString(string: " "))
        }
        title.append(
            NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: color
                ]
            )
        )
        menuItem.attributedTitle = title
        menuItem.isEnabled = true
        menuItem.action = nil
        menuItem.target = nil

        return menuItem
    }

    private func spacerItem() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: " ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 6),
                .foregroundColor: NSColor.clear
            ]
        )
        return item
    }

    private func indentedItem(title: String, action: Selector?) -> NSMenuItem {
        let menuItem = item(title: title, action: action)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 12
        paragraphStyle.headIndent = 12

        menuItem.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        return menuItem
    }

    @objc private func turnOff() {
        sleepController.turnOff()
    }

    @objc private func keepAwakeIndefinitely() {
        sleepController.keepAwakeIndefinitely()
    }

    @objc private func keepAwakeForDuration(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? DurationPayload else { return }
        sleepController.keepAwake(for: payload.seconds, selection: payload.selection)
    }

    @objc private func allowSleepInDuration(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? DurationPayload else { return }
        sleepController.allowSleep(in: payload.seconds, selection: payload.selection)
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginManager.setEnabled(!launchAtLoginManager.isEnabled)
        launchAtLoginItem?.state = launchAtLoginManager.isEnabled ? .on : .off
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let buildVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? shortVersion

        let description = "SleepLock is a native macOS menu bar utility that controls when your Mac is allowed to sleep & when your Mac stays awake."
        let aboutText = "\(description)\n\nVersion \(shortVersion) (\(buildVersion))\nCopyright 2026"
        let credits = NSAttributedString(
            string: aboutText,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.labelColor
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "SleepLock",
            .applicationIcon: NSApp.applicationIconImage,
            .credits: credits,
            .version: shortVersion,
            .applicationVersion: "Version \(shortVersion) (\(buildVersion))"
        ])
        NSApp.activate(ignoringOtherApps: true)
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
