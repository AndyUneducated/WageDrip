// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WageDripCore",
    platforms: [.iOS("27.0"), .macOS("27.0"), .watchOS("27.0")],
    products: [
        .library(name: "WageDripCore", targets: ["WageDripCore"])
    ],
    targets: [
        .target(name: "WageDripCore", resources: [.process("Resources")]),
        .testTarget(name: "WageDripCoreTests", dependencies: ["WageDripCore"]),
    ]
)
