import SwiftUI

struct EmptyStateView: View {
    let hasSearch: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: hasSearch ? "magnifyingglass" : "network.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.inkFaint)
            Text(hasSearch ? "No matches" : "No services listening")
                .font(Theme.monoSize(13))
                .foregroundStyle(Theme.inkDim)
            if !hasSearch {
                Text("Start a dev server and it'll show up here.")
                    .font(Theme.monoSize(11.5))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}
