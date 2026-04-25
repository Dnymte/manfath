# Manfath — Architecture

A macOS menu bar app that surfaces localhost listening ports and lets
developers act on them (open, copy, kill, inspect, tunnel).

This document is the design contract. Implementation should mechanically
follow it. If you find yourself deviating, update this file first.

---

## 1. Goals and non-goals

**Goals**
- Zero-config visibility into localhost listening ports.
- Feel native — SwiftUI popover, system fonts, dark/light, RTL-aware.
- Fast, flicker-free updates on a 3s cadence.
- Pluggable tunnel providers (cloudflared first).
- Enrichment (framework detection, project name) without blocking the UI.

**Non-goals (v1)**
- Remote hosts, containers beyond local Docker awareness.
- App Store distribution (blocked by `lsof` + sandboxing).
- Packet inspection, traffic graphs.
- Multi-user / team features.

**Hard constraints**
- macOS 14+, Swift 5.9+, `@Observable` macro available.
- Not sandboxed (`com.apple.security.app-sandbox = NO`). Signed with
  Developer ID, notarized, hardened runtime on.
- All shell-outs use absolute paths: `/usr/sbin/lsof`, `/bin/kill`,
  `/usr/bin/which`, `/usr/bin/open`.

---

## 2. Layered architecture

```
┌───────────────────────────────────────────────────────────┐
│  UI layer (SwiftUI, @MainActor)                            │
│  RootView · PortRow · SettingsView · MenuBarController     │
└───────────────┬───────────────────────────────────────────┘
                │ observes
┌───────────────▼───────────────────────────────────────────┐
│  Store layer (@MainActor @Observable)                      │
│  PortStore · SettingsStore · TunnelStore                   │
└───────────────┬───────────────────────────────────────────┘
                │ awaits
┌───────────────▼───────────────────────────────────────────┐
│  Service layer (actors + protocols)                        │
│  PortScanner · EnrichmentCoordinator · ProcessController   │
│  TunnelProvider · PasteboardService · BrowserService       │
└───────────────┬───────────────────────────────────────────┘
                │ shells out / reads
┌───────────────▼───────────────────────────────────────────┐
│  System layer                                              │
│  lsof · kill · cloudflared · NSWorkspace · UserDefaults    │
└───────────────────────────────────────────────────────────┘
```

**Rule**: UI never calls the service layer directly. Stores own the
bridge between actors (background) and `@Observable` state (main).

---

## 3. Core types

### `PortInfo` — value type, Identifiable, Codable, Hashable

```swift
struct PortInfo: Identifiable, Codable, Hashable {
    var id: String { "\(pid)-\(port)-\(protocolKind.rawValue)" }

    let port: UInt16
    let pid: Int32
    let processName: String          // from lsof COMMAND column
    let commandPath: String?         // from lsof -p lookup, lazy
    let user: String
    let protocolKind: ProtocolKind   // .ipv4 / .ipv6 / .both
    let firstSeenAt: Date            // preserved across scans

    // Enrichment (nil until EnrichmentCoordinator fills it)
    var enrichment: Enrichment?
}

enum ProtocolKind: String, Codable { case ipv4, ipv6, both }

struct Enrichment: Codable, Hashable {
    var framework: FrameworkHint?    // .nextjs, .vite, .django, .rails, .unknown
    var projectName: String?         // from package.json/Cargo.toml cwd
    var workingDirectory: String?
    var dockerContainer: String?
    var httpStatus: Int?
    var httpLatencyMs: Int?
}
```

**Stable identity.** `id` combines pid+port+proto. That means a process
restart (new pid, same port) shows as a new row with a fresh
`firstSeenAt`. Correct: it *is* a new server.

**`firstSeenAt` preservation.** `PortScanner` carries forward the
timestamp when a port persists across scans. The "running for 4m" UI
reads `Date().timeIntervalSince(firstSeenAt)`.

---

## 4. Concurrency model

Three zones, explicit boundaries:

| Zone | Isolation | What lives there |
|------|-----------|------------------|
| Main | `@MainActor` | All UI, all `@Observable` stores |
| Scan | `actor PortScanner` | lsof subprocess, parsing, diffing |
| Enrich | `actor EnrichmentCoordinator` | HTTP probes, cwd reads |

**Data flow per tick:**

1. `PortStore` has a long-lived `Task` that awaits
   `scanner.nextSnapshot()` (AsyncStream).
