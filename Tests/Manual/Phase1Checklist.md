# Phase 1 Verification Checklist

## App Launch & Presence
- [ ] Run `npm run start` → App compiles without warnings
- [ ] Menu bar icon appears (top right, near clock)
- [ ] Icon uses clipboard.fill SF Symbol
- [ ] No Dock icon visible (verify visually)
- [ ] App not in Cmd+Tab switcher (verify by tabbing)

## Single Instance Enforcement
- [ ] With app running, double-click OptimusClip.app again
- [ ] Second instance does NOT launch (no second icon)
- [ ] Run `ps aux | grep OptimusClip` → Only 1 process

## Icon Appearance & States
- [ ] Icon at full opacity on launch (idle state)
- [ ] Icon renders correctly in Light Mode
- [ ] Icon renders correctly in Dark Mode
- [ ] Switch macOS appearance → Icon adapts automatically

## Menu Functionality
- [ ] Click icon → Menu drops down
- [ ] "Settings..." menu item present
- [ ] "Quit Optimus Clip" menu item present
- [ ] Divider between items visible

## Keyboard Shortcuts
- [ ] With menu open, press Cmd+, → Settings placeholder alert shown
- [ ] With menu open, press Cmd+Q → App quits immediately

## State Manager Integration
- [ ] In debugger, call `menuBarState.startProcessing()`
- [ ] Icon pulses with .symbolEffect(.pulse) animation
- [ ] Call `menuBarState.stopProcessing()`
- [ ] Pulse stops, icon returns to idle
- [ ] Call `menuBarState.setDisabled(true)`
- [ ] Icon dims to ~45% opacity
- [ ] Call `menuBarState.setDisabled(false)`
- [ ] Icon returns to full opacity

## Info.plist Configuration
- [ ] LSUIElement = 1
- [ ] LSMultipleInstancesProhibited = 1
- [ ] LSMinimumSystemVersion = 15.0

## Build & Workflow
- [ ] `npm run build` succeeds
- [ ] `npm run test` passes (all unit tests)
- [ ] `npm run check` passes (format + lint)
- [ ] `npm run package` creates OptimusClip.app bundle
- [ ] `npm run stop` terminates running instance
- [ ] `npm run start` kills old instance and relaunches

## Performance Baseline
- [ ] Open Activity Monitor → Find OptimusClip
- [ ] CPU usage < 1% when idle
- [ ] Memory usage < 50 MB
- [ ] No excessive thread count (< 10 threads)
- [ ] Energy Impact: Low

## Accessibility
- [ ] Enable VoiceOver (Cmd+F5)
- [ ] Navigate to menu bar icon → VoiceOver reads "Optimus Clip"
- [ ] Open menu → VoiceOver reads menu items
- [ ] Keyboard navigation works (arrows, Enter, Escape)

## Error Cases
- [ ] Kill app via Activity Monitor → Terminates cleanly
- [ ] Force quit via Cmd+Option+Escape → Terminates cleanly
- [ ] No crash logs in Console.app

## Architecture Validation
- [ ] MenuBarStateManager is @StateObject in App struct
- [ ] IconStateMachine in OptimusClipCore is tested
- [ ] No retain cycles (spot check)
