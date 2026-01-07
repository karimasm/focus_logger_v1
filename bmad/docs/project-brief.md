# Project Brief: Focus Logger (Flow)

## Overview
Focus Logger (codename: "Flow") is a Flutter-based focus and immersion tracking app designed for individuals with ADHD. It helps users maintain awareness of how they spend their time and supports structured routines through guided flows.

## Problem Statement
People with ADHD struggle with:
- Time blindness - losing track of time during activities
- Task switching - difficulty transitioning between tasks
- Routine adherence - forgetting scheduled activities
- Self-awareness - not realizing when they've been idle

## Solution
Flow provides:
1. **Activity Logging** - Track what you're doing in real-time
2. **Guided Flows** - Structured routines with step-by-step guidance
3. **To-Do List with Enforced Alarms** - Commitments that cannot be skipped
4. **Idle Detection** - Automatic prompts when inactive for 30+ minutes
5. **Energy Check-ins** - Track energy levels after completing activities

## Target Users
- Adults with ADHD who want better time awareness
- Anyone struggling with focus and routine adherence
- Users who need accountability for commitments

## Tech Stack
- **Frontend**: Flutter 3.x (cross-platform: Linux, Android, iOS, Web)
- **State Management**: Provider
- **Local Database**: SQLite (sqflite)
- **Cloud Sync**: Supabase (PostgreSQL)
- **Architecture**: Repository pattern with cloud-first sync

## Success Metrics
- User can log activities without friction
- Guided flows complete successfully
- Alarm reminders trigger at correct times
- Idle detection works reliably
- Data syncs between devices

## Constraints
- Must work offline (local-first with cloud sync)
- Minimal battery impact
- Non-intrusive but effective reminders
- Simple, focused UI (avoid feature bloat)

## Current Status
- **Phase 1**: Core activity logging ✅
- **Phase 2**: Guided flows ✅
- **Phase 3**: To-Do with alarms ✅
- **Phase 4**: Idle detection ✅
- **Phase 5**: Analytics & insights (planned)
