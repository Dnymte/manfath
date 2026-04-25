import Foundation

/// Metadata that enrichment providers attach to a `PortInfo` after the
/// initial scan. All fields optional — each provider fills what it can.
public struct Enrichment: Codable, Hashable, Sendable {
    public var framework: FrameworkHint?
    public var projectName: String?
    public var workingDirectory: String?
    public var commandPath: String?
    public var openFileCount: Int?
    public var dockerContainer: String?
    public var httpStatus: Int?
    public var httpLatencyMs: Int?
    public var category: ProcessCategory?

    public init(
        framework: FrameworkHint? = nil,
        projectName: String? = nil,
        workingDirectory: String? = nil,
        commandPath: String? = nil,
        openFileCount: Int? = nil,
        dockerContainer: String? = nil,
        httpStatus: Int? = nil,
        httpLatencyMs: Int? = nil,
        category: ProcessCategory? = nil
    ) {
        self.framework = framework
        self.projectName = projectName
        self.workingDirectory = workingDirectory
        self.commandPath = commandPath
        self.openFileCount = openFileCount
        self.dockerContainer = dockerContainer
        self.httpStatus = httpStatus
        self.httpLatencyMs = httpLatencyMs
        self.category = category
    }

    /// Merge another enrichment into this one, preferring the other's
    /// non-nil values. Used by `EnrichmentCoordinator` to fold provider
    /// results together.
    public mutating func merge(_ other: Enrichment) {
        // Framework: prefer a specific signal over `.unknown`. Without
        // this rule the parallel providers would clobber each other
        // non-deterministically, e.g. HTTPProbe says `.nextjs` and
        // CwdProvider returns `.unknown` → final answer becomes `.unknown`.
        if let v = other.framework, v != .unknown {
            framework = v
        } else if framework == nil, other.framework != nil {
            framework = other.framework
        }
        if let v = other.projectName { projectName = v }
        if let v = other.workingDirectory { workingDirectory = v }
        if let v = other.commandPath { commandPath = v }
        if let v = other.openFileCount { openFileCount = v }
        if let v = other.dockerContainer { dockerContainer = v }
        if let v = other.httpStatus { httpStatus = v }
        if let v = other.httpLatencyMs { httpLatencyMs = v }
        if let v = other.category { category = v }
    }
}

public enum FrameworkHint: String, Codable, Hashable, Sendable {
    case nextjs
    case vite
    case cra
    case rails
    case django
    case flask
    case express
    case spring
    case rustRocket
    case rustActix
    case goStdlib
    case nuxt
    case astro
    case svelte
    case remix
    case unknown
}
