import SwiftUI

struct RootView: View {
    @Bindable var store: PortStore
    @Environment(TunnelStore.self) private var tunnelStore
    @FocusState private var searchFocused: Bool

    /// Keyed by `PortSection.id`, so both pinned groups and auto
    /// categories share one collapse state. Stays for the popover's
    /// lifetime — collapsing a section won't undo on the next scan.
    @State private var collapsedSections: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.line)
            searchBar
            Divider().background(Theme.line)
            content
            Divider().background(Theme.line)
            footer
        }
        .frame(width: 420, height: 560)
        .background(Theme.popoverGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.lineStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .top) {
            if let message = store.errorBanner {
                errorBanner(message)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.errorBanner)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                BlinkingDot(color: Theme.amber, size: 6, glow: 10)
                Text("popover.header.title")
                    .font(Theme.monoSize(12.5))
                    .foregroundStyle(Theme.inkDim)
            }
            Spacer()
            Text(headerMeta)
                .font(Theme.monoSize(11))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.2))
    }

    private var headerMeta: String {
        let count = store.filteredPorts.count
        guard let at = store.lastRefreshAt else {
            return String(localized: "popover.header.metaCold \(count)")
        }
        let elapsed = Date().timeIntervalSince(at)
        let unit: String
        if elapsed < 60 {
            unit = String(format: "%.1fs", elapsed)
        } else {
            unit = "\(Int(elapsed / 60))m"
        }
        return String(localized: "popover.header.meta \(count) \(unit)")
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.inkFaint)

            TextField(text: $store.searchText) {
                Text("popover.search.placeholder")
                    .foregroundStyle(Theme.inkFaint)
            }
            .textFieldStyle(.plain)
            .font(Theme.monoSize(12))
            .foregroundStyle(Theme.ink)
            .focused($searchFocused)

            Spacer(minLength: 0)

            Text("⌘K")
                .font(Theme.monoSize(10.5))
                .foregroundStyle(Theme.inkFaint)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.line, lineWidth: 1)
                )

            // ⌘K = kill the port typed in the search field. Power-user
            // shortcut: type 8000, hit ⌘K, the matching PID gets a
            // SIGTERM. Banner reports what was killed.
            Button("") { killPortInSearch() }
                .keyboardShortcut("k", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    // MARK: - Rows / empty state

    @ViewBuilder
    private var content: some View {
        if store.filteredPorts.isEmpty {
            EmptyStateView(hasSearch: !store.searchText.isEmpty)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    switch store.settings.viewMode {
                    case .sections:
                        ForEach(store.sectionedPorts) { section in
                            PortSectionView(
                                title: section.displayTitle,
                                count: section.ports.count,
                                isPinned: section.isPinned,
                                isCollapsed: collapsedSections.contains(section.id),
                                toggleCollapse: { toggle(section.id) },
                                ports: section.ports,
                                row: makeRow
                            )
                        }
                    case .list:
                        ForEach(Array(store.filteredPorts.enumerated()), id: \.element.id) { idx, port in
                            makeRow(port)
                            if idx < store.filteredPorts.count - 1 {
                                Rectangle()
                                    .fill(Theme.line)
                                    .frame(height: 1)
                                    .padding(.leading, 14)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func makeRow(_ port: PortInfo) -> some View {
        // Reading `store.settings.rowDisplay` here registers observation
        // in RootView's body so changes from Settings re-render the
        // whole row tree, not just whoever happens to read settings via
        // @Environment.
        PortRow(
            port: port,
            lanURL: store.lanIPv4.map { "http://\($0):\(port.port)" },
            rowDisplay: store.settings.rowDisplay,
            onOpen: { store.openInBrowser(port: port.port) },
            onCopy: { store.copyAddress(port: port.port) },
            onKill: {
                Task { await store.kill(pid: port.pid) }
            },
            onRevealInFinder: {
                if let cwd = port.enrichment?.workingDirectory {
                    BrowserService.revealInFinder(path: cwd)
                }
            },
            onCopyString: { PasteboardService.copy($0) },
            onTunnelMissing: handleTunnelMissing,
            onTunnelReady: handleTunnelReady
        )
    }

    /// Auto-copy the public URL the moment a tunnel started from the
    /// row pill becomes ready, and flash a banner so the user sees
    /// what happened. Mirrors the install-hint banner UX.
    private func handleTunnelReady(_ url: URL) {
        PasteboardService.copy(url.absoluteString)
        store.flashBanner(
            String(localized: "tunnel.readyCopied \(url.absoluteString)"),
            kind: .success
        )
    }

    private func toggle(_ id: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if collapsedSections.contains(id) {
                collapsedSections.remove(id)
            } else {
                collapsedSections.insert(id)
            }
        }
    }

    /// Parses the search field as a port number. If a live row matches,
    /// kills that port's PID and flashes a confirmation banner. No-op
    /// when the field isn't a valid port or no match is found.
    private func killPortInSearch() {
        let raw = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let portNum = UInt16(raw) else { return }
        guard let port = store.filteredPorts.first(where: { $0.port == portNum }) else {
            store.flashBanner(
                String(localized: "popover.killShortcut.noMatch \(Int(portNum))"),
                kind: .error
            )
            return
        }
        let pid = port.pid
        Task {
            await store.kill(pid: pid)
            store.flashBanner(
                String(localized: "popover.killShortcut.killed \(Int(portNum)) \(Int(pid))"),
                kind: .success
            )
            store.searchText = ""
        }
    }

    private func handleTunnelMissing() {
        guard let provider = tunnelStore.activeProvider else { return }
        PasteboardService.copy(provider.installHint().command)
        // Display name is taken from the provider itself so the banner
        // automatically tracks whichever the user picked in Settings.
        store.flashBanner(
            String(localized: "tunnel.installHintCopied \(provider.displayName)")
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                BlinkingDot(color: Theme.amberSoft, size: 5, glow: 6)
                Text(scanCadenceLabel)
                    .font(Theme.monoSize(11))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer()

            Button {
                Task { await store.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: .command)
            .help("popover.refreshNow")

            pinPresetMenu

            viewModeToggle

            Button {
                NSApp.sendAction(
                    #selector(AppDelegate.openSettings(_:)),
                    to: nil,
                    from: nil
                )
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.15))
    }

    /// Footer pin menu — lets the user toggle preset groups without
    /// opening Settings. Each item shows a checkmark when the preset
    /// is currently pinned. Custom (non-preset) groups stay
    /// Settings-only — they have nothing to toggle.
    private var pinPresetMenu: some View {
        Menu {
            Section("popover.pinMenu.section") {
                ForEach(PresetGroups.all) { preset in
                    Button {
                        togglePreset(preset)
                    } label: {
                        if isPresetPinned(preset.id) {
                            Label(preset.name, systemImage: "checkmark")
                        } else {
                            Text(preset.name)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "pin")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkFaint)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("popover.pinMenu.help")
    }

    private func isPresetPinned(_ id: String) -> Bool {
        store.settings.portGroups.contains(where: { $0.presetId == id })
    }

    private func togglePreset(_ preset: PresetGroups.Preset) {
        if let idx = store.settings.portGroups.firstIndex(where: { $0.presetId == preset.id }) {
            store.settings.portGroups.remove(at: idx)
        } else {
            store.settings.portGroups.append(PresetGroups.makeGroup(from: preset))
        }
    }

    /// Two-segment toggle for the section/list view modes. Persists
    /// through `settings.viewMode`.
    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            viewModeSegment(.sections, icon: "rectangle.3.group")
            viewModeSegment(.list, icon: "list.bullet")
        }
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private func viewModeSegment(_ mode: PopoverViewMode, icon: String) -> some View {
        let active = store.settings.viewMode == mode
        return Button {
            store.settings.viewMode = mode
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(active ? Theme.ink : Theme.inkFaint)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(active ? Theme.ink.opacity(0.06) : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(mode == .sections ? "popover.viewMode.sections" : "popover.viewMode.list")
    }

    private var scanCadenceLabel: String {
        switch store.settings.refreshInterval {
        case .s1:     return String(localized: "popover.footer.scanning1s")
        case .s3:     return String(localized: "popover.footer.scanning3s")
        case .s10:    return String(localized: "popover.footer.scanning10s")
        case .manual: return String(localized: "popover.footer.scanningManual")
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        let palette = bannerPalette(for: store.bannerKind)
        return HStack(spacing: 8) {
            Image(systemName: palette.icon)
                .foregroundStyle(palette.tint)
            Text(message)
                .font(Theme.monoSize(11.5))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Solid surface + tint wash so the message reads on top of the
        // popover's gradient at any opacity.
        .background(
            ZStack {
                Theme.bg2
                palette.tint.opacity(0.22)
            }
        )
        .overlay(
            Rectangle()
                .fill(palette.tint.opacity(0.55))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func bannerPalette(for kind: BannerKind) -> (icon: String, tint: Color) {
        switch kind {
        case .success: return ("checkmark.circle.fill",       Theme.cyan)
        case .info:    return ("info.circle.fill",             Theme.amber)
        case .error:   return ("exclamationmark.triangle.fill", Theme.danger)
        }
    }
}
