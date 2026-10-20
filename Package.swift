// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchBuddy",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "NotchBuddyCore"),
        .executableTarget(name: "NotchBuddy", dependencies: ["NotchBuddyCore"]),
        .testTarget(name: "NotchBuddyCoreTests", dependencies: ["NotchBuddyCore"]),
    ]
)
