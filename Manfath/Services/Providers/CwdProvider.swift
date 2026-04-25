import Foundation

/// Resolves a process's project name using several strategies, falling
/// through in order of confidence:
///
///  1. The cwd contains a project manifest (`package.json`, `Cargo.toml`,
///     `pyproject.toml`, `go.mod`) → read its `name`.
///  2. Walk up to 5 parent directories from the cwd looking for the
///     same manifests, or a `.git` directory. The first hit wins.
///  3. Mine the process's launch argv (read via
///     `sysctl(KERN_PROCARGS2)`) for path-like tokens, then resolve
///     each via strategies 1–2. This catches `node /Users/me/proj/server.js`
///     when the process was launched from elsewhere.
///  4. If the executable lives inside a `.app/Contents/MacOS/`, treat
///     it as a macOS app helper and return the `.app` name.
///  5. Fall back to the cwd's last path component, if any.
public struct CwdProvider: EnrichmentProvider {
    public let id = "cwd"

    private let processController: ProcessController

    public init(processController: ProcessController) {
        self.processController = processController
    }

    public func enrich(_ port: PortInfo) async -> Enrichment {
        let details = try? await processController.inspect(pid: port.pid)
        let args = ProcessArgsService.read(pid: port.pid)
        let fs = RealFileSystem()

        let resolved = Self.resolveProjectName(
            workingDirectory: details?.workingDirectory,
            executablePath: details?.commandPath ?? args?.executablePath,
            arguments: args?.arguments ?? [],
            fileSystem: fs
        )

        let framework = Self.detectFramework(
            workingDirectory: details?.workingDirectory,
            arguments: args?.arguments ?? [],
            fileSystem: fs
        )

        return Enrichment(
            framework: framework,
            projectName: resolved,
            workingDirectory: details?.workingDirectory,
            commandPath: details?.commandPath ?? args?.executablePath,
            openFileCount: details?.openFileCount
        )
    }

    /// Walk up to 5 parents from `cwd` looking for the closest project
    /// root, then run `FrameworkDetector` over its manifests + the
    /// process's argv. Returns `nil` when no signal matches; the
    /// HTTPProbeProvider's framework hint may still win in that case.
    static func detectFramework(
        workingDirectory: String?,
        arguments: [String],
        fileSystem: FileSystemReader,
        maxDepth: Int = 5
    ) -> FrameworkHint? {
        guard let start = workingDirectory else {
            return FrameworkDetector.detect(.init(arguments: arguments))
        }
        // Walk up looking for the first directory that contains any
        // project marker. That's where we read manifests + list files.
        var path = start
        for _ in 0...maxDepth {
            let inputs = inputs(at: path, fileSystem: fileSystem, arguments: arguments)
            if inputs.packageJson != nil
                || inputs.gemfile != nil
                || inputs.pyproject != nil
                || !inputs.cwdFiles.isEmpty {
                return FrameworkDetector.detect(inputs)
            }
            let parent = (path as NSString).deletingLastPathComponent
            if parent.isEmpty || parent == path || parent == "/" { break }
            path = parent
        }
        // Last resort: argv only.
        return FrameworkDetector.detect(.init(arguments: arguments))
    }

    private static let frameworkConfigFiles: [String] = [
        "next.config.js", "next.config.mjs", "next.config.ts",
        "vite.config.js", "vite.config.ts", "vite.config.mjs",
        "astro.config.mjs", "astro.config.ts", "astro.config.js",
        "nuxt.config.ts", "nuxt.config.js",
        "svelte.config.js", "svelte.config.ts",
        "remix.config.js", "remix.config.mjs",
        "manage.py", "Gemfile",
    ]

    private static func inputs(
        at path: String,
        fileSystem: FileSystemReader,
        arguments: [String]
    ) -> FrameworkDetector.Inputs {
        let pkg  = fileSystem.read(path: (path as NSString).appendingPathComponent("package.json"))
        let gem  = fileSystem.readString(path: (path as NSString).appendingPathComponent("Gemfile"))
        let pyp  = fileSystem.readString(path: (path as NSString).appendingPathComponent("pyproject.toml"))
        let presentConfigs = frameworkConfigFiles.filter { name in
            fileSystem.exists(path: (path as NSString).appendingPathComponent(name))
        }
        return .init(
            packageJson: pkg,
            cwdFiles: presentConfigs,
            gemfile: gem,
            pyproject: pyp,
            arguments: arguments
        )
    }

    // MARK: - Pure resolution (testable)

