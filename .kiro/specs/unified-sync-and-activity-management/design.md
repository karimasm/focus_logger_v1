# Design Document

## Overview

This design document specifies the awareness-based activity management system for the Focus Logger application. The system is designed as an **awareness & reflection tool for ADHD and hyperfixation states**, not just a time tracker.

**Core Principles:**
1. **Honest time tracking** - accurate durations, no overlapping activities
2. **Awareness-first** - fullscreen prompts for idle reflection, not silent background logging
3. **Enforced accountability** - flow windows cannot be dodged
4. **Reflection capture** - distraction tracking with visual feedback (duck assets)

**Platform Focus:** Android only (Web & Linux paused until core is stable)
**Sync Mode:** Single-device mode (cross-device sync paused until Android is stable)

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interface Layer                    │
│  - Home Screen (Activity Card, responsive layout)            │
│  - Timeline Tab (searchable, chronological)                  │
│  - Memo Tab (all memos, searchable)                          │
│  - Fullscreen Idle Reflection (shy_duck_idle)                │
│  - Distraction Reflection Dialog (angry_duck_knife)          │
│  - Enforced Flow Prompts                                     │
└───────────────────┬─────────────────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────────────────┐
│                    Provider Layer                            │
│  - ActivityProvider (single-activity enforcement)            │
│  - MemoProvider (memo collection management)                 │
│  - GuidedFlowProvider (enforced flows & Haid Mode)           │
│  - IdleReflectionProvider (30-min idle detection)            │
│  - TaskProvider (ad-hoc task integration)                    │
└───────────────────┬─────────────────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────────────────┐
│                    Service Layer                             │
│  - FlowAlarmService (persistent alarms, vibration)           │
│  - VoiceInputService (Android voice input)                   │
│  - HaidModeService (local persistence)                       │
│  - GhostActivityCleanupService (orphan sanitization)         │
└───────────────────┬─────────────────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────────────────┐
│                    Data Layer                                │
│  - DatabaseHelper (SQLite on Android)                        │
│  - Supabase Client (backup/future sync)                      │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. ActivityProvider

**Purpose**: Enforce single-activity rule and manage activity lifecycle.

**Key Methods**:
```dart
class ActivityProvider extends ChangeNotifier {
  // Single-activity enforcement
  Future<void> startActivity(String name, {...});  // Auto-closes previous
  Future<void> stopActivity();  // Sets end_time = now, is_running = 0
  
  // Pause with distraction reflection
  Future<void> pauseActivity(String reason);  // Shows angry_duck_knife prompt
  Future<void> resumeActivity();
  
  // Ghost activity cleanup
  Future<void> sanitizeGhostActivities();  // Called on app start
  
  // Ad-hoc integration
  Future<void> pauseForAdHoc(String taskTitle);
  Future<void> resumeAfterAdHoc();
  
  // Timeline queries
  Future<List<Activity>> getActivitiesForDate(DateTime date);
  Future<List<Activity>> searchActivities(String query);
  
  // Mascot selection
  String getMascotAsset(Activity activity);  // Returns appropriate mascot based on activity
}
```

**Mascot Selection Logic**:
```dart
String getMascotAsset(Activity activity) {
  final name = activity.name.toLowerCase();
  final category = activity.category.toLowerCase();
  final now = DateTime.now();
  final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  
  // Deep Work / Workout → capy_weight_lift
  if (name.contains('deep work') || category == 'deep work' ||
      name.contains('workout') || category == 'workout') {
    return 'assets/capy_weight_lift.png';
  }
  
  // Break / Weekend / Rest → weekend_duck_float
  if (category == 'break' || isWeekend || 
      name.contains('rest') || name.contains('break')) {
    return 'assets/weekend_duck_float.png';
  }
  
  // Travel / Commute → capy_on_flying_duck
  if (name.contains('travel') || name.contains('commute') || 
      name.contains('on the way') || name.contains('perjalanan')) {
    return 'assets/capy_on_flying_duck.png';
  }
  
  // Prayer flow → potato_duck_prayer_break
  if (activity.guidedFlowId != null && 
      (activity.guidedFlowId!.contains('prayer') || 
       activity.guidedFlowId!.contains('sholat'))) {
    return 'assets/potato_duck_prayer_break.png';
  }
  
  // Default (no specific mascot)
  return null;
}
```

