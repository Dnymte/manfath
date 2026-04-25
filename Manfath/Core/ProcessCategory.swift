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

    /// Used by the "show only real servers" filter. The rule we want
    /// is "hide things we *positively know* are noise" — app helpers
    /// (Slack, Adobe, …) and macOS system daemons. Everything else
    /// shows, including ports we couldn't classify (e.g. gunicorn,
    /// uvicorn, custom binaries) so the user isn't surprised when a
    /// real dev server they just started doesn't appear.
    public var isRealServer: Bool {
        switch self {
        case .devServer, .database, .runtime, .unknown: return true
        case .appHelper, .system:                       return false
        }
    }
}
