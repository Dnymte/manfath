import Foundation

/// Coordinates parallel enrichment across providers with a keyed,
/// time-limited cache. Per ARCHITECTURE §6:
///
/// - Fan out to all providers in parallel via `withTaskGroup`.
/// - Merge partial `Enrichment` results with `Enrichment.merge(_:)`.
/// - Cache the merged result keyed by `PortInfo.ID` for `ttl` seconds.
/// - Expose results via an `AsyncStream` the store subscribes to.
public actor EnrichmentCoordinator {

    private let providers: [any EnrichmentProvider]
    private var cache: [String: CachedEntry] = [:]
    private let ttl: TimeInterval

    private struct CachedEntry {
        let enrichment: Enrichment
        let cachedAt: Date
    }

    private let continuation: AsyncStream<EnrichmentResult>.Continuation
    public nonisolated let results: AsyncStream<EnrichmentResult>

    public init(
        providers: [any EnrichmentProvider],
        ttl: TimeInterval = 60
    ) {
        self.providers = providers
        self.ttl = ttl
        let (stream, cont) = AsyncStream<EnrichmentResult>.makeStream(
            bufferingPolicy: .unbounded
        )
        self.results = stream
        self.continuation = cont
    }

    /// Request enrichment for a port. Cache hits emit immediately;
    /// misses run all providers in parallel and emit on completion.
    public func enrich(_ port: PortInfo) async {
        if let cached = cache[port.id],
           Date().timeIntervalSince(cached.cachedAt) < ttl {
            continuation.yield(EnrichmentResult(id: port.id, enrichment: cached.enrichment))
            return
        }

        let merged = await runProviders(for: port)
        cache[port.id] = CachedEntry(enrichment: merged, cachedAt: Date())
        continuation.yield(EnrichmentResult(id: port.id, enrichment: merged))
    }

    /// Drop cache entries for ids not in `keep`. Called by the store
    /// when a scan shows ports have disappeared.
    public func invalidate(keeping keep: Set<String>) {
        cache = cache.filter { keep.contains($0.key) }
    }

    /// Test-only observation hook.
    var cacheSize: Int { cache.count }

    // MARK: - Internals

    private func runProviders(for port: PortInfo) async -> Enrichment {
        var merged = await withTaskGroup(of: Enrichment.self) { group in
            for provider in providers {
                group.addTask { await provider.enrich(port) }
            }
            var acc = Enrichment()
            for await partial in group {
                acc.merge(partial)
            }
            return acc
        }
        // Once every provider has reported, we know enough to bucket
        // the port into a category. Doing it here (rather than in a
        // provider) keeps the decision in one place.
        merged.category = CategoryClassifier.classify(
            processName: port.processName,
            executablePath: merged.commandPath,
            framework: merged.framework
        )
        return merged
    }

    deinit {
        continuation.finish()
    }
}

public struct EnrichmentResult: Sendable {
    public let id: String
    public let enrichment: Enrichment
}
