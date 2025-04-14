// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swiftui-onlive",
  platforms: [.iOS(.v16), .macOS(.v14), .watchOS(.v9), .tvOS(.v16), .visionOS(.v1)],
  products: [
    .library(
      name: "OnLive",
      targets: ["OnLive"]),
    .executable(name: "Example", targets: ["Example"]),
  ],
  targets: [
    .target(
      name: "OnLive"),
    .executableTarget(
      name: "Example",
      dependencies: ["OnLive"]
    ),
  ]
)
