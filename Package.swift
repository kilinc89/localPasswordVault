// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "LocalVault",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LocalVault", targets: ["LocalVault"]),
    ],
    targets: [
        .target(name: "VaultCore"),
        .executableTarget(name: "LocalVault", dependencies: ["VaultCore"]),
        .testTarget(name: "VaultCoreTests", dependencies: ["VaultCore"]),
    ]
)
