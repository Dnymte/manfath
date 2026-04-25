import Foundation

/// Runs `/usr/sbin/lsof` and returns the parsed result. Uses absolute
/// path (no $PATH dependence) per ARCHITECTURE §1.
///
/// Errors from the subprocess are surfaced — the caller (PortScanner)
/// decides whether to retry, log, or surface to the UI.
public struct LsofPortSource: PortSource {

    public init() {}

    public func snapshot() async throws -> [PortInfo] {
        let output = try await Self.runLsof()
        return LsofParser.parse(output, now: Date())
    }

    public enum Failure: Error {
        case launchFailed(underlying: Error)
        case nonZeroExit(status: Int32, stderr: String)
    }

    private static func runLsof() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = [
                "-iTCP",
                "-sTCP:LISTEN",
                "-nP",
                "-F", "pcLftPn",
            ]

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { proc in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""

                // lsof exits 1 when *no files match* (e.g. no listeners).
                // Treat that as a successful empty result, not an error.
                let status = proc.terminationStatus
                if status == 0 || status == 1 {
                    continuation.resume(returning: output)
                } else {
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(
                        throwing: Failure.nonZeroExit(status: status, stderr: errStr)
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: Failure.launchFailed(underlying: error))
            }
        }
    }
}
