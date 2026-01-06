# Focus Logger

An Activity Timeline & Focus Logger application built with Flutter. Track your time, focus, distractions, and energy awareness across Android, Web, and Linux desktop.

Now powered by **Supabase** for seamless cross-device synchronization.

## Features

### Core Features
- ✅ **Home Screen** - Large digital clock, live timer, and Mascot companion.
- ✅ **Activity Tracking** - Start, Stop, Pause, Resume activities with real-time sync.
- ✅ **Live Sync** - Server-authoritative state management. Start on Web, pause on Android.
- ✅ **Idle Detection** - Detects inactivity and prompts to categorize time (Deep Work vs Distraction).
- ✅ **Flow Management** - Create and edit multi-step guided routines (IF-THEN flows).
- ✅ **Energy Tracking** - Log energy levels (1-5) after every activity.
- ✅ **Haid Mode** - Skips prayer steps in routines when active.
- ✅ **Ad-Hoc Tasks** - "On It" tracking for quick, unplanned tasks.

### Architecture
- **Framework**: Flutter (Android, Web, Linux)
- **Backend / DB**: Supabase (PostgreSQL + Realtime)
- **State Management**: Provider + Repository Pattern
- **Sync Model**: Server-Authoritative (Single User Mode)

---

## IF-THEN Guided Flows

A unique feature for building habits with **guided steps**. Unlike simple checklists, these take over the screen and guide you step-by-step.

**Predefined Flows (seeded by default):**
- **Subuh Routine**: Wake up → Pray → Movement.
- **Dzuhur Routine**: Pray → Lunch/Nap → Return to Work.
- **Ashar/Magrib/Isya**: Prayer routines with specific post-prayer actions (e.g., Quran, Planning).
- **Sleep Discipline**: Prepare for tomorrow → Wind down → Sleep.
- **Distraction Recovery**: Special flow triggered when you drift off track.

**Flow Editor:**
You can create your own custom flows or edit the existing ones via the "Actions" tab.

---

## Project Structure

```
focus_logger/
├── antigravity/           # Implementation docs & walkthroughs
├── lib/
│   ├── main.dart          # App entry point
│   ├── app.dart           # App config & theme
│   ├── data/
│   │   └── repositories/  # Repository pattern implementation
│   │       ├── data_repository.dart
│   │       └── cloud_data_repository.dart (Supabase)
│   ├── models/            # Data models (SyncableModel)
│   │   ├── activity.dart
│   │   ├── user_flow_template.dart
│   │   ├── adhoc_task.dart
│   │   └── ...
│   ├── providers/         # State management
│   │   ├── activity_provider.dart
│   │   ├── flow_action_provider.dart
│   │   └── ...
│   ├── services/          # Business logic
│   │   ├── flow_seeder_service.dart
│   │   ├── idle_detection_service.dart
│   │   └── sync_service.dart
│   ├── screens/           # UI Screens
│   │   ├── home_screen.dart
│   │   ├── tasks_screen.dart   # Flow & Ad-Hoc Management
│   │   └── timeline_screen.dart
│   └── widgets/           # Reusable widgets
├── supabase_schema.sql    # Database schema definition
├── pubspec.yaml           # Dependencies
└── ...
```

## Getting Started

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Supabase Project (URL & Anon Key configured in `main.dart`)

### Running the App

1. **Web (Recommended for Dev):**
   ```bash
   flutter run -d chrome --web-port=8080
   ```

2. **Android:**
   ```bash
   flutter run -d android
   ```

3. **Linux:**
   ```bash
   flutter run -d linux
   ```

## Database Schema (Supabase)

The app uses a relational schema on Supabase:

- **activities**: The core log of what you did.
- **user_flow_templates**: Definitions of guided flows (Subuh, Work, etc.).
- **user_flow_steps**: Individual IF-THEN steps for each template.
- **adhoc_tasks**: One-off tasks.
- **energy_checks**: Energy level logs linked to activities.
- **pause_logs**: Records of why and when you paused.

## License

MIT License
