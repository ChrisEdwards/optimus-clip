// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OptimusClip",

    // PLATFORM REQUIREMENTS
    // macOS 15 (Sequoia) required for:
    // - MenuBarExtra SwiftUI component
    // - Swift 6 concurrency improvements
    // - Latest SF Symbols
    platforms: [
        .macOS(.v15)
    ],

    // PRODUCTS
    // What this package produces (the executable app)
    products: [
        .executable(
            name: "OptimusClip",
            targets: ["OptimusClip"]
        )
    ],

    // DEPENDENCIES
    // External packages this project depends on
    dependencies: [
        // Global hotkey recording and management
        // Allows users to define custom keyboard shortcuts
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            from: "2.0.0"
        ),

        // Access NSStatusItem from SwiftUI MenuBarExtra
        // Required for menu bar icon pulse animation
        .package(
            url: "https://github.com/orchetect/MenuBarExtraAccess",
            from: "1.0.0"
        ),

        // OpenAI Chat API client for LLM transformations
        // Supports GPT-4o, GPT-4o-mini, and other OpenAI models
        .package(
            url: "https://github.com/kevinhermawan/swift-llm-chat-openai",
            from: "1.0.0"
        )
    ],

    // TARGETS
    // The building blocks of this package
    targets: [
        // EXECUTABLE TARGET: OptimusClip
        // The main application entry point
        // This is the "thin" layer - just UI and app lifecycle
        .executableTarget(
            name: "OptimusClip",
            dependencies: [
                // Depends on our Core library
                "OptimusClipCore",

                // Third-party dependencies
                "KeyboardShortcuts",
                .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess"),
                .product(name: "LLMChatOpenAI", package: "swift-llm-chat-openai")
            ],
            path: "Sources/OptimusClip",

            // Swift 6 concurrency checking
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("AccessLevelOnImport")
            ]
        ),

        // LIBRARY TARGET: OptimusClipCore
        // All business logic, fully testable
        // No AppKit/SwiftUI dependencies (pure Swift)
        .target(
            name: "OptimusClipCore",
            dependencies: [],
            path: "Sources/OptimusClipCore",

            // Swift 6 concurrency checking
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("AccessLevelOnImport")
            ]
        ),

        // TEST TARGET: OptimusClipTests
        // Unit and integration tests
        .testTarget(
            name: "OptimusClipTests",
            dependencies: [
                // Depend on both Core and the main app target
                // Core for transformation logic, OptimusClip for app-level services
                "OptimusClipCore",
                "OptimusClip"
            ],
            path: "Tests/OptimusClipTests",

            // Swift 6 concurrency checking
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("AccessLevelOnImport")
            ]
        )
    ]
)
