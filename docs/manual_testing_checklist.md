# Optimus Clip MVP Manual Testing Checklist

This checklist verifies all user-facing features work correctly through interactive testing.
Complete this after the automated verification script passes.

## Prerequisites

- [ ] App is built: `make build`
- [ ] App is packaged: `make package`
- [ ] Automated verification passes: `./Scripts/verify_mvp_complete.sh`

---

## Phase 1: Menu Bar UI

### App Appearance
- [ ] App appears in menu bar (not in Dock)
- [ ] Menu bar icon is visible and clear
- [ ] Click menu bar icon → dropdown menu appears

### Menu Items
- [ ] "Settings" or "Preferences..." menu item exists
- [ ] Cmd+, keyboard shortcut opens Settings
- [ ] "Quit" menu item exists
- [ ] "Quit" properly terminates the app

### Visual Feedback
- [ ] Icon shows idle state (normal opacity)
- [ ] Icon shows processing state during transformation (if implemented)

---

## Phase 2: Clipboard & Paste

### Basic Clipboard Operations
- [ ] Copy text in any app
- [ ] Clipboard monitoring detects the change (check via transformation trigger)

### Transformation Flow
- [ ] Trigger transformation via hotkey
- [ ] Transformed text appears in target app
- [ ] Original clipboard content is preserved on failure

### Safety Features
- [ ] Self-write marker prevents infinite loops (transform same text twice → second is skipped)
- [ ] Binary content (images, PDFs) does not crash the app
- [ ] User notification shown for unsupported content types

---

## Phase 3: Hotkeys & Settings

### Settings Window
- [ ] Settings window opens with tab navigation
- [ ] Transformations tab is accessible
- [ ] Providers tab is accessible
- [ ] Permissions tab is accessible
- [ ] General tab is accessible

### Transformations Tab
- [ ] List of available transformations shown
- [ ] Add new transformation button works
- [ ] Edit existing transformation works
- [ ] Delete transformation works
- [ ] Hotkey recorder captures keyboard shortcuts
- [ ] Custom hotkey triggers the transformation

### Provider Configuration
- [ ] OpenAI section: API key field with secure input
- [ ] Anthropic section: API key field with secure input
- [ ] OpenRouter section: API key field with secure input
- [ ] Ollama section: Host/port configuration
- [ ] AWS Bedrock section: Region and credentials configuration

### Persistence
- [ ] Quit app → Relaunch → Settings are preserved
- [ ] Quit app → Relaunch → API keys still work
- [ ] Quit app → Relaunch → Hotkeys still registered

### Permissions
- [ ] Accessibility permission callout appears (if not granted)
- [ ] "Open System Settings" button works
- [ ] Permission status updates after granting

---

## Phase 4: Transformation Engine

### Algorithmic Transformations
- [ ] Uppercase transformation: "hello" → "HELLO"
- [ ] Lowercase transformation: "HELLO" → "hello"
- [ ] Title case transformation: "hello world" → "Hello World"
- [ ] Trim/strip transformation: "  hello  " → "hello"
- [ ] Unwrap transformation: removes line breaks within paragraphs

### Edge Cases
- [ ] Large text (10KB+) transforms successfully
- [ ] Special characters preserved: !@#$%^&*()
- [ ] Unicode emoji preserved: 😀🎉🚀
- [ ] Empty clipboard handled gracefully
- [ ] Multi-line text preserved correctly

---

## Phase 5: LLM Integration

### Provider Validation
- [ ] OpenAI: Valid API key shows checkmark/success
- [ ] OpenAI: Invalid API key shows error message
- [ ] Anthropic: Valid API key shows checkmark/success
- [ ] Anthropic: Invalid API key shows error message
- [ ] OpenRouter: Valid API key shows checkmark/success
- [ ] Ollama: Valid connection shows checkmark/success (if server running)

### LLM Transformations
- [ ] Create LLM transformation with system prompt
- [ ] LLM transformation executes successfully
- [ ] Processing indicator shows during LLM call
- [ ] UI remains responsive during LLM call
- [ ] Timeout error shown on slow/failed network (30s default)
- [ ] Rate limit error handled gracefully

---

## Phase 6: Data & Security

### History Logging
- [ ] Successful transformation logged to history
- [ ] Failed transformation logged to history
- [ ] History includes: timestamp, transformation name, input/output
- [ ] History includes: provider, model, system prompt (for LLM)

### Keychain Storage
- [ ] API keys stored in Keychain (verify with Keychain Access.app)
- [ ] API keys NOT in UserDefaults (check ~/Library/Preferences/)
- [ ] API keys NOT visible in any logs
- [ ] API keys persist across app restart

### Launch at Login
- [ ] Toggle in General settings
- [ ] Enable → app starts at login
- [ ] Disable → app does not start at login
- [ ] Setting persists across app restart

### Binary Data Safety
- [ ] Copy image → transformation skipped with notification
- [ ] Copy PDF → transformation skipped with notification
- [ ] Copy file reference → transformation skipped
- [ ] No crash on any binary content type

### Error Recovery
- [ ] Invalid API key → clear error message
- [ ] No network → timeout + error message
- [ ] LLM error → clipboard preserved, error shown
- [ ] Transformation failure → original content still available

---

## Cross-Phase Integration

### Restart Behavior
- [ ] Quit app → Relaunch → All settings preserved
- [ ] Quit app → Relaunch → All API keys work
- [ ] Quit app → Relaunch → All hotkeys work
- [ ] Quit app → Relaunch → History accessible

### Concurrent Operations
- [ ] Multiple rapid transformations → no crashes
- [ ] Switch provider mid-session → works correctly
- [ ] Edit transformation while idle → changes apply immediately
- [ ] Delete transformation → hotkey unregistered

---

## Non-Functional Requirements

### Performance
- [ ] Algorithmic transformation < 100ms (feels instant)
- [ ] UI responsive during LLM call (menu bar clickable)
- [ ] Memory usage < 200MB (check Activity Monitor)
- [ ] CPU usage < 5% when idle (check Activity Monitor)

### Stability
- [ ] Run app for 1+ hour → no memory leaks
- [ ] 50+ transformations in session → no degradation
- [ ] Computer sleep → wake → app still works

---

## Security Verification

### API Key Protection
- [ ] No API keys in Console.app logs
- [ ] API keys masked in UI (SecureField shows dots)
- [ ] No API keys in error messages

### Data Privacy
- [ ] No telemetry sent to developer
- [ ] All data stored locally
- [ ] Clipboard only sent to configured LLM providers

---

## Final Verification

- [ ] All automated tests pass: `swift test`
- [ ] All linting passes: `make check`
- [ ] Verification script passes: `./Scripts/verify_mvp_complete.sh`
- [ ] All manual checks above completed

---

## Sign-off

**Tester:** _________________
**Date:** _________________
**Result:** [ ] PASS / [ ] FAIL
**Notes:**

```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

*MVP Verification Checklist v1.0 - Phase 6 (Final)*
