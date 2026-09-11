// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Casmos",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "Casmos",
            targets: ["Casmos"]),
    ],
    targets: [
        .target(
            name: "Casmos",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Security")
            ]),
    ]
)