2. `PortScanner` runs lsof every N seconds (configurable), parses,
   diffs against previous snapshot, yields a new `[PortInfo]`.
3. `PortStore` receives snapshot on MainActor, updates `ports` array.
   SwiftUI diffs and animates.
4. For each newly-appeared port, `PortStore` fires
   `enrichmentCoordinator.enrich(port)` tasks in parallel.
5. Enrichment results flow back via a separate AsyncStream; PortStore
   merges them into the matching `PortInfo` by id.

**No shared mutable state across actors.** Snapshots are values.

---

## 5. Scanner subsystem

### Protocol boundary

```swift
protocol PortSource: Sendable {
    func snapshot() async throws -> [PortInfo]
}
```

v1 implementation: `LsofPortSource`. Swappable later for a `libproc`-based
source without touching the store.

### `LsofPortSource`

- Runs `/usr/sbin/lsof -iTCP -sTCP:LISTEN -nP -F pcnuLP` in a `Process`
  with a `Pipe` on stdout.
- `-F` produces field-mode output: one record per line prefixed by a
  field char. Easier and faster to parse than columnar.
- 2s timeout on the subprocess. Kill if it hangs.
- Returns `[PortInfo]` with `enrichment = nil` and `commandPath = nil`.

### `LsofParser`

Pure function: `(String) -> [PortInfo]`. No I/O, no Foundation networking.
This is where unit tests concentrate — fixtures in
`Tests/Fixtures/lsof-*.txt`.

Fixtures to include:
- `lsof-typical.txt` (node, Python, Docker)
- `lsof-empty.txt` (no listeners)
- `lsof-ipv6-only.txt`
- `lsof-both-v4-v6.txt` (same pid binds IPv4 and IPv6 on same port — merge)
- `lsof-truncated.txt` (simulated partial output)
- `lsof-unicode-command.txt` (non-ASCII process name)

### `PortScanner` actor

Owns the loop:

```swift
actor PortScanner {
    private let source: PortSource
    private var lastSnapshot: [String: PortInfo] = [:]  // keyed by id
    private var continuation: AsyncStream<[PortInfo]>.Continuation?

    var snapshots: AsyncStream<[PortInfo]> { ... }

    func start(interval: Duration) { ... }
    func stop() { ... }
    func refreshNow() async { ... }
}
```

- Preserves `firstSeenAt` by looking up each scanned port in
  `lastSnapshot` and copying the timestamp forward.
- Emits a snapshot only if it differs from the previous (by id set or
  by any field). Prevents SwiftUI re-diff on identical frames.

---

## 6. Enrichment pipeline

Enrichment is slow, unreliable, and shouldn't block the UI. Treat each
signal as an independent async provider.

```swift
protocol EnrichmentProvider: Sendable {
    func enrich(_ port: PortInfo) async -> Enrichment.Partial
}
```

Providers (run in parallel per port):

| Provider | What it adds | How |
|----------|--------------|-----|
| `HTTPProbeProvider` | `httpStatus`, `httpLatencyMs`, `framework` hint from headers | `URLSession` HEAD with 500ms timeout |
| `CwdProvider` | `workingDirectory`, `projectName` | `lsof -p PID -Fn` then look for package.json/Cargo.toml/pyproject.toml/go.mod |
| `DockerProvider` | `dockerContainer` | `which docker`, then `docker ps --format {{.ID}}:{{.Names}}:{{.Ports}}` matched by port |
| `CommandPathProvider` | `commandPath` | `lsof -p PID -Fn` (shared call with CwdProvider — dedupe) |

### `EnrichmentCoordinator`

- Keyed cache: `[PortInfo.ID: Enrichment]`.
- On `enrich(port)`: if cached and cache younger than 60s, return. Else
  fan out to providers with `async let`, merge partials, cache, emit.
- Cache invalidation: when a port disappears, its entry is dropped.

**Frameworks detected in v1** (via HTTP headers/body sniff):
Next.js, Vite, Create React App, Rails, Django, Flask, Express,
Spring, Rust (Rocket/Actix), Go stdlib, generic. `.unknown` is fine.

---

## 7. Store layer

### `PortStore` — the source of truth for UI

