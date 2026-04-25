import Foundation
import Observation
import ServiceManagement

/// Persisted user preferences. All mutable properties auto-save to
/// `UserDefaults` via `didSet`. Load happens once at init.
///
/// `launchAtLogin` is backed by `SMAppService`, not UserDefaults —
/// macOS owns that state.
@MainActor @Observable
public final class SettingsStore {

    // MARK: - Fields

    public var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: K.refreshInterval) }
    }

    public var minPort: UInt16 {
        didSet { defaults.set(Int(minPort), forKey: K.minPort) }
    }

    /// Inclusive upper bound. Defaults to `UInt16.max` (= no limit).
    public var maxPort: UInt16 {
        didSet { defaults.set(Int(maxPort), forKey: K.maxPort) }
    }

    /// User-curated pinned groups of ports. Encoded as JSON in
    /// UserDefaults. Empty by default — users opt in.
    public var portGroups: [PortGroup] {
        didSet {
            if let data = try? JSONEncoder().encode(portGroups) {
                defaults.set(data, forKey: K.portGroups)
            }
        }
    }

    public var processBlocklist: [String] {
        didSet { defaults.set(processBlocklist, forKey: K.processBlocklist) }
    }

    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: K.appearance) }
    }

    public var badgeMode: BadgeMode {
        didSet { defaults.set(badgeMode.rawValue, forKey: K.badgeMode) }
    }

    /// User's chosen UI language. Writes through to the per-app
    /// `AppleLanguages` key so AppKit/SwiftUI pick the matching `.lproj`
    /// on the next launch. Changing this requires an app restart — the
    /// bundle resolves localizations at startup, not at runtime.
    public var language: Language {
        didSet {
            defaults.set(language.rawValue, forKey: K.language)
            applyAppleLanguages()
        }
    }

    /// Sectioned-by-category vs flat list. Persisted across launches.
    public var viewMode: PopoverViewMode {
        didSet { defaults.set(viewMode.rawValue, forKey: K.viewMode) }
    }

    /// When true, hide app helpers and macOS background services.
    /// "Real" = devServer / database / runtime.
    public var showOnlyRealServers: Bool {
        didSet { defaults.set(showOnlyRealServers, forKey: K.showOnlyRealServers) }
    }

    /// How each port row presents the framework / runtime: brand icon,
    /// text label, or both. Persisted across launches.
    public var rowDisplay: RowDisplay {
        didSet { defaults.set(rowDisplay.rawValue, forKey: K.rowDisplay) }
    }

    /// Which tunnel provider runs when the user clicks "tunnel".
    /// `.auto` = first installed provider in the registry order.
    public var tunnelProvider: TunnelProviderChoice {
        didSet { defaults.set(tunnelProvider.rawValue, forKey: K.tunnelProvider) }
    }

    /// Mirrors `SMAppService.mainApp.status == .enabled`. Changes are
    /// applied by calling `setLaunchAtLogin(_:)` — the setter
    /// register/unregisters with the system.
    public private(set) var launchAtLogin: Bool

    // MARK: - Init

    @ObservationIgnored private let defaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults

        self.refreshInterval = userDefaults.string(forKey: K.refreshInterval)
            .flatMap(RefreshInterval.init(rawValue:)) ?? .s3

        let storedMin = userDefaults.object(forKey: K.minPort) as? Int
        self.minPort = storedMin.map { UInt16(clamping: $0) } ?? 1024

        let storedMax = userDefaults.object(forKey: K.maxPort) as? Int
        self.maxPort = storedMax.map { UInt16(clamping: $0) } ?? UInt16.max

        if let data = userDefaults.data(forKey: K.portGroups),
           let decoded = try? JSONDecoder().decode([PortGroup].self, from: data) {
            self.portGroups = decoded
        } else {
            self.portGroups = []
        }

        self.processBlocklist = userDefaults.array(forKey: K.processBlocklist) as? [String]
            ?? ["rapportd", "ControlCenter"]

        self.appearance = userDefaults.string(forKey: K.appearance)
            .flatMap(Appearance.init(rawValue:)) ?? .system

        self.badgeMode = userDefaults.string(forKey: K.badgeMode)
            .flatMap(BadgeMode.init(rawValue:)) ?? .count

        self.language = userDefaults.string(forKey: K.language)
            .flatMap(Language.init(rawValue:)) ?? .system

        self.viewMode = userDefaults.string(forKey: K.viewMode)
            .flatMap(PopoverViewMode.init(rawValue:)) ?? .sections

        // Default to true: most users wanted this for the noisy
        // first-launch experience.
        if userDefaults.object(forKey: K.showOnlyRealServers) == nil {
            self.showOnlyRealServers = true
        } else {
            self.showOnlyRealServers = userDefaults.bool(forKey: K.showOnlyRealServers)
        }

        self.rowDisplay = userDefaults.string(forKey: K.rowDisplay)
            .flatMap(RowDisplay.init(rawValue:)) ?? .both

        self.tunnelProvider = userDefaults.string(forKey: K.tunnelProvider)
            .flatMap(TunnelProviderChoice.init(rawValue:)) ?? .auto

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Test/preview init that starts from explicit values in an
    /// in-memory `UserDefaults`. Never touches `.standard`.
    public convenience init(
        minPort: UInt16,
        processBlocklist: [String] = ["rapportd", "ControlCenter"]
    ) {
        let ephemeral = UserDefaults(suiteName: UUID().uuidString)!
        self.init(userDefaults: ephemeral)
        self.minPort = minPort
        self.processBlocklist = processBlocklist
    }

    // MARK: - Launch-at-login

    private func applyAppleLanguages() {
        switch language {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case .english:
            defaults.set(["en"], forKey: "AppleLanguages")
        case .arabic:
            defaults.set(["ar"], forKey: "AppleLanguages")
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Register can fail when the app isn't in /Applications
            // (common in dev). Swallow and re-read status below so the
            // UI reflects reality.
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Keys

    private enum K {
        static let refreshInterval  = "manfath.refreshInterval"
        static let minPort          = "manfath.minPort"
        static let processBlocklist = "manfath.processBlocklist"
        static let appearance       = "manfath.appearance"
        static let badgeMode        = "manfath.badgeMode"
        static let language         = "manfath.language"
        static let viewMode         = "manfath.viewMode"
        static let showOnlyRealServers = "manfath.showOnlyRealServers"
        static let maxPort          = "manfath.maxPort"
        static let portGroups       = "manfath.portGroups"
        static let rowDisplay       = "manfath.rowDisplay"
        static let tunnelProvider   = "manfath.tunnelProvider"
    }
}

// MARK: - Enums

public enum RefreshInterval: String, CaseIterable, Codable, Sendable {
    case s1, s3, s10, manual

    public var duration: Duration {
        switch self {
        case .s1:     return .seconds(1)
        case .s3:     return .seconds(3)
        case .s10:    return .seconds(10)
        case .manual: return .seconds(86_400)   // effectively off
        }
    }

    public var label: String {
        switch self {
        case .s1:     return String(localized: "refresh.everySecond")
        case .s3:     return String(localized: "refresh.every3Seconds")
        case .s10:    return String(localized: "refresh.every10Seconds")
        case .manual: return String(localized: "refresh.manualOnly")
        }
    }

    public var isAutomatic: Bool { self != .manual }
}

public enum Appearance: String, CaseIterable, Codable, Sendable {
    case system, light, dark

    public var label: String {
        switch self {
        case .system: return String(localized: "appearance.followSystem")
        case .light:  return String(localized: "appearance.light")
        case .dark:   return String(localized: "appearance.dark")
        }
    }
}

public enum BadgeMode: String, CaseIterable, Codable, Sendable {
    case count, dot, hidden

    public var label: String {
        switch self {
        case .count:  return String(localized: "badge.count")
        case .dot:    return String(localized: "badge.dot")
        case .hidden: return String(localized: "badge.hidden")
        }
    }
}

public enum Language: String, CaseIterable, Codable, Sendable {
    case system, english, arabic

    public var label: String {
        switch self {
        case .system:  return String(localized: "language.system")
        case .english: return String(localized: "language.english")
        case .arabic:  return String(localized: "language.arabic")
        }
    }
}

public enum PopoverViewMode: String, CaseIterable, Codable, Sendable {
    case sections   // grouped by ProcessCategory, collapsible
    case list       // flat, sorted by current sortMode
}

/// How the popover row visualises the framework / runtime: brand icon
/// (compact), the original text label (e.g. "next.js"), or both.
public enum RowDisplay: String, CaseIterable, Codable, Sendable {
    case iconOnly
    case labelOnly
    case both

    public var label: String {
        switch self {
        case .iconOnly:  return String(localized: "rowDisplay.iconOnly")
        case .labelOnly: return String(localized: "rowDisplay.labelOnly")
        case .both:      return String(localized: "rowDisplay.both")
        }
    }
}

/// User's preferred tunnel provider. `.auto` resolves to whichever
/// provider is currently installed (cloudflared first), so the default
/// experience just works once `cloudflared` is on disk.
public enum TunnelProviderChoice: String, CaseIterable, Codable, Sendable {
    case auto
    case cloudflared
    case ngrok

    public var label: String {
        switch self {
        case .auto:        return String(localized: "tunnelProvider.auto")
        case .cloudflared: return "Cloudflare Tunnel"
        case .ngrok:       return "ngrok"
        }
    }
}
