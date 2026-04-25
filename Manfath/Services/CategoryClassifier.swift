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

    /// Generic interpreters that, on their own, tell us nothing about
    /// what's running. Treated as `.runtime` unless a framework hint
    /// upgrades them.
    static let runtimeProcessNames: Set<String> = [
        "node", "deno", "bun",
        "python", "python3",
        "ruby",
        "java",
        "dotnet",
        "php",
        "perl",
    ]

    /// Decide the category for a port given everything we know about it.
    /// Order of precedence:
    ///   1. Framework hint present → devServer (interpreters running
    ///      something we recognize)
    ///   2. Process name matches a known database
    ///   3. Executable lives inside `.app/Contents/MacOS/` → appHelper
    ///   4. Process name matches a known macOS service
    ///   5. Process name is a generic interpreter → runtime
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

        if let exe = executablePath, exe.contains(".app/Contents/MacOS/") {
            return .appHelper
        }

        if systemProcessNames.contains(lower) {
            return .system
        }

        if runtimeProcessNames.contains(lower) {
            return .runtime
        }

        return .unknown
    }
}
