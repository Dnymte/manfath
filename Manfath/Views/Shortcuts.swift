import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggles the Manfath popover from anywhere in the system.
    /// Default: ⌘⌥P. User-configurable via the Settings window
    /// (lands in step 11).
    static let togglePopover = Self(
        "togglePopover",
        default: .init(.p, modifiers: [.command, .option])
    )
}
