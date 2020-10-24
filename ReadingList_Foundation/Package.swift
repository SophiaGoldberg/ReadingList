// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ReadingList_Foundation",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "ReadingList_Foundation",
            targets: ["ReadingList_Foundation"]
        )
    ],
    targets: [
        .target(name: "ReadingList_Foundation", path: "./")
    ]
)
