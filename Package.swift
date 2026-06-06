// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "McDuck",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "McDuckCore", targets: ["McDuckCore"]),
        .executable(name: "McDuck", targets: ["McDuck"]),
        .executable(name: "mcduck-mcp", targets: ["mcduck-mcp"])
    ],
    targets: [
        .target(name: "McDuckCore"),
        .target(
            name: "McDuckMCP",
            dependencies: ["McDuckCore"]
        ),
        .executableTarget(
            name: "McDuck",
            dependencies: ["McDuckCore"]
        ),
        .executableTarget(
            name: "mcduck-mcp",
            dependencies: ["McDuckCore", "McDuckMCP"]
        ),
        .testTarget(
            name: "McDuckCoreTests",
            dependencies: ["McDuckCore"]
        ),
        .testTarget(
            name: "McDuckTests",
            dependencies: ["McDuck", "McDuckCore"]
        ),
        .testTarget(
            name: "McDuckMCPTests",
            dependencies: ["McDuckMCP", "McDuckCore"]
        )
    ]
)
