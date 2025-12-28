# Model Selector Combobox Design

**Bead:** oc-37y
**Date:** 2025-12-28

## Summary

Replace the transformation editor's model text field with a combobox that shows available models and a "Default" option that follows the provider's configured default.

## Key Decisions

1. **Shared cache** - Use existing `ModelCatalog` which caches to UserDefaults. Models fetched on provider settings page are available on transformation editor and vice versa.

2. **Lazy loading** - Only fetch when user clicks "Fetch" button. Show just "Default" option if cache is empty.

3. **Default vs pinned** - Two distinct behaviors:
   - "Default (gpt-4o)" → `model = nil` → Follows provider default, updates when default changes
   - "gpt-4o" (explicit) → `model = "gpt-4o"` → Pinned, won't change

## Data Model

No changes. Existing `TransformationConfig.model: String?` already supports:
- `nil` = use provider default
- `"model-id"` = pinned to specific model

## UI Layout

```
┌─────────────────────────────────────────────────────────┐
│ Model                                                   │
│ ┌─────────────────────────────────┐  ┌───────┐         │
│ │ Default (gpt-4o-mini)        ▼  │  │ Fetch │         │
│ └─────────────────────────────────┘  └───────┘         │
│ Using provider default                                  │
└─────────────────────────────────────────────────────────┘
```

**Combobox items:**
1. "Default (resolved-model-name)" - always first
2. Fetched/cached models from ModelCatalog

**Helper text:**
- Default selected: "Using provider default"
- Model selected: "Pinned to this model"
- Cache empty: "Click Fetch to load available models"

## Implementation

1. **TransformationEditorView.swift** - Replace `modelPickerSection`:
   - Reuse `ComboBox` component from ProviderSections
   - Add fetch button (same style as provider page)
   - Build items: Default option + cached models

2. **Extract ComboBox** - Move to shared location if needed for import

3. **Fetch via ModelCatalog** - Handles caching automatically

## Behavior

- Provider changes → Clear models, update Default display
- New transformations → Pre-select "Default"
- Fetch → Check cache first, then API if needed
