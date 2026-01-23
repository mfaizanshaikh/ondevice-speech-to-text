// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechToText",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpeechToText", targets: ["SpeechToText"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "SpeechToText",
            dependencies: [
                "WhisperKit",
                "HotKey"
            ],
            path: "SpeechToText",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SpeechToTextTests",
            dependencies: ["SpeechToText"],
            path: "SpeechToTextTests"
        )
    ]
)
