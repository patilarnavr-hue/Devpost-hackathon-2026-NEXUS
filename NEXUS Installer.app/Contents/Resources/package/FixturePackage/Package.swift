// swift-tools-version: 6.0
import Packagedescription

let package = Package(
    name: "FixturePackage",
    targets: [
        .target(name: "FixturePackage", path: "Sources/FixturePackage"),
        .executableTarget(name: "FixtureTests", dependencies: ["FixturePackage"], path: "Tests/FixtureTests")
    ]
)