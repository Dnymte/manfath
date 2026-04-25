import SwiftUI

/// macOS-13-style sidebar settings: a pane list on the left, detail
/// pane on the right. Replaces the old TabView. Each pane is its own
/// `View` (`GeneralTab`, `FiltersTab`, `UpdatesTab`, `AboutTab`) so the
/// split is purely about navigation chrome.
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var selection: Pane = .general

    enum Pane: String, Hashable, CaseIterable, Identifiable {
        case general
        case filters
        case about

        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .general: return "settings.pane.general"
            case .filters: return "settings.pane.filters"
            case .about:   return "settings.pane.about"
            }
        }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .filters: return "line.3.horizontal.decrease.circle"
            case .about:   return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $selection) { pane in
                Label(pane.label, systemImage: pane.icon)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            paneContent
                .navigationTitle(Text(selection.label))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, minHeight: 480)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selection {
        case .general: GeneralTab(settings: settings)
        case .filters: FiltersTab(settings: settings)
        case .about:   AboutTab()
        }
    }
}
