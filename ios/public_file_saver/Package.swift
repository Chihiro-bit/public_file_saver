// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "public_file_saver",
  platforms: [
    .iOS("12.0")
  ],
  products: [
    .library(name: "public-file-saver", targets: ["public_file_saver"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "public_file_saver",
      dependencies: [],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
