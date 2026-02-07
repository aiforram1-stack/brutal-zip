// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BrutalZip",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "BrutalZipCore",
            targets: ["BrutalZipCore"]
        ),
        .executable(
            name: "BrutalZip",
            targets: ["BrutalZip"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "BrutalZipCore"
        ),
        .executableTarget(
            name: "BrutalZip",
            dependencies: ["BrutalZipCore"]
        ),
        .testTarget(
            name: "BrutalZipCoreTests",
            dependencies: [
                "BrutalZipCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
