import Vapor

public struct GatekeeperConfig: Sendable {
    public enum Interval: Sendable {
        case second
        case minute
        case hour
        case day
    }

    public let limit: Int
    public let interval: Interval

    public init(maxRequests limit: Int, per interval: Interval) {
        self.limit = limit
        self.interval = interval
    }

    var refreshInterval: Double {
        switch interval {
        case .second: 1
        case .minute: 60
        case .hour: 3_600
        case .day: 86_400
        }
    }
}
