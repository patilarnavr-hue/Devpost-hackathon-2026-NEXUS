import PackageDescription

let package = Package(
    name:"Nexus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Nexus",
            path: "Sources/Nexus"
        )
    ]
)