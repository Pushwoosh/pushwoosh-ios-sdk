// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PushwooshFramework",
    products: [
        .library(
            name: "PushwooshFramework",
            targets: ["PushwooshFramework"]),
        .library(
            name: "PushwooshCore",
            targets: ["PushwooshCore"]),
        .library(
            name: "PushwooshBridge",
            targets: ["PushwooshBridge"]),
        .library(
            name: "PushwooshLiveActivities",
            targets: ["PushwooshLiveActivities"]),
        .library(
            name: "PushwooshVoIP",
            targets: ["PushwooshVoIP"])
    ],
    targets: [
        .binaryTarget(
            name: "PushwooshFramework",
            url: "__PushwooshFramework_URL__",
            checksum: "__PushwooshFramework_CHECKSUM__"
        ),
        .binaryTarget(
            name: "PushwooshCore",
            url: "__PushwooshCore_URL__",
            checksum: "__PushwooshCore_CHECKSUM__"
        ),
        .binaryTarget(
            name: "PushwooshBridge",
            url: "__PushwooshBridge_URL__",
            checksum: "__PushwooshBridge_CHECKSUM__"
        ),
        .binaryTarget(
            name: "PushwooshLiveActivities",
            url: "__PushwooshLiveActivities_URL__",
            checksum: "__PushwooshLiveActivities_CHECKSUM__"
        ),
        .binaryTarget(
            name: "PushwooshVoIP",
            url: "__PushwooshVoIP_URL__",
            checksum: "__PushwooshVoIP_CHECKSUM__"
        )
    ]
)
