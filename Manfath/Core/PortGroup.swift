import Foundation

/// Inclusive port range. Codable for persistence in UserDefaults.
public struct PortRange: Codable, Hashable, Sendable {
    public var min: UInt16
    public var max: UInt16

    public init(min: UInt16, max: UInt16) {
        self.min = Swift.min(min, max)
        self.max = Swift.max(min, max)
    }

    public func contains(_ port: UInt16) -> Bool {
        port >= min && port <= max
    }
}

/// A user-defined collection of "interesting" ports that gets pinned
/// as its own section at the top of the popover (sections view).
///
/// The model is intentionally tiny: a name + a flat set of port
/// numbers + an optional list of ranges. A port that lives in a group
/// is shown only inside that group section, not duplicated under its
/// auto-classified category.
public struct PortGroup: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var ports: [UInt16]
    public var ranges: [PortRange]
    /// Stable identifier when this group was added from a preset
    /// (`PresetGroups.all`). `nil` for fully custom groups. Used to
    /// reconcile preset on/off state across launches.
    public var presetId: String?

    public init(
        id: UUID = UUID(),
        name: String,
        ports: [UInt16] = [],
        ranges: [PortRange] = [],
        presetId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.ports = ports
        self.ranges = ranges
        self.presetId = presetId
    }

    public func contains(_ port: UInt16) -> Bool {
        if ports.contains(port) { return true }
        return ranges.contains(where: { $0.contains(port) })
    }
}
