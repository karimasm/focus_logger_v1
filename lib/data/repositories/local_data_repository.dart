import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../database/database_helper.dart';
import '../../models/models.dart';
import 'data_repository.dart';

/// Local SQLite implementation of DataRepository.
/// Used on Android and Linux platforms.
/// Wraps the existing DatabaseHelper with sync queue support.
/// 
/// SYNC ARCHITECTURE (Phase 1):
/// - Local writes go to SQLite first
/// - If online, immediately push to Supabase
/// - Direct methods return the local record (optimistic)
/// - Realtime subscription watches for remote changes
class LocalDataRepository implements DataRepository {
  static final LocalDataRepository instance = LocalDataRepository._init();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();
  
  /// Unique device identifier
  String? _deviceId;
  
  LocalDataRepository._init();

  @override
  bool get supportsLocalDb => true;
  
  @override
  String get deviceId {
    _deviceId ??= 'local_${DateTime.now().millisecondsSinceEpoch}';
    return _deviceId!;
  }
  
  SupabaseClient get _supabase => Supabase.instance.client;
  
  Future<bool> _hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ==================== ACTIVITIES ====================
  
  @override
  Future<Activity?> getActivity(String id) => _db.getActivity(id);
  
  @override
  Future<Activity?> getRunningActivity() => _db.getRunningActivity();
  
  @override
  Future<List<Activity>> getActivitiesForDate(DateTime date) => 
      _db.getActivitiesForDate(date);
  
  @override
  Future<List<Activity>> searchActivities(String query) async {
    // For local, search in database (simplified - just return empty for now)
    // Full implementation would search SQLite with LIKE query
    return <Activity>[];
  }
  
  @override
  Future<List<Activity>> getRunningActivitiesOlderThan(DateTime cutoff) =>
      _db.getRunningActivitiesOlderThan(cutoff);
  
  @override
  Future<void> insertActivity(Activity activity) async {
    await _db.insertActivity(activity);
  }
  
  @override
  Future<void> updateActivity(Activity activity) async {
    await _db.updateActivity(activity);
  }
  
  @override
  Future<void> deleteActivity(String id) async {
    await _db.deleteActivity(id);
  }
  
  @override
  Future<Map<String, Duration>> getActivityDurationsForDate(DateTime date) =>
      _db.getActivityDurationsForDate(date);

  // ==================== PAUSE LOGS ====================
  
  @override
  Future<List<PauseLog>> getPauseLogsForActivity(String activityId) =>
      _db.getPauseLogsForActivity(activityId);
  
  @override
  Future<PauseLog?> getActivePauseLog(String activityId) =>
      _db.getActivePauseLog(activityId);
  
  @override
  Future<void> insertPauseLog(PauseLog log) async {
    await _db.insertPauseLog(log);
  }
  
  @override
  Future<void> updatePauseLog(PauseLog log) async {
    await _db.updatePauseLog(log);
  }

  // ==================== MEMO ENTRIES ====================
  
  @override
  Future<List<MemoEntry>> getMemosForActivity(String activityId) =>
      _db.getMemosForActivity(activityId);
  
  @override
  Future<void> insertMemoEntry(MemoEntry memo) async {
    await _db.insertMemoEntry(memo);
  }
  
  @override
  Future<void> updateMemoEntry(MemoEntry memo) async {
    await _db.updateMemoEntry(memo);
  }
  
  @override
  Future<void> deleteMemoEntry(String id) async {
    await _db.deleteMemoEntry(id);
  }
  
  @override
  Future<List<MemoEntry>> getAllMemos() async {
    // Not used - CloudDataRepository is primary
    return <MemoEntry>[];
  }
  
  @override
  Future<List<MemoEntry>> getMemosForDate(DateTime date) async {
    // Not used - CloudDataRepository is primary
    return <MemoEntry>[];
  }
  
  @override
  Future<List<MemoEntry>> searchMemos(String query) async {
    // Not used - CloudDataRepository is primary
    return <MemoEntry>[];
  }

  // ==================== GUIDED FLOW LOGS ====================
  
  @override
  Future<List<GuidedFlowLog>> getGuidedFlowLogsForDate(DateTime date) =>
      _db.getGuidedFlowLogsForDate(date);
  
  @override
  Future<void> insertGuidedFlowLog(GuidedFlowLog log) async {
    await _db.insertGuidedFlowLog(log);
  }
  
  @override
  Future<void> updateGuidedFlowLog(GuidedFlowLog log) async {
    await _db.updateGuidedFlowLog(log);
  }
  
  @override
  Future<void> logMissedRitual(String flowId, String flowName, DateTime windowEnd) async {
    await _db.logMissedRitual(flowId, flowName, windowEnd);
  }
  
  @override
  Future<Set<String>> getCompletedFlowIdsForDate(DateTime date) =>
      _db.getCompletedFlowIdsForDate(date);

  // ==================== GUIDED FLOW STATE ====================
  
  @override
  Future<void> updateGuidedFlowLastTriggered(String flowId, DateTime time) async {
    await _db.updateGuidedFlowLastTriggered(flowId, time);
  }
  
