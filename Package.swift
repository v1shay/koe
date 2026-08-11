// swift-tools-version: 5.9

import PackageDescription
import Foundation

let skipWhisperKit = ProcessInfo.processInfo.environment["MACPARAKEET_SKIP_WHISPERKIT"] == "1"
let enableMLXLocalLLM = ProcessInfo.processInfo.environment["MACPARAKEET_ENABLE_MLX_LOCAL_LLM"] == "1"

#if compiler(<6.0)
let xcode15Compatibility = true
#else
let xcode15Compatibility = false
#endif

let shouldSkipWhisperKit = skipWhisperKit || xcode15Compatibility

let grdbDependency: Package.Dependency = xcode15Compatibility
    ? .package(url: "https://github.com/groue/GRDB.swift", exact: "6.29.3")
    : .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0")

let packageDependencies: [Package.Dependency] = [
    // GRDB 7 is Swift 6 language-mode clean, while GRDB 6 is the newest line
    // whose package manifest remains compatible with Xcode 15.4.
    grdbDependency,
    // FluidAudio for Parakeet and Nemotron STT on CoreML/ANE. Keep this exact
    // until MacParakeet migrates from DownloadUtils to the ModelHub API that
    // replaced it in the breaking 0.15.5 release.
    .package(
        url: "https://github.com/v1shay/FluidAudio",
        revision: "a710aa673a2dfbb7dae97e8d770d05d23ea9c603"
    ),
    // ArgumentParser for CLI
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    // Sparkle for auto-updates (non-App Store distribution)
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    // FluidAudio's Swift module exposes yyjson under current Xcode/Swift.
    .package(url: "https://github.com/ibireme/yyjson.git", exact: "0.12.0"),
] + (shouldSkipWhisperKit ? [] : [
    // WhisperKit for multilingual STT fallback (Korean + 95 other languages).
    // Its current swift-jinja dependency requires Swift tools 6.0, so Xcode
    // 15.4 compatibility builds omit WhisperKit and use FluidAudio engines.
    .package(url: "https://github.com/argmaxinc/argmax-oss-swift", exact: "0.18.0")
]) + (enableMLXLocalLLM ? [
    // Opt-in only. mlx-swift-lm currently needs Swift tools 6.1 and Xcode-built
    // Metal shaders, so plain `swift build` / `swift test` / CI must not resolve it.
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.31.4"),
    // Direct pin holds mlx-swift-lm's transitive MLX dependency at 0.31.4; the
    // resolver would otherwise pick 0.31.6, which requires Swift tools 6.3.
    .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.31.4"),
    // Only the Tokenizers product is used (local-directory tokenizer loading).
    // Held to 1.1.x because argmax-oss-swift (WhisperKit) cannot resolve
    // alongside swift-transformers 1.3 in the gated dependency graph.
    .package(url: "https://github.com/huggingface/swift-transformers", "1.1.6" ..< "1.2.0"),
] : [])

let coreDependencies: [Target.Dependency] = [
    .product(name: "GRDB", package: "GRDB.swift"),
    .product(name: "FluidAudio", package: "FluidAudio"),
    .product(name: "yyjson", package: "yyjson"),
    "MacParakeetObjCShims"
] + (shouldSkipWhisperKit ? [] : [
    .product(name: "WhisperKit", package: "argmax-oss-swift")
])

let whisperKitSwiftSettings: [SwiftSetting] = shouldSkipWhisperKit ? [] : [
    .define("MACPARAKEET_HAS_WHISPERKIT")
]

let compatibilitySwiftSettings: [SwiftSetting] = xcode15Compatibility ? [
    .define("MACPARAKEET_XCODE15_COMPAT")
] : []

let coreExcludes = [
    "Audio/README.md",
    "Database/README.md",
    "Licensing/README.md",
    "Resources",
    "Services/System/README.md",
    "STT/README.md",
    "TextProcessing/README.md",
] + (xcode15Compatibility ? [
    "STT/NemotronEngine.swift",
    "STT/NemotronEnglishEngine.swift",
] : [])

let mlxLocalLLMSwiftSettings: [SwiftSetting] = enableMLXLocalLLM ? [
    .define("MACPARAKEET_HAS_MLX_LOCAL_LLM")
] : []

