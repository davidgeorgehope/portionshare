// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PortionShare",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PortionShare",
            path: "Sources/PortionShare"
        )
    ]
)
