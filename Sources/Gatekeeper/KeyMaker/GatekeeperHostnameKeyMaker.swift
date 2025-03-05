import Vapor

/// A key maker implementation that uses the client's hostname to create cache keys.
///
/// This implementation creates rate limiting keys based on the client's hostname,
/// allowing rate limits to be applied per host rather than per user or other identifiers.
public struct GatekeeperHostnameKeyMaker: GatekeeperKeyMaker {

    /// Initializes a new hostname-based key maker.
    public init() {}

    /// Creates a rate limiting key based on the client's hostname.
    ///
    /// This method extracts the hostname from the request and prepends it with
    /// "gatekeeper_" to create a unique cache key for rate limiting.
    ///
    /// - Parameter req: The incoming HTTP request.
    ///
    /// - Throws: An HTTP 403 Forbidden error if the hostname cannot be determined.
    ///
    /// - Returns: A string to be used as the cache key for rate limiting.
    public func make(for req: Request) async throws -> String {
        guard let hostname = req.hostname else {
            throw Abort(.forbidden, reason: "Unable to verify peer")
        }

        return "gatekeeper_" + hostname
    }
}
