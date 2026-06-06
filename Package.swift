// swift-tools-version: 5.9

import AppleProductTypes
import PackageDescription

let package = Package(
    name: "NisaCalc",
    platforms: [.iOS(.v17)],
    products: [
        .iOSApplication(
            name: "NisaCalc",
            targets: ["NisaCalc"],
            bundleIdentifier: "com.kusakalien.nisacalc",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight]
        )
    ],
    targets: [
        .executableTarget(
            name: "NisaCalc",
            path: "Sources"
        )
    ]
)
