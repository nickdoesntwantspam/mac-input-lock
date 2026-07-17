// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacInputLock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacInputLock", targets: ["MacInputLock"])
    ],
    targets: [
        .executableTarget(
            name: "MacInputLock",
            path: "Sources/MacInputLock"
        ),
        .testTarget(
            name: "MacInputLockTests",
            dependencies: ["MacInputLock"],
            path: "Tests/MacInputLockTests"
        )
    ]
)
