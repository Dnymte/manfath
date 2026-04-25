import SwiftUI

struct PortRow: View {
    let port: PortInfo
    let lanURL: String?
    let rowDisplay: RowDisplay
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onKill: () -> Void
    let onRevealInFinder: () -> Void
    let onCopyString: (String) -> Void
    let onTunnelMissing: () -> Void
    let onTunnelReady: (URL) -> Void

    @Environment(TunnelStore.self) private var tunnelStore
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var killHovering = false
    @State private var killHoverDebounce: Task<Void, Never>?
    @State private var confirmingKill = false
    @State private var confirmResetTask: Task<Void, Never>?
    /// Set when the user starts a tunnel from the row pill. Watched
    /// by `.onChange` so we can auto-copy the public URL the moment
    /// ngrok / cloudflared finishes booting.
    @State private var autoCopyOnReady: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if isExpanded {
                InspectPanel(
                    port: port,
                    lanURL: lanURL,
                    onRevealInFinder: onRevealInFinder,
                    onCopy: onCopyString
                )
            }
        }
        .background(
            isHovering || isExpanded
                ? Theme.ink.opacity(0.025)
                : Color.clear
        )
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onChange(of: tunnelStore.tunnels[port.port]?.status) { _, newStatus in
            if autoCopyOnReady, case .running(let url) = newStatus {
                autoCopyOnReady = false
                onTunnelReady(url)
            }
        }
    }

    // MARK: - Main row

    private var mainRow: some View {
        HStack(spacing: 12) {
            // Click target: port number + process info → toggles expand.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(verbatim: String(port.port))
                        .font(.system(size: 12.5, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Theme.amber)
                        .monospacedDigit()
                        .frame(width: 60, alignment: .leading)

                    HStack(spacing: 6) {
                        if showIcon, let icon = brandIcon {
                            BrandIconView(descriptor: icon, size: 13)
                        }

                        if showProcessName {
                            Text(verbatim: port.processName)
                                .font(Theme.monoSize(12.5))
                                .foregroundStyle(Theme.ink)
                        }

                        Text(verbatim: dimSuffix)
                            .font(Theme.monoSize(12.5))
                            .foregroundStyle(Theme.inkFaint)

                        if hasActiveTunnel {
                            TunnelBadge()
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Action pills — opacity .35 at rest, full on row hover.
            HStack(spacing: 6) {
                Pill(
                    icon: "arrow.up.right.square",
                    title: "popover.action.open",
                    accent: Theme.amber,
                    action: onOpen
                )
                Pill(
                    icon: hasAnyTunnel ? "stop.circle" : "cloud",
                    title: tunnelPillKey,
                    accent: Theme.cyan,
                    action: tunnelTapped
                )
                killPill
            }
            .opacity(isHovering ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hover in
            isHovering = hover
            if !hover { resetKillConfirm() }
        }
    }

    // MARK: - Subtitle helpers

    /// Dim suffix composition adapts to `RowDisplay`:
    ///   - iconOnly:  no leading separator (no process name in front)
    ///   - labelOnly: framework word + project + pid
    ///   - both:      project + pid (framework conveyed by the icon)
    private var dimSuffix: String {
        var parts: [String] = []
        if showLabel, let hint = port.enrichment?.framework,
           let label = Self.frameworkLabel(for: hint) {
            parts.append(label)
        }
        if let proj = port.enrichment?.projectName, !proj.isEmpty {
            parts.append(proj)
        }
        parts.append(String(port.pid))
        let body = parts.joined(separator: " · ")
        return showProcessName ? " · " + body : body
    }

    /// Pick a brand icon by framework hint or process name. Returns
    /// `nil` for unrecognized processes — the row stays minimal.
    private var brandIcon: BrandIconDescriptor? {
        BrandIcons.forProcess(
            processName: port.processName,
            framework: port.enrichment?.framework
        )
    }

    private var showIcon: Bool {
        rowDisplay == .iconOnly || rowDisplay == .both
    }

    /// "Label" here = framework descriptor in the dim suffix (e.g. "next.js").
    /// In iconOnly mode the icon stands in for that.
    private var showLabel: Bool {
        rowDisplay == .labelOnly || rowDisplay == .both
    }

    /// Hide the process name (e.g. "node") in iconOnly so the row is
    /// truly compact — the brand icon already identifies the runtime.
    private var showProcessName: Bool {
        rowDisplay != .iconOnly
    }

    private static func frameworkLabel(for hint: FrameworkHint) -> String? {
        switch hint {
        case .nextjs:     return "next.js"
        case .vite:       return "vite"
        case .cra:        return "cra"
        case .rails:      return "rails"
        case .django:     return "django"
        case .flask:      return "flask"
        case .express:    return "express"
        case .spring:     return "spring"
        case .rustRocket: return "rocket"
        case .rustActix:  return "actix"
        case .goStdlib:   return "go"
        case .nuxt:       return "nuxt"
        case .astro:      return "astro"
        case .svelte:     return "svelte"
        case .remix:      return "remix"
        case .unknown:    return nil
        }
    }

    // MARK: - Tunnel

    private var hasActiveTunnel: Bool {
        guard let active = tunnelStore.tunnels[port.port] else { return false }
        if case .running = active.status { return true }
        return false
    }

    private var hasAnyTunnel: Bool {
        tunnelStore.tunnels[port.port] != nil
    }

    private var tunnelPillKey: LocalizedStringKey {
        hasAnyTunnel ? "popover.action.stop" : "popover.action.tunnel"
    }

    private func tunnelTapped() {
        if hasAnyTunnel {
            tunnelStore.stop(port: port.port)
            autoCopyOnReady = false
            return
        }
        if tunnelStore.isActiveProviderInstalled {
            // Arm the auto-copy: when the URL arrives, we'll copy it
            // and let RootView flash a banner.
            autoCopyOnReady = true
            tunnelStore.start(port: port.port)
        } else {
            onTunnelMissing()
        }
    }

    // MARK: - Kill pill (hover styling + two-tap confirm)

    private var killPill: some View {
        let labelExpanded = killHovering || confirmingKill
        return Button(action: handleKillTap) {
            HStack(spacing: 4) {
                Image(systemName: confirmingKill ? "exclamationmark.triangle.fill" : "trash")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 12, height: 12)

                if labelExpanded {
                    Text(confirmingKill
                         ? LocalizedStringKey("popover.action.confirm")
                         : LocalizedStringKey("popover.action.kill"))
                        .font(Theme.monoSize(11))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity
                        ))
                }
            }
            .foregroundStyle(killTextColor)
            .padding(.horizontal, labelExpanded ? 7 : 5)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(killBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(killBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            killHoverDebounce?.cancel()
            if hovering {
                killHoverDebounce = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    if !Task.isCancelled { killHovering = true }
                }
            } else {
                killHovering = false
                resetKillConfirm()
            }
        }
        .animation(.easeInOut(duration: 0.28), value: killHovering)
        .animation(.easeInOut(duration: 0.18), value: confirmingKill)
        .help(confirmingKill ? "row.confirmKill \(Int(port.pid))" : "row.killPid \(Int(port.pid))")
    }

    private var killTextColor: Color {
        if confirmingKill { return .white }
        return killHovering ? Theme.danger : Theme.inkDim
    }

    private var killBackground: Color {
        if confirmingKill { return Theme.danger }
        return killHovering ? Theme.danger.opacity(0.06) : .clear
    }

    private var killBorder: Color {
        if confirmingKill { return Theme.danger }
        return killHovering ? Theme.danger.opacity(0.3) : Theme.line
    }

    private func handleKillTap() {
        if confirmingKill {
            confirmResetTask?.cancel()
            confirmingKill = false
            onKill()
        } else {
            confirmingKill = true
            confirmResetTask?.cancel()
            confirmResetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { confirmingKill = false }
            }
        }
    }

    private func resetKillConfirm() {
        confirmResetTask?.cancel()
        confirmingKill = false
    }
}
