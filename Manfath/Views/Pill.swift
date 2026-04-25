import SwiftUI

/// Compact action pill: just an icon at rest, slides out the label
/// on hover. Used for `open` / `tunnel` / `kill` row actions.
struct Pill: View {
    let icon: String
    let title: LocalizedStringKey
    let accent: Color
    let action: () -> Void

    @State private var isHovering = false
    @State private var hoverDebounce: Task<Void, Never>?

    /// Activate-after delay — feels deliberate, ignores brief
    /// pass-throughs while you're aiming for an adjacent pill.
    private static let activateDelay: Duration = .milliseconds(220)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 12, height: 12)

                if isHovering {
                    Text(title)
                        .font(Theme.monoSize(11))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity
                        ))
                }
            }
            .foregroundStyle(isHovering ? accent : Theme.inkDim)
            .padding(.horizontal, isHovering ? 7 : 5)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? accent.opacity(0.06) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovering ? accent.opacity(0.3) : Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in
            hoverDebounce?.cancel()
            if hover {
                hoverDebounce = Task { @MainActor in
                    try? await Task.sleep(for: Self.activateDelay)
                    if !Task.isCancelled { isHovering = true }
                }
            } else {
                isHovering = false
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isHovering)
        .help(title)
    }
}
