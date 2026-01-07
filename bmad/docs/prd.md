# Product Requirements Document (PRD)

## Product: Focus Logger (Flow)
## Version: 1.0
## Last Updated: 2026-01-07

---

## 1. Executive Summary

Flow is a time-awareness app designed for people with ADHD. It combines activity logging, guided routines, enforced commitments, and idle detection to help users stay aware of how they spend their time.

---

## 2. Goals & Objectives

### Primary Goals
1. **Increase time awareness** - Users always know what they're doing
2. **Support routine adherence** - Guided flows help maintain structure
3. **Enforce commitments** - To-Do alarms that can't be dismissed
4. **Reduce time blindness** - Idle detection catches unlogged periods

### Success Metrics
| Metric | Target |
|--------|--------|
| Daily active usage | 5+ days/week |
| Activities logged per day | 3+ |
| Guided flow completion rate | 80%+ |
| Alarm acknowledgment time | < 30 seconds |

---

## 3. Features

### 3.1 Activity Logging (Phase 1) ✅
- Start/stop activity timer
- Categorize activities
- Pause with reason
- View today's timeline
- Manual log for past activities

### 3.2 Guided Flows (Phase 2) ✅
- Pre-defined routines (Morning, Prayer, etc.)
- Step-by-step guidance
- Safety windows (time bounds)
- Haid mode (menstruation adjustments)
- Chain context (activity relationships)

### 3.3 To-Do List (Phase 3) ✅
- Create tasks with optional alarm
- Enforced fullscreen reminder
- Conflict resolution with flows
- Pause/resume/stop functionality
- Memo attachment

### 3.4 Idle Detection (Phase 4) ✅
- 30-minute threshold
- Fullscreen reflection prompt
- Label idle period
- Persists across app restarts

### 3.5 Analytics (Phase 5) 🔜
- Daily/weekly summaries
- Category breakdown
- Focus streaks
- Energy correlation
- Data export

---

## 4. User Flows

### 4.1 Quick Activity Log
```
Home → Tap activity name → Timer starts → Do activity → Tap stop → Done
```

### 4.2 Guided Flow
```
Safety window opens → Prompt appears → Start flow → 
Complete steps → Flow ends → Energy check
```

### 4.3 To-Do with Alarm
```
Create task → Set alarm time → Wait for alarm →
Fullscreen appears → Tap "Start Now" → Complete task
```

### 4.4 Idle Recovery
```
No activity for 30 min → Idle screen appears →
Enter what you were doing → Logged as past activity
```

---

## 5. Technical Requirements

### 5.1 Platform Support
- ✅ Linux (primary development)
- ✅ Android
- 🔜 iOS
- 🔜 Web

### 5.2 Performance
- App launch < 2 seconds
- Timer accuracy ± 1 second
- Alarm trigger < 5 seconds from scheduled time
- Sync latency < 30 seconds

### 5.3 Offline Support
- Full functionality without internet
- Background sync when online
- Conflict resolution (last-write-wins)

### 5.4 Data Security
- Local SQLite encrypted (future)
- Supabase RLS (Row Level Security)
- No third-party analytics
- User data exportable

---

## 6. Design Principles

1. **Minimal friction** - Logging should be one tap
2. **Non-judgmental** - No guilt, just awareness
3. **Enforced when needed** - Alarms are commitments
4. **Flexible otherwise** - User controls their data
5. **Offline-first** - Works without internet

---

## 7. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Users ignore alarms | Enforced fullscreen, no dismiss |
| Battery drain | Efficient timers, no GPS |
| Data loss | Cloud sync, local backup |
| Feature creep | Strict scope per phase |

---

## 8. Future Considerations

- **Widgets** - Home screen quick-start buttons
- **Wearable** - Watch companion app
- **Pomodoro mode** - Built-in focus timer
- **Social** - Share progress with accountability partner
- **AI insights** - Pattern recognition and suggestions
