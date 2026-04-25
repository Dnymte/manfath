import SwiftUI
import AppKit
import KeyboardShortcuts

struct GeneralTab: View {
    @Bindable var settings: SettingsStore

    /// The language code the bundle resolved at launch. Captured once
    /// so we can detect when the picker's value diverges and prompt
    /// the user to restart.
    private let launchLanguageCode: String =
        Bundle.main.preferredLocalizations.first ?? "en"

    private var needsRestart: Bool {
        let target: String? = switch settings.language {
        case .system:  nil
        case .english: "en"
        case .arabic:  "ar"
        }
        return target.map { $0 != launchLanguageCode } ?? false
    }

    var body: some View {
        Form {
            Section {
                Picker("Refresh", selection: $settings.refreshInterval) {
                    ForEach(RefreshInterval.allCases, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }

                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { appearance in
                        Text(appearance.label).tag(appearance)
                    }
                }

                Picker("Menu bar badge", selection: $settings.badgeMode) {
                    ForEach(BadgeMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Picker("rowDisplay.title", selection: $settings.rowDisplay) {
                    ForEach(RowDisplay.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .help("rowDisplay.help")

                Picker("tunnelProvider.title", selection: $settings.tunnelProvider) {
                    ForEach(TunnelProviderChoice.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .help("tunnelProvider.help")

                Picker("Language", selection: $settings.language) {
                    ForEach(Language.allCases, id: \.self) { lang in
                        Text(lang.label).tag(lang)
                    }
                }

                if needsRestart {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("language.restartRequired")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("language.restartNow") {
                            NSApp.sendAction(
                                #selector(AppDelegate.relaunchApp(_:)),
                                to: nil,
                                from: nil
                            )
                        }
                    }
                }
            }

            Section("Shortcut") {
                KeyboardShortcuts.Recorder(
                    "Toggle popover",
                    name: .togglePopover
                )
            }

            Section("Launch") {
                Toggle(
                    "Launch Manfath at login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
