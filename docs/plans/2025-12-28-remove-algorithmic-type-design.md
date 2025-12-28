# Remove Algorithmic as User-Selectable Transformation Type

**Bead:** oc-b96
**Date:** 2025-12-28
**Status:** Design complete

## Problem

Users can create new transformations with type "algorithmic", but this just duplicates the hardcoded Clean Terminal Text behavior with no configurability. The type picker creates confusion without providing value.

## Solution

1. Remove the type picker from the transformation editor
2. New transformations default to LLM type
3. Make "Clean Terminal Text" a permanent built-in with restricted editing
4. Existing algorithmic transformations continue to work

## Design

### Model Changes

Add `isBuiltIn` property to `TransformationConfig`:

```swift
/// Whether this is a built-in transformation that cannot be deleted.
/// Built-ins have restricted editing (hotkey and enabled only).
var isBuiltIn: Bool
```

Initializer gains default parameter:

```swift
init(
    // ... existing params ...
    isBuiltIn: Bool = false
)
```

Default transformations update:

```swift
static let defaultTransformations: [TransformationConfig] = [
    TransformationConfig(
        id: cleanTerminalTextDefaultID,
        name: "Clean Terminal Text",
        type: .algorithmic,
        isEnabled: true,
        isBuiltIn: true  // Permanent built-in
    ),
    TransformationConfig(
        id: formatAsMarkdownDefaultID,
        name: "Format As Markdown",
        type: .llm,
        isEnabled: false,
        provider: "anthropic",
        isBuiltIn: false  // User can delete this example
    )
]
```

Existing stored data without `isBuiltIn` will decode with `false` default.

### Editor View Changes

**For built-in transformations (`isBuiltIn: true`):**
- Name: Read-only (LabeledContent, not TextField)
- Type picker: Hidden
- LLM Configuration: Hidden
- Hotkey recorder: Editable
- Enabled toggle: Editable
- Test section: Shown

**For user-created transformations (`isBuiltIn: false`):**
- Name: Editable
- Type picker: Removed entirely (all user transformations are LLM)
- LLM Configuration: Always shown
- Everything else: Editable

### Sidebar Changes

**Delete button:** Hidden for built-in transformations.

**Visual indicator:** Lock icon next to built-in names:

```swift
HStack {
    Text(transformation.name)
    if transformation.isBuiltIn {
        Image(systemName: "lock.fill")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}
```

### New Transformation Default

Change `addTransformation()` to create LLM type:

```swift
let newTransform = TransformationConfig(
    name: "New Transformation",
    type: .llm,  // Changed from .algorithmic
    isEnabled: true,
    isBuiltIn: false
)
```

### Migration & Edge Cases

**Existing users who deleted "Clean Terminal Text":**

On load, check if built-in exists. If missing, re-add it:

```swift
let builtInID = TransformationConfig.cleanTerminalTextDefaultID
if !loaded.contains(where: { $0.id == builtInID }) {
    loaded.insert(TransformationConfig.builtInCleanTerminalText, at: 0)
}
```

**Existing user-created algorithmic transformations:**

Continue to work unchanged. No migration needed. Users can manually recreate as LLM if desired.

## Files to Change

1. `Sources/OptimusClip/Models/TransformationConfig.swift` — Add `isBuiltIn` property
2. `Sources/OptimusClip/Views/Settings/Transformations/TransformationEditorView.swift` — Conditional UI based on `isBuiltIn`, remove type picker for non-built-ins
3. `Sources/OptimusClip/Views/Settings/Transformations/TransformationsTabView.swift` — New transformations default to LLM, ensure built-in exists on load
4. `Sources/OptimusClip/Views/Settings/Transformations/TransformationsSidebarView.swift` — Hide delete for built-ins, add lock icon

## Future Consideration

Could add a "regex/pattern" type later for configurable non-LLM transformations. The `TransformationType` enum remains in the codebase for this purpose.
