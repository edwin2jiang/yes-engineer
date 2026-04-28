import Foundation

public let SlapDaemonMachServiceName = "ai.slaptoyes.daemon"

@objc public protocol SlapDaemonProtocol {
    func ping(reply: @escaping (String) -> Void)
    func updateConfig(_ data: Data, reply: @escaping (Bool) -> Void)
    func subscribe(reply: @escaping (Bool) -> Void)
}

@objc public protocol SlapClientProtocol {
    func slapDetected(_ data: Data)
}
