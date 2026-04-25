import Foundation

/// A single listening TCP port observed on localhost.
///
/// Identity is stable across scans via `id` = `pid-port-protocol`. When a
/// process restarts (same port, new pid) the row is correctly treated as
/// a new service — `firstSeenAt` resets.
public struct PortInfo: Identifiable, Codable, Hashable, Sendable {
    public let port: UInt16
    public let pid: Int32
    public let processName: String
    public let user: String
    public let protocolKind: ProtocolKind
    public let firstSeenAt: Date
    public var enrichment: Enrichment?

    public var id: String {
        "\(pid)-\(port)-\(protocolKind.rawValue)"
    }

    public init(
        port: UInt16,
        pid: Int32,
        processName: String,
        user: String,
        protocolKind: ProtocolKind,
        firstSeenAt: Date,
        enrichment: Enrichment? = nil
    ) {
        self.port = port
        self.pid = pid
        self.processName = processName
        self.user = user
        self.protocolKind = protocolKind
        self.firstSeenAt = firstSeenAt
        self.enrichment = enrichment
    }
}

public enum ProtocolKind: String, Codable, Hashable, Sendable {
    case ipv4
    case ipv6
    case both
}
