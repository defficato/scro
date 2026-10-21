// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SCRO",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "SCROCore",
            path: "Sources/SCROCore"
        ),
        .executableTarget(
            name: "SCRO",
            dependencies: ["SCROCore"],
            path: "Sources/SCRO"
        ),
        .executableTarget(
            name: "scro-cli",
            dependencies: ["SCROCore"],
            path: "Sources/scro-cli"
        )
    ]
)
