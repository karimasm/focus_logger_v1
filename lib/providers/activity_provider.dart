import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/data.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';
import '../services/idle_detection_service.dart';

/// Callback type for auto-log prompt
typedef AutoLogPromptCallback = Future<String?> Function(DateTime slotStart, DateTime slotEnd);

/// Provider for managing activity state and timer
/// 
/// SYNC ARCHITECTURE:
/// - Never overwrites running activity from sync
/// - Subscribes to realtime for cross-device updates
/// - Memos/sync events do NOT stop activities
class ActivityProvider extends ChangeNotifier {
  final DataRepository _repo = dataRepository;
  final SyncService _syncService = SyncService();
  
  Activity? _currentActivity;
  List<Activity> _todayActivities = [];
  List<TimeSlot> _todayTimeSlots = [];
  Timer? _timer;
  Timer? _autoLogTimer;
  DateTime _selectedDate = DateTime.now();
  
  // Auto-log prompt callback (set by UI)
  AutoLogPromptCallback? _autoLogPromptCallback;
  
  // Track unlogged blocks
  List<UnloggedBlock> _unloggedBlocks = [];
  
  // Realtime subscription
  StreamSubscription<Activity?>? _realtimeSubscription;
  
  // Getters
  Activity? get currentActivity => _currentActivity;
  List<Activity> get todayActivities => _todayActivities;
  List<TimeSlot> get todayTimeSlots => _todayTimeSlots;
  DateTime get selectedDate => _selectedDate;
  bool get hasRunningActivity => _currentActivity != null && _currentActivity!.isRunning;
  bool get isPaused => _currentActivity?.isPaused ?? false;
  List<UnloggedBlock> get unloggedBlocks => _unloggedBlocks;

  ActivityProvider() {
    _init();
  }
  
  /// Set the callback for auto-log prompts
  void setAutoLogPromptCallback(AutoLogPromptCallback callback) {
    _autoLogPromptCallback = callback;
  }
  
  /// FORCE REFRESH: For Sync Now - invalidates cache and forces server fetch
  /// This ensures ghost states are cleared even if realtime missed an update
  Future<void> forceRefreshRunningState() async {
    debugPrint('[SYNC_NOW] Force refreshing running state from server...');
    
    // Clear any local cache first
    final oldState = _currentActivity;
    _currentActivity = null;
    
    // Force server fetch
    await loadRunningActivity();
    await loadTodayData();
    
    if (oldState != null && _currentActivity == null) {
      debugPrint('[SYNC_NOW] Cleared ghost session: ${oldState.name}');
    }
  }


  Future<void> _init() async {
    // Sanitize any old activities with missing end_time
    await _sanitizeOrphanedActivities();
    
    await loadRunningActivity();
    await loadTodayData();
    await _loadUnloggedBlocks();
    _startTimers();
    
    // REALTIME: Subscribe to cross-device running activity updates
    _subscribeToRealtimeUpdates();
  }
  
