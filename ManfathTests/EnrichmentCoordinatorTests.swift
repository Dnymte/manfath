import XCTest
@testable import ManfathCore

final class EnrichmentCoordinatorTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func port(_ p: UInt16, pid: Int32 = 1000) -> PortInfo {
        PortInfo(
            port: p, pid: pid, processName: "n",
            user: "u", protocolKind: .ipv4, firstSeenAt: t0, enrichment: nil
        )
    }

    // MARK: - Fan-out

    func testFansOutToAllProvidersAndMerges() async {
        let a = FixedProvider(id: "a", value: Enrichment(framework: .nextjs))
        let b = FixedProvider(id: "b", value: Enrichment(projectName: "my-app"))
        let coord = EnrichmentCoordinator(providers: [a, b])

        var iter = coord.results.makeAsyncIterator()
        await coord.enrich(port(3000))

        let result = await iter.next()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.enrichment.framework, .nextjs)
        XCTAssertEqual(result?.enrichment.projectName, "my-app")
    }

    // MARK: - Cache

    func testCacheHitShortCircuitsProviders() async {
        let counted = CountingProvider(value: Enrichment(framework: .vite))
        let coord = EnrichmentCoordinator(providers: [counted], ttl: 60)

        var iter = coord.results.makeAsyncIterator()

        await coord.enrich(port(3000))
        _ = await iter.next()
        await coord.enrich(port(3000))   // should hit cache
        _ = await iter.next()

        let calls = await counted.callCount
        XCTAssertEqual(calls, 1, "Second enrich within TTL must use cache")
    }

    func testDifferentPortsDontShareCache() async {
        let counted = CountingProvider(value: Enrichment(framework: .vite))
        let coord = EnrichmentCoordinator(providers: [counted], ttl: 60)

        var iter = coord.results.makeAsyncIterator()
        await coord.enrich(port(3000))
        _ = await iter.next()
        await coord.enrich(port(4000))
        _ = await iter.next()

        let calls = await counted.callCount
        XCTAssertEqual(calls, 2)
    }

    // MARK: - Invalidate

    func testInvalidateDropsEntries() async {
        let coord = EnrichmentCoordinator(
            providers: [FixedProvider(id: "a", value: Enrichment(framework: .vite))],
            ttl: 60
        )
        var iter = coord.results.makeAsyncIterator()

        await coord.enrich(port(3000))
        _ = await iter.next()
        await coord.enrich(port(4000))
        _ = await iter.next()

        let before = await coord.cacheSize
        XCTAssertEqual(before, 2)

        await coord.invalidate(keeping: [port(3000).id])

        let after = await coord.cacheSize
        XCTAssertEqual(after, 1)
    }
}

// MARK: - Test doubles

struct FixedProvider: EnrichmentProvider {
    let id: String
    let value: Enrichment
    func enrich(_ port: PortInfo) async -> Enrichment { value }
}

actor CountingProvider: EnrichmentProvider {
    nonisolated let id = "counting"
    let value: Enrichment
    var callCount = 0

    init(value: Enrichment) {
        self.value = value
    }

    func enrich(_ port: PortInfo) async -> Enrichment {
        callCount += 1
        return value
    }
}
