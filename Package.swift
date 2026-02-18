// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SleepLock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SleepLock", targets: ["SleepLock"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "SleepLock"
        ),
        .testTarget(
            name: "SleepLockTests",
            dependencies: [
                "SleepLock",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
