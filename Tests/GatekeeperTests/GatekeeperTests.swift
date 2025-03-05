import Testing
import VaporTesting

@testable import Gatekeeper

@Suite
struct GatekeeperTests {
    @Test
    func testGateKeeper() async throws {
        try await withApp { app in
            app.gatekeeper.config = .init(maxRequests: 10, per: .second)
            app.grouped(GatekeeperMiddleware()).get("test") { _ in HTTPStatus.ok }

            for i in 1...11 {
                try await app.test(
                    .GET, "test", headers: ["X-Forwarded-For": "::1"],
                    afterResponse: { res in
                        if i == 11 {
                            #expect(res.status == .tooManyRequests)
                        } else {
                            #expect(res.status == .ok, "failed for request \(i) with status: \(res.status)")
                        }
                    }
                )
            }
        }
    }

    @Test()
    func testGateKeeperNoPeerReturnsForbidden() async throws {
        try await withApp { app in
            app.gatekeeper.config = .init(maxRequests: 10, per: .second)
            app.grouped(GatekeeperMiddleware()).get("test") { _ in HTTPStatus.ok }

            try await app.test(
                .GET, "test",
                afterResponse: { res in
                    #expect(res.status == .forbidden)
                })
        }
    }

    @Test()
    func testGateKeeperForwardedSupported() async throws {
        try await withApp { app in
            app.gatekeeper.config = .init(maxRequests: 10, per: .second)
            app.grouped(GatekeeperMiddleware()).get("test") { _ in HTTPStatus.ok }

            try await app.test(
                .GET,
                "test",
                beforeRequest: { req in
                    req.headers.forwarded = [HTTPHeaders.Forwarded(for: "\"[::1]\"")]
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                }
            )
        }
    }

    @Test()
    func testGateKeeperCountRefresh() async throws {
        try await withApp { app in
            app.gatekeeper.config = .init(maxRequests: 100, per: .second)
            app.grouped(GatekeeperMiddleware()).get("test") { req -> HTTPStatus in
                return .ok
            }

            for _ in 0..<50 {
                try await app.test(
                    .GET, "test", headers: ["X-Forwarded-For": "::1"],
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    })
            }

            let entryBefore = try await app.gatekeeper.caches.cache.get("gatekeeper_::1", as: Gatekeeper.Entry.self)
            #expect(entryBefore!.requestsLeft == 50)

            try await Task.sleep(for: .seconds(1))

            try await app.test(
                .GET, "test", headers: ["X-Forwarded-For": "::1"],
                afterResponse: { res in
                    #expect(res.status == .ok)
                })

            let entryAfter = try await app.gatekeeper.caches.cache.get("gatekeeper_::1", as: Gatekeeper.Entry.self)
            #expect(entryAfter!.requestsLeft == 99, "Requests left should've reset")
        }
    }

    @Test
    func testGatekeeperCacheExpiry() async throws {
        try await withApp { app in
            app.gatekeeper.config = .init(maxRequests: 5, per: .second)
            app.grouped(GatekeeperMiddleware()).get("test") { req -> HTTPStatus in
                return .ok
            }

            for _ in 1...5 {
                try await app.test(
                    .GET, "test", headers: ["X-Forwarded-For": "::1"],
                    afterResponse: { res in
                        #expect(res.status == .ok)
                    })
            }

            let entryBefore = try await app.gatekeeper.caches.cache.get("gatekeeper_::1", as: Gatekeeper.Entry.self)
            #expect(entryBefore!.requestsLeft == 0)

            try await Task.sleep(for: .seconds(1))

            try await #expect(app.gatekeeper.caches.cache.get("gatekeeper_::1", as: Gatekeeper.Entry.self) == nil)
        }
    }

    @Test()
    func testRefreshIntervalValues() {
        let expected: [(GatekeeperConfig.Interval, Double)] = [
            (.second, 1),
            (.minute, 60),
            (.hour, 3_600),
            (.day, 86_400),
        ]

        expected.forEach { interval, expected in
            let rate = GatekeeperConfig(maxRequests: 1, per: interval)
            #expect(rate.refreshInterval == expected)
        }
    }

    @Test()
    func testGatekeeperUsesKeyMaker() async throws {
        struct DummyKeyMaker: GatekeeperKeyMaker {
            func make(for req: Request) -> String { "dummy" }
        }

        try await withApp { app in
            app.gatekeeper.config = .init(maxRequests: 10, per: .second)
            app.gatekeeper.keyMakers.use { _ in
                DummyKeyMaker()
            }

            app.grouped(GatekeeperMiddleware()).get("test") { req -> HTTPStatus in
                return .ok
            }

            try await app.test(.GET, "test", headers: ["X-Forwarded-For": "::1"], afterResponse: { _ in })

            let entry = try await app.gatekeeper.caches.cache.get("dummy", as: Gatekeeper.Entry.self)
            #expect(entry != nil)
        }
    }
}
