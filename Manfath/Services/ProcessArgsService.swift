import Darwin
import Foundation

/// Reads a process's launch arguments via `sysctl(KERN_PROCARGS2)`.
/// More reliable than `ps -o command=` because it sees the original
/// argv even after the process has overwritten `argv[0]` (Node, Python,
/// and Ruby do this routinely).
///
/// Layout returned by the kernel:
///
///   [argc:Int32]
///   [exec_path]              // NUL-terminated absolute path
///   [padding NULs]           // align to next argument
///   [argv[0]] [argv[1]] ...  // each NUL-terminated
///   [envp[0]] [envp[1]] ...  // env vars, ignored
///
/// Returns the parsed argv array (which includes argv[0]). The
/// executable path is exposed separately.
public enum ProcessArgsService {

    public struct Result: Equatable, Sendable {
        public let executablePath: String
        public let arguments: [String]
    }

    public static func read(pid: Int32) -> Result? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 4 else {
            return nil
        }
        var buf = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buf, &size, nil, 0) == 0 else {
            return nil
        }
        return parse(buffer: buf, length: size)
    }

    /// Pure parser, factored out so tests can drive it with synthetic
    /// fixtures (the real syscall isn't replayable in unit tests).
    static func parse(buffer: [UInt8], length: Int) -> Result? {
        guard length >= 4 else { return nil }

        let argc = buffer.withUnsafeBytes { raw -> Int32 in
            raw.load(fromByteOffset: 0, as: Int32.self)
        }
        guard argc > 0 else { return nil }

        // exec path immediately follows argc
        var i = 4
        let execStart = i
        while i < length, buffer[i] != 0 { i += 1 }
        guard let exec = String(bytes: buffer[execStart..<i], encoding: .utf8),
              !exec.isEmpty
        else { return nil }

        // skip NUL padding
        while i < length, buffer[i] == 0 { i += 1 }

        var args: [String] = []
        var current: [UInt8] = []
        while i < length, args.count < Int(argc) {
            let byte = buffer[i]
            if byte == 0 {
                if let s = String(bytes: current, encoding: .utf8) {
                    args.append(s)
                }
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(byte)
            }
            i += 1
        }

        return Result(executablePath: exec, arguments: args)
    }
}
