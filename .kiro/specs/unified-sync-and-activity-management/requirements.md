# Requirements Document

## Introduction

This specification defines the awareness-based activity management, enforced flow system, idle reflection prompts, distraction tracking, and memo management for the Focus Logger application. The system is designed as an **awareness & reflection tool for ADHD and hyperfixation states**, not just a time tracker.

**Platform Focus**: Android only (Web & Linux paused until core is stable)
**Sync Mode**: Single-device mode (cross-device sync paused until Android is stable)

## Glossary

- **System**: The Focus Logger application (Android)
- **Activity**: A time-tracked task or action with start/end timestamps
- **Ad-Hoc Task**: An unplanned task that can be created and executed on demand
- **Guided Flow**: A scheduled routine with enforced prompts (e.g., prayer times) - chained awareness events, not just time tracking
- **Flow Window**: The time period during which a guided flow is active - cannot be dodged via pause/snooze
- **Haid Mode**: A menstrual period tracking mode that affects prayer/Qur'an flow behavior
- **Idle Reflection**: A fullscreen prompt that appears after 30 minutes of no activity, using shy_duck_idle asset
- **Distraction Reflection**: A prompt that appears when user pauses an activity, using angry_duck_knife asset
- **Memo**: A standalone note that can exist independently or be attached to an activity
- **Timeline**: The chronological view of all activities - must be searchable
- **Ghost Activity**: An orphaned activity from old database/version that needs cleanup
- **Supabase**: The cloud database for data persistence

## Requirements

### Requirement 1: Single-Device Data Persistence

**User Story:** As a user, I want my activities and memos to be saved reliably to the database, so that my data persists across app restarts.

#### Acceptance Criteria

1. WHEN a user starts an activity, THEN THE System SHALL save it to SQLite immediately
2. WHEN a user completes an activity, THEN THE System SHALL update the record in SQLite immediately
3. WHEN a user creates a memo, THEN THE System SHALL save it to SQLite immediately
4. WHEN the app restarts, THEN THE System SHALL load all activities and memos from SQLite
5. WHEN displaying the timeline, THEN THE System SHALL show all saved activities (timeline must never be empty if activities exist)
6. WHEN a database operation fails, THEN THE System SHALL display an error message to the user

### Requirement 2: Single-Activity Enforcement

**User Story:** As a user, I want only one activity to run at a time, so that my timeline is accurate and honest.

#### Acceptance Criteria

1. WHEN a user starts a new activity, THEN THE System SHALL automatically close any currently running activity with end_time = now
2. WHEN closing a previous activity, THEN THE System SHALL set is_running = 0 immediately
3. WHEN the app starts, THEN THE System SHALL check for and close any ghost-running activities from old database versions
4. WHEN displaying the timeline, THEN THE System SHALL never show multiple activities running simultaneously

### Requirement 3: Ad-Hoc Task Activity Integration

**User Story:** As a user, I want starting an ad-hoc task to pause my current activity, so that my timeline accurately reflects what I'm doing.

#### Acceptance Criteria

1. WHEN a user starts an ad-hoc task while an activity is running, THEN THE System SHALL pause the current activity automatically
2. WHEN pausing for an ad-hoc task, THEN THE System SHALL set pause_reason = "Doing Ad-Hoc – <task title>"
3. WHEN an ad-hoc task is completed, THEN THE System SHALL prompt the user with "Continue previous activity?"
4. WHEN the user selects "ON IT" after ad-hoc completion, THEN THE System SHALL resume the previously paused activity
5. WHEN the user selects "Stay Paused" after ad-hoc completion, THEN THE System SHALL require the user to select a pause reason

### Requirement 4: Activity Completion Integrity

**User Story:** As a user, I want activities to close immediately when I press DONE, so that my timeline shows accurate durations.

#### Acceptance Criteria

1. WHEN a user presses DONE on an activity, THEN THE System SHALL write end_time = now immediately
2. WHEN a user presses DONE on an activity, THEN THE System SHALL set is_running = 0 immediately
3. WHEN displaying the timeline, THEN THE System SHALL never show negative durations
4. WHEN displaying the timeline, THEN THE System SHALL never show runaway durations (activities still running after 24 hours)

### Requirement 5: Ghost Activity Cleanup

**User Story:** As a user, I want old activities that were never closed to be cleaned up automatically, so that my timeline doesn't show impossible durations.

