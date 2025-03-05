import Vapor

/// Reponsible for generating a cache key for a specific `Request`
public protocol GatekeeperKeyMaker: Sendable {
    func make(for req: Request) async throws -> String
}
