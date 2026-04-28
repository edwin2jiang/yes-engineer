import AppKit
import SharedTypes
import os

final class MenuBarController: NSObject, NSMenuDelegate {
    private let log = Logger(subsystem: "ai.slaptoyes", category: "menubar")
    private let store = ConfigStore()
    private let client = DaemonClient()
    private var statusItem: NSStatusItem!
    private var pulseTimer: Timer?
    private var sensitivityCommitTimer: Timer?

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: "Always Yes")
            btn.image?.isTemplate = true
            btn.toolTip = "Always Yes"
        }

        rebuildMenu()
        client.onSlap = { [weak self] ev in self?.handleSlap(ev) }
        client.connect()
        client.push(config: store.config.daemonConfig())

        // First-run install attempt; ignore failures so user can retry from menu.
        if DaemonInstaller.status == .notRegistered {
            try? DaemonInstaller.install()
        }

        // Trigger accessibility prompt if needed.
        Permissions.requestAccessibility()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let sliderItem = NSMenuItem()
        let sliderView = SensitivitySliderView(initial: store.config.minAmplitude)
        sliderView.onChange = { [weak self] v in self?.applySensitivity(v) }
        sliderItem.view = sliderView
        menu.addItem(sliderItem)

        menu.addItem(NSMenuItem.separator())

        let pause = NSMenuItem(title: store.config.paused ? "恢复（已暂停）" : "暂停",
                               action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        menu.addItem(pause)

        menu.addItem(NSMenuItem.separator())

        let modeMenu = NSMenu()
        for m in [AppMode.whitelist, .global] {
            let item = NSMenuItem(title: modeName(m), action: #selector(setMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = m.rawValue
            item.state = (store.config.mode == m) ? .on : .off
            modeMenu.addItem(item)
        }
        let modeRoot = NSMenuItem(title: "应用范围", action: nil, keyEquivalent: "")
        modeRoot.submenu = modeMenu
        menu.addItem(modeRoot)

        let install = NSMenuItem(title: "守护进程：\(DaemonInstaller.statusDescription)",
                                  action: #selector(reinstallDaemon), keyEquivalent: "")
        install.target = self
        menu.addItem(install)

        let axOK = Permissions.isAccessibilityTrusted
        let axItem = NSMenuItem(title: "辅助功能：\(axOK ? "已授权" : "未授权（点此申请）")",
                                action: #selector(requestAX), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "退出 Always Yes", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func applySensitivity(_ v: Double) {
        // Debounce save+push: only fire 200ms after the last drag tick to
        // avoid log spam and dozens of disk writes per drag.
        sensitivityCommitTimer?.invalidate()
        sensitivityCommitTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            var cfg = self.store.config
            cfg.minAmplitude = v
            self.store.save(cfg)
            self.client.push(config: cfg.daemonConfig())
        }
    }

    private func modeName(_ m: AppMode) -> String {
        switch m {
        case .whitelist: return "所有 AI 编程应用"
        case .global: return "所有应用"
        }
    }

    // MARK: Slap handling

    private func handleSlap(_ ev: SlapEvent) {
        log.info("slap: amp=\(ev.amplitude, format: .fixed(precision: 4))")
        pulse()

        let cfg = store.config
        if cfg.paused { return }
        switch cfg.mode {
        case .whitelist:
            let bid = Frontmost.bundleID()
            guard cfg.apps.contains(bid) else {
                log.info("ignored: front=\(bid, privacy: .public) not whitelisted")
                return
            }
            sendEnterOrPrompt()
        case .global:
            sendEnterOrPrompt()
        }
    }

    private func sendEnterOrPrompt() {
        guard Permissions.isAccessibilityTrusted else {
            log.error("accessibility not trusted; prompting")
            Permissions.requestAccessibility()
            return
        }
        let ok = KeyPress.sendEnter()
        log.info("sendEnter=\(ok, privacy: .public)")
    }

    private func pulse() {
        guard let btn = statusItem.button else { return }
        btn.alphaValue = 0.3
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
            DispatchQueue.main.async { btn.alphaValue = 1.0 }
        }
    }

    // MARK: Menu actions

    @objc private func togglePause() {
        var cfg = store.config
        cfg.paused.toggle()
        store.save(cfg)
        rebuildMenu()
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let m = AppMode(rawValue: raw) else { return }
        var cfg = store.config
        cfg.mode = m
        store.save(cfg)
        rebuildMenu()
    }

    @objc private func requestAX() {
        if !Permissions.requestAccessibility() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        rebuildMenu()
    }

    @objc private func reinstallDaemon() {
        do {
            try DaemonInstaller.install()
        } catch {
            let alert = NSAlert()
            alert.messageText = "守护进程安装失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
