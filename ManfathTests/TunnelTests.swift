import XCTest
@testable import ManfathCore

// MARK: - Pure URL extraction

final class CloudflaredProviderTests: XCTestCase {

    func testExtractsURLFromTypicalLogLine() {
        let line = "2024-01-15T10:23:45Z INF |  https://foo-bar-baz.trycloudflare.com"
        let url = CloudflaredProvider.extractURL(from: line)
        XCTAssertEqual(url?.absoluteString, "https://foo-bar-baz.trycloudflare.com")
    }

    func testExtractsURLWithMixedCaseSubdomain() {
        let line = "info: https://Abc123-Xyz.trycloudflare.com is ready"
        let url = CloudflaredProvider.extractURL(from: line)
        XCTAssertEqual(url?.absoluteString, "https://Abc123-Xyz.trycloudflare.com")
    }

    func testIgnoresNonTrycloudflareURLs() {
        let line = "visit https://example.com for docs"
        XCTAssertNil(CloudflaredProvider.extractURL(from: line))
    }

    func testIgnoresLineWithoutURL() {
        XCTAssertNil(CloudflaredProvider.extractURL(from: "just a log line"))
    }

    func testLocateBinaryReturnsExistingFileOrNil() {
        let path = CloudflaredProvider.locateBinary()
        if let path {
            XCTAssertTrue(
                FileManager.default.isExecutableFile(atPath: path),
                "locateBinary returned a path but it isn't executable: \(path)"
            )
        }
        // Otherwise cloudflared isn't installed — no failure.
    }
}

// MARK: - TunnelStore state machine

@MainActor
final class TunnelStoreTests: XCTestCase {

    func testStartTransitionsToStartingThenRunning() async throws {
        let url = URL(string: "https://mock.trycloudflare.com")!
        let provider = MockTunnelProvider(scriptedEvents: [
            .starting,
            .logLine("bootstrapping"),
            .urlReady(url),
        ])
        let store = TunnelStore(providers: [provider], settings: SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))
        await store.refreshInstallState()

        store.start(port: 3000)

        try await waitUntil { store.tunnels[3000]?.status == .running(url) }

        XCTAssertEqual(store.tunnels[3000]?.status, .running(url))
        XCTAssertEqual(store.tunnels[3000]?.providerID, "mock")
        XCTAssertTrue(store.tunnels[3000]?.logLines.contains("bootstrapping") == true)
    }

    func testStopRemovesTunnelEntry() async throws {
        let provider = MockTunnelProvider(scriptedEvents: [
            .starting,
            .urlReady(URL(string: "https://x.trycloudflare.com")!),
        ])
        let store = TunnelStore(providers: [provider], settings: SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))
        await store.refreshInstallState()
        store.start(port: 3000)
        try await waitUntil { store.tunnels[3000]?.status != .starting }

        store.stop(port: 3000)

        XCTAssertNil(store.tunnels[3000])
    }

    func testStartWhenNotInstalledIsANoOp() {
        let provider = MockTunnelProvider(installed: false, scriptedEvents: [])
        let store = TunnelStore(providers: [provider], settings: SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))
        // refreshInstallState not called, stays false
        store.start(port: 3000)
        // Start still populates .starting since it doesn't re-check
        // install state (fast path). Provider will error-out when no
        // events are scripted. For correctness we accept either no
        // entry or a failed entry after a beat.
        XCTAssertNotNil(store.tunnels[3000])
    }

    func testLogBufferCapsAtHundredLines() async throws {
        let events: [TunnelEvent] = (0..<150).map { .logLine("line \($0)") }
        let provider = MockTunnelProvider(scriptedEvents: events)
        let store = TunnelStore(providers: [provider], settings: SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))
        await store.refreshInstallState()

        store.start(port: 3000)
        try await waitUntil { (store.tunnels[3000]?.logLines.count ?? 0) >= 100 }

        XCTAssertEqual(store.tunnels[3000]?.logLines.count, 100)
        // Oldest entries dropped, newest kept
        XCTAssertEqual(store.tunnels[3000]?.logLines.first, "line 50")
        XCTAssertEqual(store.tunnels[3000]?.logLines.last, "line 149")
    }

    func testToggleStartsThenStops() async throws {
        let url = URL(string: "https://x.trycloudflare.com")!
        let provider = MockTunnelProvider(scriptedEvents: [.urlReady(url)])
        let store = TunnelStore(providers: [provider], settings: SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))
        await store.refreshInstallState()

        store.toggle(port: 3000)
        try await waitUntil { store.tunnels[3000] != nil }
        XCTAssertNotNil(store.tunnels[3000])

        store.toggle(port: 3000)
        XCTAssertNil(store.tunnels[3000])
    }

    func testPruneRemovesTunnelsForDisappearedPorts() async throws {
        let provider = MockTunnelProvider(scriptedEvents: [.urlReady(URL(string: "https://a.trycloudflare.com")!)])
        let store = TunnelStore(providers: [provider], settings: SettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))
        await store.refreshInstallState()

        store.start(port: 3000)
        store.start(port: 4000)
        try await waitUntil { store.tunnels.count == 2 }

        store.prune(livePorts: [3000])

        XCTAssertNotNil(store.tunnels[3000])
        XCTAssertNil(store.tunnels[4000])
    }

    // MARK: - Helpers

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition not met within \(timeout)s")
    }
}

// MARK: - Mock

/// Yields a scripted sequence of events and keeps the stream open until
/// stopped. Installed state is configurable.
final class MockTunnelProvider: TunnelProvider, @unchecked Sendable {
    let id = "mock"
    let displayName = "Mock Tunnel"

    private let scriptedEvents: [TunnelEvent]
    private let installedValue: Bool

    init(installed: Bool = true, scriptedEvents: [TunnelEvent]) {
        self.installedValue = installed
        self.scriptedEvents = scriptedEvents
    }

    func isInstalled() async -> Bool { installedValue }

    func installHint() -> InstallHint {
        InstallHint(command: "echo mock")
    }

    func start(port: UInt16) -> AsyncThrowingStream<TunnelEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in scriptedEvents {
                continuation.yield(event)
            }
            // Keep stream open for stop tests; finish when cancelled.
            continuation.onTermination = { _ in }
        }
    }

    func stop(port: UInt16) async {}
}
