import AppKit

final class ShortcutSettingsWindowController: NSWindowController {
    private var config: AppConfig
    private var rows: [ShortcutRowView] = []
    private let rowsStack = NSStackView()
    var onSave: ((AppConfig) -> Void)?
    var onOpenControlPanel: (() -> Void)?

    init(config: AppConfig) {
        self.config = config

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 280),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "快捷键与输入内容"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        rowsStack.orientation = .vertical
        rowsStack.spacing = 8
        root.addArrangedSubview(rowsStack)
        reloadRows()

        let note = NSTextField(labelWithString: "快捷键可写成 ⇧⌥Y、option+shift+y 或 control+option+return。输入内容为空时只按回车，可取消“回车”只输入文本。")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 12)
        root.addArrangedSubview(note)

        let spacer = NSView()
        root.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        let restore = NSButton(title: "恢复默认", target: self, action: #selector(restoreDefaults))
        let openPanel = NSButton(title: "打开控制面板…", target: self, action: #selector(openControlPanel))
        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel))
        let save = NSButton(title: "保存", target: self, action: #selector(save))
        save.keyEquivalent = "\r"

        let buttonSpacer = NSView()
        buttons.addArrangedSubview(restore)
        buttons.addArrangedSubview(openPanel)
        buttons.addArrangedSubview(buttonSpacer)
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(save)
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        root.addArrangedSubview(buttons)
    }

    private func reloadRows() {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rows.removeAll()

        rowsStack.addArrangedSubview(makeHeaderRow())
        for action in config.textActions {
            let row = ShortcutRowView(action: action)
            rows.append(row)
            rowsStack.addArrangedSubview(row)
        }
    }

    func updateConfig(_ cfg: AppConfig) {
        config = cfg
        reloadRows()
    }

    private func makeHeaderRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        for (title, width) in [("启用", 52), ("名称", 140), ("输入内容", 260), ("回车", 56), ("快捷键", 150)] {
            let label = NSTextField(labelWithString: title)
            label.font = .boldSystemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.widthAnchor.constraint(equalToConstant: CGFloat(width)).isActive = true
            row.addArrangedSubview(label)
        }
        return row
    }

    @objc private func restoreDefaults() {
        config.textActions = TextAction.defaults
        reloadRows()
    }

    @objc private func cancel() {
        close()
    }

    @objc private func openControlPanel() {
        onOpenControlPanel?()
    }

    @objc private func save() {
        var nextActions: [TextAction] = []
        var seenHotkeys = Set<String>()

        for row in rows {
            guard var action = row.action() else {
                showValidationError("有一个快捷键格式不正确。")
                return
            }
            if action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showValidationError("动作名称不能为空。")
                return
            }
            let signature = "\(action.hotkey.modifiers):\(action.hotkey.keyCode)"
            if action.enabled && seenHotkeys.contains(signature) {
                showValidationError("快捷键 \(action.hotkey.displayName) 被重复使用。")
                return
            }
            if action.enabled {
                seenHotkeys.insert(signature)
            }
            action.input = action.input.trimmingCharacters(in: .newlines)
            nextActions.append(action)
        }

        config.textActions = nextActions
        if !nextActions.contains(where: { $0.id == config.slapActionID }) {
            config.slapActionID = nextActions.first(where: { $0.id == TextAction.defaultSlapActionID })?.id
                ?? nextActions.first?.id
                ?? TextAction.defaultSlapActionID
        }
        onSave?(config)
        close()
    }

    private func showValidationError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "无法保存快捷键"
        alert.informativeText = message
        alert.runModal()
    }
}

private final class ShortcutRowView: NSStackView {
    private let sourceID: String
    private let enabledBox: NSButton
    private let titleField: NSTextField
    private let inputField: NSTextField
    private let returnBox: NSButton
    private let hotkeyField: NSTextField

    init(action: TextAction) {
        self.sourceID = action.id
        self.enabledBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        self.titleField = NSTextField(string: action.title)
        self.inputField = NSTextField(string: action.input)
        self.returnBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        self.hotkeyField = NSTextField(string: action.hotkey.displayName)
        super.init(frame: .zero)

        orientation = .horizontal
        spacing = 8

        enabledBox.state = action.enabled ? .on : .off
        returnBox.state = action.autoPressReturn ? .on : .off
        enabledBox.widthAnchor.constraint(equalToConstant: 52).isActive = true
        titleField.widthAnchor.constraint(equalToConstant: 140).isActive = true
        inputField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        returnBox.widthAnchor.constraint(equalToConstant: 56).isActive = true
        hotkeyField.widthAnchor.constraint(equalToConstant: 150).isActive = true

        addArrangedSubview(enabledBox)
        addArrangedSubview(titleField)
        addArrangedSubview(inputField)
        addArrangedSubview(returnBox)
        addArrangedSubview(hotkeyField)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func action() -> TextAction? {
        guard let hotkey = HotkeySpec.parse(hotkeyField.stringValue) else { return nil }
        return TextAction(id: sourceID,
                          title: titleField.stringValue,
                          input: inputField.stringValue,
                          autoPressReturn: returnBox.state == .on,
                          hotkey: hotkey,
                          enabled: enabledBox.state == .on)
    }
}
