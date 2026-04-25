import Foundation

/// A single source of enrichment metadata. Providers run in parallel
/// per port via `EnrichmentCoordinator`. Each returns an `Enrichment`
/// containing only the fields it can populate — others stay `nil` and
/// the coordinator merges results via `Enrichment.merge(_:)`.
public protocol EnrichmentProvider: Sendable {
    var id: String { get }
    func enrich(_ port: PortInfo) async -> Enrichment
}
