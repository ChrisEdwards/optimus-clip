# History Hero Output Design

**Bead:** oc-u7w
**Date:** 2025-12-28
**Status:** Approved

## Summary

Redesign the history list to make transformed text the prominent "hero" element in each row, rather than metadata like transformation name or timestamp.

## Layout Structure

### Collapsed Row (Success)

```
┌─────────────────────────────────────────────────┐
│ Fix Grammar                           2:34 PM › │
│ The quick brown fox jumps over the lazy...      │
└─────────────────────────────────────────────────┘
```

### Collapsed Row (Failed Transformation)

```
┌─────────────────────────────────────────────────┐
│ Fix Grammar                           2:34 PM › │
│ teh qiuck bron fox...                           │  ← muted/italic (input)
│ ⚠ API rate limit exceeded                       │  ← red caption
└─────────────────────────────────────────────────┘
```

### Expanded Row

```
┌─────────────────────────────────────────────────┐
│ Fix Grammar                           2:34 PM ⌄ │
│ The quick brown fox jumps over the lazy...      │
├─────────────────────────────────────────────────┤
│ OpenAI · gpt-4o · 156 chars · 342ms             │
│                                                 │
│ Input                                    [Copy] │
│ ┌─────────────────────────────────────────────┐ │
│ │ teh qiuck bron fox...                       │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Output                                   [Copy] │
│ ┌─────────────────────────────────────────────┐ │
│ │ The quick brown fox...                      │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## Smart Preview Logic

Extract meaningful first line from output (or input for failures):

1. Trim leading whitespace and newlines
2. Take first line (up to first `\n`)
3. Truncate to ~80 characters with ellipsis if needed
4. Show *(empty)* placeholder if result is empty

Examples:

| Raw output | Smart preview |
|------------|---------------|
| `"Hello world"` | `Hello world` |
| `"\n\nFixed text here"` | `Fixed text here` |
| `"Line one\nLine two"` | `Line one` |
| `"This is very long..."` | `This is very long...` (truncated) |
| `""` | *(empty)* |

## Visual Styling

### Header Line
- Transformation name: `.caption`, `.secondary` color
- Timestamp: `.caption`, `.secondary` color
- Chevron: `.caption`, `.secondary` color

### Output Preview (Success)
- Font: `.callout`
- Color: primary
- Single line, truncated with ellipsis

### Input Preview (Failure)
- Font: `.callout`
- Color: `.secondary`
- Style: italic

### Error Message
- Font: `.caption`
- Color: `.red`
- Icon: `exclamationmark.triangle.fill` inline

### Metadata Line (Expanded Only)
- Format: `Provider · Model · N chars · Nms`
- Examples:
  - `OpenAI · gpt-4o · 156 chars · 342ms`
  - `Anthropic · claude-3-5-sonnet · 89 chars · 1204ms`
  - `156 chars · 12ms` (algorithmic, no provider)

## Edge Cases

- Very long transformation names: truncate, timestamp always visible
- Missing provider/model: omit from metadata line
- Empty input/output: show *(empty)* placeholder

## Implementation Notes

- Add `smartPreview(for:maxLength:)` helper function
- Modify `HistoryEntryView` to use new layout
- Keep existing expanded Input/Output sections
- Add metadata line to expanded view
