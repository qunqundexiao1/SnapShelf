// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapShelf",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SnapShelf", targets: ["SnapShelf"])],
    targets: [
        .executableTarget(name: "SnapShelf"),
        .testTarget(name: "SnapShelfTests", dependencies: ["SnapShelf"])
    ]
)
