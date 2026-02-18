import AppKit
import SwiftUI

@main
struct SleepLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sleepController: SleepController?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = SleepController()
        sleepController = controller

        statusBarController = StatusBarController(controller: controller)
        NSApp.setActivationPolicy(.accessory)
    }
}
