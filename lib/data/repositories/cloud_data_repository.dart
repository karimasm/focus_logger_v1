import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../services/user_service.dart';
import 'data_repository.dart';

/// Cloud-only Supabase implementation of DataRepository.
/// Used on Web platform where SQLite is not available.
/// All operations go directly to Supabase with graceful offline handling.
/// USER-SCOPED: All queries filter by current user_id
class CloudDataRepository implements DataRepository {
  static final CloudDataRepository instance = CloudDataRepository._init();
  
  CloudDataRepository._init();

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  bool get supportsLocalDb => false;

  // ==================== HELPER METHODS ====================
  
  /// Wrap Supabase calls with error handling for offline scenarios
  Future<T> _safeCall<T>(Future<T> Function() call, T defaultValue) async {
    try {
      return await call();
    } catch (e) {
      debugPrint('⚠️ CloudDataRepository: Operation failed (offline?): $e');
      return defaultValue;
    }
  }

  // ==================== ACTIVITIES ====================
  
  @override
  Future<Activity?> getActivity(String id) async {
    return _safeCall(() async {
      final response = await _supabase
          .from('activities')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response != null ? Activity.fromSupabaseMap(response) : null;
    }, null);
  }
  
  @override
  Future<Activity?> getRunningActivity() async {
    final userId = UserService().currentUserId;
    if (userId == null) {
      debugPrint('⚠️ getRunningActivity: No authenticated user');
      return null;
    }
    
    return _safeCall(() async {
      // USER-SCOPED: Get running activity for current user only
      final response = await _supabase
          .from('activities')
          .select()
          .eq('user_id', userId)
          .eq('is_running', 1)
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
      return response != null ? Activity.fromSupabaseMap(response) : null;
    }, null);
  }
  
