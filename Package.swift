// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MoatBar",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "MoatBarCore", targets: ["MoatBarCore"]),
    ],
    targets: [
        // Everything that works without a screen: running moat, decoding its
        // JSON, counting, and deciding what the menu bar icon shows.
        .target(name: "MoatBarCore"),
        .testTarget(
            name: "MoatBarCoreTests",
            dependencies: ["MoatBarCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
