import '../../models/models.dart';

/// Abstract repository interface for all data operations.
/// Platform-specific implementations:
/// - LocalDataRepository: SQLite + sync queue (Android/Linux)
/// - CloudDataRepository: Supabase-only (Web)
abstract class DataRepository {
  // ==================== ACTIVITIES ====================
  
  /// Get a single activity by ID
  Future<Activity?> getActivity(String id);
  
  /// Get the currently running activity
  Future<Activity?> getRunningActivity();
  
  /// Get activities for a specific date
  Future<List<Activity>> getActivitiesForDate(DateTime date);
  
  /// Search activities by name/category across all dates
  Future<List<Activity>> searchActivities(String query);
  
  /// Get running activities older than a cutoff time (for sanitization)
  Future<List<Activity>> getRunningActivitiesOlderThan(DateTime cutoff);
  
  /// Insert a new activity
  Future<void> insertActivity(Activity activity);
  
  /// Update an existing activity
  Future<void> updateActivity(Activity activity);
  
  /// Delete an activity
  Future<void> deleteActivity(String id);
  
  /// Get activity durations for a date
  Future<Map<String, Duration>> getActivityDurationsForDate(DateTime date);

  // ==================== PAUSE LOGS ====================
  
  /// Get pause logs for an activity
  Future<List<PauseLog>> getPauseLogsForActivity(String activityId);
  
  /// Get the active (unresolved) pause log for an activity
  Future<PauseLog?> getActivePauseLog(String activityId);
  
  /// Insert a pause log
  Future<void> insertPauseLog(PauseLog log);
  
  /// Update a pause log
  Future<void> updatePauseLog(PauseLog log);

  // ==================== MEMO ENTRIES ====================
  
  /// Get memos for an activity
  Future<List<MemoEntry>> getMemosForActivity(String activityId);
  
  /// Get all memos for current user (for Memo Tab)
  Future<List<MemoEntry>> getAllMemos();
  
  /// Get memos for a specific date
  Future<List<MemoEntry>> getMemosForDate(DateTime date);
  
  /// Search memos by text across all dates
  Future<List<MemoEntry>> searchMemos(String query);
  
  /// Insert a memo
  Future<void> insertMemoEntry(MemoEntry memo);
  
  /// Update a memo
  Future<void> updateMemoEntry(MemoEntry memo);
  
  /// Delete a memo
  Future<void> deleteMemoEntry(String id);

  // ==================== GUIDED FLOW LOGS ====================
  
  /// Get flow logs for a date
  Future<List<GuidedFlowLog>> getGuidedFlowLogsForDate(DateTime date);
  
  /// Insert a flow log
  Future<void> insertGuidedFlowLog(GuidedFlowLog log);
  
  /// Update a flow log
  Future<void> updateGuidedFlowLog(GuidedFlowLog log);
  
  /// Log a missed ritual
  Future<void> logMissedRitual(String flowId, String flowName, DateTime windowEnd);
  
  /// Get completed flow IDs for a date
  Future<Set<String>> getCompletedFlowIdsForDate(DateTime date);

  // ==================== GUIDED FLOW STATE ====================
  
  /// Update last triggered time for a flow
  Future<void> updateGuidedFlowLastTriggered(String flowId, DateTime time);
  
  /// Update last completed time for a flow
  Future<void> updateGuidedFlowLastCompleted(String flowId, DateTime time);
  
  /// Get last triggered time for a flow
  Future<DateTime?> getGuidedFlowLastTriggered(String flowId);
  
  /// Get last completed time for a flow
  Future<DateTime?> getGuidedFlowLastCompleted(String flowId);

  // ==================== GUIDED FLOWS (Database-driven) ====================
  
  /// Get all guided flows (system defaults + user custom)
  Future<List<GuidedFlow>> getAllGuidedFlows();
  
  /// Get a guided flow by ID with its steps
  Future<GuidedFlow?> getGuidedFlowById(String id);
  
  /// Get flow by safety window ID
  Future<GuidedFlow?> getGuidedFlowByWindowId(String windowId);
  
  /// Insert or update a guided flow (user custom only)
  Future<void> upsertGuidedFlow(GuidedFlow flow);
  
  /// Delete a guided flow (user custom only)
  Future<void> deleteGuidedFlow(String id);

  // ==================== USER FLOW TEMPLATES ====================
  
  /// Get all flow templates
  Future<List<UserFlowTemplate>> getAllUserFlowTemplates();
  
  /// Get a flow template by ID
  Future<UserFlowTemplate?> getUserFlowTemplate(String id);
  
