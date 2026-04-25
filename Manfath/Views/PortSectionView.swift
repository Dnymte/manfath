import SwiftUI

/// Generic section header + collapsible body. Used for both pinned
/// `PortGroup` sections (top) and auto `ProcessCategory` sections.
struct PortSectionView<RowContent: View>: View {
    let title: Text
    let count: Int
    let isPinned: Bool
    let isCollapsed: Bool
    let toggleCollapse: () -> Void
    let ports: [PortInfo]
    let row: (PortInfo) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            header
            if !isCollapsed {
                ForEach(Array(ports.enumerated()), id: \.element.id) { idx, port in
                    row(port)
                    if idx < ports.count - 1 {
                        Rectangle()
                            .fill(Theme.line)
                            .frame(height: 1)
                            .padding(.leading, 14)
                    }
                }
            }
        }
    }

    private var header: some View {
        Button(action: toggleCollapse) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.amber)
                }

                title
                    .font(Theme.monoSize(11))
                    .foregroundStyle(Theme.inkDim)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Text(verbatim: "·")
                    .font(Theme.monoSize(11))
                    .foregroundStyle(Theme.inkFaint)

                Text(verbatim: String(count))
                    .font(Theme.monoSize(11))
                    .foregroundStyle(Theme.inkFaint)
                    .monospacedDigit()

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(Color.black.opacity(0.12))
        }
        .buttonStyle(.plain)
    }
}

extension ProcessCategory {
    /// Display label, localized.
    var label: LocalizedStringKey {
        switch self {
        case .devServer: return "category.devServer"
        case .database:  return "category.database"
        case .runtime:   return "category.runtime"
        case .appHelper: return "category.appHelper"
        case .system:    return "category.system"
        case .unknown:   return "category.unknown"
        }
    }
}

extension PortSection {
    /// Resolve the section title to a SwiftUI `Text`. Group sections
    /// use the user's literal name (verbatim), categories use the
    /// localized key.
    var displayTitle: Text {
        switch self {
        case .group(let g, _):    return Text(verbatim: g.name)
        case .category(let c, _): return Text(c.label)
        }
    }
}
