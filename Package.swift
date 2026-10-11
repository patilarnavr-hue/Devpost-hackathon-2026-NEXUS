// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nexus",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Nexus", targets: ["Nexus"]),
        .executable(name: "NexusInstaller", targets: ["NexusInstaller"])
    ],
    targets: [
        .executableTarget(
            name: "Nexus",
            path: "Sources/Nexus"
        ),
        .executableTarget(
            name: "NexusInstaller",
            path: "Sources/NexusInstaller"
        )
    ]
)