  /// Get template linked to a safety window
  Future<UserFlowTemplate?> getTemplateByWindowId(String windowId);
  
  /// Insert a flow template
  Future<void> insertUserFlowTemplate(UserFlowTemplate template);
  
  /// Update a flow template
  Future<void> updateUserFlowTemplate(UserFlowTemplate template);
  
  /// Delete a flow template
  Future<void> deleteUserFlowTemplate(String id);

  // ==================== AD-HOC TASKS ====================
  
  /// Get all ad-hoc tasks
  Future<List<AdHocTask>> getAllAdHocTasks();
  
  /// Get pending ad-hoc tasks
  Future<List<AdHocTask>> getPendingAdHocTasks();
  
  /// Get in-progress ad-hoc tasks
  Future<List<AdHocTask>> getInProgressAdHocTasks();
  
  /// Get completed ad-hoc tasks
  Future<List<AdHocTask>> getCompletedAdHocTasks();
  
  /// Insert an ad-hoc task
  Future<void> insertAdHocTask(AdHocTask task);
  
  /// Update an ad-hoc task
  Future<void> updateAdHocTask(AdHocTask task);
  
  /// Delete an ad-hoc task
  Future<void> deleteAdHocTask(String id);
  
  /// Clear all completed ad-hoc tasks
  Future<void> clearCompletedAdHocTasks();

  // ==================== TIME SLOTS ====================
  
  /// Get time slots for a date
  Future<List<TimeSlot>> getTimeSlotsForDate(DateTime date);
  
  /// Insert a time slot
  Future<void> insertTimeSlot(TimeSlot slot);
  
  /// Update a time slot
  Future<void> updateTimeSlot(TimeSlot slot);

  // ==================== UNLOGGED BLOCKS ====================
  
  /// Get unlogged blocks for a date
  Future<List<UnloggedBlock>> getUnloggedBlocksForDate(DateTime date);
  
  /// Insert an unlogged block
  Future<void> insertUnloggedBlock(UnloggedBlock block);
  
  /// Delete an unlogged block
  Future<void> deleteUnloggedBlock(String id);
  
  /// Clear old unlogged blocks (>7 days)
  Future<void> clearOldUnloggedBlocks();

  // ==================== ENERGY CHECKS ====================
  
  /// Get energy checks for an activity
  Future<List<EnergyCheck>> getEnergyChecksForActivity(String activityId);
  
  /// Get energy checks for a date
  Future<List<EnergyCheck>> getEnergyChecksForDate(DateTime date);
  
  /// Get the latest energy check
  Future<EnergyCheck?> getLatestEnergyCheck();
  
  /// Insert an energy check
  Future<void> insertEnergyCheck(EnergyCheck check);

  // ==================== SYNC SUPPORT ====================
  
  /// Get pending sync items for a table (local only)
  Future<List<Map<String, dynamic>>> getPendingSyncItems(String tableName);
  
  /// Mark an item as synced (local only)
  Future<void> markAsSynced(String tableName, String id);
  
  /// Upsert from remote sync
  Future<void> upsertFromSync(String tableName, Map<String, dynamic> item);
  
  /// Check if platform supports local database
  bool get supportsLocalDb;
  
  // ==================== DIRECT CLOUD OPERATIONS ====================
  // These methods write directly to Supabase and return the confirmed record.
  // Used by Web platform for immediate cloud persistence.
  
  /// Insert activity directly to cloud, returns the confirmed record
  /// Web: writes to Supabase immediately
  /// Android/Linux: writes locally then pushes if online
  Future<Activity> insertActivityDirect(Activity activity);
  
  /// Update activity directly to cloud, returns the confirmed record
  Future<Activity> updateActivityDirect(Activity activity);
  
  /// Insert pause log directly to cloud
  Future<PauseLog> insertPauseLogDirect(PauseLog log);
  
  /// Update pause log directly to cloud
  Future<PauseLog> updatePauseLogDirect(PauseLog log);
  
  /// Insert memo directly to cloud
  Future<MemoEntry> insertMemoEntryDirect(MemoEntry memo);
  
  /// Insert ad-hoc task directly to cloud
  Future<AdHocTask> insertAdHocTaskDirect(AdHocTask task);
  
  /// Update ad-hoc task directly to cloud
  Future<AdHocTask> updateAdHocTaskDirect(AdHocTask task);
  
  // ==================== REALTIME SUPPORT ====================
  // Subscribe to real-time changes from Supabase
  
  /// Subscribe to running activity changes (cross-device sync)
  Stream<Activity?> watchRunningActivity();
  
  /// Get the current device identifier
  String get deviceId;
}
