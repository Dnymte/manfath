import XCTest
@testable import ManfathCore

@MainActor
final class PortStoreTests: XCTestCase {

    // MARK: - Fixtures

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_060)
    private let t2 = Date(timeIntervalSince1970: 1_700_000_120)

    private func port(
        _ port: UInt16,
        pid: Int32 = 1000,
        name: String = "proc",
        firstSeenAt: Date? = nil
    ) -> PortInfo {
        PortInfo(
            port: port,
            pid: pid,
            processName: name,
            user: "user",
            protocolKind: .ipv4,
            firstSeenAt: firstSeenAt ?? t0,
            enrichment: nil
        )
    }

    private func makeStore(
        minPort: UInt16 = 1024,
        blocklist: [String] = [],
        _ ports: [PortInfo] = []
    ) -> PortStore {
        let source = ScriptedSource(scripts: [ports])
        let scanner = PortScanner(source: source)
        let settings = SettingsStore(minPort: minPort, processBlocklist: blocklist)
        let store = PortStore(scanner: scanner, settings: settings)
        store.receive(ports)
        return store
    }

    // MARK: - Filters

    func testMinPortFilterExcludesBelowThreshold() {
        let store = makeStore(minPort: 1024, [
            port(80, name: "nginx"),
            port(443, name: "nginx"),
            port(3000, name: "node"),
            port(8080, name: "node"),
        ])

        let result = store.filteredPorts
        XCTAssertEqual(result.map(\.port), [3000, 8080])
    }

    func testBlocklistIsCaseInsensitive() {
        let store = makeStore(blocklist: ["RapportD"], [
            port(3000, name: "node"),
            port(4000, name: "rapportd"),
            port(5000, name: "Rapportd"),
        ])

        let result = store.filteredPorts
        XCTAssertEqual(result.map(\.port), [3000])
    }

    func testDefaultBlocklistHidesSystemNoise() {
        let source = ScriptedSource(scripts: [])
        let scanner = PortScanner(source: source)
        let settings = SettingsStore()   // defaults
        let store = PortStore(scanner: scanner, settings: settings)
        store.receive([
            port(3000, name: "node"),
            port(4000, name: "rapportd"),
            port(5000, name: "ControlCenter"),
        ])

        XCTAssertEqual(store.filteredPorts.map(\.port), [3000])
    }

    // MARK: - Search

    func testSearchByPortNumberSubstring() {
        let store = makeStore([
            port(3000, name: "node"),
            port(3001, name: "node"),
            port(8080, name: "python"),
        ])
        store.searchText = "300"

        XCTAssertEqual(store.filteredPorts.map(\.port), [3000, 3001])
    }

    func testSearchByProcessNameIsCaseInsensitive() {
        let store = makeStore([
            port(3000, name: "Node"),
            port(3001, name: "python"),
        ])
        store.searchText = "NODE"

        XCTAssertEqual(store.filteredPorts.map(\.port), [3000])
    }

    func testSearchByPid() {
        let store = makeStore([
            port(3000, pid: 1234, name: "a"),
            port(3001, pid: 5678, name: "b"),
            port(3002, pid: 1299, name: "c"),
        ])
        store.searchText = "12"   // matches 1234 and 1299

        XCTAssertEqual(store.filteredPorts.map(\.port), [3000, 3002])
    }

    func testEmptySearchReturnsAll() {
        let store = makeStore([
            port(3000, name: "a"),
            port(4000, name: "b"),
        ])
        store.searchText = "   "   // whitespace only

        XCTAssertEqual(store.filteredPorts.count, 2)
    }

    // MARK: - Sort

    func testPortAscendingByDefault() {
        let store = makeStore([
            port(8080, name: "a"),
            port(3000, name: "b"),
            port(5173, name: "c"),
        ])

        XCTAssertEqual(store.filteredPorts.map(\.port), [3000, 5173, 8080])
    }

    func testPortDescending() {
        let store = makeStore([
            port(3000, name: "a"),
            port(8080, name: "b"),
            port(5173, name: "c"),
        ])
        store.sortMode = .portDescending

        XCTAssertEqual(store.filteredPorts.map(\.port), [8080, 5173, 3000])
    }

    func testSortByProcessName() {
        let store = makeStore([
            port(3000, name: "zebra"),
            port(4000, name: "apple"),
            port(5000, name: "mango"),
        ])
        store.sortMode = .processName

        XCTAssertEqual(store.filteredPorts.map(\.processName), ["apple", "mango", "zebra"])
    }

    func testSortByFirstSeenDescending() {
        let store = makeStore([
            port(3000, name: "a", firstSeenAt: t0),
            port(4000, name: "b", firstSeenAt: t2),
            port(5000, name: "c", firstSeenAt: t1),
        ])
        store.sortMode = .firstSeenDescending

        XCTAssertEqual(store.filteredPorts.map(\.port), [4000, 5000, 3000])
    }

    // MARK: - Filter + search composition

    func testFilterAndSearchComposeCorrectly() {
        let store = makeStore(minPort: 1024, blocklist: ["rapportd"], [
            port(80, name: "nginx"),           // below minPort
            port(3000, name: "rapportd"),      // blocklisted
            port(3001, name: "node"),          // matches
            port(4000, name: "Node"),          // matches
            port(5000, name: "python"),        // doesn't match search
        ])
        store.searchText = "node"

        XCTAssertEqual(store.filteredPorts.map(\.port), [3001, 4000])
    }

    // MARK: - Integration with scanner

    func testStoreReceivesSnapshotsFromScanner() async throws {
        let expected = [port(3000, name: "node")]
        let source = ScriptedSource(scripts: [expected])
        let scanner = PortScanner(source: source)
        let settings = SettingsStore(minPort: 0)
        let store = PortStore(scanner: scanner, settings: settings)

        store.start()
        defer { store.stop() }

        await scanner.refreshNow()

        // Wait for the subscription task to deliver the snapshot.
        try await waitUntil(timeout: 1.0) {
            store.ports.count == 1
        }

        XCTAssertEqual(store.ports.map(\.port), [3000])
        XCTAssertNotNil(store.lastRefreshAt)
    }

    // MARK: - Lifecycle

    func testStartIsIdempotent() {
        let store = makeStore([])
        store.start()
        store.start()   // must not crash
        store.stop()
    }

    func testStopWithoutStartIsSafe() {
        let store = makeStore([])
        store.stop()
        store.stop()
    }

    // MARK: - Helpers

    @MainActor
    private func waitUntil(
        timeout: TimeInterval,
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
