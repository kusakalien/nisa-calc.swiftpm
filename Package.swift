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
            displayVersion: "1.1",
            bundleVersion: "2",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight]
        )
    ],
    targets: [
        .executableTarget(
            name: "NisaCalc",
            path: "Sources"
        )
    ]
)
