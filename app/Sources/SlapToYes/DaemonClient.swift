import Foundation
import SharedTypes
import os

final class DaemonClient: NSObject, SlapClientProtocol {
    private let log = Logger(subsystem: "ai.slaptoyes", category: "client")
    private var connection: NSXPCConnection?
    var onSlap: ((SlapEvent) -> Void)?

    func connect() {
        let conn = NSXPCConnection(machServiceName: SlapDaemonMachServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: SlapDaemonProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: SlapClientProtocol.self)
        conn.exportedObject = self
        conn.invalidationHandler = { [weak self] in
            self?.log.error("xpc: invalidated")
            self?.connection = nil
        }
        conn.interruptionHandler = { [weak self] in
            self?.log.error("xpc: interrupted")
        }
        conn.resume()
        self.connection = conn

        proxy()?.subscribe { ok in
            self.log.info("subscribe: \(ok, privacy: .public)")
        }
    }

    func ping(reply: @escaping (String?) -> Void) {
        guard let p = proxy() else { reply(nil); return }
        p.ping { reply($0) }
    }

    func push(config: DaemonConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        proxy()?.updateConfig(data) { _ in }
    }

    private func proxy() -> SlapDaemonProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { [weak self] err in
            self?.log.error("xpc proxy: \(err.localizedDescription, privacy: .public)")
        } as? SlapDaemonProtocol
    }

    // MARK: SlapClientProtocol

    func slapDetected(_ data: Data) {
        guard let event = try? JSONDecoder().decode(SlapEvent.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onSlap?(event)
        }
    }
}