  @override
  Future<void> updateGuidedFlowLastCompleted(String flowId, DateTime time) async {
    await _db.updateGuidedFlowLastCompleted(flowId, time);
  }
  
  @override
  Future<DateTime?> getGuidedFlowLastTriggered(String flowId) =>
      _db.getGuidedFlowLastTriggered(flowId);
  
  @override
  Future<DateTime?> getGuidedFlowLastCompleted(String flowId) =>
      _db.getGuidedFlowLastCompleted(flowId);

  // ==================== GUIDED FLOWS (Database-driven) ====================
  // GuidedFlow methods - not used, kept for interface compliance
  // App now uses UserFlowTemplate system via FlowSeederService
  
  @override
  Future<List<GuidedFlow>> getAllGuidedFlows() async {
    // Deprecated - use getAllUserFlowTemplates instead
    return [];
  }
  
  @override
  Future<GuidedFlow?> getGuidedFlowById(String id) async {
    // Deprecated - use getUserFlowTemplate instead
    return null;
  }
  
  @override
  Future<GuidedFlow?> getGuidedFlowByWindowId(String windowId) async {
    // Deprecated - use getTemplateByWindowId instead
    return null;
  }
  
  @override
  Future<void> upsertGuidedFlow(GuidedFlow flow) async {
    // Not implemented - use UserFlowTemplate methods
  }
  
  @override
  Future<void> deleteGuidedFlow(String id) async {
    // Not implemented - use deleteUserFlowTemplate
  }

  // ==================== USER FLOW TEMPLATES ====================
  
  @override
  Future<List<UserFlowTemplate>> getAllUserFlowTemplates() =>
      _db.getAllUserFlowTemplates();
  
  @override
  Future<UserFlowTemplate?> getUserFlowTemplate(String id) =>
      _db.getUserFlowTemplate(id);
  
  @override
  Future<UserFlowTemplate?> getTemplateByWindowId(String windowId) =>
      _db.getTemplateByWindowId(windowId);
  
  @override
  Future<void> insertUserFlowTemplate(UserFlowTemplate template) async {
    await _db.insertUserFlowTemplate(template);
  }
  
  @override
  Future<void> updateUserFlowTemplate(UserFlowTemplate template) async {
    await _db.updateUserFlowTemplate(template);
  }
  
  @override
  Future<void> deleteUserFlowTemplate(String id) async {
    await _db.deleteUserFlowTemplate(id);
  }

  // ==================== AD-HOC TASKS ====================
  
  @override
  Future<List<AdHocTask>> getAllAdHocTasks() => _db.getAllAdHocTasks();
  
  @override
  Future<List<AdHocTask>> getPendingAdHocTasks() => _db.getPendingAdHocTasks();
  
  @override
  Future<List<AdHocTask>> getInProgressAdHocTasks() => _db.getInProgressAdHocTasks();
  
  @override
  Future<List<AdHocTask>> getCompletedAdHocTasks() => _db.getCompletedAdHocTasks();
  
  @override
  Future<void> insertAdHocTask(AdHocTask task) async {
    await _db.insertAdHocTask(task);
  }
  
  @override
  Future<void> updateAdHocTask(AdHocTask task) async {
    await _db.updateAdHocTask(task);
  }
  
  @override
  Future<void> deleteAdHocTask(String id) async {
    await _db.deleteAdHocTask(id);
  }
  
  @override
  Future<void> clearCompletedAdHocTasks() async {
    await _db.clearCompletedAdHocTasks();
  }

  // ==================== TIME SLOTS ====================
  
  @override
  Future<List<TimeSlot>> getTimeSlotsForDate(DateTime date) =>
      _db.getTimeSlotsForDate(date);
  
  @override
  Future<void> insertTimeSlot(TimeSlot slot) async {
    await _db.insertTimeSlot(slot);
  }
  
  @override
  Future<void> updateTimeSlot(TimeSlot slot) async {
    await _db.updateTimeSlot(slot);
  }

  // ==================== UNLOGGED BLOCKS ====================
  
  @override
  Future<List<UnloggedBlock>> getUnloggedBlocksForDate(DateTime date) =>
      _db.getUnloggedBlocksForDate(date);
  
  @override
  Future<void> insertUnloggedBlock(UnloggedBlock block) async {
    await _db.insertUnloggedBlock(block);
  }
  
  @override
  Future<void> deleteUnloggedBlock(String id) async {
    await _db.deleteUnloggedBlock(id);
  }
  
  @override
  Future<void> clearOldUnloggedBlocks() async {
    await _db.clearOldUnloggedBlocks();
  }

  // ==================== ENERGY CHECKS ====================
  
  @override
  Future<List<EnergyCheck>> getEnergyChecksForActivity(String activityId) =>
      _db.getEnergyChecksForActivity(activityId);
  
  @override
  Future<List<EnergyCheck>> getEnergyChecksForDate(DateTime date) =>
      _db.getEnergyChecksForDate(date);
  
