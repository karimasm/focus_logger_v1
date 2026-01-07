# Focus Logger (Flow)

A Focus & Immersion Tracking app built with Flutter, designed for individuals with ADHD. Track your time, maintain routines, and stay aware of how you spend your day.

Powered by **Supabase** for seamless cross-device synchronization.

## Features

### Core Features
- **Activity Tracking** - Start, Stop, Pause, Resume activities with real-time sync
- **To-Do List** - Tasks with enforced alarm reminders (cannot be dismissed!)
- **Guided Flows** - Step-by-step routines triggered by safety windows
- **Idle Detection** - Prompts after 30 min inactivity to log what you were doing
- **Energy Check-ins** - Track energy levels (1-5) after activities
- **Haid Mode** - Adjusts prayer routines during menstruation

### Architecture
- **Framework**: Flutter (Android, iOS, Linux, Web)
- **Backend**: Supabase (PostgreSQL + Realtime)
- **State Management**: Provider + Repository Pattern
- **Sync Model**: Cloud-first with offline support

---

## Guided Flows

Unique feature for building habits with **guided steps**. Unlike simple checklists, these take over the screen and guide you step-by-step.

**Predefined Flows:**
- **Subuh Routine**: Wake up → Pray → Movement
- **Dzuhur Routine**: Pray → Lunch/Nap → Return to Work
- **Ashar/Magrib/Isya**: Prayer routines with post-prayer actions
- **Sleep Discipline**: Prepare for tomorrow → Wind down → Sleep
- **Distraction Recovery**: Flow triggered when you drift off track

---

## Project Structure

```
focus_logger/
├── bmad/                  # BMAD project documentation
│   ├── docs/              # PRD, architecture, workflow
│   ├── epics/             # Feature epics
│   └── stories/           # User stories
├── lib/
│   ├── main.dart          # App entry point
│   ├── app.dart           # App config & theme
│   ├── data/repositories/ # Repository pattern (Cloud + Local)
│   ├── models/            # Data models
│   ├── providers/         # State management
│   ├── services/          # Business logic
│   ├── screens/           # UI Screens
│   ├── widgets/           # Reusable widgets
│   └── theme/             # AppColors & theming
├── supabase_*.sql         # Database migrations
└── pubspec.yaml           # Dependencies
```

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Supabase Project (configure `.env` with URL & Anon Key)

### Running the App

```bash
# Linux
flutter run -d linux

# Android
flutter run -d android

# Web
flutter run -d chrome
```

### Building for Production

```bash
flutter build linux --release
flutter build apk --release
```

## Database Schema

Core tables in Supabase:

| Table | Description |
|-------|-------------|
| `activities` | Time-tracked activities |
| `adhoc_tasks` | To-Do items with alarms |
| `user_flow_templates` | Guided flow definitions |
| `safety_windows` | Time windows for flow triggers |
| `energy_checks` | Energy level logs |
| `memo_entries` | Notes attached to activities |

## Development

See [bmad/docs/development-workflow.md](bmad/docs/development-workflow.md) for development guidelines.

## License

MIT License
