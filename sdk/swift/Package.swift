// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SkanQRCode",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "SkanQRCode", targets: ["SkanQRCode"])
    ],
    targets: [
        .target(name: "SkanQRCode")
    ]
)