#### Acceptance Criteria

1. WHEN the app starts, THEN THE System SHALL check for activities with is_running = 1 that are older than 24 hours
2. WHEN a ghost activity is found, THEN THE System SHALL set end_time = start_time + 1 hour
3. WHEN a ghost activity is found, THEN THE System SHALL set is_running = 0
4. WHEN the app starts, THEN THE System SHALL clean up any orphaned data from old database versions
5. WHEN migrating from old database structure, THEN THE System SHALL preserve valid data and discard corrupted records

### Requirement 6: Fullscreen Idle Reflection Prompt

**User Story:** As a user with ADHD, I want a fullscreen prompt to appear when I've been idle for 30 minutes, so that I maintain awareness of my time usage and can reflect on what I was doing.

#### Acceptance Criteria

1. WHEN no activity is running and 30 minutes have elapsed, THEN THE System SHALL show a fullscreen idle reflection prompt
2. WHEN the idle reflection prompt appears, THEN THE System SHALL display the shy_duck_idle asset
3. WHEN the idle reflection prompt appears, THEN THE System SHALL ask "Kamu tadi ngapain?" (What were you doing?)
4. WHEN the idle reflection prompt appears, THEN THE System SHALL allow text input for reflection
5. WHEN the idle reflection prompt appears, THEN THE System SHALL allow voice input for reflection
6. WHEN the user responds to the prompt, THEN THE System SHALL create a memo with the reflection (can be standalone, not attached to activity)
7. WHEN the user dismisses the prompt without responding, THEN THE System SHALL still record that idle time occurred
8. WHEN testing, THEN THE System SHALL allow configurable idle interval (shorter than 30 minutes for testing)

### Requirement 7: Distraction Reflection on Pause

**User Story:** As a user with ADHD, I want to reflect on why I'm pausing an activity, so that I can track my distractions and improve focus.

#### Acceptance Criteria

1. WHEN a user pauses an activity, THEN THE System SHALL show a distraction reflection prompt
2. WHEN the distraction reflection prompt appears, THEN THE System SHALL display the angry_duck_knife asset
3. WHEN the distraction reflection prompt appears, THEN THE System SHALL ask for the reason for pausing
4. WHEN the user provides a pause reason, THEN THE System SHALL store it with the activity
5. WHEN the user provides a pause reason, THEN THE System SHALL optionally create a memo with the reflection
6. WHEN the user resumes the activity, THEN THE System SHALL track the paused duration accurately

### Requirement 8: Enforced Flow System

**User Story:** As a user, I want flow windows to be enforced and impossible to dodge, so that I maintain accountability for my routines.

#### Acceptance Criteria

1. WHEN a flow window begins, THEN THE System SHALL show an enforced flow prompt that cannot be dismissed
2. WHEN a flow window begins, THEN THE System SHALL play an alert sound immediately
3. WHEN a flow window begins, THEN THE System SHALL trigger vibration immediately
4. WHILE the user has not pressed ON IT, THEN THE System SHALL repeat the alert every 2 minutes
5. WHEN the user presses ON IT, THEN THE System SHALL stop all alerts and vibrations
6. WHEN running in the background, THEN THE System SHALL still trigger alerts and vibrations
7. WHEN a flow window is active, THEN THE System SHALL NOT allow pause or snooze to dodge the flow
8. WHEN the app opens during an active flow window, THEN THE System SHALL show the enforced flow prompt if not completed

### Requirement 9: Flow Completion Definition

**User Story:** As a user, I want flows to be marked completed only when I actually do them, so that my accountability is honest.

#### Acceptance Criteria

1. WHEN determining if a flow is completed, THEN THE System SHALL check if the user pressed ON IT
2. WHEN determining if a flow is completed, THEN THE System SHALL check if the user pressed DONE after all steps
3. IF a flow window passes without ON IT being pressed, THEN THE System SHALL mark the flow as missed (not completed)
4. IF a flow is started but not finished, THEN THE System SHALL mark the flow as abandoned (not completed)

### Requirement 10: Memo Collection View

**User Story:** As a user, I want to see all my memos in one place, so that I can review my reflections and notes across all activities.

#### Acceptance Criteria

