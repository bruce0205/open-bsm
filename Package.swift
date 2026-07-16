// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenBSM",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "OpenBSMCore", targets: ["OpenBSMCore"]),
        .executable(name: "OpenBSMInputMethod", targets: ["OpenBSMInputMethod"]),
    ],
    targets: [
        .target(name: "OpenBSMCore"),
        .executableTarget(
            name: "OpenBSMInputMethod",
            dependencies: ["OpenBSMCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("InputMethodKit"),
            ]
        ),
        .testTarget(
            name: "OpenBSMCoreTests",
            dependencies: ["OpenBSMCore"]
        ),
    ]
)
