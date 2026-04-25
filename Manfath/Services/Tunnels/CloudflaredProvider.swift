import Foundation

/// Runs `cloudflared tunnel --url http://localhost:PORT` and scrapes
/// its stderr for the public `*.trycloudflare.com` URL. The process
/// stays alive for the tunnel's lifetime.
public final class CloudflaredProvider: TunnelProvider, @unchecked Sendable {

    public let id = "cloudflared"
    public let displayName = "Cloudflare Tunnel"

    private let runtime = Runtime()

    public init() {}

    // MARK: - Install check

    public func isInstalled() async -> Bool {
        Self.locateBinary() != nil
    }

    public func installHint() -> InstallHint {
        InstallHint(
            command: "brew install cloudflared",
            documentationURL: URL(string: "https://formulae.brew.sh/formula/cloudflared")
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
                "tunnel",
                "--url", "http://localhost:\(port)",
                "--no-autoupdate",
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }
                for rawLine in text.split(separator: "\n") {
                    let line = String(rawLine)
                    continuation.yield(.logLine(line))
                    if let url = Self.extractURL(from: line) {
                        continuation.yield(.urlReady(url))
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

            continuation.onTermination = { [runtime] _ in
                Task { await runtime.terminate(port: port) }
            }
        }
    }

    public func stop(port: UInt16) async {
        await runtime.terminate(port: port)
    }

    // MARK: - Pure helpers (tested directly)

    /// Extracts the first `https://<sub>.trycloudflare.com` URL from a
    /// log line. cloudflared prints something like:
    ///
    ///     2024-01-15T10:23:45Z INF |  https://foo-bar-baz.trycloudflare.com
    static func extractURL(from line: String) -> URL? {
        let pattern = #"https://[a-zA-Z0-9-]+\.trycloudflare\.com"#
        guard let range = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return URL(string: String(line[range]))
    }

    static func locateBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/cloudflared",   // Apple Silicon Homebrew
            "/usr/local/bin/cloudflared",      // Intel Homebrew / manual
        ]
        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    // MARK: - Errors

    public enum Failure: Error, LocalizedError {
        case notInstalled

        public var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "cloudflared is not installed."
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
