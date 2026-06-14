// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "SlapToYes",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SharedTypes",
            path: "Sources/SharedTypes"
        ),
        .executableTarget(
            name: "SlapDaemon",
            dependencies: ["SharedTypes"],
            path: "Sources/SlapDaemon"
        ),
        .executableTarget(
            name: "SlapToYes",
            dependencies: ["SharedTypes"],
            path: "Sources/SlapToYes"
        ),
        .testTarget(
            name: "SlapToYesTests",
            dependencies: ["SlapToYes"],
            path: "Tests/SlapToYesTests"
        ),
    ]
)
