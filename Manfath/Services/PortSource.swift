import Foundation

/// Abstraction over the mechanism used to enumerate listening ports.
///
/// `LsofPortSource` is the v1 implementation. A future `LibprocPortSource`
/// could swap in without touching the scanner or stores.
public protocol PortSource: Sendable {
    /// Return the current set of listening ports. Each call is independent;
    /// the source holds no state across calls. Temporal data
    /// (`firstSeenAt`) reflects "now" — `PortScanner` overrides it with
    /// preserved timestamps for ports it has seen before.
    func snapshot() async throws -> [PortInfo]
}
