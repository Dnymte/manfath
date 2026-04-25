import Foundation
import Observation

/// SwiftUI-facing source of truth for the list of ports.
///
/// Bridges the `PortScanner` actor (background) to SwiftUI (main actor).
/// Views read `filteredPorts` and write `searchText` / `sortMode`.
@MainActor @Observable
public final class PortStore {

    public private(set) var ports: [PortInfo] = []
    public private(set) var lastRefreshAt: Date?

    /// Primary IPv4 on the LAN (Wi-Fi or Ethernet), refreshed
    /// periodically so mobile-test URLs stay valid across network
    /// changes. `nil` when off-network.
    public private(set) var lanIPv4: String?

    public var searchText: String = ""
    public var sortMode: SortMode = .portAscending

    public let scanner: PortScanner
    public let settings: SettingsStore
    public let processController: ProcessController
    public let enrichmentCoordinator: EnrichmentCoordinator?

    /// Transient banner shown briefly at the top of the popover.
    /// Cleared automatically after a few seconds.
    public private(set) var errorBanner: String?
    public private(set) var bannerKind: BannerKind = .error
    private var errorClearTask: Task<Void, Never>?

    private var subscriptionTask: Task<Void, Never>?
    private var enrichmentSubscriptionTask: Task<Void, Never>?
    private var lanRefreshTask: Task<Void, Never>?

    public init(
        scanner: PortScanner,
        settings: SettingsStore,
        processController: ProcessController = ProcessController(),
        enrichmentCoordinator: EnrichmentCoordinator? = nil
    ) {
        self.scanner = scanner
        self.settings = settings
        self.processController = processController
        self.enrichmentCoordinator = enrichmentCoordinator
    }

    /// Start the scan loop and subscribe to snapshots. Idempotent.
    /// Reads `settings.refreshInterval` and reacts to changes.
    public func start() {
        guard subscriptionTask == nil else { return }

        let stream = scanner.snapshots
        subscriptionTask = Task { [weak self] in
            for await snap in stream {
                self?.receive(snap)
            }
        }

        if let coordinator = enrichmentCoordinator {
            let results = coordinator.results
            enrichmentSubscriptionTask = Task { [weak self] in
                for await result in results {
                    self?.applyEnrichment(id: result.id, enrichment: result.enrichment)
                }
            }
        }

        trackRefreshInterval()
        startLANRefresh()
    }

    /// Re-arms on every `settings.refreshInterval` change and restarts
    /// the scanner with the new cadence. `.manual` stops the auto loop.
    private func trackRefreshInterval() {
        withObservationTracking {
            applyRefreshInterval(settings.refreshInterval)
        } onChange: {
            Task { @MainActor [weak self] in
                self?.trackRefreshInterval()
            }
        }
    }

    private func applyRefreshInterval(_ interval: RefreshInterval) {
        Task { [scanner] in
            await scanner.stop()
            if interval.isAutomatic {
                await scanner.start(interval: interval.duration)
            }
        }
    }