  /// Subscribe to realtime running activity changes from other devices
  void _subscribeToRealtimeUpdates() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _repo.watchRunningActivity().listen(
      _handleRemoteActivityUpdate,
      onError: (e) => debugPrint('Realtime subscription error: $e'),
    );
  }
  
  /// Handle activity updates from other devices
  /// SERVER IS SINGLE SOURCE OF TRUTH
  /// If server says running → update local
  /// If server says none → CLEAR local ghost
  void _handleRemoteActivityUpdate(Activity? serverActivity) {
    debugPrint('[RUNNING_STATE] realtime_update server=${serverActivity?.name ?? "none"}');
    
    if (serverActivity != null && serverActivity.isRunning) {
      // Server has running activity → adopt it
      if (_currentActivity?.id != serverActivity.id) {
        debugPrint('[ACTION] adopting server running activity: ${serverActivity.name}');
        _currentActivity = serverActivity;
        notifyListeners();
      }
    } else {
      // SERVER SAYS NONE → CLEAR ANY LOCAL GHOST
      if (_currentActivity != null) {
        debugPrint('[ACTION] clearing local ghost session (server says none)');
        _currentActivity = null;
        notifyListeners();
      }
    }
  }
  
  /// TIMELINE SANITIZATION: Fix activities with missing end_time
  /// - If old (>24h) activity is marked as running but has no end_time: close it
  /// - Prevents negative duration display on timeline
  Future<void> _sanitizeOrphanedActivities() async {
    try {
      final orphaned = await _repo.getRunningActivitiesOlderThan(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      
      for (final activity in orphaned) {
        // Close orphaned activities with end_time = start_time + reasonable duration
        final endTime = activity.startTime.add(const Duration(hours: 1));
        final fixed = activity.copyWith(
          endTime: endTime,
          isRunning: false,
        );
        await _repo.updateActivity(fixed);
        debugPrint('Sanitized orphaned activity: ${activity.name}');
      }
    } catch (e) {
      debugPrint('Error sanitizing orphaned activities: $e');
    }
  }

  void _startTimers() {
    // UI timer - updates every second for stopwatch display
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (hasRunningActivity) {
        notifyListeners();
      }
    });

    // Auto-log timer - checks every minute for 30-minute intervals
    _startAutoLogTimer();
  }

  void _startAutoLogTimer() {
    // Calculate delay until next 30-minute mark
    final now = DateTime.now();
    final minutesToNext = 30 - (now.minute % 30);
    final initialDelay = Duration(
      minutes: minutesToNext,
      seconds: 60 - now.second,
    );

    Future.delayed(initialDelay, () {
      _handleAutoLogInterval();
      // Then run every 30 minutes
      _autoLogTimer = Timer.periodic(const Duration(minutes: 30), (_) {
        _handleAutoLogInterval();
      });
    });
  }
  
  /// Handle the 30-minute auto-log interval
  /// NEW BEHAVIOR: Prompt user instead of silently creating entries
  Future<void> _handleAutoLogInterval() async {
    // FIX: Use UTC for database storage
    final now = DateTime.now().toUtc();
    final slotEnd = DateTime.utc(now.year, now.month, now.day, now.hour, (now.minute ~/ 30) * 30);
    final slotStart = slotEnd.subtract(const Duration(minutes: 30));
    
    // If there's a running activity, just create the time slot with that activity
    if (hasRunningActivity && _currentActivity != null) {
      final timeSlot = TimeSlot(
        slotStart: slotStart,
        slotEnd: slotEnd,
        activityId: _currentActivity!.id,
        label: _currentActivity!.name,
      );
      await _repo.insertTimeSlot(timeSlot);
      await loadTodayData();
      return;
    }
    
    // No activity running - this is a potential unlogged block
    // Try to prompt user through callback
    if (_autoLogPromptCallback != null) {
      final activityName = await _autoLogPromptCallback!(slotStart, slotEnd);
      
      if (activityName != null && activityName.isNotEmpty) {
        // User provided an activity name
        final timeSlot = TimeSlot(
          slotStart: slotStart,
          slotEnd: slotEnd,
          label: activityName,
          isEdited: true,
        );
        await _repo.insertTimeSlot(timeSlot);
      } else {
        // User ignored or declined - mark as unlogged block
        await _createUnloggedBlock(slotStart, slotEnd);
      }
    } else {
      // No callback set - mark as unlogged block (don't create unlabeled entry)
      await _createUnloggedBlock(slotStart, slotEnd);
    }
    
    await loadTodayData();
    await _loadUnloggedBlocks();
  }
  
  /// Create an unlogged block instead of an unlabeled entry
  Future<void> _createUnloggedBlock(DateTime start, DateTime end) async {
    final block = UnloggedBlock(
      startTime: start,
      endTime: end,
    );
    await _repo.insertUnloggedBlock(block);
  }
  
  /// Load unlogged blocks for today
  Future<void> _loadUnloggedBlocks() async {
    _unloggedBlocks = await _repo.getUnloggedBlocksForDate(_selectedDate);
    notifyListeners();
  }
  
  /// Label an unlogged block (convert to time slot)
  Future<void> labelUnloggedBlock(String blockId, String label) async {
    final block = _unloggedBlocks.firstWhere((b) => b.id == blockId, orElse: () => throw Exception('Block not found'));
    
    // Create time slot with the label
    final timeSlot = TimeSlot(
      slotStart: block.startTime,
      slotEnd: block.endTime,
      label: label,
      isEdited: true,
    );
    await _repo.insertTimeSlot(timeSlot);
    
    // Remove the unlogged block
    await _repo.deleteUnloggedBlock(blockId);
    
    await loadTodayData();
    await _loadUnloggedBlocks();
  }

  /// Load running activity - SERVER IS SINGLE SOURCE OF TRUTH
  /// 
  /// GHOST STATE FIX:
  /// - Always query server first
  /// - If server says NONE → clear any local ghost
  /// - Never trust local cache over server
  Future<void> loadRunningActivity() async {
    debugPrint('[RUNNING_STATE] loading from server...');
    
    // Log current local state for debugging
    if (_currentActivity != null) {
      debugPrint('[RUNNING_STATE] local_cache=${_currentActivity!.id} (${_currentActivity!.name})');
    } else {
      debugPrint('[RUNNING_STATE] local_cache=none');
    }
    
    // ALWAYS query server first - server is single source of truth
    final serverActivity = await _syncService.getGlobalRunningActivity();
    
    if (serverActivity != null && serverActivity.isRunning) {
      debugPrint('[RUNNING_STATE] server_state=${serverActivity.id} (${serverActivity.name})');
      _currentActivity = serverActivity;
    } else {
      debugPrint('[RUNNING_STATE] server_state=none');
      
      // SERVER SAYS NONE → CLEAR ANY LOCAL GHOST
      if (_currentActivity != null) {
        debugPrint('[ACTION] clearing local ghost session: ${_currentActivity!.name}');
        _currentActivity = null;
      }
    }
    
    notifyListeners();
  }

  Future<void> loadTodayData() async {
    _todayActivities = await _repo.getActivitiesForDate(_selectedDate);
    _todayTimeSlots = await _repo.getTimeSlotsForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = date;
    await loadTodayData();
    await _loadUnloggedBlocks();
  }

  /// Start a new activity
  /// USER-SCOPED: Activity is owned by current user, not device
  /// CONSISTENCY RULE: Only one activity can be active at a time per user
  /// SYNC ARCHITECTURE: Uses direct write methods for immediate cloud persistence
  Future<void> startActivity(
    String name, {
    String category = 'Uncategorized',
    ActivitySource source = ActivitySource.manual,
    String? guidedFlowId,
    String? chainContext,
  }) async {
    // Stop any running activity first (ensures single activity at a time)
    if (hasRunningActivity) {
      await stopActivity();
    }

    // USER-SCOPED: Get current user ID
    final userId = UserService().currentUserId;
    
    // FIX: Store startTime in UTC to avoid timezone mismatch
    final activity = Activity(
      name: name,
      category: category,
      startTime: DateTime.now().toUtc(),
      isRunning: true,
      userId: userId, // USER-SCOPED: Set owner
      source: source,
      guidedFlowId: guidedFlowId,
      chainContext: chainContext,
    );

    // Use direct write method for immediate cloud persistence
    _currentActivity = await _repo.insertActivityDirect(activity);
    await loadTodayData();
    notifyListeners();
    
    // Notify idle detection service
    IdleDetectionService().onActivityStarted();
    
    // Trigger sync for activity start (backup sync)
    await _syncService.triggerSync(SyncEvent.activityStarted);
  }

  /// Stop the current activity
  /// SYNC ARCHITECTURE: Uses direct write methods for immediate cloud persistence
  Future<void> stopActivity() async {
    if (_currentActivity == null) return;

    // FIX: Use UTC for consistent timezone handling
    final nowUtc = DateTime.now().toUtc();
    
    // If paused, add remaining pause duration
    int totalPausedSeconds = _currentActivity!.pausedDurationSeconds;
    if (_currentActivity!.isPaused && _currentActivity!.pausedAt != null) {
      totalPausedSeconds += nowUtc.difference(_currentActivity!.pausedAt!.toUtc()).inSeconds;
      
      // Complete the active pause log
      final activePause = await _repo.getActivePauseLog(_currentActivity!.id);
      if (activePause != null) {
        await _repo.updatePauseLogDirect(activePause.copyWith(
          resumeTime: nowUtc,
          userId: UserService().currentUserId,
        ));
      }
    }

    final updated = _currentActivity!.copyWith(
      endTime: nowUtc,
      isRunning: false,
      isPaused: false,
      pausedDurationSeconds: totalPausedSeconds,
      pausedAt: null,
    );

    // Use direct write method for immediate cloud persistence
    await _repo.updateActivityDirect(updated);
    _currentActivity = null;
    await loadTodayData();
    notifyListeners();
    
    // Notify idle detection service
    IdleDetectionService().onActivityStopped();
    
    // Trigger sync for activity done (backup sync)
    await _syncService.triggerSync(SyncEvent.activityDone);
  }

  /// Pause the current activity
  /// SYNC ARCHITECTURE: Uses direct write methods for immediate cloud persistence
  Future<void> pauseActivity(PauseReason reason, {String? customReason}) async {
    if (_currentActivity == null || !_currentActivity!.isRunning || _currentActivity!.isPaused) {
      return;
    }

    // FIX: Use UTC for consistent timezone handling
    final now = DateTime.now().toUtc();
    
    // Create pause log with direct write
    final pauseLog = PauseLog(
      activityId: _currentActivity!.id,
      userId: UserService().currentUserId,
      pauseTime: now,
      reason: reason,
      customReason: customReason,
    );
    await _repo.insertPauseLogDirect(pauseLog);

    // Update activity state with direct write
    final updated = _currentActivity!.copyWith(
      isPaused: true,
      pausedAt: now,
    );
    _currentActivity = await _repo.updateActivityDirect(updated);
    notifyListeners();
    
    // Trigger sync for pause (backup sync)
    await _syncService.triggerSync(SyncEvent.paused);
  }

  /// Resume the current activity
  /// SYNC ARCHITECTURE: Uses direct write methods for immediate cloud persistence
  Future<void> resumeActivity() async {
    if (_currentActivity == null || !_currentActivity!.isPaused) {
      return;
    }

    // FIX: Use UTC for consistent timezone handling
    final now = DateTime.now().toUtc();
    
    // Calculate pause duration (both times should be in UTC)
    final pauseDuration = _currentActivity!.pausedAt != null
        ? now.difference(_currentActivity!.pausedAt!.toUtc()).inSeconds
        : 0;

    // Complete the active pause log with direct write
    final activePause = await _repo.getActivePauseLog(_currentActivity!.id);
    if (activePause != null) {
      await _repo.updatePauseLogDirect(activePause.copyWith(
        resumeTime: now,
        userId: UserService().currentUserId,
      ));
    }

    // Update activity state with direct write
    final updated = _currentActivity!.copyWith(
      isPaused: false,
      pausedAt: null,
      pausedDurationSeconds: _currentActivity!.pausedDurationSeconds + pauseDuration,
    );
    _currentActivity = await _repo.updateActivityDirect(updated);
    notifyListeners();
    
    // Trigger sync for resume (backup sync)
    await _syncService.triggerSync(SyncEvent.resumed);
  }

  /// Edit an activity
  Future<void> updateActivityDetails(
    String activityId, {
    String? name,
    String? category,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final activity = await _repo.getActivity(activityId);
    if (activity == null) return;

    final updated = activity.copyWith(
      name: name,
      category: category,
      startTime: startTime,
      endTime: endTime,
    );
    await _repo.updateActivity(updated);
    
    if (_currentActivity?.id == activityId) {
      _currentActivity = updated;
    }
    await loadTodayData();
    notifyListeners();
  }

  /// Get pause logs for an activity
  Future<List<PauseLog>> getPauseLogs(String activityId) async {
    return await _repo.getPauseLogsForActivity(activityId);
  }

  /// Get activity durations for the selected date
  Future<Map<String, Duration>> getActivityDurations() async {
    return await _repo.getActivityDurationsForDate(_selectedDate);
  }

  /// Edit a time slot
  Future<void> updateTimeSlotLabel(String slotId, String label) async {
    final slots = _todayTimeSlots.where((s) => s.id == slotId);
    if (slots.isEmpty) return;

    final slot = slots.first;
    final updated = slot.copyWith(label: label, isEdited: true);
    await _repo.updateTimeSlot(updated);
    await loadTodayData();
  }
  
  /// Called when app is resumed - sync and check for global running activity
  Future<void> onAppResumed() async {
    await loadRunningActivity();
    await loadTodayData();
    await _loadUnloggedBlocks();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoLogTimer?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
