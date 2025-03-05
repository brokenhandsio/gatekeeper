import Vapor

/// A rate limiting middleware for Vapor applications.
///
/// Gatekeeper provides configurable rate limiting functionality to control
/// how frequently requests can be made to your application's endpoints. It uses
/// a cache to track request counts for each client and enforces configured limits.
public struct Gatekeeper {
    private let cache: Cache
    private let config: GatekeeperConfig
    private let keyMaker: GatekeeperKeyMaker

    /// Creates a new Gatekeeper instance.
    ///
    /// - Parameters:
    ///   - cache: The cache implementation to store rate limiting data.
    ///   - config: Configuration for rate limiting behavior.
    ///   - identifier: A key maker that determines how to identify requests for rate limiting.
    public init(cache: Cache, config: GatekeeperConfig, identifier: GatekeeperKeyMaker) {
        self.cache = cache
        self.config = config
        self.keyMaker = identifier
    }

    /// Applies rate limiting to the incoming request.
    ///
    /// This method checks if the request should be allowed to proceed based on
    /// configured rate limits. If the request exceeds the limit, an error is thrown.
    /// Otherwise, the rate limiting state is updated and stored in the cache.
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request to be rate limited.
    ///   - error: The error to throw when the rate limit is exceeded.
    ///            Defaults to an HTTP 429 Too Many Requests error.
    ///
    /// - Throws: The provided error if the rate limit has been exceeded.
    ///
    /// - Returns: Void if the request is within rate limits.
    public func gatekeep(
        on request: Request,
        throwing error: Error = Abort(.tooManyRequests, reason: "Slow down. You sent too many requests.")
    ) async throws {
        let key = try await keyMaker.make(for: request)

        guard let hostname = request.hostname else {
            throw Abort(.forbidden, reason: "Unable to verify peer")
        }

        var entry = try await cache.get(key) ?? Entry(hostname: hostname, createdAt: Date(), requestsLeft: config.limit)

        guard entry.requestsLeft > 0 else {
            throw error
        }

        entry.touch()

        // The amount of time the entry has existed.
        let entryLifeTime = Int(Date().timeIntervalSince1970 - entry.createdAt.timeIntervalSince1970)
        // Remaining time until the entry expires. The entry would be expired by cache if it was negative.
        let timeRemaining = Int(config.refreshInterval) - entryLifeTime
        return try await cache.set(key, to: entry, expiresIn: .seconds(timeRemaining))
    }
}
