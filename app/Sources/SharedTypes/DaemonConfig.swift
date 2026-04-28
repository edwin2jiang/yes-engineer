import Foundation

public struct DaemonConfig: Codable, Sendable {
    public var minAmplitude: Double
    public var cooldownMs: Int

    public init(minAmplitude: Double = 0.144, cooldownMs: Int = 600) {
        self.minAmplitude = minAmplitude
        self.cooldownMs = cooldownMs
    }
}
