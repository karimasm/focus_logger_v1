# Focus Logger - Cross-Device Sync & Behavior Changes

This document outlines the significant changes made to implement cross-device sync and updated behavior rules.

## 1. CROSS-DEVICE SYNC (Event-Based)

### Sync Triggers
Synchronization now occurs on these specific events:
- **Activity Started** - When user starts any activity
- **Activity Done** - When user stops/completes any activity
- **Ad-Hoc Created** - When creating a new ad-hoc task
- **Ad-Hoc Completed** - When completing an ad-hoc task
- **Memo Added** - When adding a memo to an activity
- **Paused** - When pausing an activity
- **Resumed** - When resuming an activity
- **App Opened/Resumed** - When the app comes to foreground
- **Manual Sync** - When user presses "Sync Now" button

### Offline Queue
- Changes are automatically queued when offline
- Queue is pushed when connectivity is restored
- Pending changes count is displayed in the sync status bar

### Conflict Resolution
- Uses **UUID + updated_at merge** strategy
- Most recent `updated_at` timestamp wins
- No per-device isolation - global state is maintained

### Files Changed
- `lib/services/sync_service.dart` - Complete rewrite with event-based triggers
- `lib/providers/sync_provider.dart` - Enhanced with event triggering and queue tracking

---

## 2. MANUAL SYNC BUTTON

### Status Display
The sync status bar on Home screen now shows:
- **Last synced: <timestamp>** - When idle
- **Syncing…** - While sync is in progress
- **Offline (X queued)** - When offline with pending changes
- **Sync Now** button - Prominently displayed for manual sync

### Visual Indicators
- Cloud icons for different states (done, offline, error)
- Color coding (green = success, orange = offline, red = error)
- Queued update count shown when there are pending changes

### Files Changed
- `lib/screens/home_screen.dart` - Enhanced sync status bar

---

## 3. ENFORCED FLOW WINDOW (Late-Open Support)

### Late-Open Behavior
If the user opens the app while already inside a flow window:
1. The app checks for active safety windows on launch
2. If a window is active AND the routine hasn't been completed/missed:
   - The enforced flow prompt WILL appear
   - This works even if opened 5 minutes into a 30-minute window

### Flow Status Tracking
- `FlowExecutionStatus.notStarted` - Window opened, waiting for ON IT
- `FlowExecutionStatus.inProgress` - User pressed ON IT
- `FlowExecutionStatus.completed` - User finished with DONE
- `FlowExecutionStatus.missed` - Window ended without ON IT

### Missed Flow Detection
A flow is only marked as **missed** AFTER the window ends with no ON IT action.

### Files Changed
- `lib/providers/guided_flow_provider.dart` - Added late-open support
- `lib/app.dart` - Added `AppLifecycleHandler` for app resume detection

---

## 4. COMPLETED TODAY RULE (Corrected)

### Previous Behavior (Wrong)
- Flows were marked "completed" just because window time passed

### New Behavior (Correct)
A flow is only considered **"Completed Today"** if:
1. User pressed **ON IT** (started the flow)
2. User finished all steps and pressed **DONE**

### Missed vs Completed
- **Completed**: User went through ON IT → DONE sequence
- **Missed**: Window ended without user pressing ON IT
- These are now visually distinguished in the Enforced Events section

### UI Changes
- "Completed Today" section shows flows with checkmark (green)
- "Missed Today" section shows flows with X mark (red)
- "All rituals completed" only shows if no flows were missed

### Files Changed
- `lib/providers/guided_flow_provider.dart` - Corrected completion logic
- `lib/models/guided_flow.dart` - `isCompleted` getter already correct
- `lib/screens/home_screen.dart` - Added missed flows display

---

## 5. AUTO-LOGGING EVERY 30 MINUTES (Behavior Change)

### Previous Behavior (Wrong)
- Silently created "Unlabeled" activity entries every 30 minutes

### New Behavior (Correct)
If no activity is running when 30 minutes elapse:
1. **Prompt the user** with a notification/dialog
2. Ask: "What were you doing in the past 30 minutes?"
3. Allow text/voice input for labeling
4. If user ignores → mark as **"unlogged block"** (NOT "unlabeled activity")

### Unlogged Blocks
- Tracked separately from activities
- Can be labeled later by the user
- Old blocks (>7 days) are automatically cleaned up

### Database Changes
- New table: `unlogged_blocks` (local only)
- Stores: id, start_time, end_time, created_at

### Files Changed
- `lib/providers/activity_provider.dart` - Added awareness-first auto-logging
- `lib/database/database_helper.dart` - Added unlogged_blocks table (v4)
- `lib/screens/home_screen.dart` - Updated note text

---

## 6. CONSISTENCY RULE (Single Global Activity)

### Rule
Only **one activity** can be active at a time across all devices.

### Implementation
- When starting a new activity, any running activity is stopped first
- On app resume, conflicts are detected and resolved
- Most recently started activity wins in conflict resolution

### Conflict Resolution
When multiple devices have running activities:
1. Activities are sorted by `start_time` (most recent first)
2. All but the most recent are automatically stopped
3. Remote state is used if it's newer than local

### Files Changed
- `lib/services/sync_service.dart` - Added conflict resolution
- `lib/providers/activity_provider.dart` - Uses global activity check

---

## Database Schema Updates

### New Table: `unlogged_blocks` (Local)
```sql
CREATE TABLE unlogged_blocks (
  id TEXT PRIMARY KEY,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

### Supabase Schema Updates
Added `adhoc_tasks` table for cross-device sync:
```sql
CREATE TABLE adhoc_tasks (
  id uuid PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  device_id text,
  title text NOT NULL,
  description text,
  execution_state integer DEFAULT 0,
  started_at timestamptz,
  completed_at timestamptz,
  linked_activity_id uuid REFERENCES activities(id),
  sort_order integer DEFAULT 0
);
```

---

## Summary

These changes implement:
✅ **Honest time history** - No more silent unlabeled entries
✅ **Real flow accountability** - ON IT + DONE required for completion
✅ **Reliable cross-device behavior** - Event-based sync with conflict resolution
✅ **Awareness-first auto-logging** - Prompts instead of silent logging
