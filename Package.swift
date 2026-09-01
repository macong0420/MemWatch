// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MemWatch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MemWatch",
            path: "Sources/MemWatch"
        )
    ]
)