### 2. IdleReflectionProvider

**Purpose**: Detect idle periods and show fullscreen reflection prompts.

**Key Methods**:
```dart
class IdleReflectionProvider extends ChangeNotifier {
  // Configuration
  Duration idleThreshold = Duration(minutes: 30);  // Configurable for testing
  
  // Idle detection
  void startIdleTimer();
  void resetIdleTimer();  // Called when activity starts
  void stopIdleTimer();
  
  // Reflection prompt
  bool get shouldShowIdlePrompt;
  Future<void> showIdleReflectionPrompt();  // Fullscreen with shy_duck_idle
  Future<void> submitIdleReflection(String reflection);  // Creates memo
  Future<void> dismissIdlePrompt();  // Records idle time occurred
}
```

**Idle Detection Behavior**:
- Timer starts when no activity is running
- After 30 minutes (configurable), shows fullscreen prompt
- Prompt displays `shy_duck_idle` asset
- User can input reflection via text or voice
- Reflection is saved as memo attached to a special "Idle Time" activity
- If dismissed without input, idle time is still recorded

### 3. MemoProvider

**Purpose**: Manage memo collection and search.

**Key Methods**:
```dart
class MemoProvider extends ChangeNotifier {
  // Memo creation
  Future<void> createMemo(String content, String activityId);
  
  // Memo queries
  Future<List<Memo>> getAllMemos();  // For Memo tab
  Future<List<Memo>> searchMemos(String query);
  Future<List<Memo>> getMemosForActivity(String activityId);
  
  // Navigation
  Activity? getActivityForMemo(String memoId);
}
```

### 4. GuidedFlowProvider

**Purpose**: Manage enforced flow windows and Haid Mode.

**Key Methods**:
```dart
class GuidedFlowProvider extends ChangeNotifier {
  // Haid Mode state
  HaidMode _haidMode;
  
  // Flow window management
  Future<void> checkActiveWindows();  // Called on app resume
  bool isFlowWindowActive(SafetyWindow window);
  
  // Enforced flow (cannot be dodged)
  Future<void> showEnforcedFlowPrompt(SafetyWindow window);
  Future<void> acknowledgeFlow(String flowId);  // ON IT pressed
  Future<void> completeFlow(String flowId);  // DONE pressed
  
  // Haid Mode integration
  Future<void> toggleHaidMode();
  bool shouldSkipFlow(SafetyWindow window);
  Future<void> checkHaidModePrompt();  // After 5-7 days
  
  // Flow status
  bool isFlowCompleted(String flowId, DateTime date);
  Future<void> markFlowMissed(String flowId);
  Future<void> markFlowSkipped(String flowId, String reason);
}
```

**Flow Status States**:
```dart
enum FlowExecutionStatus {
  notStarted,   // Window opened, waiting for ON IT
  inProgress,   // User pressed ON IT
  completed,    // User finished with DONE
  missed,       // Window ended without ON IT
  abandoned,    // Started but not finished
  skipped,      // Skipped due to Haid Mode
}
```

### 5. FlowAlarmService

**Purpose**: Provide persistent, repeating alarms for flow windows.

**Key Methods**:
```dart
class FlowAlarmService {
  // Alarm management
  Future<void> triggerFlowAlarm(SafetyWindow window);
  Future<void> stopAlarm();
  Future<void> acknowledgeWindow(String windowId);
  
  // Internal
  Future<void> _playAlarmSound();
  Future<void> _vibrate();
  void _startReminderTimer(SafetyWindow window);  // Repeats every 2 min
}
```

