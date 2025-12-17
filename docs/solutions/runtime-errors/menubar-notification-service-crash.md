---
title: MenuBarExtra Flickering Due to NotificationService Crash Without App Bundle
category: runtime-errors
component: NotificationService
symptoms:
  - MenuBarExtra menu flickering
  - Menu auto-closing after a few seconds
  - Menu items briefly selecting then deselecting
tags:
  - macos-menu-bar
  - notification-center
  - swift-runtime
  - un-user-notification-center
  - bundle-identifier
  - swiftui-menubarextra
created: 2025-12-16
verified: true
---

# MenuBarExtra Flickering Due to NotificationService Crash

## Problem

The MenuBarExtra menu was exhibiting erratic behavior:
- Menu would flicker when opened
- Menu items would select briefly then deselect
- Menu would auto-close after a few seconds

## Root Cause

`NotificationService` was accessing `UNUserNotificationCenter.current()` during initialization, which crashes when the app is run without a proper `.app` bundle (e.g., running the debug binary directly with `.build/debug/OptimusClip`).

The crash cascade:
1. `MenuBarStateManager` init subscribes to `TransformationFlowCoordinator.shared.$isProcessing`
2. `TransformationFlowCoordinator.shared` accesses `ErrorRecoveryManager.shared`
3. `ErrorRecoveryManager` accesses `NotificationService.shared`
4. `NotificationService.init()` calls `setupNotificationCategories()` and `requestPermission()`
5. Both methods call `UNUserNotificationCenter.current()` which crashes without a bundle

The crash error:
```
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException',
reason: 'bundleProxyForCurrentProcess is nil: mainBundle.bundleURL file:///.build/debug/'
```

## Solution

Add `Bundle.main.bundleIdentifier` guards to all `NotificationService` methods that access `UNUserNotificationCenter`:

```swift
// In setupNotificationCategories()
private func setupNotificationCategories() {
    // Guard against running without a proper app bundle (e.g., debug binary)
    guard Bundle.main.bundleIdentifier != nil else {
        return
    }
    // ... rest of method
}

// In requestPermission()
public func requestPermission() async {
    // Guard against running without a proper app bundle (e.g., debug binary)
    guard Bundle.main.bundleIdentifier != nil else {
        self.permissionGranted = false
        return
    }
    // ... rest of method
}

// In showError()
do {
    // Guard against running without a proper app bundle
    guard Bundle.main.bundleIdentifier != nil else {
        NSSound.beep()
        return
    }
    try await UNUserNotificationCenter.current().add(request)
} catch {
    NSSound.beep()
}

// In showTransient()
do {
    // Guard against running without a proper app bundle
    guard Bundle.main.bundleIdentifier != nil else {
        return
    }
    try await UNUserNotificationCenter.current().add(request)
} catch {
    // Silent fail for transient notifications
}
```

## Investigation Steps

1. **Reduced to minimal app** - Stripped OptimusClipApp.swift to absolute minimum (just `import SwiftUI` and static menu buttons) - still worked
2. **Added back AppDelegate adaptor** - Still worked
3. **Added back MenuBarStateManager** - Crashed with the bundle error
4. **Identified cascade** - MenuBarStateManager triggered singleton chain leading to NotificationService
5. **Added bundle guards** - Fixed the crash, menu works correctly

## Prevention

1. **Always guard system API access** - APIs like `UNUserNotificationCenter` may have runtime requirements (valid bundle, entitlements, etc.)

2. **Test debug builds directly** - Run `.build/debug/AppName` directly to catch bundle-dependent issues

3. **Lazy singleton initialization** - Avoid singletons that initialize expensive/system-dependent resources on first access

4. **Graceful degradation** - When system APIs aren't available, fall back to simpler alternatives (e.g., `NSSound.beep()` instead of notifications)

## Related Files

- `Sources/OptimusClip/Services/NotificationService.swift`
- `Sources/OptimusClip/MenuBarStateManager.swift`
- `Sources/OptimusClip/Managers/TransformationFlowCoordinator.swift`

## Commit

`5f4f6f2` - Fix menu bar flickering by adding bundle guards to NotificationService
