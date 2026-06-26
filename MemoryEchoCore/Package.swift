// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoryEchoCore",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "MemoryEchoCore", targets: ["MemoryEchoCore"]),
    ],
    targets: [
        .target(
            name: "MemoryEchoCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
