// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "onboarding-kit",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "onboarding-kit",
            targets: ["onboarding-kit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/plaid/plaid-link-ios.git", exact: "3.1.1"),

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "onboarding-kit",
            dependencies: [
                .product(name: "LinkKit", package: "plaid-link-ios"),
            ]),
        .testTarget(
            name: "onboarding-kitTests",
            dependencies: ["onboarding-kit"]),
    ])
