// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NisaCalc",
    platforms: [
        .iOS(.v18)
    ],
    targets: [
        .executableTarget(
            name: "NisaCalc",
            path: "Sources"
        )
    ]
)
