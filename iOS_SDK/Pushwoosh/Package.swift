// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Pushwoosh",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // Main SDK - pre-built XCFramework
        .library(
            name: "Pushwoosh",
            targets: ["Pushwoosh"]
        ),
        // Optional gRPC transport module
        .library(
            name: "PushwooshGRPC",
            targets: ["PushwooshGRPC"]
        ),
    ],
    dependencies: [
        // SwiftProtobuf for protobuf serialization
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.20.0"),
    ],
    targets: [
        // Main Pushwoosh SDK (binary target)
        .binaryTarget(
            name: "PushwooshFramework",
            path: "XCFrameworks/PushwooshFramework.xcframework"
        ),
        .binaryTarget(
            name: "PushwooshCore",
            path: "XCFrameworks/PushwooshCore.xcframework"
        ),
        .binaryTarget(
            name: "PushwooshBridge",
            path: "XCFrameworks/PushwooshBridge.xcframework"
        ),
        // Wrapper target for main SDK
        .target(
            name: "Pushwoosh",
            dependencies: [
                "PushwooshFramework",
                "PushwooshCore",
                "PushwooshBridge"
            ],
            path: "Sources/Pushwoosh"
        ),
        // gRPC transport module (pure HTTP/2 implementation)
        .target(
            name: "PushwooshGRPC",
            dependencies: [
                "PushwooshCore",
                "PushwooshBridge",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "PushwooshGRPC",
            exclude: ["Proto", "Info.plist", "PushwooshGRPC.h"]
        ),
    ]
)
