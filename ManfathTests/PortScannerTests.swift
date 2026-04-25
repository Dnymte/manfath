import XCTest
@testable import ManfathCore

final class PortScannerTests: XCTestCase {

    // MARK: - Helpers

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_003)

    private func port(
        _ port: UInt16,
        pid: Int32 = 1234,
        name: String = "node",
        firstSeenAt: Date,
        enrichment: Enrichment? = nil
    ) -> PortInfo {
        PortInfo(
            port: port,
            pid: pid,
            processName: name,
            user: "user",
            protocolKind: .ipv4,
            firstSeenAt: firstSeenAt,
            enrichment: enrichment
        )
    }

    // MARK: - Core behaviors

    func testFirstRefreshEmitsOnce() async {
        let source = ScriptedSource(scripts: [[port(3000, firstSeenAt: t0)]])
        let scanner = PortScanner(source: source)

        await scanner.refreshNow()

        let count = await scanner.emissionCount
        let current = await scanner.currentPorts
        XCTAssertEqual(count, 1)
        XCTAssertEqual(current.count, 1)
        XCTAssertEqual(current[0].port, 3000)
    }

    func testIdenticalSnapshotSuppressesEmission() async {
        let snap = [port(3000, firstSeenAt: t0)]
        let source = ScriptedSource(scripts: [snap, snap])
        let scanner = PortScanner(source: source)

        await scanner.refreshNow()
        await scanner.refreshNow()

        let count = await scanner.emissionCount
        XCTAssertEqual(count, 1, "Second refresh with identical content must not re-emit")
    }

    func testChangedSnapshotEmits() async {
        let source = ScriptedSource(scripts: [
            [port(3000, firstSeenAt: t0)],
            [port(3000, firstSeenAt: t0), port(5173, firstSeenAt: t1)],
        ])
        let scanner = PortScanner(source: source)

        await scanner.refreshNow()
        await scanner.refreshNow()

        let count = await scanner.emissionCount
        let current = await scanner.currentPorts
        XCTAssertEqual(count, 2)
        XCTAssertEqual(current.count, 2)
    }

    // MARK: - firstSeenAt preservation

    func testFirstSeenAtPreservedAcrossScans() async {
        // Same pid+port+proto seen twice with different firstSeenAt from
        // the source. Scanner must keep the first timestamp.
        let source = ScriptedSource(scripts: [
            [port(3000, firstSeenAt: t0)],
            [port(3000, firstSeenAt: t1)],   // source says "now=t1", but row already existed
        ])
        let scanner = PortScanner(source: source)

        await scanner.refreshNow()
        await scanner.refreshNow()

        let current = await scanner.currentPorts
        XCTAssertEqual(current.count, 1)
        XCTAssertEqual(
            current[0].firstSeenAt, t0,
            "firstSeenAt must be preserved across scans for the same id"
        )
    }

    func testFirstSeenAtResetsOnPidChange() async {
        // Same port, different pid = different id = new row.
        let source = ScriptedSource(scripts: [
            [port(3000, pid: 1234, firstSeenAt: t0)],
            [port(3000, pid: 9999, firstSeenAt: t1)],  // process restarted
        ])
        let scanner = PortScanner(source: source)

        await scanner.refreshNow()
        await scanner.refreshNow()

        let current = await scanner.currentPorts
        XCTAssertEqual(current.count, 1)
        XCTAssertEqual(current[0].pid, 9999)
        XCTAssertEqual(
            current[0].firstSeenAt, t1,
            "New pid = new row, firstSeenAt must reflect the new observation"
        )
    }

    // MARK: - Enrichment preservation

    func testEnrichmentPreservedAcrossScans() async {
        let enriched = port(
            3000,
            firstSeenAt: t0,
            enrichment: Enrichment(framework: .vite, projectName: "my-site")
        )
        let bare = port(3000, firstSeenAt: t1, enrichment: nil)

        // First snapshot has enrichment (simulates: scanner emits, then
        // enrichment coordinator updates, then next tick happens).
        // We inject the enrichment via the first script and expect it to
        // carry over to the second tick where source has no enrichment.
        let source = ScriptedSource(scripts: [[enriched], [bare]])
        let scanner = PortScanner(source: source)

        await scanner.refreshNow()
        await scanner.refreshNow()

        let current = await scanner.currentPorts
        XCTAssertEqual(current[0].enrichment?.framework, .vite)
        XCTAssertEqual(current[0].enrichment?.projectName, "my-site")
    }

    // MARK: - Stream delivery

    func testStreamDeliversSnapshots() async throws {
        let source = ScriptedSource(scripts: [
            [port(3000, firstSeenAt: t0)],
            [port(3000, firstSeenAt: t0), port(5173, firstSeenAt: t1)],
        ])
        let scanner = PortScanner(source: source)

        var iter = scanner.snapshots.makeAsyncIterator()

        await scanner.refreshNow()
        let first = await iter.next()
        XCTAssertEqual(first?.count, 1)

        await scanner.refreshNow()
        let second = await iter.next()
        XCTAssertEqual(second?.count, 2)
    }

    // MARK: - Start/stop

    func testStartStopIsIdempotent() async {
        let source = ScriptedSource(scripts: [[port(3000, firstSeenAt: t0)]])
        let scanner = PortScanner(source: source)

        await scanner.stop()   // stop before any start
        await scanner.stop()   // stop twice
        await scanner.start(interval: .seconds(60))
        await scanner.start(interval: .seconds(60))   // re-start replaces prior loop
        await scanner.stop()
    }

    // MARK: - Scan failure handling

    func testScanFailureDoesNotCrash() async {
        let source = FailingSource()
        let scanner = PortScanner(source: source)

        await scanner.refreshNow()   // must not throw to caller

        let count = await scanner.emissionCount
        XCTAssertEqual(count, 0, "Failed scan must not emit")
    }
}

// MARK: - Test doubles

/// Replays a scripted sequence of snapshots. When calls exceed scripts,
/// repeats the last entry.
actor ScriptedSource: PortSource {
    private let scripts: [[PortInfo]]
    private var callIndex = 0

    init(scripts: [[PortInfo]]) {
        self.scripts = scripts
    }

    func snapshot() async throws -> [PortInfo] {
        let idx = min(callIndex, scripts.count - 1)
        callIndex += 1
        return scripts[idx]
    }
}

/// Always throws. Used to verify scanner resilience.
struct FailingSource: PortSource {
    struct Boom: Error {}
    func snapshot() async throws -> [PortInfo] { throw Boom() }
}
