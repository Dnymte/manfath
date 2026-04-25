import Foundation

/// Sends a HEAD request to `http://localhost:<port>` and infers the
/// framework from response headers. Non-HTTP services (Postgres, Redis,
/// gRPC, …) just time out silently — their rows stay without a
/// framework hint, which is correct.
public struct HTTPProbeProvider: EnrichmentProvider {
    public let id = "http-probe"

    private let session: URLSession
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 0.8) {
        self.timeout = timeout
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
    }

    public func enrich(_ port: PortInfo) async -> Enrichment {
        guard let url = URL(string: "http://localhost:\(port.port)") else {
            return Enrichment()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Manfath/0.1 (localhost probe)", forHTTPHeaderField: "User-Agent")

        let start = Date()
        let response: HTTPURLResponse
        do {
            let (_, resp) = try await session.data(for: request)
            guard let http = resp as? HTTPURLResponse else { return Enrichment() }
            response = http
        } catch {
            // Connection refused, timeout, TLS required, non-HTTP protocol —
            // all land here. No enrichment to add.
            return Enrichment()
        }
        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)

        let headers = Self.normalizeHeaders(response.allHeaderFields)
        let framework = Self.detectFramework(from: headers)

        return Enrichment(
            framework: framework,
            httpStatus: response.statusCode,
            httpLatencyMs: elapsedMs
        )
    }

    // MARK: - Pure helpers (tested directly)

    /// Lowercases keys so lookups are case-insensitive.
    static func normalizeHeaders(_ raw: [AnyHashable: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in raw {
            guard let k = key as? String else { continue }
            out[k.lowercased()] = "\(value)"
        }
        return out
    }

    /// Inspect `Server` and `X-Powered-By` to guess the framework.
    /// Unknown → `nil` (not `.unknown`) so the row falls back to
    /// project/process name without claiming false certainty.
    static func detectFramework(from headers: [String: String]) -> FrameworkHint? {
        let server = headers["server"]?.lowercased() ?? ""
        let xPoweredBy = headers["x-powered-by"]?.lowercased() ?? ""

        if xPoweredBy.contains("next") { return .nextjs }
        if xPoweredBy.contains("express") { return .express }
        if server.contains("wsgiserver") { return .django }
        if server.contains("werkzeug") { return .flask }
        if server.contains("webpack-dev-server") { return .cra }
        if server.contains("rocket") { return .rustRocket }
        if server.contains("actix") { return .rustActix }
        if server.contains("apache-coyote") || server.contains("tomcat") { return .spring }
        if server.contains("phusion passenger") || xPoweredBy.contains("rails") { return .rails }
        if server.contains("vite") { return .vite }
        // Go stdlib sets no Server by default; can't detect reliably.
        return nil
    }
}
