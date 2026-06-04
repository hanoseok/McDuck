// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "McDuck",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "McDuckCore", targets: ["McDuckCore"]),
        .executable(name: "McDuck", targets: ["McDuck"])
    ],
    targets: [
        .target(name: "McDuckCore"),
        .executableTarget(
            name: "McDuck",
            dependencies: ["McDuckCore"],
            resources: [
                .process("Resources/AppIcon.png"),
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "McDuckCoreTests",
            dependencies: ["McDuckCore"]
        )
    ]
)