  @override
  Future<List<Activity>> getActivitiesForDate(DateTime date) async {
    final userId = UserService().currentUserId;
    if (userId == null) return <Activity>[];
    
    return _safeCall(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // USER-SCOPED: Filter by user_id
      final response = await _supabase
          .from('activities')
          .select()
          .eq('user_id', userId)
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String())
          .order('start_time');
      
      return response.map((m) => Activity.fromSupabaseMap(m)).toList();
    }, <Activity>[]);
  }
  
  @override
  Future<List<Activity>> getRunningActivitiesOlderThan(DateTime cutoff) async {
    final userId = UserService().currentUserId;
    if (userId == null) return <Activity>[];
    
    return _safeCall(() async {
      // USER-SCOPED: Filter by user_id
      final response = await _supabase
          .from('activities')
          .select()
          .eq('user_id', userId)
          .eq('is_running', 1)
          .lt('start_time', cutoff.toIso8601String());
      
      return response.map((m) => Activity.fromSupabaseMap(m)).toList();
    }, <Activity>[]);
  }
  
  @override
  Future<void> insertActivity(Activity activity) async {
    await _safeCall(() async {
      await _supabase.from('activities').upsert(activity.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> updateActivity(Activity activity) async {
    await _safeCall(() async {
      await _supabase.from('activities').upsert(activity.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> deleteActivity(String id) async {
    await _safeCall(() async {
      await _supabase.from('activities').delete().eq('id', id);
    }, null);
  }
  
  @override
  Future<Map<String, Duration>> getActivityDurationsForDate(DateTime date) async {
    final activities = await getActivitiesForDate(date);
    final Map<String, Duration> durations = {};
    for (final activity in activities) {
      final current = durations[activity.name] ?? Duration.zero;
      durations[activity.name] = current + activity.duration;
    }
    return durations;
  }

  // ==================== PAUSE LOGS ====================
  
  @override
  Future<List<PauseLog>> getPauseLogsForActivity(String activityId) async {
    return _safeCall(() async {
      final response = await _supabase
          .from('pause_logs')
          .select()
          .eq('activity_id', activityId)
          .order('pause_time');
      
      return response.map((m) => PauseLog.fromSupabaseMap(m)).toList();
    }, <PauseLog>[]);
  }
  
  @override
  Future<PauseLog?> getActivePauseLog(String activityId) async {
    return _safeCall(() async {
      final response = await _supabase
          .from('pause_logs')
          .select()
          .eq('activity_id', activityId)
          .isFilter('resume_time', null)
          .limit(1)
          .maybeSingle();
      
      return response != null ? PauseLog.fromSupabaseMap(response) : null;
    }, null);
  }
  
  @override
  Future<void> insertPauseLog(PauseLog log) async {
    await _safeCall(() async {
      await _supabase.from('pause_logs').upsert(log.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> updatePauseLog(PauseLog log) async {
    await _safeCall(() async {
      await _supabase.from('pause_logs').upsert(log.toSupabaseMap());
    }, null);
  }

  // ==================== MEMO ENTRIES ====================
  
  @override
  Future<List<MemoEntry>> getMemosForActivity(String activityId) async {
    return _safeCall(() async {
      final response = await _supabase
          .from('memo_entries')
          .select()
          .eq('activity_id', activityId)
          .order('timestamp');
      
      return response.map((m) => MemoEntry.fromSupabaseMap(m)).toList();
    }, <MemoEntry>[]);
  }
  
  @override
  Future<List<MemoEntry>> getAllMemos() async {
    final userId = UserService().currentUserId;
    if (userId == null) return <MemoEntry>[];
    
    return _safeCall(() async {
      final response = await _supabase
          .from('memo_entries')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);
      
      return response.map((m) => MemoEntry.fromSupabaseMap(m)).toList();
    }, <MemoEntry>[]);
  }
  
  @override
  Future<void> insertMemoEntry(MemoEntry memo) async {
    await _safeCall(() async {
      await _supabase.from('memo_entries').upsert(memo.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> updateMemoEntry(MemoEntry memo) async {
    await _safeCall(() async {
      await _supabase.from('memo_entries').upsert(memo.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> deleteMemoEntry(String id) async {
    await _safeCall(() async {
      await _supabase.from('memo_entries').delete().eq('id', id);
    }, null);
  }

  // ==================== GUIDED FLOW LOGS ====================
  
  @override
  Future<List<GuidedFlowLog>> getGuidedFlowLogsForDate(DateTime date) async {
    return _safeCall(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final response = await _supabase
          .from('guided_flow_logs')
          .select()
          .gte('triggered_at', startOfDay.toIso8601String())
          .lt('triggered_at', endOfDay.toIso8601String())
          .order('triggered_at');
      
      return response.map((m) => GuidedFlowLog.fromSupabaseMap(m)).toList();
    }, <GuidedFlowLog>[]);
  }
  
  @override
  Future<void> insertGuidedFlowLog(GuidedFlowLog log) async {
    await _safeCall(() async {
      await _supabase.from('guided_flow_logs').upsert(log.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> updateGuidedFlowLog(GuidedFlowLog log) async {
    await _safeCall(() async {
      await _supabase.from('guided_flow_logs').upsert(log.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> logMissedRitual(String flowId, String flowName, DateTime windowEnd) async {
    final log = GuidedFlowLog(
      flowId: flowId,
      flowName: flowName,
      triggeredAt: windowEnd,
      completedAt: windowEnd,
      stepsCompleted: 0,
      totalSteps: 0,
      wasMissed: true,
      userId: UserService().currentUserId,
    );
    await insertGuidedFlowLog(log);
  }
  
  @override
  Future<Set<String>> getCompletedFlowIdsForDate(DateTime date) async {
    final logs = await getGuidedFlowLogsForDate(date);
    return logs.where((l) => l.isCompleted).map((l) => l.flowId).toSet();
  }

  // ==================== GUIDED FLOW STATE ====================
  // Note: Flow state is stored in SharedPreferences, not Supabase
  // These are no-ops on Web as flow state is local config
  
  @override
  Future<void> updateGuidedFlowLastTriggered(String flowId, DateTime time) async {
    // No-op on Web - flow state is local preference
  }
  
  @override
  Future<void> updateGuidedFlowLastCompleted(String flowId, DateTime time) async {
    // No-op on Web - flow state is local preference
  }
  
  @override
  Future<DateTime?> getGuidedFlowLastTriggered(String flowId) async => null;
  
  @override
  Future<DateTime?> getGuidedFlowLastCompleted(String flowId) async => null;

  // ==================== USER FLOW TEMPLATES ====================
  // Note: Flow templates are seeded locally, not synced
  // On Web, we return the hardcoded predefined templates
  
  @override
  Future<List<UserFlowTemplate>> getAllUserFlowTemplates() async {
    // Return predefined templates for Web
    // In future, this could also come from Supabase
    return _getPredefinedTemplates();
  }
  
  @override
  Future<UserFlowTemplate?> getUserFlowTemplate(String id) async {
    final templates = await getAllUserFlowTemplates();
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
  
  @override
  Future<UserFlowTemplate?> getTemplateByWindowId(String windowId) async {
    final templates = await getAllUserFlowTemplates();
    try {
      return templates.firstWhere(
        (t) => t.linkedSafetyWindowId == windowId && t.isActive,
      );
    } catch (_) {
      return null;
    }
  }
  
  @override
  Future<void> insertUserFlowTemplate(UserFlowTemplate template) async {
    // No-op on Web - templates are predefined
  }
  
  @override
  Future<void> updateUserFlowTemplate(UserFlowTemplate template) async {
    // No-op on Web - templates are predefined
  }
  
  @override
  Future<void> deleteUserFlowTemplate(String id) async {
    // No-op on Web - templates are predefined
  }
  
  /// Get predefined flow templates for Web - matches PredefinedFlows exactly
  List<UserFlowTemplate> _getPredefinedTemplates() {
    return [
      // ==================== SUBUH ====================
      UserFlowTemplate(
        id: 'subuh_flow',
        name: 'Subuh Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_subuh',
        initialPrompt: 'Wake up and pray Subuh',
        steps: [
          UserFlowStep(
            id: 'subuh_prayer',
            flowTemplateId: 'subuh_flow',
            stepOrder: 0,
            ifCondition: 'time is in Subuh window',
            thenAction: 'pray Subuh',
            activityName: 'Sholat Subuh (guided)',
            description: 'Perform your Subuh prayer',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'subuh_movement',
            flowTemplateId: 'subuh_flow',
            stepOrder: 1,
            ifCondition: 'you are done praying',
            thenAction: 'move your body',
            activityName: 'Morning Movement (guided)',
            description: 'Light physical activity to wake up',
            estimatedMinutes: 5,
          ),
        ],
      ),
      // ==================== DZUHUR ====================
      UserFlowTemplate(
        id: 'dzuhur_flow',
        name: 'Dzuhur Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_dzuhur',
        initialPrompt: 'Time for Dzuhur prayer',
        steps: [
          UserFlowStep(
            id: 'dzuhur_prayer',
            flowTemplateId: 'dzuhur_flow',
            stepOrder: 0,
            ifCondition: 'time is in Dzuhur window',
            thenAction: 'pray Dzuhur',
            activityName: 'Sholat Dzuhur (guided)',
            description: 'Perform your Dzuhur prayer',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'dzuhur_lunch',
            flowTemplateId: 'dzuhur_flow',
            stepOrder: 1,
            ifCondition: 'you are done praying',
            thenAction: 'have lunch or take a nap',
            activityName: 'Lunch / Nap (guided)',
            description: 'Rest and recharge',
            estimatedMinutes: 45,
          ),
          UserFlowStep(
            id: 'dzuhur_return',
            flowTemplateId: 'dzuhur_flow',
            stepOrder: 2,
            ifCondition: 'you finished lunch/nap',
            thenAction: 'return to work',
            activityName: 'Return to Work (guided)',
            description: 'Transition back to work mode at 13:30',
            estimatedMinutes: 5,
          ),
        ],
      ),
      // ==================== ASHAR ====================
      UserFlowTemplate(
        id: 'ashar_flow',
        name: 'Ashar Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_ashar',
        initialPrompt: 'Time for Ashar prayer',
        steps: [
          UserFlowStep(
            id: 'ashar_prayer',
            flowTemplateId: 'ashar_flow',
            stepOrder: 0,
            ifCondition: 'time is in Ashar window',
            thenAction: 'pray Ashar',
            activityName: 'Sholat Ashar (guided)',
            description: 'Perform your Ashar prayer',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'ashar_return',
            flowTemplateId: 'ashar_flow',
            stepOrder: 1,
            ifCondition: 'you are done praying',
            thenAction: 'return to work',
            activityName: 'Return to Work (guided)',
            description: 'Continue your afternoon work session',
            estimatedMinutes: 5,
          ),
        ],
      ),
      // ==================== MAGRIB ====================
      UserFlowTemplate(
        id: 'magrib_flow',
        name: 'Magrib Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_magrib',
        initialPrompt: 'Time for Magrib prayer',
        steps: [
          UserFlowStep(
            id: 'magrib_prayer',
            flowTemplateId: 'magrib_flow',
            stepOrder: 0,
            ifCondition: 'time is in Magrib window',
            thenAction: 'pray Magrib',
            activityName: 'Sholat Magrib (guided)',
            description: 'Perform your Magrib prayer',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'magrib_dinner',
            flowTemplateId: 'magrib_flow',
            stepOrder: 1,
            ifCondition: 'you are done praying',
            thenAction: 'have dinner',
            activityName: 'Dinner (guided)',
            description: 'Evening meal time',
            estimatedMinutes: 30,
          ),
          UserFlowStep(
            id: 'magrib_quran',
            flowTemplateId: 'magrib_flow',
            stepOrder: 2,
            ifCondition: 'you finished dinner',
            thenAction: 'write 1 Al-Quran verse',
            activityName: 'Quran - One Verse (guided)',
            description: 'Manual handwriting / copying of one verse',
            estimatedMinutes: 15,
          ),
        ],
      ),
      // ==================== ISYA ====================
      UserFlowTemplate(
        id: 'isya_flow',
        name: 'Isya Routine',
        category: 'prayer',
        linkedSafetyWindowId: 'window_isya',
        initialPrompt: 'Time for Isya prayer',
        steps: [
          UserFlowStep(
            id: 'isya_prayer',
            flowTemplateId: 'isya_flow',
            stepOrder: 0,
            ifCondition: 'time is in Isya window',
            thenAction: 'pray Isya',
            activityName: 'Sholat Isya (guided)',
            description: 'Perform your Isya prayer',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'isya_skincare',
            flowTemplateId: 'isya_flow',
            stepOrder: 1,
            ifCondition: 'you are done praying',
            thenAction: 'do your skincare routine',
            activityName: 'Skincare Routine (guided)',
            description: 'Evening skincare',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'isya_planning',
            flowTemplateId: 'isya_flow',
            stepOrder: 2,
            ifCondition: 'you finished skincare',
            thenAction: 'set tasks for tomorrow',
            activityName: 'Tomorrow Planning (guided)',
            description: 'Small planning set for next day',
            estimatedMinutes: 10,
          ),
        ],
      ),
      // ==================== SLEEP ====================
      UserFlowTemplate(
        id: 'sleep_flow',
        name: 'Sleep Discipline',
        category: 'sleep',
        linkedSafetyWindowId: 'window_sleep',
        initialPrompt: 'Time to prepare for sleep',
        steps: [
          UserFlowStep(
            id: 'sleep_prepare',
            flowTemplateId: 'sleep_flow',
            stepOrder: 0,
            ifCondition: 'time is in Sleep window',
            thenAction: 'prepare for tomorrow',
            activityName: 'Prepare Tomorrow (guided)',
            description: 'Clear desk, layout items, mental unload',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'sleep_winddown',
            flowTemplateId: 'sleep_flow',
            stepOrder: 1,
            ifCondition: 'you prepared everything',
            thenAction: 'wind down',
            activityName: 'Wind-Down (guided)',
            description: 'Light reflection, calm your mind',
            estimatedMinutes: 10,
          ),
          UserFlowStep(
            id: 'sleep_sleep',
            flowTemplateId: 'sleep_flow',
            stepOrder: 2,
            ifCondition: 'you are calm',
            thenAction: 'go to sleep',
            activityName: 'Sleep (guided)',
            description: 'Time to rest',
            estimatedMinutes: 5,
          ),
        ],
      ),
      // ==================== DISTRACTION RECOVERY ====================
      UserFlowTemplate(
        id: 'distraction_recovery',
        name: 'Distraction Recovery',
        category: 'recovery',
        linkedSafetyWindowId: null,
        initialPrompt: "You were distracted. Let's get back on track.",
        steps: [
          UserFlowStep(
            id: 'recovery_recall',
            flowTemplateId: 'distraction_recovery',
            stepOrder: 0,
            ifCondition: 'you were distracted',
            thenAction: 'recall what you were doing',
            activityName: 'Focus Recovery (guided)',
            description: 'Take a moment to remember your previous task',
            estimatedMinutes: 2,
          ),
        ],
      ),
    ];
  }

  // ==================== AD-HOC TASKS ====================
  
  @override
  Future<List<AdHocTask>> getAllAdHocTasks() async {
    return _safeCall(() async {
      final response = await _supabase
          .from('adhoc_tasks')
          .select()
          .order('sort_order')
          .order('created_at', ascending: false);
      
      return response.map((m) => AdHocTask.fromSupabaseMap(m)).toList();
    }, <AdHocTask>[]);
  }
  
  @override
  Future<List<AdHocTask>> getPendingAdHocTasks() async {
    return _safeCall(() async {
      final response = await _supabase
          .from('adhoc_tasks')
          .select()
          .eq('execution_state', TaskExecutionState.pending.index)
          .order('sort_order')
          .order('created_at', ascending: false);
      
      return response.map((m) => AdHocTask.fromSupabaseMap(m)).toList();
    }, <AdHocTask>[]);
  }
  
  @override
  Future<List<AdHocTask>> getInProgressAdHocTasks() async {
    return _safeCall(() async {
      final response = await _supabase
          .from('adhoc_tasks')
          .select()
          .eq('execution_state', TaskExecutionState.inProgress.index);
      
      return response.map((m) => AdHocTask.fromSupabaseMap(m)).toList();
    }, <AdHocTask>[]);
  }
  
  @override
  Future<List<AdHocTask>> getCompletedAdHocTasks() async {
    return _safeCall(() async {
      final response = await _supabase
          .from('adhoc_tasks')
          .select()
          .eq('execution_state', TaskExecutionState.completed.index)
          .order('completed_at', ascending: false);
      
      return response.map((m) => AdHocTask.fromSupabaseMap(m)).toList();
    }, <AdHocTask>[]);
  }
  
  @override
  Future<void> insertAdHocTask(AdHocTask task) async {
    await _safeCall(() async {
      await _supabase.from('adhoc_tasks').upsert(task.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> updateAdHocTask(AdHocTask task) async {
    await _safeCall(() async {
      await _supabase.from('adhoc_tasks').upsert(task.toSupabaseMap());
    }, null);
  }
  
  @override
  Future<void> deleteAdHocTask(String id) async {
    await _safeCall(() async {
      await _supabase.from('adhoc_tasks').delete().eq('id', id);
    }, null);
  }
  
  @override
  Future<void> clearCompletedAdHocTasks() async {
    await _safeCall(() async {
      await _supabase
          .from('adhoc_tasks')
          .delete()
          .eq('execution_state', TaskExecutionState.completed.index);
    }, null);
  }

  // ==================== TIME SLOTS ====================
  // Time slots are local-only, not synced to Supabase
  
  @override
  Future<List<TimeSlot>> getTimeSlotsForDate(DateTime date) async => [];
  
  @override
  Future<void> insertTimeSlot(TimeSlot slot) async {}
  
  @override
  Future<void> updateTimeSlot(TimeSlot slot) async {}

  // ==================== UNLOGGED BLOCKS ====================
  // Unlogged blocks are local-only, not synced
  
  @override
  Future<List<UnloggedBlock>> getUnloggedBlocksForDate(DateTime date) async => [];
  
  @override
  Future<void> insertUnloggedBlock(UnloggedBlock block) async {}
  
  @override
  Future<void> deleteUnloggedBlock(String id) async {}
  
  @override
  Future<void> clearOldUnloggedBlocks() async {}

  // ==================== ENERGY CHECKS ====================
  
  @override
  Future<List<EnergyCheck>> getEnergyChecksForActivity(String activityId) async {
    return _safeCall(() async {
      final response = await _supabase
          .from('energy_checks')
          .select()
          .eq('activity_id', activityId)
          .order('recorded_at');
      return response.map((m) => EnergyCheck.fromMap(m)).toList();
    }, <EnergyCheck>[]);
  }
  
  @override
  Future<List<EnergyCheck>> getEnergyChecksForDate(DateTime date) async {
    final userId = UserService().currentUserId;
    if (userId == null) return <EnergyCheck>[];
    
    return _safeCall(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final response = await _supabase
          .from('energy_checks')
          .select()
          .eq('user_id', userId)
          .gte('recorded_at', startOfDay.toIso8601String())
          .lt('recorded_at', endOfDay.toIso8601String())
          .order('recorded_at');
      return response.map((m) => EnergyCheck.fromMap(m)).toList();
    }, <EnergyCheck>[]);
  }
  
  @override
  Future<EnergyCheck?> getLatestEnergyCheck() async {
    final userId = UserService().currentUserId;
    if (userId == null) return null;
    
    return _safeCall(() async {
      final response = await _supabase
          .from('energy_checks')
          .select()
          .eq('user_id', userId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response != null ? EnergyCheck.fromMap(response) : null;
    }, null);
  }
  
  @override
  Future<void> insertEnergyCheck(EnergyCheck check) async {
    await _safeCall(() async {
      final data = check.toSupabaseMap();
      data['user_id'] = UserService().currentUserId;
      await _supabase.from('energy_checks').upsert(data);
    }, null);
  }

  // ==================== SYNC SUPPORT ====================
  // No local sync queue on Web - everything goes directly to Supabase
  
  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems(String tableName) async => [];
  
  @override
  Future<void> markAsSynced(String tableName, String id) async {}
  
  @override
  Future<void> upsertFromSync(String tableName, Map<String, dynamic> item) async {
    // Direct insert to Supabase
    await _safeCall(() async {
      await _supabase.from(tableName).upsert(item);
    }, null);
  }

  // ==================== DIRECT CLOUD OPERATIONS ====================
  // These methods write directly to Supabase and read back the confirmed record.
  // This ensures the UI always shows what's actually in the database.
  
  /// Unique device identifier for this instance
  String? _deviceId;
  
  @override
  String get deviceId {
    _deviceId ??= 'web_${DateTime.now().millisecondsSinceEpoch}';
    return _deviceId!;
  }
  
  @override
  Future<Activity> insertActivityDirect(Activity activity) async {
    try {
      // Write to Supabase
      await _supabase.from('activities').upsert(activity.toSupabaseMap());
      
      // Read back the confirmed record
      final response = await _supabase
          .from('activities')
          .select()
          .eq('id', activity.id)
          .single();
      
      return Activity.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('❌ insertActivityDirect failed: $e');
      // Return the original activity on error (optimistic update)
      return activity;
    }
  }
  
  @override
  Future<Activity> updateActivityDirect(Activity activity) async {
    try {
      // Update in Supabase
      await _supabase.from('activities').upsert(activity.toSupabaseMap());
      
      // Read back the confirmed record
      final response = await _supabase
          .from('activities')
          .select()
          .eq('id', activity.id)
          .single();
      
      return Activity.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('❌ updateActivityDirect failed: $e');
      return activity;
    }
  }
  
  @override
  Future<PauseLog> insertPauseLogDirect(PauseLog log) async {
    try {
      await _supabase.from('pause_logs').upsert(log.toSupabaseMap());
      final response = await _supabase
          .from('pause_logs')
          .select()
          .eq('id', log.id)
          .single();
      return PauseLog.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('❌ insertPauseLogDirect failed: $e');
      return log;
    }
  }
  
  @override
  Future<PauseLog> updatePauseLogDirect(PauseLog log) async {
    try {
      await _supabase.from('pause_logs').upsert(log.toSupabaseMap());
      final response = await _supabase
          .from('pause_logs')
          .select()
          .eq('id', log.id)
          .single();
      return PauseLog.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('❌ updatePauseLogDirect failed: $e');
      return log;
    }
  }
  
  @override
  Future<MemoEntry> insertMemoEntryDirect(MemoEntry memo) async {
    try {
      await _supabase.from('memo_entries').upsert(memo.toSupabaseMap());
      final response = await _supabase
          .from('memo_entries')
          .select()
          .eq('id', memo.id)
          .single();
      return MemoEntry.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('❌ insertMemoEntryDirect failed: $e');
      return memo;
    }
  }
  
  @override
  Future<AdHocTask> insertAdHocTaskDirect(AdHocTask task) async {
    try {
      await _supabase.from('adhoc_tasks').upsert(task.toSupabaseMap());
      final response = await _supabase
          .from('adhoc_tasks')
          .select()
          .eq('id', task.id)
          .single();
      return AdHocTask.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('❌ insertAdHocTaskDirect failed: $e');
      return task;
    }
  }
  
  @override
  Future<AdHocTask> updateAdHocTaskDirect(AdHocTask task) async {
    try {
      await _supabase.from('adhoc_tasks').upsert(task.toSupabaseMap());
      final response = await _supabase
          .from('adhoc_tasks')
          .select()
          .eq('id', task.id)
          .single();
      return AdHocTask.fromSupabaseMap(response);
    } catch (e) {
      debugPrint('❌ updateAdHocTaskDirect failed: $e');
      return task;
    }
  }

  // ==================== REALTIME SUPPORT ====================
  // Subscribe to real-time changes from Supabase for cross-device sync
  
  @override
  Stream<Activity?> watchRunningActivity() {
    // Create a stream that listens to Supabase Realtime changes on activities table
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
