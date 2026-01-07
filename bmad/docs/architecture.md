# Technical Architecture: Focus Logger

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Screens   │  │   Widgets   │  │      Dialogs        │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                     │            │
│         └────────────────┼─────────────────────┘            │
│                          ▼                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    Providers                          │  │
│  │  ┌────────────┐ ┌────────────┐ ┌──────────────────┐  │  │
│  │  │ Activity   │ │ Guided     │ │ FlowAction       │  │  │
│  │  │ Provider   │ │ FlowProv   │ │ Provider         │  │  │
│  │  └────────────┘ └────────────┘ └──────────────────┘  │  │
│  └──────────────────────────┬───────────────────────────┘  │
│                             │                               │
│  ┌──────────────────────────▼───────────────────────────┐  │
│  │                  Data Repository                      │  │
│  │  ┌─────────────────┐    ┌────────────────────────┐   │  │
│  │  │ LocalDataRepo   │    │   CloudDataRepo        │   │  │
│  │  │ (SQLite)        │    │   (Supabase)           │   │  │
│  │  └─────────────────┘    └────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    Services                           │  │
│  │  ┌────────────┐ ┌────────────┐ ┌──────────────────┐  │  │
│  │  │ IdleDetect │ │ Sync       │ │ FlowAlarm        │  │  │
│  │  │ Service    │ │ Service    │ │ Service          │  │  │
│  │  └────────────┘ └────────────┘ └──────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Providers (State Management)

| Provider | Responsibility |
|----------|---------------|
| `ActivityProvider` | Current activity, pause/resume, today's activities |
| `GuidedFlowProvider` | Flow templates, active flow state, safety windows |
| `FlowActionProvider` | To-Do tasks (pending/in-progress/completed) |
| `MemoProvider` | Notes attached to activities |
| `TaskProvider` | Legacy tasks (being migrated to FlowActionProvider) |

### 2. Models

| Model | Description |
|-------|-------------|
| `Activity` | Time-tracked activity with start/end times |
| `AdHocTask` | To-Do item with alarm, pause support |
| `UserFlowTemplate` | Guided flow definition with steps |
| `SafetyWindow` | Time window for flow triggers |
| `MemoEntry` | Note attached to activity |
| `EnergyCheck` | Energy level check-in |

### 3. Services

| Service | Description |
|---------|-------------|
| `IdleDetectionService` | Detects 30+ min inactivity |
| `SyncService` | Background cloud sync |
| `FlowSeederService` | Seeds default flow templates |
| `MascotService` | Mascot images for UI |

### 4. Database Schema

```sql
-- Core tables
activities (id, name, category, start_time, end_time, is_running, ...)
adhoc_tasks (id, title, status, alarm_time, alarm_triggered, ...)
user_flow_templates (id, name, category, steps, ...)
safety_windows (id, name, start_hour, end_hour, ...)
memo_entries (id, activity_id, text, ...)
energy_checks (id, activity_id, level, ...)
```

## Data Flow

### Activity Logging
```
User taps "Start" → ActivityProvider.startActivity() 
  → Repository.insertActivityDirect() 
  → SQLite + Supabase (parallel)
  → IdleDetectionService.onActivityStarted()
```

### Alarm Trigger
```
Timer tick (1s) → HomeScreen._checkTodoAlarm()
  → Check pending tasks with alarm_time <= now
  → If found: markAlarmTriggered() + show TodoReminderScreen
  → User clicks "Start" → FlowActionProvider.startTask()
```

### Idle Detection
```
Timer tick (5min) → IdleDetectionService._checkIdle()
  → Check if now - lastActivityTime >= 30 min
  → If idle: trigger onIdleDetected callback
  → Show IdleReflectionScreen
```

## Design Decisions

1. **Cloud-First Sync**: Supabase is source of truth, local SQLite is cache
2. **Single Activity Rule**: Only one activity can run at a time
3. **UTC Storage**: All times stored in UTC, converted to local for display
4. **Enforced Alarms**: To-Do alarms cannot be dismissed, only started
5. **Safety Windows**: Flows only trigger within defined time windows
