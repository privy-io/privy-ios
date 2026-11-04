import XCTest
@testable import FactoryKit
@testable import PrivySDK

internal final class AuthRefreshServiceImplTests: PrivyTestCase {
    private struct StubError: Error {}

    /// Holds refreshes in flight until `open()` is called.
    private actor Gate {
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            if isOpen { return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func open() {
            isOpen = true
            waiters.forEach { $0.resume() }
            waiters = []
        }
    }

    private var testAuthRepository: TestAuthRepository!
    private var authRefreshService: AuthRefreshService!

    override internal func setUp() {
        super.setUp()
        let testAuthRepository = TestAuthRepository()
        register(\PrivyContainer.authRepository) { testAuthRepository }
        self.testAuthRepository = testAuthRepository
        self.authRefreshService = resolve(\PrivyContainer.authRefreshService)
    }

    private func rotatedTokens() -> SessionUpdateAction {
        .set(accessToken: "new-auth-token", refreshToken: "new-refresh-token", identityToken: nil)
    }

    // MARK: Forwarding

    internal func testRefreshAuthForwardsTokensAndReturnsResponse() async throws {
        testAuthRepository.refreshSessionResult = .success(.test(userId: "refreshed-user"))

        let response = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")

        XCTAssertEqual(response.user.id, "refreshed-user")
        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 1)
        XCTAssertEqual(testAuthRepository.refreshSessionRequests.first?.token, "auth")
        XCTAssertEqual(testAuthRepository.refreshSessionRequests.first?.refreshToken, "refresh")
    }

    // MARK: Deduplication

    internal func testConcurrentRefreshesWithSameTokensCollapseIntoOneApiCall() async throws {
        let gate = Gate()
        testAuthRepository.refreshSessionGate = { await gate.wait() }
        testAuthRepository.refreshSessionResult = .success(.test(sessionUpdateAction: rotatedTokens()))
        let service = try XCTUnwrap(authRefreshService)

        let results = try await withThrowingTaskGroup(of: AuthResponse.self) { group in
            for _ in 0 ..< 5 {
                group.addTask { try await service.refreshAuth(authToken: "auth", refreshToken: "refresh") }
            }
            // Let the first call reach the repository (and the rest queue behind it) before releasing it.
            while testAuthRepository.refreshSessionRequests.isEmpty { await Task.yield() }
            await gate.open()

            var responses: [AuthResponse] = []
            for try await response in group { responses.append(response) }
            return responses
        }

        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 1)
        XCTAssertTrue(results.allSatisfy { $0.token == "new-auth-token" })
    }

    internal func testRotatedTokensAreServedFromCacheOnLaterCalls() async throws {
        testAuthRepository.refreshSessionResult = .success(.test(sessionUpdateAction: rotatedTokens()))

        _ = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")
        let second = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")

        XCTAssertEqual(second.token, "new-auth-token")
        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 1)
    }

    internal func testDifferentTokensRefreshIndependently() async throws {
        testAuthRepository.refreshSessionResult = .success(.test(sessionUpdateAction: rotatedTokens()))

        _ = try await authRefreshService.refreshAuth(authToken: "auth-1", refreshToken: "refresh-1")
        _ = try await authRefreshService.refreshAuth(authToken: "auth-2", refreshToken: "refresh-2")

        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 2)
    }

    // MARK: Cache eviction

    internal func testResponseReturningSameTokensIsNotCached() async throws {
        testAuthRepository.refreshSessionResult = .success(
            .test(sessionUpdateAction: .set(accessToken: "auth", refreshToken: "refresh", identityToken: nil))
        )

        _ = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")
        _ = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")

        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 2)
    }

    internal func testClearActionIsNotCached() async throws {
        testAuthRepository.refreshSessionResult = .success(.test(sessionUpdateAction: .clear))

        _ = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")
        _ = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")

        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 2)
    }

    internal func testIgnoreActionIsNotCached() async throws {
        testAuthRepository.refreshSessionResult = .success(
            .test(sessionUpdateAction: .ignore(accessToken: "other-auth", refreshToken: nil, identityToken: nil))
        )

        _ = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")
        _ = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")

        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 2)
    }

    // MARK: Failures

    internal func testFailureIsPropagated() async {
        testAuthRepository.refreshSessionResult = .failure(StubError())

        await XCTAssertThrowsErrorAsync(try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")) { error in
            XCTAssertTrue(error is StubError)
        }
    }

    internal func testFailedRefreshIsNotCachedSoNextCallRetries() async throws {
        testAuthRepository.refreshSessionResult = .failure(StubError())
        await XCTAssertThrowsErrorAsync(try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh"))

        testAuthRepository.refreshSessionResult = .success(.test(sessionUpdateAction: rotatedTokens()))
        let response = try await authRefreshService.refreshAuth(authToken: "auth", refreshToken: "refresh")

        XCTAssertEqual(response.token, "new-auth-token")
        XCTAssertEqual(testAuthRepository.refreshSessionRequests.count, 2)
    }
}
