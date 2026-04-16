import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    // Holding this token tells macOS never to App-Nap or suspend us
    private var activityToken: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .idleDisplaySleepDisabled],
            reason: "Klok menu bar clock must update every second"
        )
        statusBarController = StatusBarController()
    }
}
