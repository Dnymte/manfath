import SwiftUI

struct InspectPanel: View {
    let port: PortInfo
    let lanURL: String?
    let onRevealInFinder: () -> Void
    let onCopy: (String) -> Void

    @Environment(TunnelStore.self) private var tunnelStore

    // Inline ngrok-authtoken setup state. Activates when a tunnel
    // start fails with the missing-authtoken signal.
    @State private var authtokenInput: String = ""
    @State private var savingAuthtoken: Bool = false
    @State private var authtokenError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lanURL {
                lanSection(url: lanURL)
                Divider().padding(.vertical, 2)
            }

            tunnelSection
            Divider().padding(.vertical, 2)
            if let cwd = port.enrichment?.workingDirectory {
                pathRow(
                    label: "inspect.directory",
                    value: cwd,
                    trailing: {
                        iconButton(
                            systemName: "folder",
                            help: "inspect.revealInFinder",
                            action: onRevealInFinder
                        )
                    }
                )
            }
            if let cmd = port.enrichment?.commandPath {
                pathRow(
                    label: "inspect.executable",
                    value: cmd,
                    trailing: { EmptyView() }
                )
            }
            if let count = port.enrichment?.openFileCount {
                labelValue(label: "inspect.files", value: String(localized: "inspect.filesOpen \(count)"))
            }
            if let status = port.enrichment?.httpStatus {
                let latencySuffix = port.enrichment?.httpLatencyMs
                    .map { " · \($0)ms" } ?? ""
                labelValue(
                    label: "inspect.http",
                    value: "\(status)\(latencySuffix)",
                    valueColor: httpStatusColor(status)
                )
            }
            labelValue(label: "inspect.user", value: port.user)
            labelValue(label: "inspect.protocol", value: protocolLabel)
            labelValue(label: "inspect.process", value: "\(port.processName) · PID \(port.pid)")
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Tunnel section

    @ViewBuilder
    private var tunnelSection: some View {
        let tunnel = tunnelStore.tunnels[port.port]

        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Share publicly")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let tunnel {
                    tunnelStatusView(tunnel)
                } else if tunnelStore.isActiveProviderInstalled {
                    Button {
                        tunnelStore.start(port: port.port)
                    } label: {
                        Label(startTunnelLabel, systemImage: "cloud")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.tint)
                } else {
                    notInstalledView
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func tunnelStatusView(_ tunnel: ActiveTunnel) -> some View {
        switch tunnel.status {
        case .starting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Starting tunnel…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                stopButton
            }
        case .running(let url):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(url.absoluteString)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(url.absoluteString)
                }
                HStack(spacing: 8) {
                    Button {
                        BrowserService.open(url: url)
                    } label: {
                        Label("tunnel.open", systemImage: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)

                    Button {
                        onCopy(url.absoluteString)
                    } label: {
                        Label("tunnel.copyUrl", systemImage: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)

                    ShareLink(item: url) {
                        Label("tunnel.share", systemImage: "square.and.arrow.up")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                    stopButton
                }
            }
        case .failed(let reason):
            if Self.isAuthtokenFailure(reason) {
                ngrokAuthSetup
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                    dismissButton
                }
            }
        }
    }

    // MARK: - ngrok auth setup (inline flow)

    static func isAuthtokenFailure(_ reason: String) -> Bool {
        reason.lowercased().contains("authtoken")
    }

    private var ngrokAuthSetup: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                Text("tunnel.ngrokAuth.title")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                dismissButton
            }

            Text("tunnel.ngrokAuth.body")
                .font(.caption2)
                .foregroundStyle(Theme.inkDim)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: "https://dashboard.ngrok.com/get-started/your-authtoken") {
                    BrowserService.open(url: url)
                }
            } label: {
                Label("tunnel.ngrokAuth.openDashboard", systemImage: "arrow.up.right.square")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.tint)

            HStack(spacing: 6) {
                SecureField(
                    String(localized: "tunnel.ngrokAuth.placeholder"),
                    text: $authtokenInput
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
                .disabled(savingAuthtoken)
                .onSubmit { submitAuthtoken() }

                Button {
                    submitAuthtoken()
                } label: {
                    if savingAuthtoken {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("tunnel.ngrokAuth.save")
                            .font(.caption2)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(savingAuthtoken
                          || authtokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let err = authtokenError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private func submitAuthtoken() {
        let token = authtokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !savingAuthtoken else { return }
        savingAuthtoken = true
        authtokenError = nil

        Task {
            let error = await tunnelStore.saveNgrokAuthtoken(token, retryPort: port.port)
            savingAuthtoken = false
            if let error {
                authtokenError = error
            } else {
                authtokenInput = ""
            }
        }
    }

    private var stopButton: some View {
        Button {
            tunnelStore.stop(port: port.port)
        } label: {
            Label("Stop", systemImage: "stop.circle")
                .font(.caption2)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
    }

    private var dismissButton: some View {
        Button {
            tunnelStore.stop(port: port.port)
        } label: {
            Image(systemName: "xmark")
                .font(.caption2)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("Dismiss")
    }

    private var startTunnelLabel: LocalizedStringKey {
        // Match the label to whichever provider will run.
        let id = tunnelStore.activeProvider?.id ?? "cloudflared"
        return id == "ngrok" ? "tunnel.startNgrok" : "tunnel.startCloudflare"
    }

    private var notInstalledLabel: LocalizedStringKey {
        let id = tunnelStore.activeProvider?.id ?? "cloudflared"
        return id == "ngrok" ? "tunnel.ngrokNotInstalled" : "tunnel.cloudflaredNotInstalled"
    }

    private var notInstalledView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notInstalledLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let hint = tunnelStore.activeInstallHint {
                HStack(spacing: 6) {
                    Text(hint.command)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.07))
                        .cornerRadius(3)
                    Button {
                        onCopy(hint.command)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy install command")
                    Button {
                        Task { await tunnelStore.refreshInstallState() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("Re-check install")
                }
            }
        }
    }

    // MARK: - LAN section

    @ViewBuilder
    private func lanSection(url: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Test on phone")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(url)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(url)
                Button {
                    onCopy(url)
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if let qr = QRCodeService.generate(from: url, size: 90) {
                Image(nsImage: qr)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 90, height: 90)
                    .padding(4)
                    .background(Color.white)
                    .cornerRadius(4)
                    .help("Scan with your phone camera")
            }
        }
    }

    // MARK: - Row variants

    @ViewBuilder
    private func pathRow<Trailing: View>(
        label: LocalizedStringKey,
        value: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            labelColumn(label)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
            Spacer(minLength: 4)
            iconButton(
                systemName: "doc.on.doc",
                help: "inspect.copy",
                action: { onCopy(value) }
            )
            trailing()
        }
    }

    @ViewBuilder
    private func labelValue(
        label: LocalizedStringKey,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            labelColumn(label)
            Text(value)
                .font(.caption)
                .foregroundStyle(valueColor)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func labelColumn(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(width: 64, alignment: .leading)
    }

    private func iconButton(
        systemName: String,
        help: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .frame(width: 20, height: 18)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help)
    }

    // MARK: - Formatting

    private var protocolLabel: String {
        switch port.protocolKind {
        case .ipv4: return "IPv4"
        case .ipv6: return "IPv6"
        case .both: return "IPv4 + IPv6"
        }
    }

    private func httpStatusColor(_ status: Int) -> Color {
        switch status {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .primary
        }
    }
}