```swift
@MainActor @Observable
final class PortStore {
    private(set) var ports: [PortInfo] = []
    private(set) var lastRefreshAt: Date?
    private(set) var isScanning: Bool = false

    var searchText: String = ""
    var sortMode: SortMode = .portAscending

    var filteredPorts: [PortInfo] { /* apply search + settings filters */ }

    func start() { /* subscribe to scanner + enrichment streams */ }
    func refreshNow() async { ... }
}
```

Filtering order: settings blocklist → port range → search text → sort.

### `SettingsStore` — @Observable wrapper over UserDefaults

```swift
@MainActor @Observable
final class SettingsStore {
    var refreshInterval: RefreshInterval  // .s1, .s3, .s10, .manual
    var minPort: UInt16                    // default 1024
    var processBlocklist: [String]         // default ["rapportd", "ControlCenter"]
    var appearance: Appearance             // .system, .light, .dark
    var launchAtLogin: Bool                // SMAppService-backed
    var badgeMode: BadgeMode               // .count, .dot, .hidden
    var globalHotkey: KeyboardShortcuts.Name?
}
```

UserDefaults keys namespaced: `com.manfath.settings.*`. Migrations
handled in a single `SettingsMigrator.run()` called at launch.

### `TunnelStore`

State of each active tunnel keyed by port. See §9.

---

## 8. UI layer

### File layout

```
Views/
  MenuBarController.swift      // NSStatusItem + NSPopover host (AppKit)
  RootView.swift               // SwiftUI root, 420x560
  PortList.swift               // scrollable list with diff animation
  PortRow.swift                // single row, hover, actions
  InspectPanel.swift           // inline expanded row content
  EmptyStateView.swift
  FooterView.swift
  SearchField.swift
  Settings/
    SettingsWindow.swift       // AppKit window hosting SwiftUI
    GeneralTab.swift
    FiltersTab.swift
    TunnelsTab.swift
    AboutTab.swift
```

### Rules

- Views take stores via `@Environment` (one store per environment key).
- No view performs I/O. Actions call store methods.
- `PortRow` is pure presentation + closure callbacks for actions.
- Monospaced digits: `.monospacedDigit()` on the port number.
- RTL: no hard-coded leading/trailing; use `HStack` with
  `.environment(\.layoutDirection, ...)` only for number sequences
  that must stay LTR (ports, IPs, URLs).

### Badge rendering

`MenuBarController` watches `portStore.filteredPorts.count` and
`settings.badgeMode`, redraws the `NSStatusItem.button.image` as a
composited `network` symbol + count text. Use `NSImage` with
`isTemplate = true` for automatic dark/light.

---

## 9. Action layer

### `ProcessController`

```swift
enum KillResult { case ok, requiresPrivileges, notFound, failed(String) }

actor ProcessController {
    func kill(pid: Int32, signal: Int32 = SIGTERM) async -> KillResult
    func inspect(pid: Int32) async throws -> ProcessDetails
}
```

- `kill` shells out to `/bin/kill`. If exit code indicates EPERM,
  return `.requiresPrivileges` — UI shows an error, never prompts for
  sudo.
- `inspect` runs `lsof -p PID` and returns working dir, open file
  count, command path.

### `TunnelProvider` protocol

```swift
protocol TunnelProvider: Sendable {
    static var id: String { get }             // "cloudflared"
    static var displayName: String { get }    // "Cloudflare Tunnel"

    func isInstalled() async -> Bool
    func installHint() -> InstallHint         // brew cmd, doc URL

    func start(port: UInt16) -> AsyncThrowingStream<TunnelEvent, Error>
    func stop(port: UInt16) async
}

enum TunnelEvent {
    case starting
    case urlReady(URL)
    case logLine(String)
    case terminated(reason: String?)
}
```

### `CloudflaredProvider` (v1)

- `isInstalled`: `/usr/bin/which cloudflared` exit 0.
- `start`: launch `cloudflared tunnel --url http://localhost:PORT`,
  scrape stdout for the `trycloudflare.com` URL (regex), emit events.
- `stop`: `Process.terminate()` on the handle.
- Bookkeeping lives in `TunnelStore`:
  `[port: ActiveTunnel]` with status, url, log buffer (last 100 lines).

### Adding a new provider later

1. Create a type conforming to `TunnelProvider`.
2. Register in `TunnelRegistry.providers` (static array).
3. Settings → Tunnels tab auto-lists it.

No changes to UI, store, or scanner needed. This is why the protocol
is worth defining now even though we ship one provider.

### Small services

