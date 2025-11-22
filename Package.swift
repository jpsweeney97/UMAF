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
    .package(
      url: "https://github.com/apple/swift-tools-support-core.git",
      from: "0.6.0"
    ),
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      from: "1.3.0"
    ),
    .package(
      url: "https://github.com/apple/swift-crypto.git",
      from: "3.0.0"
    ),
    .package(
      url: "https://github.com/swiftlang/swift-markdown.git",
      from: "0.3.0"
    ),
    .package(
      url: "https://github.com/scinfu/SwiftSoup.git",
      from: "2.7.0"
    ),
    // NEW: Apple's standard logging
    .package(
      url: "https://github.com/apple/swift-log.git",
      from: "1.5.0"
    ),
  ],
  targets: [
    .target(
      name: "UMAFCore",
      dependencies: [
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "Markdown", package: "swift-markdown"),
        .product(name: "SwiftSoup", package: "SwiftSoup"),
        // NEW: Link Logging
        .product(name: "Logging", package: "swift-log"),
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
