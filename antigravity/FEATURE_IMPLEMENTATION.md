# Focus Logger - Comprehensive Feature Implementation

This document summarizes all features implemented for cross-device sync, behavior rules, and platform safety.

## 1. CROSS-DEVICE SYNC (Event-Based)

### Sync Triggers
Syncs on these events (not version-based):
- `activityStarted` - When any activity starts
- `activityDone` - When any activity completes
- `adHocCreated` - When creating an ad-hoc task
- `adHocCompleted` - When completing an ad-hoc task
- `memoAdded` - When adding a memo
- `paused` / `resumed` - When pausing/resuming an activity
- `appOpened` - When the app opens or resumes
- Manual "Sync Now" button press

### Offline Queue
- Local changes are queued with `sync_status = 1` (pending)
- Queue is pushed when connectivity is restored
- `SyncProvider` tracks and displays pending changes count

### Conflict Resolution
- Uses UUID + `updated_at` timestamp
- Newest `updated_at` wins
- No device-local isolation

### Files:
- `lib/services/sync_service.dart`
- `lib/providers/sync_provider.dart`

---

## 2. MANUAL SYNC CONTROL

### UI on Home Screen
- Sync status bar with:
  - Last synced timestamp
  - "Syncing..." indicator
  - "Offline (X queued)" status
  - "Sync Now" button
- Tooltip with detailed status

### Files:
- `lib/screens/home_screen.dart` (sync status bar)

---

## 3. SINGLE-ACTIVITY MODE

### Rules
- Only one activity can be running globally
- Starting a new activity closes the previous one
- Starting an Ad-Hoc task pauses current activity with reason:
  `"Doing Ad-Hoc – <task name>"`

### Ad-Hoc Completion Dialog
When ad-hoc task completes:
1. Show dialog: "Continue previous activity?"
2. "ON IT" → Resume previous activity
3. "Stay Paused" → Require pause reason selection

### Files:
- `lib/providers/activity_provider.dart`
- `lib/providers/flow_action_provider.dart`
- `lib/widgets/adhoc_dialogs.dart`

---

## 4. ACTIVITY COMPLETION & TIMELINE RULES

### Immediate Close
- When DONE → `end_time` written immediately, `is_running = false`
- When starting new → auto-close previous

### Timeline Sanitization
- On app start, orphaned activities (>24h running) are auto-closed
- Prevents negative duration display
- `end_time` set to `start_time + 1 hour` for orphaned entries

### Files:
- `lib/providers/activity_provider.dart` (`_sanitizeOrphanedActivities`)
- `lib/database/database_helper.dart` (`getRunningActivitiesOlderThan`)

---

## 5. ENFORCED FLOW WINDOWS (Late-Open Support)

### Behavior
- If app opens during an active window, flow is shown
- Works even if opened 5 minutes into a 30-minute window
- Checks `FlowExecutionStatus` to determine if eligible

### Completion Rules (Corrected)
- `completed` = User pressed ON IT + finished all steps with DONE
- `missed` = Window ended without ON IT
- `skipped` = Haid Mode active (prayer flows only)

### Files:
- `lib/providers/guided_flow_provider.dart`

---

## 6. ENFORCED FLOW ALARM BEHAVIOR

### Alarm Triggers
- When flow window begins → play sound + vibrate
- Repeat reminder every 2 minutes until ON IT pressed
- Stops when user acknowledges

### Platform Support
- Works on Android/iOS (full feature)
- Web: Audio only (no vibration)
- Linux/Desktop: Haptic feedback fallback

### Files:
- `lib/services/flow_alarm_service.dart`

---

## 7. AUTO-LOGGING (Awareness Mode)

### Every 30 Minutes
If no activity is running:
1. Prompt user: "What were you doing?"
2. Allow text + voice input
3. If answered → create activity entry
4. If ignored → create `UnloggedBlock` (not unlabeled activity)