- `PasteboardService.copy(_ string: String)` — wraps `NSPasteboard`.
- `BrowserService.open(url: URL)` — wraps `NSWorkspace.open`.
- `QRCodeService.generate(from: String) -> NSImage` — CoreImage CIFilter.
- `LANAddressService.primaryIPv4() -> String?` — `getifaddrs`, filter
  for en0/en1, skip loopback and link-local.

---

## 10. Data flow, one full tick

```
T+0s    PortScanner fires.
T+0s    LsofPortSource runs lsof, returns 5 PortInfo (enrichment nil).
T+0s    Scanner diffs: 1 new (pid 47213, port 5173), 4 same.
T+0s    Scanner preserves firstSeenAt on the 4, stamps new port.
T+0s    Scanner yields [PortInfo] on snapshots stream.
T+0ms   PortStore receives on MainActor, replaces ports array.
        SwiftUI ForEach animates the new row in.
T+5ms   PortStore calls enrichmentCoordinator.enrich(newPort).
T+5ms   Coordinator fans out: HTTP probe, cwd lookup, docker check in
        parallel.
T+180ms HTTP probe returns 200, Server: "Vite". framework = .vite.
T+220ms Cwd lookup returns /Users/me/projects/site with package.json
        name "my-site".
T+260ms Docker returns nil.
T+260ms Coordinator merges, emits Enrichment for the port id.
T+260ms PortStore merges enrichment into the matching PortInfo.
        Row subtitle updates from "node 47213" to "Vite · my-site".
```

---

## 11. Settings window

Separate AppKit `NSWindow` hosting a SwiftUI `TabView`. Opened via
footer gear or `⌘,`. Not part of the popover — popover dismisses on
focus loss, which would be hostile to editing settings.

Tabs: **General** (interval, hotkey, appearance, launch at login),
**Filters** (min port, blocklist editor), **Tunnels** (provider list,
install status, per-provider config), **About** (version, credits,
licenses, update note pointing at Homebrew).

---

## 12. Error handling strategy

- **Expected failures** (lsof returns non-zero, cloudflared not installed,
  HTTP probe times out): represented as values, surfaced in UI via
  small inline banners or row badges. Never thrown past the store.
- **Unexpected failures** (decode errors, invariant violations): logged
  via `os.Logger` subsystem `com.manfath`, category per module. Don't
  crash the app.
- **User-facing errors** localized via String Catalog. No raw error
  descriptions in UI.

---

## 13. Persistence

| Data | Where | Why |
|------|-------|-----|
| Settings | `UserDefaults` | Small, structured, observable via KVO |
| Tunnel logs (recent) | In-memory only | Ephemeral |
| Pinned ports + aliases | `UserDefaults` | Small |
| Activity log (Tier-3) | `~/Library/Application Support/Manfath/activity.sqlite` | Queryable, bounded |
| Enrichment cache | In-memory only | Rebuilds in <1s on launch |

---

## 14. Localization

- Strings via `.xcstrings` (String Catalogs). English + Arabic on day
  one, even if Arabic is machine-translated initially — structure
  matters more than polish.
- Layout: use `Layout` and `alignment` APIs that respect
  `layoutDirection`. Test by setting scheme arg
  `-AppleLanguages "(ar)"`.
- Numeric fields (port, PID, URLs) stay LTR inside RTL layouts — wrap
  with `.environment(\.layoutDirection, .leftToRight)` on the label
  only.

---

## 15. Testing strategy

| Layer | Coverage |
|-------|----------|
| `LsofParser` | Heavy unit tests with fixtures. This is the riskiest code. |
| `PortScanner` | Test with a mock `PortSource` that yields scripted snapshots. Verify firstSeenAt preservation and diff suppression. |
| `EnrichmentCoordinator` | Mock providers, verify cache behavior and parallel fan-out. |
| `PortStore` | Verify filtering, sorting, search. |
| `CloudflaredProvider` | Integration test behind a compile flag; skipped in CI. |
| UI | Snapshot tests for `PortRow` states (idle, hover, inspected, tunneling) using `swift-snapshot-testing` if added. Optional. |

Fixtures live in `ManfathTests/Fixtures/`. No network in tests.

---

## 16. File and target layout

