# Epic: To-Do List with Enforced Alarms (Phase 3)

## Epic ID: FLOW-E003
## Status: ✅ Done
## Completed: 2026-01-07

## Description
Implement a To-Do list feature where users can create one-time tasks with optional alarm times. When the alarm triggers, the user is forced to start the task - no dismissing allowed.

## Business Value
- Helps users commit to important tasks
- Removes the "I'll do it later" escape
- Integrates with existing flow system

## User Stories (Completed)

### Story 1: Create To-Do Task ✅
- User can add task with title
- Optional description
- Optional alarm time picker
- Task appears in "To Do" tab

### Story 2: Enforced Alarm ✅
- Fullscreen reminder at alarm time
- Sound + vibration alerts
- Only "MULAI SEKARANG" button
- Cannot be dismissed or skipped
- Back button blocked

### Story 3: Task Execution ✅
- Timer starts when task started
- Pause/resume functionality
- Memo attachment
- Stop and complete

### Story 4: Conflict Resolution ✅
- Detect overlap with active Flow window
- Show conflict screen with choices
- User picks To-Do or Flow
- Non-selected item rescheduled

## Technical Implementation

### Files Created
- `lib/screens/todo_reminder_screen.dart`
- `lib/screens/adhoc_reminder_screen.dart`
- `lib/screens/adhoc_flow_conflict_screen.dart`

### Files Modified
- `lib/models/adhoc_task.dart` - Added alarm fields
- `lib/providers/flow_action_provider.dart` - Alarm methods
- `lib/screens/home_screen.dart` - Alarm checking
- `lib/screens/tasks_screen.dart` - UI updates

### Database Changes
```sql
ALTER TABLE adhoc_tasks ADD COLUMN alarm_time TIMESTAMPTZ;
ALTER TABLE adhoc_tasks ADD COLUMN alarm_triggered BOOLEAN DEFAULT FALSE;
ALTER TABLE adhoc_tasks ADD COLUMN is_paused BOOLEAN DEFAULT FALSE;
ALTER TABLE adhoc_tasks ADD COLUMN paused_at TIMESTAMPTZ;
ALTER TABLE adhoc_tasks ADD COLUMN paused_duration_seconds INTEGER DEFAULT 0;
```

## Lessons Learned
- Mark alarm as triggered IMMEDIATELY when showing popup (not after user action)
- Use flags at both UI level and service level to prevent double-triggers
- Consistent color system prevents contrast issues
