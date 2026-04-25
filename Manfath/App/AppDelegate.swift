import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var store: PortStore?
    private var tunnelStore: TunnelStore?
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let scanner = PortScanner(source: LsofPortSource())
        let settings = SettingsStore()
        let processController = ProcessController()
        let enrichment = EnrichmentCoordinator(providers: [
            HTTPProbeProvider(),
            CwdProvider(processController: processController),
        ])
        let store = PortStore(
            scanner: scanner,
            settings: settings,
            processController: processController,
            enrichmentCoordinator: enrichment
        )
        store.start()

        let tunnelStore = TunnelStore(settings: settings)
        Task { await tunnelStore.refreshInstallState() }

        self.store = store
        self.tunnelStore = tunnelStore
        self.menuBar = MenuBarController(store: store, tunnelStore: tunnelStore)

        trackAppearance()
        trackTunnelPruning()
    }

    // MARK: - Tunnel pruning

    private func trackTunnelPruning() {
        withObservationTracking {
            if let ports = store?.ports, let tunnelStore {
                let live = Set(ports.map(\.port))
                tunnelStore.prune(livePorts: live)
            }
        } onChange: {
            Task { @MainActor [weak self] in
                self?.trackTunnelPruning()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
    }

    @objc func relaunchApp(_ sender: Any?) {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Appearance

    private func trackAppearance() {
        withObservationTracking {
            if let settings = store?.settings {
                applyAppearance(settings.appearance)
            }
        } onChange: {
            Task { @MainActor [weak self] in
                self?.trackAppearance()
            }
        }
    }

    private func applyAppearance(_ appearance: Appearance) {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Settings window

    @objc func openSettings(_ sender: Any?) {
        guard let store else { return }
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(settings: store.settings)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "Manfath Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 760, height: 520))
            window.minSize = NSSize(width: 720, height: 480)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
