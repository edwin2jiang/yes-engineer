import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let menubar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menubar.start()
        if ProcessInfo.processInfo.environment["ALWAYS_YES_OPEN_SETTINGS"] == "1" {
            DispatchQueue.main.async { [weak self] in
                self?.menubar.showControlPanelForUITesting()
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
