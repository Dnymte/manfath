import Foundation

/// Parses the field-mode output of:
///
///     /usr/sbin/lsof -iTCP -sTCP:LISTEN -nP -F pcLftPn
///
/// Each line starts with a field identifier:
///
/// - `p` pid — starts a new process record
/// - `c` command name
/// - `L` login/user
/// - `f` file descriptor — starts a new file record within the process
/// - `t` type (IPv4 / IPv6)
/// - `P` protocol (TCP expected)
/// - `n` name (address:port)
///
/// Pure function. No I/O. All temporal data (`firstSeenAt`) comes from
/// the `now` parameter so tests stay deterministic.
public enum LsofParser {

    public static func parse(_ input: String, now: Date) -> [PortInfo] {
        var result: [PortInfo] = []
        var mergeIndex: [String: Int] = [:]      // "pid:port" -> index in result

        var curPid: Int32?
        var curCommand: String?
        var curUser: String?

        var inFile = false
        var fileType: String?
        var fileProto: String?
        var fileName: String?

        func emitCurrentFile() {
            defer {
                inFile = false
                fileType = nil
                fileProto = nil
                fileName = nil
            }
            guard inFile,
                  let pid = curPid,
                  let cmd = curCommand,
                  let user = curUser,
                  let proto = fileProto, proto == "TCP",
                  let type = fileType,
                  let name = fileName,
                  let port = extractPort(from: name)
            else { return }

            let kind: ProtocolKind
            switch type {
            case "IPv4": kind = .ipv4
            case "IPv6": kind = .ipv6
            default: return
            }

            let mergeKey = "\(pid):\(port)"
            if let idx = mergeIndex[mergeKey] {
                let existing = result[idx]
                if existing.protocolKind != kind && existing.protocolKind != .both {
                    result[idx] = PortInfo(
                        port: existing.port,
                        pid: existing.pid,
                        processName: existing.processName,
                        user: existing.user,
                        protocolKind: .both,
                        firstSeenAt: existing.firstSeenAt,
                        enrichment: existing.enrichment
                    )
                }
            } else {
                let info = PortInfo(
                    port: port,
                    pid: pid,
                    processName: cmd,
                    user: user,
                    protocolKind: kind,
                    firstSeenAt: now,
                    enrichment: nil
                )
                mergeIndex[mergeKey] = result.count
                result.append(info)
            }
        }

        for rawLine in input.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            guard let first = line.first else { continue }
            let value = String(line.dropFirst())

            switch first {
            case "p":
                emitCurrentFile()
                curPid = Int32(value)
                curCommand = nil
                curUser = nil
            case "c":
                curCommand = value
            case "L":
                curUser = value
            case "f":
                emitCurrentFile()
                inFile = true
            case "t":
                fileType = value
            case "P":
                fileProto = value
            case "n":
                fileName = value
            default:
                break
            }
        }
        emitCurrentFile()

        return result
    }

    /// Extract the port from an lsof name like `*:3000`, `127.0.0.1:8080`,
    /// `[::1]:5173`, `[::]:22`, or `[fe80::1%en0]:3000`.
    ///
    /// Strategy: port is always the digits after the *last* `:`. Works
    /// because IPv6 addresses appear inside `[...]` in lsof output, so
    /// the last colon is unambiguous.
    static func extractPort(from name: String) -> UInt16? {
        guard let colonIdx = name.lastIndex(of: ":") else { return nil }
        let portSub = name[name.index(after: colonIdx)...]
        return UInt16(portSub)
    }
}
