// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KickCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KickCore", targets: ["KickCore"])],
    targets: [
        .target(name: "KickCore", resources: [.process("Resources")]),
        .testTarget(name: "KickCoreTests", dependencies: ["KickCore"], resources: [.copy("Fixtures")]),
    ]
)
