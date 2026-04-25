import Foundation

/// A mechanism for exposing a local port publicly. Cloudflare Tunnel is
/// v1; ngrok / Tailscale Funnel / bore are pluggable later by adding
/// a new conformance and registering it in `TunnelRegistry`.
public protocol TunnelProvider: Sendable {
    var id: String { get }
    var displayName: String { get }

    func isInstalled() async -> Bool
    func installHint() -> InstallHint

    /// Starts a tunnel for the given port. Returned stream emits
    /// lifecycle events until the tunnel terminates. Cancelling
    /// iteration tears the tunnel down.
    func start(port: UInt16) -> AsyncThrowingStream<TunnelEvent, Error>

    /// Request immediate termination of the tunnel for a port. Safe to
    /// call whether or not a tunnel is running.
    func stop(port: UInt16) async
}

public enum TunnelEvent: Sendable {
    case starting
    case urlReady(URL)
    case logLine(String)
    case terminated(reason: String?)
}

public struct InstallHint: Sendable {
    public let command: String
    public let documentationURL: URL?

    public init(command: String, documentationURL: URL? = nil) {
        self.command = command
        self.documentationURL = documentationURL
    }
}
