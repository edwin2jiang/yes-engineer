import CoreGraphics

enum KeyPress {
    static let kVKReturn: CGKeyCode = 0x24

    static func sendEnter() -> Bool {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return false }
        guard
            let down = CGEvent(keyboardEventSource: src, virtualKey: kVKReturn, keyDown: true),
            let up = CGEvent(keyboardEventSource: src, virtualKey: kVKReturn, keyDown: false)
        else { return false }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
