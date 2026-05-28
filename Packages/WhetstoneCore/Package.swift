// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhetstoneCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WhetstoneCore", targets: ["WhetstoneCore"])
    ],
    targets: [
        .target(name: "WhetstoneCore"),
        .testTarget(name: "WhetstoneCoreTests", dependencies: ["WhetstoneCore"])
    ]
)
