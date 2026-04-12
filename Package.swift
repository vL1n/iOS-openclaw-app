// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenClawOperator",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "OpenClawCore",
            targets: ["OpenClawCore"]
        )
    ],
    targets: [
        .target(
            name: "OpenClawCore",
            path: "Shared"
        ),
        .testTarget(
            name: "OpenClawCoreTests",
            dependencies: ["OpenClawCore"],
            path: "Tests/OpenClawCoreTests"
        )
    ]
)
