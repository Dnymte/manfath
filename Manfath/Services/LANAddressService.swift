import Darwin
import Foundation

/// Returns the primary IPv4 address on the LAN — whatever Wi-Fi or
/// Ethernet is currently connected. Used to build per-port URLs like
/// `http://192.168.1.42:3000` for mobile testing.
///
/// Filters out:
/// - Loopback (127.0.0.0/8)
/// - Link-local self-assigned (169.254.0.0/16)
/// - Non-`en*` / `bridge*` interfaces (VPN, utun, etc. typically aren't
///   what a phone on the same Wi-Fi should connect to)
public enum LANAddressService {

    public static func primaryIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            let name = String(cString: current.pointee.ifa_name)
            guard
                isPreferredInterface(name),
                let addr = current.pointee.ifa_addr,
                addr.pointee.sa_family == UInt8(AF_INET),
                (current.pointee.ifa_flags & UInt32(IFF_UP)) != 0,
                (current.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) == 0
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let getnameResult = getnameinfo(
                addr,
                socklen_t(MemoryLayout<sockaddr_in>.size),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard getnameResult == 0 else { continue }

            let ip = String(cString: host)
            if isRoutable(ip) { return ip }
        }

        return nil
    }

    // MARK: - Pure helpers (tested directly)

    static func isPreferredInterface(_ name: String) -> Bool {
        name.hasPrefix("en") || name.hasPrefix("bridge")
    }

    static func isRoutable(_ ip: String) -> Bool {
        if ip.isEmpty { return false }
        if ip.hasPrefix("127.") { return false }
        if ip.hasPrefix("169.254.") { return false }
        return true
    }
}
