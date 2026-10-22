// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TipShareCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TipShareCore", targets: ["TipShareCore"])],
    targets: [
        .target(name: "TipShareCore"),
        .testTarget(name: "TipShareCoreTests", dependencies: ["TipShareCore"]),
    ]
)
