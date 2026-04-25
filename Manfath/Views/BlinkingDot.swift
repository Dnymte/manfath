import SwiftUI

/// Live LED indicator that pulses on a 2.2s loop.
/// Matches the mock's `@keyframes blink { 0%,60% opacity 1; 80% .3; 100% 1 }`.
struct BlinkingDot: View {
    let color: Color
    let size: CGFloat
    let glow: CGFloat

    init(color: Color, size: CGFloat = 6, glow: CGFloat = 10) {
        self.color = color
        self.size = size
        self.glow = glow
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.2) / 2.2
            let opacity = blinkOpacity(at: phase)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .opacity(opacity)
                .shadow(color: color.opacity(opacity * 0.9), radius: glow / 2)
        }
    }

    private func blinkOpacity(at t: Double) -> Double {
        if t < 0.6 { return 1.0 }
        if t < 0.8 { return 1.0 - (t - 0.6) / 0.2 * 0.7 }   // 1.0 → 0.3
        return 0.3 + (t - 0.8) / 0.2 * 0.7                  // 0.3 → 1.0
    }
}
