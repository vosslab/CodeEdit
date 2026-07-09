// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodeEdit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(
            name: "SwiftlyCodeEdit",
            targets: ["CodeEdit"]
        ),
    ],
    dependencies: [
        .package(path: "Packages/CodeEditHighlighting"),
        .package(path: "Packages/CodeEditLanguages"),
        .package(path: "Packages/CodeEditTextView"),
        .package(path: "Packages/CodeEditSyntaxDefinitions"),
    ],
    targets: [
        .executableTarget(
            name: "CodeEdit",
            dependencies: [
                .product(name: "CodeEditHighlighting", package: "CodeEditHighlighting"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "CodeEditSyntaxDefinitions", package: "CodeEditSyntaxDefinitions"),
            ],
            path: "CodeEdit",
            resources: [
                .process("Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "CodeEditTests",
            dependencies: [
                "CodeEdit",
            ],
            path: "CodeEditTests/PackageSmoke"
        ),
    ]
)
