// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "gatekeeper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Gatekeeper",
            targets: ["Gatekeeper"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.113.0")
    ],
    targets: [
        .target(
            name: "Gatekeeper",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]),
        .testTarget(
            name: "GatekeeperTests",
            dependencies: [
                "Gatekeeper",
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
