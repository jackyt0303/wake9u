// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wake9u",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Wake9uDomain", targets: ["Wake9uDomain"]),
        .executable(name: "Wake9uDomainCheck", targets: ["Wake9uDomainCheck"])
    ],
    targets: [
        .target(name: "Wake9uDomain"),
        .executableTarget(name: "Wake9uDomainCheck", dependencies: ["Wake9uDomain"])
    ]
)
