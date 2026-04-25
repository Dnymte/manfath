import Foundation
import Observation

/// Per-port tunnel state, observable from SwiftUI. Owns the stream
/// subscription tasks and delegates all shell-outs to providers.
@MainActor @Observable
public final class TunnelStore {

    public private(set) var tunnels: [UInt16: ActiveTunnel] = [:]

    /// Install state per provider id (e.g. `"cloudflared"`, `"ngrok"`).
    /// Refreshed via `refreshInstallState()`. `false` for unknown ids.
    public private(set) var installState: [String: Bool] = [:]

    private var tasks: [UInt16: Task<Void, Never>] = [:]
    private let providers: [any TunnelProvider]
    private let settings: SettingsStore

    public init(
        providers: [any TunnelProvider] = TunnelRegistry.providers,
        settings: SettingsStore
    ) {
        self.providers = providers
        self.settings = settings
    }

    // MARK: - Provider selection

    /// The provider Manfath should use right now, based on the user's
    /// `tunnelProvider` setting and current install state.
    /// `nil` only when no providers are registered.
    public var activeProvider: (any TunnelProvider)? {
        switch settings.tunnelProvider {
        case .cloudflared:
            return providers.first(where: { $0.id == "cloudflared" })
        case .ngrok:
            return providers.first(where: { $0.id == "ngrok" })
        case .auto:
            // Prefer the first installed provider; fall back to first
            // registered one so an install hint can render.
            return providers.first(where: { installState[$0.id] == true })
                ?? providers.first
        }
    }

    public var isActiveProviderInstalled: Bool {
        guard let p = activeProvider else { return false }
        return installState[p.id] ?? false
    }

    public var activeInstallHint: InstallHint? {
        activeProvider?.installHint()
    }

    /// Re-check every registered provider's binary on disk. Useful
    /// after the user clicks the inline "I installed it" button or
    /// after switching providers in Settings.
    public func refreshInstallState() async {
        var newState: [String: Bool] = [:]
        for provider in providers {
            newState[provider.id] = await provider.isInstalled()
        }
        installState = newState
    }

    // MARK: - Lifecycle per port

    public func start(port: UInt16) {
        guard let provider = activeProvider, tunnels[port] == nil else { return }

        tunnels[port] = ActiveTunnel(
            status: .starting,
            logLines: [],
            providerID: provider.id
        )

        let stream = provider.start(port: port)
        let providerID = provider.id

        tasks[port] = Task { [weak self] in
            do {
                for try await event in stream {
                    self?.apply(event: event, port: port)
                }
            } catch {
                self?.apply(
                    error: error,
                    port: port,
                    providerID: providerID
                )
            }
        }
    }

    public func stop(port: UInt16) {
        tasks[port]?.cancel()
        tasks[port] = nil
        tunnels.removeValue(forKey: port)

        Task { [providers] in
            for provider in providers {
                await provider.stop(port: port)
            }
        }
    }

    /// Run `ngrok config add-authtoken <token>` and, on success, drop
    /// the failed-state tunnel for `port` so the row becomes startable
    /// again. Returns a user-facing error string on failure, `nil` on
    /// success.
    public func saveNgrokAuthtoken(_ token: String, retryPort port: UInt16?) async -> String? {
        guard let provider = providers.first(where: { $0.id == "ngrok" }) as? NgrokProvider else {
            return "ngrok provider not registered"
        }
        do {
            try await provider.saveAuthtoken(token)
            if let port {
                tunnels.removeValue(forKey: port)   // clear failed state
                tasks[port] = nil
                start(port: port)                    // try again
            }
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
        }
    }

    public func toggle(port: UInt16) {
        if tunnels[port] == nil {
            start(port: port)
        } else {
            stop(port: port)
        }
    }

    /// Drop any tunnels whose ports disappeared from the live list.
    /// Called by `PortStore` from its scan callback.
    public func prune(livePorts: Set<UInt16>) {
        for port in tunnels.keys where !livePorts.contains(port) {
            stop(port: port)
        }
    }

    // MARK: - Event handling

    private func apply(event: TunnelEvent, port: UInt16) {
        guard var current = tunnels[port] else { return }

        switch event {
        case .starting:
            current.status = .starting
        case .urlReady(let url):
            current.status = .running(url)
        case .logLine(let line):
            current.logLines.append(line)
            if current.logLines.count > 100 {
                current.logLines.removeFirst(current.logLines.count - 100)
            }
        case .terminated(let reason):
            current.status = .failed(reason ?? "terminated")
        }

        tunnels[port] = current
    }

    private func apply(error: Error, port: UInt16, providerID: String) {
        let message = (error as? LocalizedError)?.errorDescription
            ?? String(describing: error)
        tunnels[port] = ActiveTunnel(
            status: .failed(message),
            logLines: tunnels[port]?.logLines ?? [],
            providerID: providerID
        )
        tasks[port] = nil
    }
}

// MARK: - Public state types

public struct ActiveTunnel: Equatable, Sendable {
    public var status: TunnelStatus
    public var logLines: [String]
    public let providerID: String
}

public enum TunnelStatus: Equatable, Sendable {
    case starting
    case running(URL)
    case failed(String)
}
