import SwiftUI

/// Inline cyan badge shown after a row's process metadata when an
/// active tunnel exists for that port.
struct TunnelBadge: View {
    let label: String

    init(label: String = "live") {
        self.label = label
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.cyan)
                .frame(width: 5, height: 5)
                .shadow(color: Theme.cyan, radius: 3)
            Text(label)
                .font(Theme.monoSize(10.5))
                .foregroundStyle(Theme.cyan)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.cyan.opacity(0.08))
        )
    }
}