    /// Apply the strategies above. Pure: takes a `FileSystemReader`
    /// abstraction so tests can drive synthetic layouts.
    static func resolveProjectName(
        workingDirectory: String?,
        executablePath: String?,
        arguments: [String],
        fileSystem: FileSystemReader
    ) -> String? {
        // 1 + 2 — walk up from cwd
        if let cwd = workingDirectory,
           let name = walkForProjectName(startingAt: cwd, fileSystem: fileSystem) {
            return name
        }

        // 3 — mine argv for path-like tokens; resolve each via 1–2
        for arg in arguments.dropFirst() where looksLikePath(arg) {
            // The arg might be a script file path. Try both the file's
            // parent directory and the arg as a directory itself.
            let parent = (arg as NSString).deletingLastPathComponent
            if !parent.isEmpty,
               let name = walkForProjectName(startingAt: parent, fileSystem: fileSystem) {
                return name
            }
            if let name = walkForProjectName(startingAt: arg, fileSystem: fileSystem) {
                return name
            }
        }

        // 4 — `.app` helper
        if let exe = executablePath, let app = appBundleName(from: exe) {
            return app
        }

        // 5 — last-ditch: cwd's own folder name
        if let cwd = workingDirectory {
            let last = (cwd as NSString).lastPathComponent
            if !last.isEmpty && last != "/" { return last }
        }

        return nil
    }

    /// Walk from `start` up to 5 parents, returning the project name
    /// from the first directory containing a recognized manifest or a
    /// `.git` folder. `nil` if nothing matches before hitting `/` or
    /// the parent equals self (`/` reached).
    static func walkForProjectName(
        startingAt start: String,
        fileSystem: FileSystemReader,
        maxDepth: Int = 5
    ) -> String? {
        var path = start
        for _ in 0...maxDepth {
            if let name = readProjectName(at: path, fileSystem: fileSystem) {
                return name
            }
            let parent = (path as NSString).deletingLastPathComponent
            if parent.isEmpty || parent == path || parent == "/" { break }
            path = parent
        }
        return nil
    }

    /// Try the manifests at `path`. Returns the manifest's declared
    /// name; if only `.git` exists, returns the directory's basename.
    /// `nil` if the directory has none of the markers.
    static func readProjectName(at path: String, fileSystem: FileSystemReader) -> String? {
        if let data = fileSystem.read(path: (path as NSString).appendingPathComponent("package.json")),
           let name = parsePackageJsonName(data) {
            return name
        }
        if let str = fileSystem.readString(path: (path as NSString).appendingPathComponent("Cargo.toml")),
           let name = parseTomlName(from: str) {
            return name
        }
        if let str = fileSystem.readString(path: (path as NSString).appendingPathComponent("pyproject.toml")),
           let name = parseTomlName(from: str) {
            return name
        }
        if let str = fileSystem.readString(path: (path as NSString).appendingPathComponent("go.mod")),
           let name = parseGoModName(from: str) {
            return name
        }
        if fileSystem.exists(path: (path as NSString).appendingPathComponent(".git")) {
            return (path as NSString).lastPathComponent
        }
        return nil
    }

    /// `/Applications/Adobe Creative Cloud.app/Contents/MacOS/Adobe Crash Reporter`
    /// → "Adobe Creative Cloud". Returns nil if no `.app` ancestor.
    static func appBundleName(from executable: String) -> String? {
        let parts = executable.split(separator: "/", omittingEmptySubsequences: true)
        guard let i = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        let withSuffix = parts[i]
        let bare = withSuffix.dropLast(".app".count)
        return bare.isEmpty ? nil : String(bare)
    }

    /// Heuristic: anything with a `/` and not starting with `-`
    /// (we don't want flags like `-/dev/stdin`).
    static func looksLikePath(_ s: String) -> Bool {
        guard !s.isEmpty, !s.hasPrefix("-") else { return false }
        return s.contains("/")
    }

    // MARK: - Manifest parsers (kept stable; existing tests depend on these)

    static func parsePackageJsonName(_ data: Data) -> String? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = obj as? [String: Any],
            let name = dict["name"] as? String,
            !name.isEmpty
        else { return nil }
        return name
    }

    static func parseTomlName(from content: String) -> String? {
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("name") else { continue }
            let quotes: [Character] = ["\"", "'"]
            guard let startIdx = trimmed.firstIndex(where: { quotes.contains($0) }) else {
                continue
            }
            let quote = trimmed[startIdx]
            let afterStart = trimmed.index(after: startIdx)
            guard let endIdx = trimmed[afterStart...].firstIndex(of: quote) else {
                continue
            }
            let name = String(trimmed[afterStart..<endIdx])
            if !name.isEmpty { return name }
        }
        return nil
    }

    static func parseGoModName(from content: String) -> String? {
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("module ") else { continue }
            let modulePath = String(trimmed.dropFirst("module ".count))
                .trimmingCharacters(in: .whitespaces)
            let lastComponent = (modulePath as NSString).lastPathComponent
            return lastComponent.isEmpty ? nil : lastComponent
        }
        return nil
    }

    /// Legacy convenience kept for existing call sites and tests that
    /// pass a real path on disk.
    static func readProjectName(at path: String) -> String? {
        readProjectName(at: path, fileSystem: RealFileSystem())
    }
}

// MARK: - File system abstraction

/// Minimal slice of FileManager that we use, broken out so tests can
/// supply a synthetic in-memory tree without touching the real disk.
public protocol FileSystemReader: Sendable {
    func exists(path: String) -> Bool
    func read(path: String) -> Data?
    func readString(path: String) -> String?
}

public struct RealFileSystem: FileSystemReader {
    public init() {}
    public func exists(path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    public func read(path: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: path))
    }
    public func readString(path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }
}
