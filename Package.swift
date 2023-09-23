// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TCA-Navigation",
    platforms: [.iOS(.v16)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        /*.library(
         name: "TCA-Navigation",
         targets: ["TCA-Navigation"]),*/
        .library(name: "Delegates", targets: ["Delegates"]),
        .library(name: "Dependency", targets: ["Dependency"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        /*.target(
         name: "TCA-Navigation"),
         .testTarget(
         name: "TCA-NavigationTests",
         dependencies: ["TCA-Navigation"]),*/
        .target(
            name: "Delegates",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Tagged", package: "swift-tagged")
            ]
        ),
        .target(
            name: "Dependency",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Tagged", package: "swift-tagged")
            ]
        )
    ]
)