```
Manfath/
  Manfath.xcodeproj
  Manfath/                      # app target
    ManfathApp.swift            # @main, sets up stores
    AppDelegate.swift           # NSApplicationDelegate for menu bar
    Info.plist                  # LSUIElement = YES (no dock icon)
    Manfath.entitlements        # app-sandbox = NO, hardened runtime bits
    Resources/
      Assets.xcassets
      Localizable.xcstrings
    Core/
      PortInfo.swift
      Enrichment.swift
      Errors.swift
    Services/
      PortSource.swift
      LsofPortSource.swift
      LsofParser.swift
      PortScanner.swift
      EnrichmentCoordinator.swift
      Providers/
        HTTPProbeProvider.swift
        CwdProvider.swift
        DockerProvider.swift
        CommandPathProvider.swift
      ProcessController.swift
      Tunnels/
        TunnelProvider.swift
        TunnelRegistry.swift
        CloudflaredProvider.swift
      PasteboardService.swift
      BrowserService.swift
      QRCodeService.swift
      LANAddressService.swift
    Stores/
      PortStore.swift
      SettingsStore.swift
      TunnelStore.swift
    Views/
      MenuBarController.swift
      RootView.swift
      PortList.swift
      PortRow.swift
      InspectPanel.swift
      EmptyStateView.swift
      FooterView.swift
      SearchField.swift
      Settings/
        SettingsWindow.swift
        GeneralTab.swift
        FiltersTab.swift
        TunnelsTab.swift
        AboutTab.swift
    Utilities/
      ShellRunner.swift         # Process/Pipe wrapper with timeout
      Logger+Manfath.swift
      Date+Relative.swift
  ManfathTests/
    LsofParserTests.swift
    PortScannerTests.swift
    EnrichmentCoordinatorTests.swift
    PortStoreTests.swift
    Fixtures/
      lsof-typical.txt
      lsof-empty.txt
      lsof-ipv6-only.txt
      lsof-both-v4-v6.txt
      lsof-truncated.txt
      lsof-unicode-command.txt
  README.md
  ARCHITECTURE.md               # this file
```

---

## 17. Signing, entitlements, distribution

- `com.apple.security.app-sandbox` = **NO** (required for lsof/kill).
- Hardened runtime: **ON**.
- Entitlements needed:
  - `com.apple.security.cs.allow-jit` = NO
  - `com.apple.security.cs.allow-unsigned-executable-memory` = NO
  - `com.apple.security.cs.disable-library-validation` = NO
- `Info.plist`:
  - `LSUIElement` = YES (no dock icon, menu bar only)
  - `NSHumanReadableCopyright`
  - No usage descriptions needed (no mic/camera/contacts).
- Distribution: Developer ID signed + notarized DMG.
- `notarytool submit` flow documented in README.

---

## 18. Resolved decisions

1. **Bundle identifier.** `com.manfath.app`.
2. **Default global hotkey.** ⌘⌥P, user-configurable via `KeyboardShortcuts` SPM.
3. **Update mechanism.** Homebrew Cask. Users run
   `brew upgrade --cask manfath`. No in-app updater, no appcast — the
   tap repo is the source of truth.
4. **Tier-1 feature scope.** All five in v1: framework detection,
   project name from cwd, LAN+QR, global hotkey, diff animations.
5. **Arabic translation.** Translate at authoring time. Strings go into
   `Localizable.xcstrings` in both languages from first commit; refine
   with a native-speaker review pass before public release.

---

## 19. Build order (enforced)

1. Xcode project scaffold + targets + entitlements + Info.plist.
2. `PortInfo`, `Enrichment`, `LsofParser` + fixture tests. **Stop and
   run tests.**
3. `LsofPortSource`, `PortScanner` + scanner tests with mock source.
4. `PortStore` + store tests. Console-log snapshots, no UI yet.
5. `MenuBarController` + minimal `RootView` showing a plain list. Wire
   to `PortStore`. **First visible milestone.**
6. `PortRow` + hover actions (Open, Copy, Kill). `ProcessController`.
7. Tier-1 enrichment: `HTTPProbeProvider`, `CwdProvider`. Wire display.
8. `InspectPanel` expansion.
9. LAN + QR code UI.
10. Global hotkey.
11. `SettingsStore`, `SettingsWindow`, all tabs.
12. `TunnelProvider` protocol, `CloudflaredProvider`, `TunnelStore`,
    per-row tunnel UI.
13. String Catalog pass, Arabic RTL verification.
14. Homebrew Cask formula + tap docs.
15. Sign, notarize, DMG script, README polish.

Each step ends with: builds clean, tests pass (if test-bearing),
visible app still launches.
