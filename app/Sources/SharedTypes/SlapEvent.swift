import Foundation

public struct SlapEvent: Codable, Sendable {
    public let amplitude: Double
    public let timestamp: Date
    public let severity: String

    public init(amplitude: Double, timestamp: Date, severity: String) {
        self.amplitude = amplitude
        self.timestamp = timestamp
        self.severity = severity
    }
}
