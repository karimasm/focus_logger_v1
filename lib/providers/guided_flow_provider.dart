import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/data.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../services/flow_alarm_service.dart';
import '../services/user_service.dart';

/// Callback type for showing Haid check dialog
/// Returns true if user chose "Masih haid", false if "Sudah selesai"
typedef HaidCheckCallback = Future<bool> Function();

/// Flow execution status for tracking completion
enum FlowExecutionStatus {
  notStarted,   // Window opened but user never pressed ON IT
  inProgress,   // User pressed ON IT, flow is active
  completed,    // User pressed ON IT and finished all steps with DONE
  missed,       // Window ended without user pressing ON IT
  skipped,      // Skipped due to Haid Mode
}

/// Provider for managing IF-THEN guided flow state machine with safety windows
/// Now reads from UserFlowTemplate database (Flow Templates are the single source of truth)
/// 
/// CORRECTED COMPLETION RULES:
/// - A flow is only "Completed Today" if user pressed ON IT AND finished all steps with DONE
/// - If window passes without ON IT -> marked as "missed" (not completed)
/// - Late-open support: If user opens app DURING an active window, still show the flow
/// 
/// HAID MODE:
/// - When active, prayer and Qur'an flows are automatically skipped
/// - Not marked as missed or failed
class GuidedFlowProvider extends ChangeNotifier {
  final DataRepository _repo = dataRepository;
  final SyncService _syncService = SyncService();
  final FlowAlarmService _alarmService = FlowAlarmService.instance;
  
  // Flow state - now using UserFlowTemplate instead of GuidedFlow
  GuidedFlowState _state = GuidedFlowState.idle;
  UserFlowTemplate? _activeTemplate;
  int _currentStepIndex = 0;
  GuidedFlowLog? _currentFlowLog;
  Activity? _currentStepActivity;
  String? _previousStepId; // For chain context
  
  // Current safety window
  SafetyWindow? _currentWindow;
  
  // Track flow status: Only flows with ON IT + DONE are completed
  Map<String, FlowExecutionStatus> _flowStatusToday = {};
  
  // Cached templates from database
  List<UserFlowTemplate> _templates = [];
  
  // Timers
  Timer? _checkTimer;
  Timer? _activityTimer;
  DateTime? _stepStartTime;
  
  // Distraction recovery
  Activity? _previousActivityBeforeDistraction;
  bool _showingDistractionRecovery = false;
  
  // Haid Mode - will be loaded from storage in init
  HaidMode? _haidMode;
  
  // Callback for Haid check dialog - set by UI
  HaidCheckCallback? _haidCheckCallback;
  
  // Pending Haid check state
  bool _pendingHaidCheck = false;
  UserFlowTemplate? _pendingHaidCheckTemplate;
  SafetyWindow? _pendingHaidCheckWindow;
  
  // Getters
  GuidedFlowState get state => _state;
  UserFlowTemplate? get activeTemplate => _activeTemplate;
  int get currentStepIndex => _currentStepIndex;
  UserFlowStep? get currentStep => 
      _activeTemplate != null && _currentStepIndex < _activeTemplate!.steps.length
          ? _activeTemplate!.steps[_currentStepIndex]
          : null;
  bool get isFlowActive => _state != GuidedFlowState.idle;
  GuidedFlowLog? get currentFlowLog => _currentFlowLog;
  Activity? get currentStepActivity => _currentStepActivity;
  SafetyWindow? get currentWindow => _currentWindow;
  bool get showingDistractionRecovery => _showingDistractionRecovery;
  Activity? get previousActivityBeforeDistraction => _previousActivityBeforeDistraction;
  HaidMode? get haidMode => _haidMode;
  bool get isHaidModeActive => _haidMode?.isActive ?? false;
  bool get hasPendingHaidCheck => _pendingHaidCheck;
  UserFlowTemplate? get pendingHaidCheckTemplate => _pendingHaidCheckTemplate;
  
  /// Set the callback for Haid check dialog
  void setHaidCheckCallback(HaidCheckCallback callback) {
    _haidCheckCallback = callback;
  }
  
  /// Get elapsed time for current step
  Duration get currentStepElapsed {
    if (_stepStartTime == null) return Duration.zero;
    return DateTime.now().difference(_stepStartTime!);
  }
  
