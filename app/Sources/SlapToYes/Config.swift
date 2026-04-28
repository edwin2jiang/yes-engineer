import Foundation
import SharedTypes

enum AppMode: String, Codable {
    case whitelist, global
}

struct AppConfig: Codable {
    var minAmplitude: Double = 0.144
    var cooldownMs: Int = 600
    var mode: AppMode = .whitelist
    var apps: [String] = AppConfig.defaultApps
    var paused: Bool = false

    static let defaultApps: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "net.kovidgoyal.kitty",
        "io.alacritty",
        "co.zeit.hyper",
        "org.tabby",
        "com.github.wez.wezterm",
        "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf",
        "dev.zed.Zed",
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode",
    ]

    func daemonConfig() -> DaemonConfig {
        DaemonConfig(minAmplitude: minAmplitude, cooldownMs: cooldownMs)
    }
}

final class ConfigStore {
    private let url: URL
    private(set) var config: AppConfig

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SlapToYes", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) {
            self.config = cfg
        } else {
            self.config = AppConfig()
        }
    }

    func save(_ cfg: AppConfig) {
        self.config = cfg
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(cfg) {
            try? data.write(to: url)
        }
    }
}
