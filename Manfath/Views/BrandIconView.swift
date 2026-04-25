import SwiftUI

/// Renders a `BrandIconDescriptor` at the given square size. SVGs from
/// the asset catalog are template-rendered (single-color) so the tint
/// is applied via `.foregroundStyle`.
struct BrandIconView: View {
    let descriptor: BrandIconDescriptor
    let size: CGFloat

    var body: some View {
        Group {
            switch descriptor.source {
            case .asset(let name):
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            case .sfSymbol(let name):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(descriptor.tint)
    }
}
