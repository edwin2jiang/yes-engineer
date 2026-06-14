import AppKit
import SharedTypes
import os

final class MenuBarController: NSObject, NSMenuDelegate {
    private let log = Logger(subsystem: "ai.slaptoyes", category: "menubar")
    private let store = ConfigStore()
    private let client = DaemonClient()
    private let hotkeys = HotkeyManager()
    private let feedback = FeedbackPresenter()
    private var statusItem: NSStatusItem!
    private var pulseTimer: Timer?
    private var sensitivityCommitTimer: Timer?
    private var accessibilityPromptTimer: Timer?
    private var shortcutSettings: ShortcutSettingsWindowController?
    private var settingsWindow: SettingsWindowController?

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: "Always Yes")
            btn.image?.isTemplate = true
            btn.toolTip = "Always Yes"
        }

        // First-run install attempt; ignore failures so user can retry from menu.
        if DaemonInstaller.status == .notRegistered {
            try? DaemonInstaller.install()
        }

        rebuildMenu()
        hotkeys.onFire = { [weak self] actionID in
            self?.performActionIfAllowed(actionID: actionID, source: "hotkey")
        }
        hotkeys.register(actions: store.config.activeHotkeyActions)
        client.onSlap = { [weak self] ev in self?.handleSlap(ev) }
        client.onConnected = { [weak self] in
            guard let self = self else { return }
            self.client.push(config: self.store.config.daemonConfig())
        }
        client.connect()

        updateAutoAccessibilityPrompting()
    }

    func showControlPanelForUITesting() {
        openControlPanel()
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

        let panel = NSMenuItem(title: "打开控制面板…", action: #selector(openControlPanel), keyEquivalent: ",")
        panel.target = self
        menu.addItem(panel)

        menu.addItem(NSMenuItem.separator())

        let pauseMenu = NSMenu()
        for (title, key, paused) in [
            ("全部暂停", "all", store.config.paused),
            ("暂停拍击动作", "slap", store.config.pauseSlapActions),
            ("暂停快捷键", "hotkeys", store.config.pauseHotkeys),
        ] {
            let item = NSMenuItem(title: title, action: #selector(togglePauseFlag(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            item.state = paused ? .on : .off
            pauseMenu.addItem(item)
        }
        let pauseRootTitle: String
        if store.config.paused {
            pauseRootTitle = "暂停控制（全部已暂停）"
        } else if store.config.pauseSlapActions || store.config.pauseHotkeys {
            pauseRootTitle = "暂停控制（部分已暂停）"
        } else {
            pauseRootTitle = "暂停控制"
        }
        let pauseRoot = NSMenuItem(title: pauseRootTitle, action: nil, keyEquivalent: "")
        pauseRoot.submenu = pauseMenu
        menu.addItem(pauseRoot)

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

        let slapMenu = NSMenu()
        for action in store.config.textActions {
            let item = NSMenuItem(title: action.menuTitle, action: #selector(setSlapAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action.id
            item.state = (store.config.slapActionID == action.id) ? .on : .off
            slapMenu.addItem(item)
        }
        let slapRoot = NSMenuItem(title: "拍击动作", action: nil, keyEquivalent: "")
        slapRoot.submenu = slapMenu
        menu.addItem(slapRoot)

        let shortcutsMenu = NSMenu()
        for action in store.config.textActions where action.enabled {
            let item = NSMenuItem(title: "\(action.menuTitle)  \(action.hotkey.displayName)",
                                  action: #selector(runShortcutAction(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = action.id
            shortcutsMenu.addItem(item)
        }
        shortcutsMenu.addItem(NSMenuItem.separator())
        let editShortcuts = NSMenuItem(title: "编辑快捷键与输入内容…",
                                       action: #selector(openShortcutSettings),
                                       keyEquivalent: ",")
        editShortcuts.target = self
        shortcutsMenu.addItem(editShortcuts)
        let shortcutsRoot = NSMenuItem(title: "快捷键", action: nil, keyEquivalent: "")
        shortcutsRoot.submenu = shortcutsMenu
        menu.addItem(shortcutsRoot)

        let feedbackMenu = NSMenu()
        for mode in FeedbackMode.allCases {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(setFeedbackMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (store.config.feedbackMode == mode) ? .on : .off
            feedbackMenu.addItem(item)
        }
        let feedbackRoot = NSMenuItem(title: "执行反馈", action: nil, keyEquivalent: "")
        feedbackRoot.submenu = feedbackMenu
        menu.addItem(feedbackRoot)

        menu.addItem(NSMenuItem.separator())

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
            self.applyConfig(cfg, feedbackMessage: nil)
        }
    }

    private func applyConfig(_ cfg: AppConfig, feedbackMessage: String? = nil) {
        store.save(cfg)
        client.push(config: cfg.daemonConfig())
        hotkeys.register(actions: cfg.activeHotkeyActions)
        updateAutoAccessibilityPrompting()
        rebuildMenu()
        shortcutSettings?.updateConfig(cfg)
        settingsWindow?.updateConfig(cfg)
        if let feedbackMessage = feedbackMessage {
            showFeedback(feedbackMessage)
        }
    }

    private func modeName(_ m: AppMode) -> String {
        switch m {
        case .whitelist: return "所有 AI 编程应用"
        case .global: return "所有应用"
        }
    }

    private func updateAutoAccessibilityPrompting() {
        accessibilityPromptTimer?.invalidate()
        accessibilityPromptTimer = nil

        guard store.config.autoRequestAccessibility, !Permissions.isAccessibilityTrusted else { return }
        Permissions.requestAccessibilityIfNeeded()
        accessibilityPromptTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            guard self.store.config.autoRequestAccessibility, !Permissions.isAccessibilityTrusted else {
                timer.invalidate()
                self.accessibilityPromptTimer = nil
                return
            }
            Permissions.requestAccessibilityIfNeeded()
            self.settingsWindow?.refreshStatus()
            self.rebuildMenu()
        }
    }

    // MARK: Slap handling

    private func handleSlap(_ ev: SlapEvent) {
        log.info("slap: amp=\(ev.amplitude, format: .fixed(precision: 4))")
        pulse()

        let cfg = store.config
        if cfg.isSlapPaused { return }
        switch cfg.mode {
        case .whitelist:
            let bid = Frontmost.bundleID()
            guard cfg.apps.contains(bid) else {
                log.info("ignored: front=\(bid, privacy: .public) not whitelisted")
                return
            }
            performAction(id: cfg.slapActionID)
        case .global:
            performAction(id: cfg.slapActionID)
        }
    }

    private func performActionIfAllowed(actionID: String, source: String) {
        let cfg = store.config
        if cfg.isHotkeyPaused {
            log.info("ignored \(source, privacy: .public): paused")
            return
        }
        switch cfg.mode {
        case .whitelist:
            let bid = Frontmost.bundleID()
            guard cfg.apps.contains(bid) else {
                log.info("ignored \(source, privacy: .public): front=\(bid, privacy: .public) not whitelisted")
                return
            }
            performAction(id: actionID)
        case .global:
            performAction(id: actionID)
        }
    }

    private func performAction(id: String) {
        guard Permissions.isAccessibilityTrusted else {
            log.error("accessibility not trusted; ignoring action")
            return
        }
        let action = store.config.action(id: id)
        KeyPress.send(text: action.input, pressReturn: action.autoPressReturn) { [weak self] ok in
            guard let self = self else { return }
            self.log.info("performAction \(action.id, privacy: .public)=\(ok, privacy: .public)")
            if ok {
                self.showFeedback(self.feedbackMessage(for: action))
            }
        }
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

    @objc private func togglePauseFlag(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        var cfg = store.config
        switch key {
        case "all":
            cfg.paused.toggle()
        case "slap":
            cfg.pauseSlapActions.toggle()
        case "hotkeys":
            cfg.pauseHotkeys.toggle()
        default:
            return
        }
        applyConfig(cfg)
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let m = AppMode(rawValue: raw) else { return }
        var cfg = store.config
        cfg.mode = m
        applyConfig(cfg)
    }

    @objc private func setSlapAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        var cfg = store.config
        cfg.slapActionID = id
        applyConfig(cfg)
    }

    @objc private func setFeedbackMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = FeedbackMode(rawValue: raw) else { return }
        var cfg = store.config
        cfg.feedbackMode = mode
        applyConfig(cfg, feedbackMessage: "执行反馈：\(mode.menuTitle)")
    }

    @objc private func runShortcutAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        performActionIfAllowed(actionID: id, source: "menu")
    }

    @objc private func openShortcutSettings() {
        let controller = ShortcutSettingsWindowController(config: store.config)
        controller.onSave = { [weak self] cfg in
            guard let self = self else { return }
            self.applyConfig(cfg, feedbackMessage: "快捷键与输入内容已保存")
        }
        controller.onOpenControlPanel = { [weak self] in
            self?.openControlPanel()
        }
        controller.onHotkeyRecordingChanged = { [weak self] recording in
            self?.setHotkeyRecording(recording)
        }
        shortcutSettings = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openControlPanel() {
        let controller = settingsWindow ?? SettingsWindowController(config: store.config, configURL: store.url)
        controller.onSave = { [weak self] cfg in
            self?.applyConfig(cfg, feedbackMessage: "控制面板设置已保存")
        }
        controller.onRequestAccessibility = { [weak self] in
            self?.requestAX()
            self?.settingsWindow?.refreshStatus()
        }
        controller.onReinstallDaemon = { [weak self] in
            self?.reinstallDaemon()
            self?.settingsWindow?.refreshStatus()
        }
        controller.onHotkeyRecordingChanged = { [weak self] recording in
            self?.setHotkeyRecording(recording)
        }
        settingsWindow = controller
        controller.updateConfig(store.config)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setHotkeyRecording(_ recording: Bool) {
        hotkeys.register(actions: recording ? [] : store.config.activeHotkeyActions)
    }

    private func showFeedback(_ message: String) {
        feedback.show(message, mode: store.config.feedbackMode, statusItem: statusItem)
    }

    private func feedbackMessage(for action: TextAction) -> String {
        let text = action.input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return action.autoPressReturn ? "已执行：按回车" : "已执行：\(action.title)"
        }
        let preview = text.count > 28 ? "\(text.prefix(28))…" : text
        if action.autoPressReturn {
            return "已执行：输入 \(preview) 并回车"
        }
        return "已执行：输入 \(preview)"
    }

    @objc private func requestAX() {
        if !Permissions.requestAccessibility(prompt: true) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        rebuildMenu()
    }

    @objc private func reinstallDaemon() {
        do {
            try DaemonInstaller.install()
            client.connect()
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
