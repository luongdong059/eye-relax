// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EyeRelax",
    defaultLocalization: "vi",
    platforms: [.macOS(.v13)],
    targets: [
        // Core: models + engine thuần logic, không phụ thuộc UI — test được độc lập.
        .target(
            name: "EyeRelaxCore",
            path: "Sources/EyeRelaxCore"
        ),
        // App: UI (SwiftUI/AppKit), overlay, menu bar, cửa sổ chính.
        .executableTarget(
            name: "EyeRelax",
            dependencies: ["EyeRelaxCore"],
            path: "Sources/EyeRelax",
            resources: [
                .copy("Resources/cartoon.png")
            ]
        ),
        .testTarget(
            name: "EyeRelaxCoreTests",
            dependencies: ["EyeRelaxCore"],
            path: "Tests/EyeRelaxCoreTests"
        ),
    ]
)
