// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeynoteMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "keynote-mcp",
            targets: ["KeynoteMCP"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            from: "0.10.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "KeynoteMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/KeynoteMCP"
        )
    ]
)
