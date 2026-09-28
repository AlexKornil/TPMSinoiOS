// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TPMSinoiOS",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "TPMSinoiOS", targets: ["TPMSinoiOS"])
    ],
    targets: [
        .target(
            name: "TPMSinoiOS",
            path: "TPMSinoiOS",
            exclude: ["Info.plist"]
        )
    ]
)