**Alarm Behavior**:
- Plays sound + vibration immediately when window begins
- Repeats every 2 minutes until user presses ON IT
- Works in background (uses Android notifications)
- Cannot be snoozed or paused

### 6. GhostActivityCleanupService

**Purpose**: Clean up orphaned activities from old database versions.

**Key Methods**:
```dart
class GhostActivityCleanupService {
  // Cleanup on app start
  Future<void> sanitizeGhostActivities();
  
  // Internal
  Future<List<Activity>> _findGhostActivities();  // is_running = 1, older than 24h
  Future<void> _closeGhostActivity(Activity activity);  // end_time = start_time + 1h
  Future<void> _migrateOldDatabaseStructure();
}
```

### 7. VoiceInputService

**Purpose**: Provide voice input for Android.

**Key Methods**:
```dart
class VoiceInputService {
  // Voice input
  Future<String?> listen({
    required String locale,
    Duration? timeout,
  });
  
  // Availability check
  Future<bool> checkAvailability();
  bool get isAvailable;  // Always true on Android with permission
}
```

## Data Models

### Activity Model

```dart
class Activity {
  final String id;  // UUID
  final DateTime createdAt;
  final DateTime updatedAt;
  
  final String name;
  final String category;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isAutoGenerated;
  final bool isRunning;
  final bool isPaused;
  final int pausedDurationSeconds;
  final DateTime? pausedAt;
  final String? pauseReason;  // For distraction tracking
  final ActivitySource source;
  final String? guidedFlowId;
  
  // Computed properties
  Duration get duration {
    if (endTime == null) return Duration.zero;
    final total = endTime!.difference(startTime);
    return total - Duration(seconds: pausedDurationSeconds);
  }
  
  bool get isGhost {
    return isRunning && 
           DateTime.now().difference(startTime) > Duration(hours: 24);
  }
}
```

### Memo Model

```dart
class Memo {
  final String id;  // UUID
  final String activityId;  // Always attached to an activity
  final String content;
  final DateTime createdAt;
  final MemoType type;  // reflection, distraction, idle, general
  
  // For display in Memo tab
  Activity? activity;  // Loaded when displaying
}

enum MemoType {
  reflection,    // General reflection
  distraction,   // From pause/distraction prompt
  idle,          // From idle reflection prompt
  general,       // User-created memo
}
```

### Haid Mode Model

```dart
class HaidMode {
  final bool isActive;
  final DateTime? cycleStartAt;
  final DateTime? lastPromptDate;
  final DateTime? updatedAt;
  
  // Skipped categories
  static const List<String> skippedCategories = ['prayer', 'quran', 'sholat'];
  
  bool shouldSkipCategory(String category) {
    return isActive && skippedCategories.contains(category.toLowerCase());
  }
  
  int get daysSinceStart {
    if (cycleStartAt == null) return 0;
    return DateTime.now().difference(cycleStartAt!).inDays;
  }
  
  bool get shouldPromptCheck {
    if (!isActive || cycleStartAt == null) return false;
    final days = daysSinceStart;
    return days >= 5 && days <= 10;
  }
}
```

### GuidedFlowLog Model

```dart
class GuidedFlowLog {
  final String id;
  final String flowId;
  final String flowName;
  final DateTime triggeredAt;
  final DateTime? completedAt;
  final int stepsCompleted;
  final int totalSteps;
  final bool wasAbandoned;
  final bool wasMissed;
  final bool wasSkipped;
  final String? skipReason;
  
  bool get isCompleted {
    return completedAt != null && 
           stepsCompleted == totalSteps && 
           !wasAbandoned && 
           !wasMissed;
  }
}
```


## UI Components

### Mascot/Asset System

The app uses mascot assets to provide visual feedback based on user state:

