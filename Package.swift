// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacInputLock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacInputLock", targets: ["MacInputLock"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "MacInputLock",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MacInputLock",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "MacInputLockTests",
            dependencies: ["MacInputLock"],
            path: "Tests/MacInputLockTests"
        )
    ]
)
