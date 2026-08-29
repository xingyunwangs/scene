// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Scene",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Scene", targets: ["Scene"]),
        .library(name: "SceneCore", targets: ["SceneCore"]),
    ],
    targets: [
        .target(name: "SceneCore"),
        .executableTarget(name: "Scene", dependencies: ["SceneCore"]),
        .testTarget(name: "SceneCoreTests", dependencies: ["SceneCore"]),
    ]
)