  @override
  Future<EnergyCheck?> getLatestEnergyCheck() => _db.getLatestEnergyCheck();
  
  @override
  Future<void> insertEnergyCheck(EnergyCheck check) async {
    await _db.insertEnergyCheck(check);
  }

  // ==================== SYNC SUPPORT ====================
  
  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems(String tableName) =>
      _db.getPendingSyncItems(tableName);
  
  @override
  Future<void> markAsSynced(String tableName, String id) async {
    await _db.markAsSynced(tableName, id);
  }
  
  @override
  Future<void> upsertFromSync(String tableName, Map<String, dynamic> item) async {
    await _db.upsertFromSync(tableName, item);
  }

  // ==================== DIRECT CLOUD OPERATIONS ====================
  // On Android/Linux: Write locally first, then push to cloud if online.
  // This ensures local state is always consistent without network delays.
  
  @override
  Future<Activity> insertActivityDirect(Activity activity) async {
    // 1. Write to local SQLite
    await _db.insertActivity(activity);
    
    // 2. If online, push to Supabase immediately
    if (await _hasInternet()) {
      try {
        await _supabase.from('activities').upsert(activity.toSupabaseMap());
        await _db.markAsSynced('activities', activity.id);
        debugPrint('📤 Activity pushed to cloud: ${activity.name}');
      } catch (e) {
        debugPrint('⚠️ Failed to push activity to cloud: $e');
        // Activity is still in local queue for later sync
      }
    }
    
    return activity;
  }
  
  @override
  Future<Activity> updateActivityDirect(Activity activity) async {
    // 1. Update local SQLite
    await _db.updateActivity(activity);
    
    // 2. If online, push to Supabase immediately
    if (await _hasInternet()) {
      try {
        await _supabase.from('activities').upsert(activity.toSupabaseMap());
        await _db.markAsSynced('activities', activity.id);
        debugPrint('📤 Activity update pushed to cloud: ${activity.name}');
      } catch (e) {
        debugPrint('⚠️ Failed to push activity update to cloud: $e');
      }
    }
    
    return activity;
  }
  
  @override
  Future<PauseLog> insertPauseLogDirect(PauseLog log) async {
    await _db.insertPauseLog(log);
    
    if (await _hasInternet()) {
      try {
        await _supabase.from('pause_logs').upsert(log.toSupabaseMap());
        await _db.markAsSynced('pause_logs', log.id);
      } catch (e) {
        debugPrint('⚠️ Failed to push pause log to cloud: $e');
      }
    }
    
    return log;
  }
  
  @override
  Future<PauseLog> updatePauseLogDirect(PauseLog log) async {
    await _db.updatePauseLog(log);
    
    if (await _hasInternet()) {
      try {
        await _supabase.from('pause_logs').upsert(log.toSupabaseMap());
        await _db.markAsSynced('pause_logs', log.id);
      } catch (e) {
        debugPrint('⚠️ Failed to push pause log update to cloud: $e');
      }
    }
    
    return log;
  }
  
  @override
  Future<MemoEntry> insertMemoEntryDirect(MemoEntry memo) async {
    await _db.insertMemoEntry(memo);
    
    if (await _hasInternet()) {
      try {
        await _supabase.from('memo_entries').upsert(memo.toSupabaseMap());
        await _db.markAsSynced('memo_entries', memo.id);
      } catch (e) {
        debugPrint('⚠️ Failed to push memo to cloud: $e');
      }
    }
    
    return memo;
  }
  
  @override
  Future<AdHocTask> insertAdHocTaskDirect(AdHocTask task) async {
    await _db.insertAdHocTask(task);
    
    if (await _hasInternet()) {
      try {
        await _supabase.from('adhoc_tasks').upsert(task.toSupabaseMap());
        await _db.markAsSynced('adhoc_tasks', task.id);
      } catch (e) {
        debugPrint('⚠️ Failed to push ad-hoc task to cloud: $e');
      }
    }
    
    return task;
  }
  
  @override
  Future<AdHocTask> updateAdHocTaskDirect(AdHocTask task) async {
    await _db.updateAdHocTask(task);
    
    if (await _hasInternet()) {
      try {
        await _supabase.from('adhoc_tasks').upsert(task.toSupabaseMap());
        await _db.markAsSynced('adhoc_tasks', task.id);
      } catch (e) {
        debugPrint('⚠️ Failed to push ad-hoc task update to cloud: $e');
      }
    }
    
    return task;
  }

  // ==================== REALTIME SUPPORT ====================
  // Subscribe to real-time changes from Supabase for cross-device sync
  
  @override
  Stream<Activity?> watchRunningActivity() {
    // Create a stream that listens to Supabase Realtime changes
    return _supabase
        .from('activities')
        .stream(primaryKey: ['id'])
        .eq('is_running', 1)
        .order('start_time', ascending: false)
        .limit(1)
        .map((List<Map<String, dynamic>> data) {
          if (data.isEmpty) return null;
          return Activity.fromSupabaseMap(data.first);
        });
  }
}
