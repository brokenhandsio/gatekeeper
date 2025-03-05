import Vapor

/// Middleware that applies rate limiting to routes in a Vapor application.
///
/// This middleware can be applied to individual routes or route groups to enforce
/// rate limiting according to the configured parameters. It leverages the Gatekeeper
/// service to track and control request rates.
public struct GatekeeperMiddleware: AsyncMiddleware {
    private let config: GatekeeperConfig?
    private let keyMaker: GatekeeperKeyMaker?
    private let error: Error?

    /// Initialize a new middleware for rate-limiting routes, by optionally overriding default configurations.
    ///
    /// When parameters are not provided, the middleware will use the default configurations
    /// registered with the application.
    ///
    /// - Parameters:
    ///     - config: Optional configuration that overrides the default `app.gatekeeper.config`.
    ///               Specifies the limit and refresh interval for rate limiting.
    ///     - keyMaker: Optional key maker that overrides the default `app.gatekeeper.keyMaker`.
    ///                 Determines how clients are identified for rate limiting purposes.
    ///     - error: Optional custom error to be thrown when the rate limit is exceeded,
    ///              instead of the default error.
    public init(config: GatekeeperConfig? = nil, keyMaker: GatekeeperKeyMaker? = nil, error: Error? = nil) {
        self.config = config
        self.keyMaker = keyMaker
        self.error = error
    }

    /// Performs rate limiting before passing the request to the next responder.
    ///
    /// This method checks if the incoming request should be allowed based on configured
    /// rate limits. If the request is within limits, it proceeds to the next middleware
    /// or route handler. Otherwise, an error is thrown.
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request to be rate limited.
    ///   - next: The next responder in the chain.
    ///
    /// - Throws: An error if the rate limit has been exceeded or if other validation fails.
    ///
    /// - Returns: The response from the next responder if the request is within rate limits.
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let gatekeeper = request.gatekeeper(config: config, keyMaker: keyMaker)

        if let error {
            try await gatekeeper.gatekeep(on: request, throwing: error)
        } else {
            try await gatekeeper.gatekeep(on: request)
        }

        return try await next.respond(to: request)
    }
}