    /// Stop the scan loop and cancel the subscription. Idempotent.
    public func stop() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        enrichmentSubscriptionTask?.cancel()
        enrichmentSubscriptionTask = nil
        lanRefreshTask?.cancel()
        lanRefreshTask = nil
        Task { [scanner] in
            await scanner.stop()
        }
    }

    private func startLANRefresh() {
        lanIPv4 = LANAddressService.primaryIPv4()
        lanRefreshTask?.cancel()
        lanRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                let next = LANAddressService.primaryIPv4()
                self?.lanIPv4 = next
            }
        }
    }

    /// Force an immediate scan without waiting for the next tick.
    public func refreshNow() async {
        await scanner.refreshNow()
    }

    /// Entry point for incoming snapshots. Internal so tests can drive
    /// it directly without spinning up an actual scanner subscription.
    ///
    /// Preserves enrichment across scans by merging in previously known
    /// enrichments (the scanner's source returns `enrichment: nil`
    /// every tick). Ports that arrive without enrichment are dispatched
    /// to the coordinator for lookup.
    func receive(_ snapshot: [PortInfo]) {
        let oldById = Dictionary(uniqueKeysWithValues: ports.map { ($0.id, $0) })
        let merged = snapshot.map { new -> PortInfo in
            if new.enrichment == nil, let old = oldById[new.id], old.enrichment != nil {
                var out = new
                out.enrichment = old.enrichment
                return out
            }
            return new
        }

        self.ports = merged
        self.lastRefreshAt = Date()

        guard let coordinator = enrichmentCoordinator else { return }

        let currentIds = Set(merged.map(\.id))
        Task { await coordinator.invalidate(keeping: currentIds) }

        for port in merged where port.enrichment == nil {
            Task { [port] in
                await coordinator.enrich(port)
            }
        }
    }

    /// Applied on the main actor when the coordinator emits a result.
    /// Merges into the matching `PortInfo` in `ports`; if the port has
    /// since disappeared, the update is dropped.
    func applyEnrichment(id: String, enrichment: Enrichment) {
        guard let idx = ports.firstIndex(where: { $0.id == id }) else { return }
        var updated = ports[idx]
        updated.enrichment = enrichment
        ports[idx] = updated
    }

    // MARK: - Row actions

    public func openInBrowser(port: UInt16) {
        BrowserService.openLocalhost(port: port)
    }

    public func copyAddress(port: UInt16) {
        PasteboardService.copy("localhost:\(port)")
    }

    public func kill(pid: Int32) async {
        let result = await processController.kill(pid: pid)
        switch result {
        case .ok:
            // Next scan will drop the row; no UI feedback needed here.
            break
        case .requiresPrivileges:
            showError(String(localized: "kill.requiresPrivileges"))
        case .notFound:
            showError(String(localized: "kill.notFound"))
        case .failed(let msg):
            showError(String(localized: "kill.failed \(msg)"))
        }
    }

    private func showError(_ message: String) {
        bannerKind = .error
        errorBanner = message
        scheduleBannerClear()
    }

    /// Surface a transient banner — colour adapts to `kind` (info, hint
    /// → blue/amber; success → cyan; error → red). Lets cross-cutting UI
    /// (tunnel start, install hints, etc.) report a one-line note
    /// without owning its own banner state.
    public func flashBanner(_ message: String, kind: BannerKind = .info) {
        bannerKind = kind
        errorBanner = message
        scheduleBannerClear()
    }

    private func scheduleBannerClear() {
        errorClearTask?.cancel()
        errorClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run { self?.errorBanner = nil }
        }
    }

    // MARK: - Derived view state

    /// Filter order per ARCHITECTURE §7: blocklist → port range →
    /// real-server filter → search text → sort.
    public var filteredPorts: [PortInfo] {
        let blocklist = Set(settings.processBlocklist.map { $0.lowercased() })
        let minPort = settings.minPort
        let maxPort = settings.maxPort
        let realOnly = settings.showOnlyRealServers
        let groups = settings.portGroups
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let filtered = ports.filter { port in
            // Pinned groups override the range filter — if you've
            // explicitly favorited a port, you want to see it.
            let inAGroup = groups.contains { $0.contains(port.port) }
            if !inAGroup {
                guard port.port >= minPort, port.port <= maxPort else { return false }
            }
            guard !blocklist.contains(port.processName.lowercased()) else { return false }
            // Hide non-real-server categories when the filter is on.
            // We give an as-yet-unenriched port the benefit of the doubt
            // so it doesn't blink in and out as enrichment lands.
            if realOnly, !inAGroup, let cat = port.enrichment?.category, !cat.isRealServer {
                return false
            }
            if query.isEmpty { return true }
            return String(port.port).contains(query)
                || port.processName.lowercased().contains(query)
                || String(port.pid).contains(query)
        }

        return filtered.sorted(by: comparator(for: sortMode))
    }

    /// Sections in render order: pinned groups first, then auto
    /// `ProcessCategory` buckets. Each port appears in **exactly one**
    /// section — when multiple groups list the same port (e.g. both
    /// `preset.nextjs` and `preset.react` claim 3000), we disambiguate
    /// by the detected framework. If no framework hint is available
    /// the first matching group in the user's defined order wins.
    public var sectionedPorts: [PortSection] {
        let groups = settings.portGroups
        var sections: [PortSection] = []
        var groupBuckets: [UUID: [PortInfo]] = [:]
        var consumed: Set<String> = []

        for port in filteredPorts {
            guard let group = Self.bestGroup(for: port, candidates: groups) else { continue }
            groupBuckets[group.id, default: []].append(port)
            consumed.insert(port.id)
        }

        // Render groups in user-defined order, skipping empties.
        for group in groups {
            if let portsInGroup = groupBuckets[group.id], !portsInGroup.isEmpty {
                sections.append(.group(group: group, ports: portsInGroup))
            }
        }

        // Auto categories for everything not claimed by a group.
        var buckets: [ProcessCategory: [PortInfo]] = [:]
        for port in filteredPorts where !consumed.contains(port.id) {
            let cat = port.enrichment?.category ?? .unknown
            buckets[cat, default: []].append(port)
        }
        for cat in ProcessCategory.allCases {
            if let portsInCat = buckets[cat], !portsInCat.isEmpty {
                sections.append(.category(category: cat, ports: portsInCat))
            }
        }
        return sections
    }

    /// Pick the single group a port belongs in. When multiple groups
    /// list the same port, prefer the one whose `presetId` matches the
    /// detected framework; otherwise fall through to user order.
    static func bestGroup(for port: PortInfo, candidates: [PortGroup]) -> PortGroup? {
        let matching = candidates.filter { $0.contains(port.port) }
        if matching.count <= 1 { return matching.first }

        if let framework = port.enrichment?.framework, framework != .unknown,
           let expected = presetId(for: framework),
           let preferred = matching.first(where: { $0.presetId == expected }) {
            return preferred
        }
        return matching.first
    }

    /// Map a `FrameworkHint` to the matching preset id from
    /// `PresetGroups.all`. Used to break ties when multiple groups
    /// claim the same port.
    private static func presetId(for hint: FrameworkHint) -> String? {
        switch hint {
        case .nextjs:                   return "preset.nextjs"
        case .vite:                     return "preset.vite"
        case .cra:                      return "preset.react"
        case .rails:                    return "preset.rails"
        case .django:                   return "preset.django"
        case .flask:                    return "preset.flask"
        case .express:                  return "preset.express"
        case .spring:                   return "preset.spring"
        case .rustRocket, .rustActix:   return "preset.actix"
        case .goStdlib:                 return "preset.gohttp"
        case .nuxt:                     return "preset.nuxt"      // not in catalog yet
        case .astro:                    return "preset.astro"
        case .svelte:                   return "preset.svelte"
        case .remix:                    return "preset.remix"
        case .unknown:                  return nil
        }
    }

    /// Real-server count for the optional badge / settings counter.
    /// Counts only categories where `isRealServer == true`.
    public var realServerCount: Int {
        filteredPorts.filter {
            ($0.enrichment?.category ?? .unknown).isRealServer
        }.count
    }

    private func comparator(for mode: SortMode) -> (PortInfo, PortInfo) -> Bool {
        switch mode {
        case .portAscending:
            return { $0.port < $1.port }
        case .portDescending:
            return { $0.port > $1.port }
        case .processName:
            return {
                $0.processName.localizedCaseInsensitiveCompare($1.processName)
                    == .orderedAscending
            }
        case .firstSeenDescending:
            return { $0.firstSeenAt > $1.firstSeenAt }
        }
    }
}

