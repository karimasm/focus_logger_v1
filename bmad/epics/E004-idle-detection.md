# Epic: Idle Detection (Phase 4)

## Epic ID: FLOW-E004
## Status: ✅ Done
## Completed: 2026-01-07

## Description
Detect when users have been inactive (no logged activity) for 30+ minutes and prompt them to reflect on what they were doing during that time.

## Business Value
- Catches unlogged time periods
- Increases time awareness
- Reduces "where did my time go?" moments
- Non-judgmental approach to accountability

## User Stories (Completed)

### Story 1: Idle Detection Service ✅
- Track last activity start/stop time
- Persist across app restarts (SharedPreferences)
- 30-minute threshold
- Initialize on app start

### Story 2: Idle Prompt ✅
- Fullscreen reflection screen
- Shows idle duration
- Input field for activity description
- Category selector
- Saves as past activity

### Story 3: App Resume Check ✅
- Check idle state when app comes to foreground
- Show prompt if idle threshold exceeded
- Prevent duplicate prompts

## Technical Implementation

### Files Modified
- `lib/services/idle_detection_service.dart`
  - Added `init()` method
  - Added `markAsPrompted()` method
  - Added `hasPromptedForCurrentIdle` getter
  - Fixed null `_lastActivityTime` handling

- `lib/main.dart`
  - Added `IdleDetectionService().init()` call

- `lib/providers/activity_provider.dart`
  - Call `onActivityStarted()` when activity starts
  - Call `onActivityStopped()` when activity stops

- `lib/screens/home_screen.dart`
  - `_checkIdleState()` with proper flag checking
  - `didChangeAppLifecycleState()` uses service method

### Key Logic
```dart
// Check idle every second (when no activity running)
void _checkIdleState() {
  if (_idlePopupShown) return;
  if (!hasRunningActivity && isIdle && !hasPromptedForCurrentIdle) {
    markAsPrompted();
    showIdleScreen();
  }
}
```

## Lessons Learned
- Service must be initialized on app start
- Double-flag approach: UI flag + service flag
- Reset timer on BOTH activity start AND stop
- Don't reset popup flag on app resume (causes duplicates)
