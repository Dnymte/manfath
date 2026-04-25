import Foundation

/// Static list of shipped tunnel providers. Adding a new provider:
///
/// 1. Conform a type to `TunnelProvider`.
/// 2. Append it to `TunnelRegistry.providers`.
///
/// No other code changes needed — `TunnelStore` picks up registered
/// providers and the Settings → Tunnels tab (step 12b) lists them.
public enum TunnelRegistry {
    public static var providers: [any TunnelProvider] {
        [CloudflaredProvider(), NgrokProvider()]
    }
}