  /// Get formatted elapsed time
  String get formattedStepElapsed {
    final d = currentStepElapsed;
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Get time remaining in current safety window
  Duration? get windowTimeRemaining {
    if (_currentWindow == null) return null;
    return _currentWindow!.timeRemaining(DateTime.now());
  }

  GuidedFlowProvider() {
    _initFlowChecker();
  }

  /// Initialize timer to check for scheduled flows and safety windows
  void _initFlowChecker() {
    // Load templates, completed flows, and Haid Mode
    _loadTemplates();
    _loadFlowStatusToday();
    _loadHaidMode();
    
    // Check every minute for scheduled flows
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkSafetyWindows();
    });
    
    // Also check immediately on startup (with delay to allow seeding)
    Future.delayed(const Duration(seconds: 2), () {
      _checkSafetyWindows();
    });
  }

  Future<void> _loadTemplates() async {
    _templates = await _repo.getAllUserFlowTemplates();
    notifyListeners();
  }

  Future<void> _loadHaidMode() async {
    // Try to pull from Supabase first (for cross-device sync)
    final remoteHaidMode = await HaidModeService.pullFromSupabase();
    if (remoteHaidMode != null) {
      _haidMode = remoteHaidMode;
    } else {
      // Fallback to local storage
      _haidMode = await HaidModeService.load();
    }
    notifyListeners();
  }

  /// Activate Haid Mode
  Future<void> activateHaidMode() async {
    _haidMode = await HaidModeService.activate();
    // Trigger sync for Haid Mode change
    await _syncService.triggerSync(SyncEvent.haidModeChange);
    await HaidModeService.syncToSupabase(_haidMode!);
    notifyListeners();
  }

  /// Deactivate Haid Mode
  Future<void> deactivateHaidMode() async {
    _haidMode = await HaidModeService.deactivate();
    // Trigger sync for Haid Mode change
    await _syncService.triggerSync(SyncEvent.haidModeChange);
    await HaidModeService.syncToSupabase(_haidMode!);
    notifyListeners();
  }

  /// Mark Haid Mode prompt as shown today
  Future<void> markHaidPromptShown() async {
    if (_haidMode != null) {
      _haidMode = await HaidModeService.markPrompted(_haidMode!);
    }
    notifyListeners();
  }

  /// Check if we should prompt to check if still on period
  bool get shouldPromptHaidCheck => _haidMode?.shouldPromptCheck ?? false;
  
  /// Handle user response from Haid check dialog
  /// stillMenstruating = true means "Masih haid" was selected
  /// stillMenstruating = false means "Sudah selesai" was selected
  Future<void> handleHaidCheckResponse(bool stillMenstruating) async {
    final template = _pendingHaidCheckTemplate;
    final window = _pendingHaidCheckWindow;
    
    if (template == null) return;
    
    if (stillMenstruating) {
      // User selected "Masih haid" → Skip prayer steps only, continue with non-prayer steps
      debugPrint('Haid Mode: Filtering out prayer steps from ${template.name}');
      
      // Filter out prayer-related steps
      final nonPrayerSteps = template.steps.where((step) {
        final stepName = step.activityName.toLowerCase();
        const prayerKeywords = ['sholat', 'salat', 'prayer', 'pray', 'quran', 'dzikir'];
        return !prayerKeywords.any((kw) => stepName.contains(kw));
      }).toList();
      
      if (nonPrayerSteps.isEmpty) {
        // All steps are prayer-related, skip entire flow
        await _logSkippedDueToHaid(template);
        _flowStatusToday[template.id] = FlowExecutionStatus.skipped;
        debugPrint('Flow ${template.name} fully skipped (all steps are prayer)');
      } else {
        // Create modified template with only non-prayer steps
        final modifiedTemplate = UserFlowTemplate(
          id: template.id,
          name: '${template.name} (Haid Mode)',
          category: template.category,
          linkedSafetyWindowId: template.linkedSafetyWindowId,
          initialPrompt: 'Skip prayer, continue with other activities',
          steps: nonPrayerSteps,
          isActive: template.isActive,
          createdAt: template.createdAt,
          updatedAt: template.updatedAt,
        );
        
        // Trigger the modified flow starting from first non-prayer step
        if (window != null) {
          _currentWindow = window;
        }
        await triggerTemplate(modifiedTemplate);
        debugPrint('Flow ${template.name} triggered with ${nonPrayerSteps.length} non-prayer steps');
      }
    } else {
      // User selected "Sudah selesai" → Deactivate Haid Mode, continue normal flow
      await deactivateHaidMode();
      
      // Now trigger the prayer flow normally
      if (window != null) {
        _currentWindow = window;
        await _alarmService.triggerFlowAlarm(window);
        await triggerTemplate(template);
      }
    }
    
    notifyListeners();
  }
  
  /// Log a flow as skipped due to Haid Mode
  Future<void> _logSkippedDueToHaid(UserFlowTemplate template) async {
    final now = DateTime.now();
    
    // Create a log entry with wasSkippedHaid = true
    final log = GuidedFlowLog(
      flowId: template.id,
      flowName: template.name,
      triggeredAt: now,
      completedAt: now,
      stepsCompleted: 0,
      totalSteps: template.steps.length,
      wasSkippedHaid: true,
      userId: UserService().currentUserId,
    );
    
    await _repo.insertGuidedFlowLog(log);
    await _syncService.triggerSync(SyncEvent.activityDone);
  }

  /// Load flow execution status for today
  /// Only considers flows where user pressed ON IT and completed as "completed"
  Future<void> _loadFlowStatusToday() async {
    final logs = await _repo.getGuidedFlowLogsForDate(DateTime.now());
    _flowStatusToday = {};
    
    for (final log in logs) {
      if (log.isSkippedDueToHaid) {
        // Flow was skipped due to Haid Mode
        _flowStatusToday[log.flowId] = FlowExecutionStatus.skipped;
      } else if (log.wasMissed) {
        _flowStatusToday[log.flowId] = FlowExecutionStatus.missed;
      } else if (log.isCompleted) {
        // CORRECTED: Only mark as completed if user went through the flow
        // isCompleted checks stepsCompleted >= totalSteps && !wasAbandoned && !wasMissed && !wasSkippedHaid
        _flowStatusToday[log.flowId] = FlowExecutionStatus.completed;
      } else if (log.stepsCompleted > 0) {
        // User started (pressed ON IT) but didn't finish
        _flowStatusToday[log.flowId] = FlowExecutionStatus.inProgress;
      }
    }
    notifyListeners();
  }
  
  /// Called when app is opened or resumed
  /// LATE-OPEN SUPPORT: Check if we're in a flow window and should show the flow
  Future<void> onAppResumed() async {
    if (_state != GuidedFlowState.idle) return; // Already in a flow
    
    await _loadTemplates();
    await _loadFlowStatusToday();
    await _loadHaidMode();
    await _checkSafetyWindows(forceCheck: true);
  }

  /// Check if any safety windows are active
  /// LATE-OPEN SUPPORT: If app is opened during a window, show the flow even if late
  /// HAID MODE: Skip prayer flows if Haid Mode is active
  Future<void> _checkSafetyWindows({bool forceCheck = false}) async {
    if (_state != GuidedFlowState.idle) return;
    
    // Reload templates to get latest edits
    await _loadTemplates();
    
    final now = DateTime.now();
    
    // Check for active window
    final activeWindow = PredefinedSafetyWindows.getCurrentWindow(now);
    
    if (activeWindow != null) {
      // We're currently in a window
      final template = await _repo.getTemplateByWindowId(activeWindow.id);
      
      if (template != null) {
        // HAID MODE CHECK: Show dialog to confirm if still menstruating
        if (_haidMode?.shouldSkipCategory(template.category) ?? false) {
          debugPrint('Prayer window active with Haid Mode - requesting confirmation');
          
          // Set pending check state for UI to handle
          _pendingHaidCheck = true;
          _pendingHaidCheckTemplate = template;
          _pendingHaidCheckWindow = activeWindow;
          
          // If callback is set, use it; otherwise auto-skip
          if (_haidCheckCallback != null) {
            final stillMenstruating = await _haidCheckCallback!();
            await handleHaidCheckResponse(stillMenstruating);
          } else {
            // No callback, auto-skip
            await _logSkippedDueToHaid(template);
            _flowStatusToday[template.id] = FlowExecutionStatus.skipped;
          }
          
          _pendingHaidCheck = false;
          _pendingHaidCheckTemplate = null;
          _pendingHaidCheckWindow = null;
          notifyListeners();
          return;
        }
        
        final status = _flowStatusToday[template.id];
        
        // LATE-OPEN SUPPORT: Show flow if:
        // 1. Flow hasn't been completed today (user pressed ON IT + DONE)
        // 2. Flow hasn't been marked as missed yet
        // 3. Flow isn't already in progress
        // 4. Flow isn't skipped due to Haid Mode
        if (status != FlowExecutionStatus.completed && 
            status != FlowExecutionStatus.missed &&
            status != FlowExecutionStatus.inProgress &&
            status != FlowExecutionStatus.skipped) {
          // Window is active and flow not completed/missed - show it
          _currentWindow = activeWindow;
          
          // ALARM BEHAVIOR: Trigger alarm when window begins
          await _alarmService.triggerFlowAlarm(activeWindow);
          
          await triggerTemplate(template);
        }
      }
    } else {
      _currentWindow = null;
    }
    
    // Check for missed windows (windows that have ended without ON IT)
    await _checkForMissedWindows(now);
    
    notifyListeners();
  }
  
  /// Check for windows that have ended without the user engaging
  Future<void> _checkForMissedWindows(DateTime now) async {
    for (final window in PredefinedSafetyWindows.all) {
      if (window.hasPassed(now)) {
        final template = await _repo.getTemplateByWindowId(window.id);
        if (template != null) {
          // HAID MODE: Don't mark as missed if skipped due to period
          if (_haidMode?.shouldSkipCategory(template.category) ?? false) {
            continue;
          }
          
          final status = _flowStatusToday[template.id];
          
          // CORRECTED: Only mark as missed if:
          // 1. Not already completed (user pressed ON IT + DONE)
          // 2. Not already marked as missed
          // 3. User never pressed ON IT (notStarted or null)
          if (status == null || status == FlowExecutionStatus.notStarted) {
            await _logMissedRitual(window, template);
          }
        }
      }
    }
  }

  Future<void> _logMissedRitual(SafetyWindow window, UserFlowTemplate template) async {
    // Check if already logged as missed today
    final existingLogs = await _repo.getGuidedFlowLogsForDate(DateTime.now());
    final alreadyLogged = existingLogs.any((log) => log.flowId == template.id && log.wasMissed);
    
    if (!alreadyLogged) {
      await _repo.logMissedRitual(
        template.id,
        template.name,
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 
                 window.endHour, window.endMinute),
      );
      _flowStatusToday[template.id] = FlowExecutionStatus.missed;
      
      // Sync the missed ritual
      await _syncService.triggerSync(SyncEvent.activityDone);
    }
  }

  /// Trigger a flow template
  Future<void> triggerTemplate(UserFlowTemplate template) async {
    if (_state != GuidedFlowState.idle) {
      debugPrint('Cannot trigger flow: another flow is active');
      return;
    }

    _activeTemplate = template;
    _currentStepIndex = 0;
    _previousStepId = null;
    _state = GuidedFlowState.waiting;
    
    // Mark as notStarted (waiting for ON IT)
    _flowStatusToday[template.id] = FlowExecutionStatus.notStarted;
    
    // Create flow log (but NOT marked as completed yet)
    _currentFlowLog = GuidedFlowLog(
      flowId: template.id,
      flowName: template.name,
      triggeredAt: DateTime.now().toUtc(),  // FIX: Use UTC
      totalSteps: template.steps.length,
      stepsCompleted: 0, // 0 until user presses ON IT and completes steps
      userId: UserService().currentUserId,
    );
    
    // Save flow log to database
    await _repo.insertGuidedFlowLog(_currentFlowLog!);
    
    // Update last triggered time
    await _repo.updateGuidedFlowLastTriggered(template.id, DateTime.now().toUtc());  // FIX: Use UTC
    
    notifyListeners();
  }

  /// Trigger distraction recovery flow
  Future<void> triggerDistractionRecovery(Activity previousActivity) async {
    _previousActivityBeforeDistraction = previousActivity;
    _showingDistractionRecovery = true;
    // Look for distraction recovery template
    final template = await _repo.getTemplateByWindowId('');
    if (template == null) {
      // Fallback: create a simple recovery prompt
      debugPrint('No distraction recovery template found');
      return;
    }
    await triggerTemplate(template);
  }

  /// User tapped "ON IT" - start the current step
  /// This is the key action that starts tracking completion
  /// ALARM: Stops the alarm when user acknowledges
  Future<void> startCurrentStep() async {
    if (_state != GuidedFlowState.waiting || currentStep == null) return;
    
    // FIX: Use UTC for consistent timezone handling
    final now = DateTime.now().toUtc();
    _stepStartTime = now;
    _state = GuidedFlowState.inProgress;
    
    // Mark flow as in progress (user engaged)
    _flowStatusToday[_activeTemplate!.id] = FlowExecutionStatus.inProgress;
    
    // ALARM: Stop the alarm - user acknowledged
    if (_currentWindow != null) {
      await _alarmService.acknowledgeWindow(_currentWindow!.id);
    }
    
    // Create activity for this step with chain context
    final activity = Activity(
      name: currentStep!.activityName,
      category: _activeTemplate!.category,
      startTime: now, // REAL timestamp when user tapped (UTC)
      isRunning: true,
      source: ActivitySource.guided,
      guidedFlowId: _activeTemplate!.id,
      chainContext: _previousStepId,
    );
    
    await _repo.insertActivity(activity);
    _currentStepActivity = activity;
    
    // Trigger sync for activity start
    await _syncService.triggerSync(SyncEvent.activityStarted);
    
    // Start timer for UI updates
    _activityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    
    notifyListeners();
  }

  /// User tapped "DONE" - complete the current step
  Future<void> completeCurrentStep() async {
    if (_state != GuidedFlowState.inProgress || _currentStepActivity == null) {
      return;
    }
    
    // FIX: Use UTC for consistent timezone handling
    final now = DateTime.now().toUtc();
    
    // Stop the activity
    final completedActivity = _currentStepActivity!.copyWith(
      endTime: now,
      isRunning: false,
    );
    await _repo.updateActivity(completedActivity);
    
    // Trigger sync for activity done
    await _syncService.triggerSync(SyncEvent.activityDone);
    
    // Store this step ID for chain context
    _previousStepId = currentStep!.id;
    
    // Cancel timer
    _activityTimer?.cancel();
    _activityTimer = null;
    
    // Update flow log
    _currentFlowLog = _currentFlowLog!.copyWith(
      stepsCompleted: _currentStepIndex + 1,
    );
    await _repo.updateGuidedFlowLog(_currentFlowLog!);
    
    // Move to next step or complete flow
    _currentStepIndex++;
    _currentStepActivity = null;
    _stepStartTime = null;
    
    if (_currentStepIndex >= _activeTemplate!.steps.length) {
      // Flow completed - user pressed ON IT and finished all steps with DONE
      await _completeFlow();
    } else {
      // More steps remaining, show next step prompt
      _state = GuidedFlowState.waiting;
      notifyListeners();
    }
  }

  /// Complete the entire flow
  /// CORRECTED: This is only called when user pressed ON IT AND completed all steps
  Future<void> _completeFlow() async {
    // FIX: Use UTC for consistent timezone handling
    final now = DateTime.now().toUtc();
    
    _currentFlowLog = _currentFlowLog!.copyWith(
      completedAt: now,
    );
    await _repo.updateGuidedFlowLog(_currentFlowLog!);
    
    // Update last completed time
    await _repo.updateGuidedFlowLastCompleted(_activeTemplate!.id, now);
    
    // CORRECTED: Mark as completed (user went through the entire flow)
    _flowStatusToday[_activeTemplate!.id] = FlowExecutionStatus.completed;
    
    // Handle distraction recovery completion
    if (_showingDistractionRecovery) {
      _showingDistractionRecovery = false;
      _previousActivityBeforeDistraction = null;
    }
    
    _resetFlowState();
    notifyListeners();
  }

  /// Reset flow state to idle
  void _resetFlowState() {
    _state = GuidedFlowState.idle;
    _activeTemplate = null;
    _currentStepIndex = 0;
    _currentFlowLog = null;
    _currentStepActivity = null;
    _stepStartTime = null;
    _previousStepId = null;
    _activityTimer?.cancel();
    _activityTimer = null;
  }

  /// Get all available flow templates from database
  List<UserFlowTemplate> get availableTemplates => _templates;
  
  /// Get enforced templates (linked to safety windows)
  List<UserFlowTemplate> get enforcedTemplates => 
      _templates.where((t) => t.linkedSafetyWindowId != null && t.linkedSafetyWindowId!.isNotEmpty).toList();

  /// Get all safety windows (still predefined for time enforcement)
  List<SafetyWindow> get safetyWindows => PredefinedSafetyWindows.all;

  /// Check if a flow template is TRULY completed today
  /// CORRECTED: Only returns true if user pressed ON IT and finished all steps
  bool isFlowCompletedToday(String templateId) {
    final status = _flowStatusToday[templateId];
    return status == FlowExecutionStatus.completed;
  }
  
  /// Check if a flow was missed today
  bool isFlowMissedToday(String templateId) {
    final status = _flowStatusToday[templateId];
    return status == FlowExecutionStatus.missed;
  }
  
  /// Check if a flow was skipped today (Haid Mode)
  bool isFlowSkippedToday(String templateId) {
    final status = _flowStatusToday[templateId];
    return status == FlowExecutionStatus.skipped;
  }
  
  /// Get the execution status of a flow for today
  FlowExecutionStatus? getFlowStatusToday(String templateId) {
    return _flowStatusToday[templateId];
  }

  /// Get flow logs for a specific date
  Future<List<GuidedFlowLog>> getFlowLogsForDate(DateTime date) async {
    return await _repo.getGuidedFlowLogsForDate(date);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _activityTimer?.cancel();
    super.dispose();
  }
}
