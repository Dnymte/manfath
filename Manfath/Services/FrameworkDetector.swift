import Foundation

/// Pure framework-detection logic. Looks at the project's manifests
/// and the process's launch argv to figure out what's actually
/// running, independent of (and complementing) the HTTP probe.
///
/// Order of confidence, highest first:
///   1. A known config file in the cwd (`next.config.*`, `vite.config.*`,
///      `astro.config.*`, etc.) — unambiguous.
///   2. A specific dev-tool dependency in `package.json`
///      (`next`, `react-scripts`, `vite`, `@remix-run/dev`, …).
///   3. A token in `argv` (`next`, `vite`, `react-scripts start`, …).
///   4. Backend manifests: `Gemfile` w/ `rails`, `pyproject.toml` w/
///      `django` or `flask`, `manage.py` for Django.
///
/// Returns `nil` when nothing matches — caller falls back to whatever
/// the HTTP probe found.
public enum FrameworkDetector {

    public struct Inputs: Sendable {
        public let packageJson: Data?
        public let cwdFiles: [String]      // names only, not paths
        public let gemfile: String?
        public let pyproject: String?
        public let arguments: [String]

        public init(
            packageJson: Data? = nil,
            cwdFiles: [String] = [],
            gemfile: String? = nil,
            pyproject: String? = nil,
            arguments: [String] = []
        ) {
            self.packageJson = packageJson
            self.cwdFiles = cwdFiles
            self.gemfile = gemfile
            self.pyproject = pyproject
            self.arguments = arguments
        }
    }

    public static func detect(_ inputs: Inputs) -> FrameworkHint? {
        // 1. Config files in cwd — strongest signal.
        for file in inputs.cwdFiles {
            if let hint = configFileHint(file) { return hint }
        }

        // 2. package.json dependencies.
        if let data = inputs.packageJson,
           let hint = packageJsonHint(data) {
            return hint
        }

        // 3. Process argv tokens.
        if let hint = argvHint(inputs.arguments) { return hint }

        // 4. Backend manifests.
        if let gem = inputs.gemfile, gem.range(of: #"\brails\b"#, options: .regularExpression) != nil {
            return .rails
        }
        if let pyproject = inputs.pyproject?.lowercased() {
            if pyproject.contains("django") { return .django }
            if pyproject.contains("flask")  { return .flask }
        }
        if inputs.cwdFiles.contains("manage.py") { return .django }

        return nil
    }

    // MARK: - Strategy helpers (each pure, individually testable)

    static func configFileHint(_ filename: String) -> FrameworkHint? {
        let lower = filename.lowercased()
        if lower.hasPrefix("next.config.")    { return .nextjs }
        if lower.hasPrefix("vite.config.")    { return .vite }
        if lower.hasPrefix("astro.config.")   { return .astro }
        if lower.hasPrefix("nuxt.config.")    { return .nuxt }
        if lower.hasPrefix("svelte.config.")  { return .svelte }
        if lower.hasPrefix("remix.config.")   { return .remix }
        if lower == "manage.py"               { return .django }
        if lower == "rails"                   { return .rails }
        return nil
    }

    /// Parse the dependencies map from `package.json` and return the
    /// first matching framework. Combines `dependencies`,
    /// `devDependencies`, and `peerDependencies`.
    static func packageJsonHint(_ data: Data) -> FrameworkHint? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else { return nil }

        var deps: Set<String> = []
        for key in ["dependencies", "devDependencies", "peerDependencies"] {
            if let dict = obj[key] as? [String: Any] {
                for k in dict.keys { deps.insert(k.lowercased()) }
            }
        }

        // More-specific tools first so e.g. Next (which itself depends
        // on react) is picked over a bare "react" hit.
        if deps.contains("next")              { return .nextjs }
        if deps.contains("nuxt")              { return .nuxt }
        if deps.contains("astro")             { return .astro }
        if deps.contains("@remix-run/dev")    { return .remix }
        if deps.contains("@sveltejs/kit")     { return .svelte }
        if deps.contains("svelte")            { return .svelte }
        if deps.contains("vite")              { return .vite }
        if deps.contains("react-scripts")     { return .cra }
        if deps.contains("express")           { return .express }
        if deps.contains("@nestjs/core")      { return .express } // closest mapping

        return nil
    }

    /// Look for telltale tokens in argv. Walks backwards from the end
    /// (which usually contains the script path / entry) for efficiency.
    static func argvHint(_ argv: [String]) -> FrameworkHint? {
        for raw in argv {
            let arg = raw.lowercased()
            // Direct executable / module names
            if arg.hasSuffix("/next") || arg.hasSuffix("\\next") || arg == "next" { return .nextjs }
            if arg.contains("/.bin/next") || arg.contains("node_modules/next") { return .nextjs }
            if arg.contains("react-scripts") { return .cra }
            if arg.hasSuffix("/vite") || arg == "vite" || arg.contains("node_modules/vite") { return .vite }
            if arg.contains("astro") && arg.contains("node_modules") { return .astro }
            if arg.contains("nuxt")  && arg.contains("node_modules") { return .nuxt }
            if arg.contains("@remix-run") { return .remix }
            if arg.contains("svelte-kit") { return .svelte }
            if arg.hasSuffix("manage.py") { return .django }
            if arg.contains("rails server") || arg == "rails" { return .rails }
            if arg.hasSuffix("/flask") || arg == "flask" { return .flask }
        }
        return nil
    }
}
