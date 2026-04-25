import Foundation

/// Runs `ngrok http <port> --log=stdout --log-format=logfmt` and
/// scrapes the public `*.ngrok-free.app` / `*.ngrok.app` / `*.ngrok.io`
/// URL out of its log stream. Free tier requires a one-time
/// `ngrok config add-authtoken …` setup; we surface that hint via
/// `Failure.missingAuthtoken` when the process bails on auth.
public final class NgrokProvider: TunnelProvider, @unchecked Sendable {

    public let id = "ngrok"
    public let displayName = "ngrok"

    private let runtime = Runtime()

    public init() {}

    // MARK: - Install check

    public func isInstalled() async -> Bool {
        Self.locateBinary() != nil
    }

    public func installHint() -> InstallHint {
        InstallHint(
            command: "brew install ngrok",
            documentationURL: URL(string: "https://ngrok.com/download")
        )
    }

    // MARK: - Start / stop

    public func start(port: UInt16) -> AsyncThrowingStream<TunnelEvent, Error> {
        AsyncThrowingStream { continuation in
            guard let binary = Self.locateBinary() else {
                continuation.finish(throwing: Failure.notInstalled)
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = [
                "http",
                "\(port)",
                "--log=stdout",
                "--log-format=logfmt",
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            // Best-effort log streaming. ngrok line-buffers stdout
            // when piped, so URLs may arrive minutes late or not at
            // all — that's why the API poll below is the source of
            // truth for `urlReady`.
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }
                for rawLine in text.split(separator: "\n") {
                    let line = String(rawLine)
                    continuation.yield(.logLine(line))
                    if Self.indicatesAuthFailure(line) {
                        continuation.finish(throwing: Failure.missingAuthtoken)
                        return
                    }
                }
            }

            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.yield(.terminated(reason: "exit \(proc.terminationStatus)"))
                continuation.finish()
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
                return
            }

            continuation.yield(.starting)
            Task { [runtime] in await runtime.register(process, for: port) }

            // Poll ngrok's local inspector API for the public URL.
            // Authoritative — ngrok always boots web_addr=127.0.0.1:4040
            // by default and the response gives us a structured URL.
            let pollTask = Task {
                if let url = await Self.pollForPublicURL(localPort: port) {
                    continuation.yield(.urlReady(url))
                }
            }

            continuation.onTermination = { [runtime] _ in
                pollTask.cancel()
                Task { await runtime.terminate(port: port) }
            }
        }
    }

    public func stop(port: UInt16) async {
        await runtime.terminate(port: port)
    }

    /// Run `ngrok config add-authtoken <token>` synchronously. Throws
    /// on non-zero exit so callers can surface the message.
    public func saveAuthtoken(_ token: String) async throws {
        guard let binary = Self.locateBinary() else { throw Failure.notInstalled }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.emptyToken }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["config", "add-authtoken", trimmed]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw Failure.saveFailed(stderr.isEmpty ? "exit \(process.terminationStatus)" : stderr)
        }
    }

    // MARK: - Inspector API polling

    /// Hits `127.0.0.1:4040/api/tunnels` until ngrok publishes a tunnel
    /// matching `localPort`. Returns the first matching public URL or
    /// `nil` if the deadline passes (default 15s).
    static func pollForPublicURL(
        localPort: UInt16,
        deadline: TimeInterval = 15,
        pollInterval: Duration = .milliseconds(300)
    ) async -> URL? {
        guard let apiURL = URL(string: "http://127.0.0.1:4040/api/tunnels") else {
            return nil
        }
        let session = URLSession(configuration: .ephemeral)
        let cutoff = Date().addingTimeInterval(deadline)
        while !Task.isCancelled, Date() < cutoff {
            try? await Task.sleep(for: pollInterval)
            do {
                let (data, _) = try await session.data(from: apiURL)
                if let url = parsePublicURL(from: data, localPort: localPort) {
                    return url
                }
            } catch {
                // 4040 not up yet; loop and try again.
                continue
            }
        }
        return nil
    }

    /// Parse the public URL whose `config.addr` matches our local port.
    /// Pure — exposed for tests against fixture JSON.
    static func parsePublicURL(from data: Data, localPort: UInt16) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tunnels = json["tunnels"] as? [[String: Any]]
        else { return nil }

        for tunnel in tunnels {
            guard let publicURL = tunnel["public_url"] as? String,
                  publicURL.hasPrefix("https://")
            else { continue }
            let config = tunnel["config"] as? [String: Any]
            let addr = (config?["addr"] as? String) ?? ""
            // ngrok writes addr as "http://localhost:3000" or just "3000".
            if addr.hasSuffix(":\(localPort)") || addr == "\(localPort)" {
                return URL(string: publicURL)
            }
        }
        return nil
    }

    /// ngrok rejects unauthenticated sessions on the free tier with a
    /// distinctive error code / phrase. Detect both so we can surface
    /// a useful message instead of "ngrok exited 1".
    static func indicatesAuthFailure(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("err_ngrok_4018")
            || lower.contains("authentication failed")
            || (lower.contains("authtoken") && lower.contains("required"))
    }

    static func locateBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ngrok",   // Apple Silicon Homebrew
            "/usr/local/bin/ngrok",      // Intel Homebrew / manual
        ]
        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    // MARK: - Errors

    public enum Failure: Error, LocalizedError {
        case notInstalled
        case missingAuthtoken
        case emptyToken
        case saveFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "ngrok is not installed."
            case .missingAuthtoken:
                // Friendlier than a shell command — the InspectPanel
                // catches this case and shows an inline setup flow.
                return "ngrok needs an authtoken to start tunnels."
            case .emptyToken:
                return "Token is empty."
            case .saveFailed(let detail):
                return "Couldn't save authtoken: \(detail)"
            }
        }
    }

    // MARK: - Internals

    private actor Runtime {
        private var processes: [UInt16: Process] = [:]

        func register(_ process: Process, for port: UInt16) {
            processes[port] = process
        }

        func terminate(port: UInt16) {
            if let process = processes.removeValue(forKey: port) {
                process.terminate()
            }
        }
    }
}
