// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NisaCalc",
    platforms: [.iOS(.v18)],
    products: [
        .iOSApplication(
            name: "NisaCalc",
            targets: ["NisaCalc"],
            bundleIdentifier: "com.kusakalien.nisacalc",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .calculator),
            accentColor: .presetColor(.green),
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
