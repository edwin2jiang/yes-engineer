import Foundation
import ServiceManagement
import os

enum DaemonInstaller {
    private static let log = Logger(subsystem: "ai.slaptoyes", category: "installer")
    static let plistName = "ai.slaptoyes.daemon.plist"

    static var service: SMAppService {
        SMAppService.daemon(plistName: plistName)
    }

    static func install() throws {
        try service.register()
        log.info("daemon registered")
    }

    static func uninstall() throws {
        try service.unregister()
        log.info("daemon unregistered")
    }

    static var status: SMAppService.Status {
        service.status
    }

    static var statusDescription: String {
        switch service.status {
        case .notRegistered: return "未安装"
        case .enabled: return "已启用"
        case .requiresApproval: return "需在系统设置中批准"
        case .notFound: return "未找到 plist"
        @unknown default: return "未知"
        }
    }
}
