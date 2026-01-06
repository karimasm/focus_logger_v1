# Changelog

All notable changes to Focus Logger will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.0] - 2026-01-05

### Added
- **Repository Pattern** for platform-safe data access
  - `DataRepository` abstract interface
  - `LocalDataRepository` for Android/Linux (SQLite + sync queue)
  - `CloudDataRepository` for Web (Supabase-only)
  - `RepositoryFactory` for platform detection
- **Haid Mode Sync** across devices via `SyncEvent.haidModeChange`
- **Indonesian Haid Check Dialog** - "Apakah kamu masih haid?" prompt
- **wasSkippedHaid field** in `GuidedFlowLog` for tracking flows skipped due to menstruation
- **fromSupabaseMap factories** for all synced models

### Fixed
- **Web Platform Crash** - SQLite no longer called on Web
- **Nullable access errors** in guided_flow_provider.dart
- **Import path issues** in data repository

### Changed
- All providers now use `DataRepository` instead of `DatabaseHelper` directly
- Sync service skips local queue operations on Web
- Database version bumped to 5

---

## Release Lanes

| Version | Focus |
|---------|-------|
| 0.8.x | Architecture & sync refactor |
| 0.9.x | Stabilization & UX polish |
| 1.0 | Daily-workflow release |