1. WHEN a user creates a memo, THEN THE System SHALL attach it to the current or specified activity
2. WHEN viewing the timeline, THEN THE System SHALL show a "Memo" tab alongside the timeline tab
3. WHEN viewing the Memo tab, THEN THE System SHALL display all memos from all activities in chronological order
4. WHEN viewing the Memo tab, THEN THE System SHALL allow searching memos by content
5. WHEN displaying a memo in the Memo tab, THEN THE System SHALL show which activity it belongs to
6. WHEN a user taps a memo in the Memo tab, THEN THE System SHALL navigate to the associated activity
7. WHEN viewing an activity detail, THEN THE System SHALL show all memos attached to that activity

### Requirement 11: Timeline Search and Display

**User Story:** As a user, I want to search my timeline and see all my activities, so that I can review my history and find specific entries.

#### Acceptance Criteria

1. WHEN viewing the timeline, THEN THE System SHALL display all activities in chronological order
2. WHEN viewing the timeline, THEN THE System SHALL provide a search function
3. WHEN searching the timeline, THEN THE System SHALL filter activities by name, category, or date
4. WHEN displaying the timeline, THEN THE System SHALL never show overlapping activities
5. WHEN displaying the timeline, THEN THE System SHALL calculate durations as end_time - start_time - paused_duration_seconds
6. WHEN displaying activity durations, THEN THE System SHALL format them as hours:minutes
7. WHEN an activity exists in the database, THEN THE System SHALL display it in the timeline (timeline must not be empty)

### Requirement 12: Responsive Activity Card Layout

**User Story:** As a user on different Android devices, I want the activity card to display correctly, so that the counter and duration don't break or overflow.

#### Acceptance Criteria

1. WHEN displaying the activity card, THEN THE System SHALL keep the counter/seconds on the same line
2. WHEN displaying the activity card on small screens, THEN THE System SHALL scale text appropriately
3. WHEN displaying the activity card on large screens, THEN THE System SHALL not stretch elements awkwardly
4. WHEN the activity name is long, THEN THE System SHALL truncate with ellipsis rather than breaking layout
5. WHEN displaying duration, THEN THE System SHALL use consistent formatting across all device sizes

### Requirement 13: Haid Mode Local Persistence

**User Story:** As a user, I want my Haid Mode status to persist locally, so that the app remembers my state across restarts.

#### Acceptance Criteria

1. WHEN Haid Mode is enabled, THEN THE System SHALL store the status in SQLite
2. WHEN the app restarts, THEN THE System SHALL load the Haid Mode status from SQLite
3. WHEN storing Haid Mode, THEN THE System SHALL include haid_mode_active (boolean)
4. WHEN storing Haid Mode, THEN THE System SHALL include haid_mode_updated_at (timestamp)
5. WHEN storing Haid Mode, THEN THE System SHALL include haid_cycle_start_at (timestamp)

### Requirement 14: Haid Mode Flow Behavior

**User Story:** As a user in Haid Mode, I want prayer and Qur'an flows to be skipped appropriately, so that I'm not prompted for activities I cannot perform.

#### Acceptance Criteria

1. WHEN a prayer flow window begins and Haid Mode is active, THEN THE System SHALL show a prompt "Apakah kamu masih haid?"
2. WHEN the user responds "Masih haid" to the prompt, THEN THE System SHALL skip the prayer flow
3. WHEN a flow is skipped due to Haid Mode, THEN THE System SHALL set status = skipped_due_to_haid (not missed)
4. WHEN the user responds "Sudah selesai" to the prompt, THEN THE System SHALL disable Haid Mode
5. WHEN the user responds "Sudah selesai" to the prompt, THEN THE System SHALL continue with the normal enforced flow
6. WHEN Haid Mode has been active for 5-7 days, THEN THE System SHALL prompt the user to confirm their status
7. WHILE Haid Mode is active, THEN THE System SHALL not enforce prayer or Qur'an flows on any device

### Requirement 15: Voice Input (Android Only)

**User Story:** As an Android user, I want to use voice input for memos and reflections, so that I can capture thoughts quickly.

#### Acceptance Criteria

1. WHEN running on Android, THEN THE System SHALL enable voice input with microphone permissions
2. WHEN voice input is available, THEN THE System SHALL show microphone buttons in memo entry
3. WHEN voice input is available, THEN THE System SHALL show microphone buttons in idle reflection prompt
4. WHEN voice input is available, THEN THE System SHALL show microphone buttons in distraction reflection prompt
5. WHEN voice input fails, THEN THE System SHALL fall back to text input gracefully