public enum SortMode: String, CaseIterable, Sendable {
    case portAscending
    case portDescending
    case processName
    case firstSeenDescending
}

/// Visual tone for transient banners. View layer maps each case to a
/// colour palette; logic layer just tags meaning.
public enum BannerKind: Sendable {
    case info       // generic note — neutral / amber
    case success    // tunnel ready, copy succeeded — cyan
    case error      // kill failed, install missing — danger red
}

/// One section in the popover's sections-view. Either a user-pinned
/// `PortGroup` or an auto-classified `ProcessCategory`. Identifiable so
/// SwiftUI's ForEach can diff cleanly across re-renders.
public enum PortSection: Identifiable, Sendable {
    case group(group: PortGroup, ports: [PortInfo])
    case category(category: ProcessCategory, ports: [PortInfo])

    public var id: String {
        switch self {
        case .group(let g, _):    return "group-\(g.id.uuidString)"
        case .category(let c, _): return "cat-\(c.rawValue)"
        }
    }

    public var ports: [PortInfo] {
        switch self {
        case .group(_, let p), .category(_, let p): return p
        }
    }

    /// True for `.group` sections — used by the view to render a pin
    /// affordance in the section header.
    public var isPinned: Bool {
        if case .group = self { return true }
        return false
    }

    /// `LocalizedStringKey` for category sections (so they translate),
    /// or the raw user-typed group name for pinned groups.
    public var titleKey: String {
        switch self {
        case .group(let g, _):    return g.name
        case .category(let c, _): return c.rawValue   // resolves via category.<rawValue>
        }
    }
}
