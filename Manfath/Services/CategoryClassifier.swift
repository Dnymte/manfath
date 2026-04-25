import Foundation

/// Pure function bucket: takes the breadcrumbs we've already collected
/// (process name from lsof, executable path, framework hint from HTTP
/// probe) and decides which category the port belongs to.
///
/// Stateless — safe to call from any actor.
public enum CategoryClassifier {

    /// Database engines we recognize by their canonical executable name
    /// (lowercased, no extension). New entries should match what shows
    /// up in `lsof`'s `c` field, NOT the friendly product name.
    static let databaseProcessNames: Set<String> = [
        "postgres", "postgresql", "postmaster",
        "mysqld", "mariadbd", "mysql",
        "redis-server", "redis",
        "mongod",
        "memcached",
        "cassandra",
        "elasticsearch", "elastic",
        "influxd",
        "etcd",
        "couchdb",
        "neo4j",
        "rabbitmq-server",
        "clickhouse",
    ]

    /// macOS background services that almost never matter to a
    /// developer. Hidden by default behind the "real servers" filter.
    static let systemProcessNames: Set<String> = [
        "rapportd",
        "controlcenter",
        "sharingd",
        "mdnsresponder",
        "systemstats",
        "identityservicesd",
        "locationd",
        "coreaudiod",
        "bluetoothd",
        "useractivityd",
        "airplayuiagent",
        "remoted",
        "remoteservicedeleg",
        "trustd",
        "softwareupdated",
        "callservicesd",
        "imagent",
        "nsurlsessiond",
        "cloudd",
        "bird",
        "apsd",
        "searchpartyd",
        "homed",
        "homeenergyd",
        "geod",
        "syncdefaultsd",
        "remindd",
        "calaccessd",
        "siriinferenced",
        "knowledge-agent",
        "biomesyncd",
        "screensharingd",
        "wirelessproxd",
    ]

    /// Base names for generic interpreters. `isRuntime(_:)` matches
    /// these as-is *or* with a numeric/version suffix — so `python`,
    /// `python3`, `python3.11`, `python3.12.4`, `ruby2.7`, `node20`
    /// all classify the same.
    static let runtimeBaseNames: [String] = [
        "node", "deno", "bun",
        "python", "ruby", "java",
        "dotnet", "php", "perl",
    ]

    /// True when `name` is a known interpreter, with or without a
    /// version-style suffix.
    static func isRuntime(_ name: String) -> Bool {
        let lower = name.lowercased()
        for base in runtimeBaseNames {
            if lower == base { return true }
            if lower.hasPrefix(base) {
                let suffix = lower.dropFirst(base.count)
                // Accepts "3", "3.10", "3.12.4", "2.7", "-3.11", etc.
                if !suffix.isEmpty,
                   suffix.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) {
                    return true
                }
            }
        }
        return false
    }

    /// Decide the category for a port given everything we know about it.
    /// Order of precedence:
    ///   1. Framework hint present → devServer
    ///   2. Process name matches a known database
    ///   3. Process name is a known interpreter (`python`, `node`, …)
    ///      — wins over the `.app` heuristic below, because Python from
    ///      Xcode and similar bundled interpreters live inside
    ///      `.app/Contents/MacOS/` but are absolutely real dev runtimes.
    ///   4. Executable lives inside `.app/Contents/MacOS/` → appHelper
    ///   5. Process name matches a known macOS service → system
    ///   6. Otherwise unknown
    public static func classify(
        processName: String,
        executablePath: String?,
        framework: FrameworkHint?
    ) -> ProcessCategory {
        let lower = processName.lowercased()

        if let hint = framework, hint != .unknown {
            return .devServer
        }

        if databaseProcessNames.contains(lower) {
            return .database
        }

        if isRuntime(processName) {
            return .runtime
        }

        if let exe = executablePath, exe.contains(".app/Contents/MacOS/") {
            return .appHelper
        }

        if systemProcessNames.contains(lower) {
            return .system
        }

        return .unknown
    }
}
