// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TPMSinoiOS",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(name: "TPMSinoiOS", targets: ["TPMSinoiOS"])
    ],
    targets: [
        .executableTarget(
            name: "TPMSinoiOS",
            path: "TPMSinoiOS",
            exclude: ["Info.plist", "Assets.xcassets"]
        )
    ]
)
