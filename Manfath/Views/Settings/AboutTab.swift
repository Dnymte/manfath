import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text("Manfath")
                    .font(.system(size: 22, weight: .semibold))
                Text(versionLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text("A localhost port dashboard for developers.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("about.updateNote")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack(spacing: 16) {
                Link("Source", destination: URL(string: "https://github.com/Dnymte/manfath")!)
                Link("Report an issue", destination: URL(string: "https://github.com/Dnymte/manfath/issues")!)
            }
            .font(.caption)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return String(localized: "about.version \(version) \(build)")
    }
}
