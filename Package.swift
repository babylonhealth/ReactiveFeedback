// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "ReactiveFeedback",
    products: [
        .library(name: "ReactiveFeedback", targets: ["ReactiveFeedback"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "7.1.1"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "10.0.0"),
    ],
    targets: [
        .target(name: "ReactiveFeedback", dependencies: ["ReactiveSwift"], path: "ReactiveFeedback"),
        .testTarget(name: "ReactiveFeedbackTests", dependencies: ["ReactiveFeedback", "ReactiveSwift", "Nimble"], path: "ReactiveFeedbackTests"),
    ],
    swiftLanguageVersions: [5]
)
