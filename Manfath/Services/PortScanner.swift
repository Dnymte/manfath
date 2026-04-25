import Foundation

/// Owns the scan loop. On each tick:
///
/// 1. Asks the `PortSource` for the current set of ports.
/// 2. Preserves `firstSeenAt` and `enrichment` for ports already known.
/// 3. Emits on `snapshots` only if the merged result differs from the
///    previous emission — prevents UI re-diffs on identical frames.
///
/// `snapshots` is a single-subscriber `AsyncStream`. `PortStore` owns
/// the subscription; no other consumer should iterate it.
public actor PortScanner {

    private let source: any PortSource
    private var lastPorts: [PortInfo] = []
    private var lastById: [String: PortInfo] = [:]
    private var loopTask: Task<Void, Never>?

    private let continuation: AsyncStream<[PortInfo]>.Continuation
    public nonisolated let snapshots: AsyncStream<[PortInfo]>

    // Observation hooks for tests. Not part of the public contract.
    private(set) var emissionCount: Int = 0
    var currentPorts: [PortInfo] { lastPorts }

    public init(source: any PortSource) {
        self.source = source
        let (stream, cont) = AsyncStream<[PortInfo]>.makeStream(bufferingPolicy: .unbounded)
        self.snapshots = stream
        self.continuation = cont
    }

    /// Start a recurring loop that ticks every `interval`. Calling `start`
    /// while a loop is already running replaces it.
    public func start(interval: Duration) {
        stop()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: interval)
            }
        }
    }

    /// Stop the recurring loop. Safe to call multiple times.
    public func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    /// Force a single scan now, independent of the loop.
    public func refreshNow() async {
        await tick()
    }

    private func tick() async {
        do {
            let raw = try await source.snapshot()
            let merged = merge(newPorts: raw)
            if merged != lastPorts {
                lastPorts = merged
                lastById = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
                emissionCount += 1
                continuation.yield(merged)
            }
        } catch {
            // Scan failures are non-fatal. Log (when Logger is wired) and
            // skip this tick — next tick retries.
        }
    }

    /// For each port in `newPorts`, if we've seen the same id before,
    /// copy `firstSeenAt` and `enrichment` forward. Otherwise use what
    /// the source gave us.
    private func merge(newPorts: [PortInfo]) -> [PortInfo] {
        newPorts.map { port in
            guard let existing = lastById[port.id] else { return port }
            return PortInfo(
                port: port.port,
                pid: port.pid,
                processName: port.processName,
                user: port.user,
                protocolKind: port.protocolKind,
                firstSeenAt: existing.firstSeenAt,
                enrichment: existing.enrichment
            )
        }
    }

    deinit {
        continuation.finish()
    }
}