| Asset | File | Trigger Condition | Meaning |
|-------|------|-------------------|---------|
| 🏋️ Capy Weight Lift | `capy_weight_lift.png` | Activity name/category = "Deep Work" OR "Workout" | Disciplined / focused mode |
| 🦆 Weekend Duck Float | `weekend_duck_float.png` | Activity in "Break" OR day = weekend OR tag = rest | Intentional rest |
| 🦆 Capy on Flying Duck | `capy_on_flying_duck.png` | Activity name contains "Travel", "Commute", "On The Way" | Moving between places |
| 🐤 Shy Duck Idle | `shy_duck_idle.png` | No activity running > 30m → show idle prompt | "What did you do in the last 30 minutes?" |
| 😤 Angry Duck Knife | `angry_duck_knife.png` | Activity switched unexpectedly OR paused without reason | Attention hijacked / distraction |
| 🥔 Potato Duck Prayer | `potato_duck_prayer_break.png` | Guided flow = prayer window OR chain flow = prayer break | Reflective pause / ibadah |

**Asset Display Rules:**
- Mascot appears inside the activity card based on activity type/state
- Idle mascot (shy_duck_idle) appears in fullscreen idle reflection prompt
- Distraction mascot (angry_duck_knife) appears in pause/distraction dialog
- Prayer mascot (potato_duck_prayer_break) appears during prayer flow windows

### 1. Fullscreen Idle Reflection Screen

```
┌─────────────────────────────────────────┐
│                                         │
│         [shy_duck_idle asset]           │
│                                         │
│      "Kamu tadi ngapain?"               │
│      (What were you doing?)             │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ [Text input field]          🎤 │    │
│  └─────────────────────────────────┘    │
│                                         │
│     [Submit]        [Skip]              │
│                                         │
└─────────────────────────────────────────┘
```

### 2. Distraction Reflection Dialog

```
┌─────────────────────────────────────────┐
│                                         │
│       [angry_duck_knife asset]          │
│                                         │
│      "Kenapa pause?"                    │
│      (Why are you pausing?)             │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ [Reason input field]        🎤 │    │
│  └─────────────────────────────────┘    │
│                                         │
│     [Save & Pause]    [Cancel]          │
│                                         │
└─────────────────────────────────────────┘
```

### 3. Timeline Screen with Tabs

