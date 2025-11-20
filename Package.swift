// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "UMAF",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "UMAFCore",
      targets: ["UMAFCore"]
    ),
    .executable(
      name: "umaf",
      targets: ["umaf"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-tools-support-core", from: "0.6.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
  ],
  targets: [
    .target(
      name: "UMAFCore",
      dependencies: [
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core")
      ]
    ),
    .executableTarget(
      name: "umaf",
      dependencies: [
        "UMAFCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "UMAFCoreTests",
      dependencies: ["UMAFCore"]
    ),
  ]
)
