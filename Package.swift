// swift-tools-version: 5.9
import PackageDescription

// The Swift package mirrors the Xcode app's source tree so pure-logic
// code can be tested via `swift test` without needing Xcode. The app
// target itself is generated from project.yml via XcodeGen.
//
// Directories excluded here contain code that depends on AppKit/SwiftUI
// or is otherwise app-target-only. As files are added, update the
// `sources` list.

let package = Package(
    name: "ManfathCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ManfathCore", targets: ["ManfathCore"]),
    ],
    targets: [
        .target(
            name: "ManfathCore",
            path: "Manfath",
            exclude: ["App", "Resources", "Views"],
            sources: ["Core", "Services", "Stores"]
        ),
        .testTarget(
            name: "ManfathCoreTests",
            dependencies: ["ManfathCore"],
            path: "ManfathTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
