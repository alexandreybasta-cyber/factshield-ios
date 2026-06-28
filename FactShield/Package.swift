// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactShield",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FactShield",
            targets: ["FactShield"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FactShield",
            dependencies: [],
            path: "FactShield"
        ),
    ]
)