### Files:
- `lib/providers/activity_provider.dart`
- `lib/models/unlogged_block.dart`
- `lib/database/database_helper.dart` (unlogged_blocks table)

---

## 8. VOICE-TO-TEXT PLATFORM RULES

### Platform Detection
```dart
VoiceInputService.isPlatformSupported
```

| Platform | Supported |
|----------|-----------|
| Android  | ✅ Full   |
| iOS      | ✅ Full   |
| Web      | ✅ Partial (browser-dependent) |
| Linux    | ❌ Hidden (no mic button) |
| Windows  | ❌ Hidden |
| macOS    | ❌ Hidden |

### Voice Input Locations
1. Start Activity sheet - voice button (platform-aware)
2. Memo on running activity - voice button (platform-aware)

### Files:
- `lib/services/voice_input_service.dart`
- `lib/widgets/start_activity_sheet.dart`
- `lib/widgets/memo_sheet.dart`

---

## 9. HAID MODE (Conditional Prayer Skipping)

### Purpose
During menstrual period, prayer and Qur'an flows are skipped without being marked as missed.

### UI
- Toggle on Home screen
- Shows day count (Day 1, Day 2, etc.)
- Prompt after 5-7 days: "Are you still on your period?"

### Skipped Categories
- `prayer`, `sholat`, `quran`

### Storage
- `SharedPreferences` for persistence
- Fields: `isActive`, `startDate`, `lastPromptDate`

### Files:
- `lib/models/haid_mode.dart`
- `lib/providers/guided_flow_provider.dart`
- `lib/screens/home_screen.dart` (UI components)

---

## 10. WEB MODE BEHAVIOR

### Supported Features
- All tracking (start/stop/pause)
- Sync with Supabase
- Memo entry
- Timeline view

### Limited Features
- Alarm: Audio only (no vibration)
- Fullscreen enforcement: Not enforced
- Voice input: Browser-dependent

---

## Database Schema

### Local (SQLite) - Version 4
- `activities` - with sync fields
- `pause_logs` - with sync fields
- `guided_flow_logs` - with sync fields
- `memo_entries` - with sync fields
- `adhoc_tasks` - with sync fields
- `unlogged_blocks` - local only (no sync)
- `user_flow_templates` - flow definitions
- `user_flow_steps` - flow step definitions
- `energy_checks` - energy logging

### Remote (Supabase)
- `activities`
- `pause_logs`
- `guided_flow_logs`
- `memo_entries`
- `adhoc_tasks`

---

## New Files Created

1. `lib/models/haid_mode.dart` - Haid Mode model
2. `lib/models/unlogged_block.dart` - Unlogged block model
3. `lib/services/flow_alarm_service.dart` - Alarm service
4. `lib/widgets/adhoc_dialogs.dart` - Ad-hoc completion dialogs

## Files Modified

1. `lib/services/voice_input_service.dart` - Platform-aware voice
2. `lib/services/sync_service.dart` - Event-based sync
3. `lib/providers/guided_flow_provider.dart` - Haid Mode + alarms
4. `lib/providers/activity_provider.dart` - Sanitization + single-activity
5. `lib/screens/home_screen.dart` - Haid Mode UI
6. `lib/widgets/start_activity_sheet.dart` - Platform-aware voice
7. `lib/widgets/memo_sheet.dart` - Platform-aware voice
8. `lib/database/database_helper.dart` - New tables + methods
9. `pubspec.yaml` - New dependencies

---

## Summary

✅ Cross-device sync (event-based, UUID + updated_at)
✅ Manual sync control with status display
✅ Single-activity enforcement
✅ Timeline sanitization (no orphaned activities)
✅ Late-open flow window support
✅ Flow alarm with repeating reminders
✅ Awareness-first auto-logging
✅ Platform-safe voice input
✅ Haid Mode for prayer skipping
✅ Web mode with graceful degradation
