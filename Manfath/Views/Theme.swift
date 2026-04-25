import SwiftUI

/// Design tokens for the Manfath popover. Mirrors the marketing site's
/// `.popover` block. Pure styling — no logic.
enum Theme {
    static let bg0       = Color(red: 10/255,  green: 10/255,  blue: 12/255)   // #0a0a0c
    static let bg1       = Color(red: 16/255,  green: 16/255,  blue: 20/255)   // #101014
    static let bg2       = Color(red: 22/255,  green: 22/255,  blue: 27/255)   // #16161b
    static let surfaceHi = Color(red: 26/255,  green: 26/255,  blue: 31/255)   // #1a1a1f
    static let surfaceLo = Color(red: 20/255,  green: 20/255,  blue: 24/255)   // #141418

    static let ink       = Color(red: 232/255, green: 228/255, blue: 218/255)  // #e8e4da
    static let inkDim    = Color(red: 154/255, green: 149/255, blue: 138/255)  // #9a958a
    static let inkFaint  = Color(red: 90/255,  green: 86/255,  blue: 78/255)   // #5a564e

    static let line       = ink.opacity(0.08)
    static let lineStrong = ink.opacity(0.16)

    static let amber     = Color(red: 184/255, green: 255/255, blue: 92/255)   // #b8ff5c
    static let amberSoft = Color(red: 143/255, green: 200/255, blue: 64/255)   // #8fc840
    static let cyan      = Color(red: 92/255,  green: 228/255, blue: 255/255)  // #5ce4ff
    static let danger    = Color(red: 255/255, green: 122/255, blue: 122/255)  // #ff7a7a

    static let popoverGradient = LinearGradient(
        colors: [surfaceHi, surfaceLo],
        startPoint: .top,
        endPoint: .bottom
    )

    static let mono     = Font.system(.body, design: .monospaced)
    static let monoSize: (CGFloat) -> Font = { size in
        .system(size: size, design: .monospaced)
    }
}
