# Model Cache Design

## Problem

When fetching models in the provider settings screen, then navigating to model selection in the transformations editor (using the same provider), users must re-fetch. Returning to the providers screen also requires re-fetching. Models should be cached at the application level to avoid redundant API calls.

## Current State

Five separate `@State private var availableModels` variables exist across views:
- `OpenAIProviderSection` (line 12)
- `OpenRouterProviderSection` (line 207)
- `OllamaProviderSection` (line 324)
- `AWSBedrockProviderSection` (line 466)
- `TransformationEditorView` (line 53)

Each view fetches independently via provider-specific validators. No shared cache exists.

## Design Decisions

1. **Cache lifetime**: Per settings window session. Cache persists while settings is open, clears when window closes.
2. **Fetch button behavior**: Always makes fresh API call and updates cache. Cache benefit is for navigation between tabs, not for skipping intentional fetches.

## Solution

### 1. ModelCache Class

Create `Sources/OptimusClip/Services/ModelCache.swift`:

```swift
import Foundation
import OptimusClipCore
import SwiftUI

/// Application-level cache for fetched LLM models.
///
/// Injected via SwiftUI environment. Cache lifetime is tied to
/// the settings window session - cleared when window closes.
@Observable
final class ModelCache {
    private var cache: [LLMProviderKind: [LLMModel]] = [:]

    /// Returns cached models for provider, or nil if not cached.
    func models(for provider: LLMProviderKind) -> [LLMModel]? {
        self.cache[provider]
    }

    /// Stores models in cache for provider.
    func setModels(_ models: [LLMModel], for provider: LLMProviderKind) {
        self.cache[provider] = models
    }

    /// Clears all cached models.
    func clear() {
        self.cache.removeAll()
    }
}

// MARK: - Environment Key

private struct ModelCacheKey: EnvironmentKey {
    static let defaultValue: ModelCache = ModelCache()
}

extension EnvironmentValues {
    var modelCache: ModelCache {
        get { self[ModelCacheKey.self] }
        set { self[ModelCacheKey.self] = newValue }
    }
}
```

### 2. App Integration

In `OptimusClipApp.swift`, add cache property and inject into settings:

```swift
@main
struct OptimusClipApp: App {
    // ... existing properties ...

    /// Model cache for settings window session.
    @State private var modelCache = ModelCache()

    var body: some Scene {
        // ... MenuBarExtra unchanged ...

        Settings {
            SettingsView()
                .onAppear { self.modelCache = ModelCache() }
        }
        .environment(\.modelCache, self.modelCache)
        // ... rest unchanged ...
    }
}
```

The `onAppear` creates a fresh cache each time the settings window opens.

### 3. Provider Section Changes

Each provider section changes from local state to shared cache.

**Before:**
```swift
struct OpenAIProviderSection: View {
    @State private var availableModels: [OpenAIModel] = []
    @State private var isLoadingModels = false
}
```

**After:**
```swift
struct OpenAIProviderSection: View {
    @Environment(\.modelCache) private var modelCache
    @State private var isLoadingModels = false

    private var availableModels: [OpenAIModel] {
        self.modelCache.models(for: .openAI)?
            .map { OpenAIModel(id: $0.id) } ?? []
    }

    private func fetchModels() {
        self.isLoadingModels = true
        Task {
            do {
                let models = try await OpenAIValidator.listModels(apiKey: self.apiKey)
                await MainActor.run {
                    self.modelCache.setModels(
                        models.map { LLMModel(id: $0.id, name: $0.id) },
                        for: .openAI
                    )
                    self.isLoadingModels = false
                }
            } catch { /* existing error handling */ }
        }
    }
}
```

Apply same pattern to:
- `OpenRouterProviderSection` (provider: `.openRouter`)
- `OllamaProviderSection` (provider: `.ollama`)
- `AWSBedrockProviderSection` (provider: `.awsBedrock`)

### 4. TransformationEditorView Changes

```swift
struct TransformationEditorView: View {
    @Environment(\.modelCache) private var modelCache
    @State private var isLoadingModels = false

    private var availableModels: [LLMModel] {
        guard let providerKind = self.currentProviderKind else { return [] }
        return self.modelCache.models(for: providerKind) ?? []
    }

    private func fetchModels() {
        guard let providerKind = self.currentProviderKind else { return }
        self.isLoadingModels = true
        Task {
            let fetcher = ModelFetcher()
            let models = await fetcher.fetchModels(for: providerKind)
            await MainActor.run {
                self.modelCache.setModels(models, for: providerKind)
                self.isLoadingModels = false
            }
        }
    }
}
```

### 5. Cleanup

Remove `onChange` handlers that clear models when credentials change:

```swift
// DELETE these patterns from provider sections:
.onChange(of: self.apiKey) { _, _ in
    self.availableModels = []  // Remove this line
}
```

Cache retains models even if credentials change. User can re-fetch if needed.

## Files to Modify

1. **Create**: `Sources/OptimusClip/Services/ModelCache.swift`
2. **Modify**: `Sources/OptimusClip/OptimusClipApp.swift`
3. **Modify**: `Sources/OptimusClip/Views/Settings/Providers/ProviderSections.swift`
4. **Modify**: `Sources/OptimusClip/Views/Settings/Transformations/TransformationEditorView.swift`

## Testing

1. Open settings, go to Providers tab
2. Configure OpenAI, click Fetch - models load
3. Navigate to Transformations tab, select OpenAI provider - models already populated
4. Navigate back to Providers tab - models still populated
5. Close settings window, reopen - cache is cleared, must fetch again
6. Click Fetch when models already cached - fresh fetch occurs