let appDependencies: [Target.Dependency] = [
    "MacParakeetCore",
    "MacParakeetViewModels",
    .product(name: "Sparkle", package: "Sparkle")
] + (enableMLXLocalLLM ? [
    "MacParakeetLocalLLM"
] : [])

let appTestDependencies: [Target.Dependency] = [
    "MacParakeet",
    "MacParakeetCore",
    "MacParakeetViewModels",
    "MacParakeetObjCShims"
] + (enableMLXLocalLLM ? [
    "MacParakeetLocalLLM"
] : [])

// Apple's Swift Testing module ships with Xcode 16. Keep the XCTest suite
// available on Xcode 15.4 while leaving these three Swift Testing files active
// on newer toolchains.
let appTestExcludes = xcode15Compatibility ? [
    "Services/CLIOperationPrivacyTests.swift",
    "Services/Telemetry/ObservabilityTests.swift",
    "Services/Telemetry/TelemetryErrorClassifierTests.swift",
] : []

let mlxLocalLLMTargets: [Target] = enableMLXLocalLLM ? [
    .target(
        name: "MacParakeetLocalLLM",
        dependencies: [
            "MacParakeetCore",
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
            .product(name: "Tokenizers", package: "swift-transformers"),
        ],
        path: "Sources/MacParakeetLocalLLM",
        swiftSettings: mlxLocalLLMSwiftSettings
    )
] : []

let standardTargets: [Target] = [
    // Main GUI app
    .executableTarget(
        name: "MacParakeet",
        dependencies: appDependencies,
        path: "Sources/MacParakeet",
        resources: [.process("Resources")],
        swiftSettings: mlxLocalLLMSwiftSettings + compatibilitySwiftSettings
    ),
    // macparakeet-cli — versioned public surface (semver, Sources/CLI/CHANGELOG.md).
    // Consumed by the macOS app, scripted callers, and downstream agent skills
    // (see /AGENTS.md and integrations/README.md).
    .executableTarget(
        name: "CLI",
        dependencies: [
            "MacParakeetCore",
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ],
        path: "Sources/CLI",
        exclude: ["CHANGELOG.md", "README.md"]
    ),
    // Objective-C shim target for catching NSException in Swift.
    // Swift's `do/try/catch` cannot catch Objective-C exceptions raised by
    // AppKit / AVFoundation / Core Audio — we need an @try/@catch trampoline
    // to convert them into Swift-throwable NSError values. See issue #91.
    .target(
        name: "MacParakeetObjCShims",
        path: "Sources/MacParakeetObjCShims",
        publicHeadersPath: "include"
    ),
    // Shared core library (no UI dependencies)
    .target(
        name: "MacParakeetCore",
        dependencies: coreDependencies,
        path: "Sources/MacParakeetCore",
        exclude: coreExcludes,
        swiftSettings: whisperKitSwiftSettings + compatibilitySwiftSettings
    ),
    // ViewModels library (testable, depends on Core + AppKit/SwiftUI)
    .target(
        name: "MacParakeetViewModels",
        dependencies: ["MacParakeetCore"],
        path: "Sources/MacParakeetViewModels",
        swiftSettings: compatibilitySwiftSettings
    ),
    // Tests
    .testTarget(
        name: "MacParakeetTests",
        dependencies: appTestDependencies,
        path: "Tests/MacParakeetTests",
        exclude: appTestExcludes,
        swiftSettings: whisperKitSwiftSettings + mlxLocalLLMSwiftSettings + compatibilitySwiftSettings
    ),
    .testTarget(
        name: "CLITests",
        dependencies: ["CLI", "MacParakeetCore"],
        path: "Tests/CLITests"
    )
]

let package = Package(
    name: "MacParakeet",
    platforms: [
        // Note: SPM doesn't support patch-level versions for macOS 14, but the app
        // documents macOS 14.2+ and enforces it at runtime.
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacParakeet", targets: ["MacParakeet"]),
        .executable(name: "macparakeet-cli", targets: ["CLI"]),
        .library(name: "MacParakeetCore", targets: ["MacParakeetCore"]),
        .library(name: "MacParakeetViewModels", targets: ["MacParakeetViewModels"])
    ],
    dependencies: packageDependencies,
    targets: standardTargets + mlxLocalLLMTargets
)
