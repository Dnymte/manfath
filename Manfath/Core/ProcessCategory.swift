import Foundation

/// Bucket a port falls into for the sectioned popover view.
///
/// Order is meaningful — sections render in declaration order, so this
/// dictates what appears at the top of the list.
public enum ProcessCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case devServer  // anything matched by HTTPProbeProvider's framework heuristics
    case database   // postgres, redis, mongo, mysql, …
    case runtime    // raw `node` / `python` / `ruby` / `java` with no framework hint
    case appHelper  // executable inside `.app/Contents/MacOS/`
    case system     // known macOS background services
    case unknown    // everything else

    /// True for categories the user is most likely actively developing
    /// against. Used by the "show only real servers" filter.
    public var isRealServer: Bool {
        switch self {
        case .devServer, .database, .runtime: return true
        case .appHelper, .system, .unknown:   return false
        }
    }
}
