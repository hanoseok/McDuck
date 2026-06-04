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
            // The asset catalog is compiled into the app's main bundle by
            // build-app.sh (swift build does not run actool), so exclude it here.
            exclude: ["Resources/Assets.xcassets"],
            resources: [
                .process("Resources/AppIcon.png")
            ]
        ),
        .testTarget(
            name: "McDuckCoreTests",
            dependencies: ["McDuckCore"]
        )
    ]
)
