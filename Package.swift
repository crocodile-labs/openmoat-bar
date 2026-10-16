// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MoatBar",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "MoatBar", targets: ["MoatBar"]),
        .library(name: "MoatBarCore", targets: ["MoatBarCore"]),
    ],
    targets: [
        // Everything that works without a screen: running moat, decoding its
        // JSON, counting, and deciding what the menu bar icon shows.
        .target(name: "MoatBarCore"),
        // The AppKit menu bar app. Logic belongs in MoatBarCore.
        .executableTarget(
            name: "MoatBar",
            dependencies: ["MoatBarCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MoatBarCoreTests",
            dependencies: ["MoatBarCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