```
┌─────────────────────────────────────────┐
│  [🔍 Search...]                         │
├─────────────────────────────────────────┤
│  [Timeline]  [Memo]                     │
├─────────────────────────────────────────┤
│                                         │
│  Timeline Tab:                          │
│  ┌─────────────────────────────────┐    │
│  │ Activity 1          2:30       │    │
│  │ Category • 10:00 - 12:30       │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ Activity 2          1:15       │    │
│  │ Category • 13:00 - 14:15       │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Memo Tab:                              │
│  ┌─────────────────────────────────┐    │
│  │ 📝 "Reflection content..."     │    │
│  │ From: Activity 1 • 10:30       │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 📝 "Distraction note..."       │    │
│  │ From: Activity 2 • 13:45       │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

### 4. Responsive Activity Card

```
┌─────────────────────────────────────────┐
│  Activity Name                          │
│  Category                               │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │     02:30:45                    │    │  ← Counter stays on one line
│  │     (hours:minutes:seconds)     │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [Pause]  [Done]  [Memo]                │
└─────────────────────────────────────────┘
```

**Responsive Rules**:
- Counter text uses `FittedBox` to scale on small screens
- Activity name truncates with ellipsis if too long
- Buttons use `Wrap` or `Row` with `MainAxisSize.min`
- Minimum touch target size: 48x48dp

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do.*

### Data Persistence Properties

**Property 1: Activity Persistence**
*For any* activity that is started, the system should save it to SQLite immediately and it should be retrievable after app restart.
**Validates: Requirements 1.1, 1.4**

**Property 2: Memo Persistence**
*For any* memo that is created, the system should save it to SQLite immediately and it should be retrievable after app restart.
**Validates: Requirements 1.3, 1.4**

**Property 3: Timeline Non-Empty**
*For any* database state where activities exist, the timeline should display all activities (never be empty).
**Validates: Requirements 1.5, 11.7**

### Single-Activity Enforcement Properties

**Property 4: Single Running Activity**
*For any* point in time, the system should have at most one activity with is_running = true.
**Validates: Requirements 2.1, 2.2, 2.4**

**Property 5: Immediate Activity Closure**
*For any* activity when DONE is pressed, the system should immediately set end_time = now and is_running = 0.
**Validates: Requirements 4.1, 4.2**

**Property 6: Non-Negative Durations**
*For any* activity displayed on the timeline, the calculated duration (end_time - start_time - paused_duration_seconds) should be non-negative.
**Validates: Requirements 4.3**

**Property 7: No Runaway Activities**
*For any* activity displayed on the timeline, if it has is_running = false, it should have a duration less than 24 hours.
**Validates: Requirements 4.4**

### Ghost Activity Properties

**Property 8: Ghost Activity Sanitization**
*For any* activity with is_running = true that is older than 24 hours, the system should set end_time = start_time + 1 hour and is_running = 0 on app start.
**Validates: Requirements 5.1, 5.2, 5.3**

### Idle Reflection Properties

**Property 9: Idle Prompt After Threshold**
*For any* period where no activity is running and the idle threshold (30 minutes) has elapsed, the system should show a fullscreen idle reflection prompt.
**Validates: Requirements 6.1**

**Property 10: Idle Reflection Creates Memo**
*For any* idle reflection prompt where the user provides input, the system should create a memo with the reflection content.
**Validates: Requirements 6.6**

### Distraction Reflection Properties

**Property 11: Pause Shows Distraction Prompt**
*For any* activity pause action, the system should show a distraction reflection prompt with the angry_duck_knife asset.
**Validates: Requirements 7.1, 7.2**

**Property 12: Pause Reason Stored**
*For any* pause action where the user provides a reason, the system should store the pause_reason with the activity.
**Validates: Requirements 7.4**

### Flow Enforcement Properties

**Property 13: Flow Cannot Be Dodged**
*For any* active flow window, the system should not allow pause or snooze to dismiss the flow prompt.
**Validates: Requirements 8.7**

**Property 14: Flow Alarm Repeats**
*For any* flow window where the user has not pressed ON IT, the system should repeat the alert every 2 minutes.
**Validates: Requirements 8.4**

**Property 15: Flow Completed Requires ON IT and DONE**
*For any* flow, it should be marked as completed only if the user pressed ON IT and pressed DONE after completing all steps.
**Validates: Requirements 9.1, 9.2**

**Property 16: Flow Missed Without ON IT**
*For any* flow window that ends without the user pressing ON IT, the system should mark the flow status as missed.
**Validates: Requirements 9.3**

### Memo Collection Properties

**Property 17: Memo Always Attached**
*For any* memo created, it should be attached to an activity (no standalone memos).
**Validates: Requirements 10.1**

**Property 18: Memo Tab Shows All Memos**
*For any* memo in the database, it should appear in the Memo tab.
**Validates: Requirements 10.3**

**Property 19: Memo Search Works**
*For any* memo containing a search term, it should appear in search results when that term is searched.
**Validates: Requirements 10.4**

### Timeline Properties

**Property 20: Chronological Timeline Order**
*For any* set of activities displayed on the timeline, they should be ordered by start_time.
**Validates: Requirements 11.1**

**Property 21: Timeline Search Works**
*For any* activity matching a search query (name, category, or date), it should appear in search results.
**Validates: Requirements 11.2, 11.3**

**Property 22: No Overlapping Activities**
*For any* two consecutive activities on the timeline, the first activity's end_time should be less than or equal to the second activity's start_time.
**Validates: Requirements 11.4**

### Responsive Layout Properties

**Property 23: Counter Stays On One Line**
*For any* activity card displayed, the counter/duration should remain on a single line without wrapping.
**Validates: Requirements 12.1**

### Haid Mode Properties

**Property 24: Haid Mode Persistence**
*For any* Haid Mode state change, the system should store the status in SQLite and load it correctly on app restart.
**Validates: Requirements 13.1, 13.2**

**Property 25: Flow Skipped During Haid Mode**
*For any* prayer or Qur'an flow that is skipped due to Haid Mode, the system should set status = skipped_due_to_haid.
**Validates: Requirements 14.3**

**Property 26: Haid Mode Prompt After 5-7 Days**
*For any* Haid Mode that has been active for 5-7 days, the system should prompt the user to confirm their status.
**Validates: Requirements 14.6**

## Error Handling

### Database Errors

**SQLite Errors**:
- Display error message to user
- Log error details for debugging
- Retry operation if transient error
- Never silently fail

### Voice Input Errors

**Permission Denied**:
- Show text input as fallback
- Display message explaining voice input unavailable
- Never crash

**Recognition Failed**:
- Show error message
- Allow retry
- Fall back to text input

### Flow Alarm Errors

**Audio Playback Failure**:
- Fall back to vibration only
- Log error but don't crash
- Still show visual prompt

**Background Execution Failure**:
- Show notification as fallback
- Ensure alarm still triggers when app opens

## Testing Strategy

### Unit Tests

**Critical Unit Tests**:
1. Activity start saves to SQLite immediately
2. Activity stop sets end_time and is_running = 0
3. Ghost activities sanitized on app start
4. Idle prompt appears after 30 minutes (use shorter interval for testing)
5. Pause shows distraction reflection prompt
6. Flow alarm repeats every 2 minutes until ON IT
7. Memo search returns matching results
8. Timeline search returns matching activities
9. Haid Mode persists across app restart
10. Activity card counter stays on one line

### Property-Based Tests

**Framework**: Use `test` package with custom property test helpers for Dart/Flutter

**Configuration**:
- Minimum 100 iterations per property test
- Each test tagged with: `Feature: unified-sync-and-activity-management, Property {number}: {property_text}`
- Use random generators for:
  - Activities with random names, timestamps, durations
  - Memos with random content
  - Flow windows with random times
  - Idle periods of random duration

### Integration Tests

**Cross-Component Tests**:
1. Activity start → idle timer reset → no idle prompt
2. Activity stop → idle timer start → idle prompt after threshold
3. Pause → distraction prompt → memo created → resume
4. Flow window start → alarm → ON IT → alarm stop → activity log
5. Haid Mode toggle → flow skip → status update

### Manual Testing Checklist

**Activity Lifecycle**:
1. Start activity, verify saved to database
2. Stop activity, verify end_time set immediately
3. Start new activity while one running, verify previous closed
4. Leave activity running 25 hours, restart app, verify sanitized

**Idle Reflection**:
1. Stop all activities, wait 30 minutes, verify fullscreen prompt
2. Enter reflection, verify memo created
3. Dismiss without input, verify idle time recorded

**Distraction Reflection**:
1. Pause activity, verify angry_duck_knife prompt
2. Enter reason, verify stored with activity
3. Resume, verify paused duration tracked

**Timeline & Memo**:
1. Create activities with memos, verify timeline shows all
2. Switch to Memo tab, verify all memos visible
3. Search timeline, verify results correct
4. Search memos, verify results correct
5. Tap memo, verify navigates to activity

**Responsive Layout**:
1. Test on small phone (320dp width)
2. Test on large phone (412dp width)
3. Test on tablet (600dp width)
4. Verify counter never wraps to new line

## Summary

This design provides a comprehensive solution for awareness-based activity management with:

1. **Single-activity enforcement** with immediate closure
2. **Ghost activity cleanup** on app start
3. **Fullscreen idle reflection** with shy_duck_idle asset
4. **Distraction reflection** on pause with angry_duck_knife asset
5. **Enforced flow system** that cannot be dodged
6. **Memo collection view** with search
7. **Timeline search** for finding old activities
8. **Responsive activity card** that doesn't break on different devices
9. **Haid Mode** with local persistence

The system is focused on Android only, with single-device mode, prioritizing core stability before expanding to other platforms or cross-device sync.
