import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/data.dart';
import '../models/models.dart';
import '../services/flow_template_seeder.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';

/// Provider for managing ad-hoc tasks and user flow templates
/// This replaces the simple TaskProvider with a more robust system
class FlowActionProvider extends ChangeNotifier {
  final DataRepository _repo = dataRepository;
  final FlowTemplateSeeder _seeder = FlowTemplateSeeder();
  final SyncService _syncService = SyncService();
  
  // Ad-hoc tasks
  List<AdHocTask> _pendingTasks = [];
  List<AdHocTask> _inProgressTasks = [];
  List<AdHocTask> _completedTasks = [];
  
  // User flow templates
  List<UserFlowTemplate> _flowTemplates = [];
  
  // Timer for updating in-progress tasks
  Timer? _taskTimer;
  
  // Getters
  List<AdHocTask> get pendingTasks => _pendingTasks;
  List<AdHocTask> get inProgressTasks => _inProgressTasks;
  List<AdHocTask> get completedTasks => _completedTasks;
  List<UserFlowTemplate> get flowTemplates => _flowTemplates;
  
  /// Get the currently active (running, not paused) adhoc task
  AdHocTask? get activeAdhocTask => _inProgressTasks.isNotEmpty && !_inProgressTasks.first.isPaused
      ? _inProgressTasks.first
      : null;
  
  /// Check if there's an adhoc task in progress (running or paused)
  bool get hasAdhocInProgress => _inProgressTasks.isNotEmpty;
  
  /// Check if the active adhoc task is paused
  bool get isAdhocPaused => _inProgressTasks.isNotEmpty && _inProgressTasks.first.isPaused;
  
  /// Get only templates linked to safety windows (enforced routines)
  List<UserFlowTemplate> get enforcedFlows => 
      _flowTemplates.where((t) => t.linkedSafetyWindowId != null && t.linkedSafetyWindowId!.isNotEmpty).toList();
  
  /// Get custom flows (not linked to safety windows)
  List<UserFlowTemplate> get customFlows =>
      _flowTemplates.where((t) => t.linkedSafetyWindowId == null || t.linkedSafetyWindowId!.isEmpty).toList();
  
  FlowActionProvider() {
    _init();
  }
  
  Future<void> _init() async {
    // Seeding now happens in main.dart via FlowSeederService
    await loadAdHocTasks();
    await loadFlowTemplates();
    _startTaskTimer();
  }
  
  void _startTaskTimer() {
    _taskTimer?.cancel();
    _taskTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_inProgressTasks.isNotEmpty) {
        // Check for alarm triggers
        _checkAdhocAlarms();
        notifyListeners();
      }
    });
  }
  
  /// Check if any adhoc task alarm should trigger
  /// Note: Just for notifyListeners - actual alarm display is handled by UI
  void _checkAdhocAlarms() {
    // Just trigger UI update, don't log every second
    // The actual alarm handling is done in home_screen._checkTodoAlarm()
  }
  
  /// Get adhoc task that needs alarm reminder shown
  AdHocTask? get adhocNeedingAlarmReminder {
    final now = DateTime.now();
    for (final task in _inProgressTasks) {
      if (task.alarmTime != null && 
          !task.alarmTriggered && 
          now.isAfter(task.alarmTime!)) {
        return task;
      }
    }
    return null;
  }
  
  /// Mark alarm as triggered for a task
  Future<void> markAlarmTriggered(String taskId) async {
    final taskIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = _inProgressTasks[taskIndex];
    final userId = UserService().currentUserId;
    final updatedTask = task.copyWith(
      alarmTriggered: true,
      userId: task.userId ?? userId,
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
  }
  
  // ==================== AD-HOC TASKS ====================
  
  Future<void> loadAdHocTasks() async {
    _pendingTasks = await _repo.getPendingAdHocTasks();
    _inProgressTasks = await _repo.getInProgressAdHocTasks();
    _completedTasks = await _repo.getCompletedAdHocTasks();
    notifyListeners();
  }
  
  /// Create a new ad-hoc task
  Future<void> createTask(String title, {String? description, DateTime? alarmTime}) async {
    final task = AdHocTask(
      title: title,
      description: description,
      sortOrder: _pendingTasks.length,
      userId: UserService().currentUserId,
      alarmTime: alarmTime?.toUtc(),
      alarmTriggered: false,
    );
    await _repo.insertAdHocTask(task);
    await loadAdHocTasks();
    
    // Trigger sync for ad-hoc task creation
    await _syncService.triggerSync(SyncEvent.adHocCreated);
  }
  
  // Track the activity that was paused when starting an ad-hoc task
  Activity? _pausedActivityForTask;
  String? _pausedActivityTaskId;
  
  /// Get the activity that was paused when starting the current ad-hoc task
  Activity? get pausedActivityForTask => _pausedActivityForTask;
  
  /// Clear the paused activity reference (after user handles the dialog)
  void clearPausedActivityReference() {
    _pausedActivityForTask = null;
    _pausedActivityTaskId = null;
    notifyListeners();
  }
  
  /// User pressed "ON IT" - start executing task
  /// This also creates an Activity entry for timeline tracking
  /// If there's a running activity, it will be paused first (single-activity mode)
  Future<Activity?> startTask(String taskId, {Activity? currentRunningActivity}) async {
    final taskIndex = _pendingTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return null;
    
    final task = _pendingTasks[taskIndex];
    // FIX: Use UTC for consistent timezone handling
    final now = DateTime.now().toUtc();
    
    // Store reference to the activity we're about to pause
    if (currentRunningActivity != null && currentRunningActivity.isRunning) {
      _pausedActivityForTask = currentRunningActivity;
      _pausedActivityTaskId = taskId;
      
      // The actual pausing is done by the caller (ActivityProvider)
      // with the pause reason: "Doing Ad-Hoc – <task name>"
    }
    
    // FIX: Get current user ID for database constraint
    final userId = UserService().currentUserId;
    
    // Create an activity for this task
    final activity = Activity(
      name: task.title,
      category: 'Ad-hoc Task',
      startTime: now,
      isRunning: true,
      source: ActivitySource.manual,
      userId: userId,  // FIX: Add user_id
    );
    await _repo.insertActivity(activity);
    
    // Update task state with user_id (ensure userId is set for legacy tasks)
    final updatedTask = task.copyWith(
      executionState: TaskExecutionState.inProgress,
      startedAt: now,
      linkedActivityId: activity.id,
      userId: task.userId ?? userId,  // FIX: Ensure userId is set
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
    
    // Trigger sync for activity start
    await _syncService.triggerSync(SyncEvent.activityStarted);
    
    return activity;
  }
  
  /// User pressed "DONE" - complete the task
  /// This also stops the linked Activity
  /// Returns the previously paused activity (if any) for resume confirmation
  Future<Activity?> completeTask(String taskId) async {
    final taskIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return null;
    
    final task = _inProgressTasks[taskIndex];
    // FIX: Use UTC for consistent timezone handling
    final now = DateTime.now().toUtc();
    // FIX: Get userId for database constraint
    final userId = UserService().currentUserId;
    
    // Stop the linked activity if it exists
    if (task.linkedActivityId != null) {
      final activity = await _repo.getActivity(task.linkedActivityId!);
      if (activity != null && activity.isRunning) {
        final updated = activity.copyWith(
          endTime: now,
          isRunning: false,
        );
        await _repo.updateActivity(updated);
      }
    }
    
    // Update task state with userId
    final updatedTask = task.copyWith(
      executionState: TaskExecutionState.completed,
      completedAt: now,
      userId: task.userId ?? userId,  // FIX: Ensure userId is set
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
    
    // Trigger sync for ad-hoc task completion
    await _syncService.triggerSync(SyncEvent.adHocCompleted);
    
    // Return the previously paused activity for resume confirmation
    final pausedActivity = _pausedActivityForTask;
    
    // Clear the reference (caller is now responsible for handling)
    // Don't clear here - let the UI clear it after handling the dialog
    
    return pausedActivity;
  }
  
  /// Cancel an in-progress task (move back to pending)
  Future<void> cancelTask(String taskId) async {
    final taskIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = _inProgressTasks[taskIndex];
    
    // Stop the linked activity if running
    if (task.linkedActivityId != null) {
      final activity = await _repo.getActivity(task.linkedActivityId!);
      if (activity != null && activity.isRunning) {
        final updated = activity.copyWith(
          endTime: DateTime.now().toUtc(),
          isRunning: false,
        );
        await _repo.updateActivity(updated);
      }
    }
    
    // FIX: Get userId for database constraint
    final userId = UserService().currentUserId;
    
    // Reset task to pending (but keep the created_at for age tracking)
    final updatedTask = task.copyWith(
      executionState: TaskExecutionState.pending,
      startedAt: null,
      linkedActivityId: null,
      userId: task.userId ?? userId,  // FIX: Ensure userId is set
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
  }
  
  /// Delete a task completely
  Future<void> deleteTask(String taskId) async {
    await _repo.deleteAdHocTask(taskId);
    await loadAdHocTasks();
  }
  
  /// Clear all completed tasks
  Future<void> clearCompletedTasks() async {
    await _repo.clearCompletedAdHocTasks();
    await loadAdHocTasks();
  }
  
  /// Reorder pending tasks
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final task = _pendingTasks.removeAt(oldIndex);
    _pendingTasks.insert(newIndex, task);
    
    final userId = UserService().currentUserId;
    for (int i = 0; i < _pendingTasks.length; i++) {
      final updated = _pendingTasks[i].copyWith(
        sortOrder: i,
        userId: _pendingTasks[i].userId ?? userId,  // FIX: Ensure userId
      );
      await _repo.updateAdHocTask(updated);
    }
    notifyListeners();
  }
  
  /// Pause an in-progress adhoc task
  Future<void> pauseTask(String taskId, {String? reason}) async {
    final taskIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = _inProgressTasks[taskIndex];
    if (task.isPaused) return; // Already paused
    
    final now = DateTime.now().toUtc();
    final userId = UserService().currentUserId;
    
    // Also pause the linked activity if running
    if (task.linkedActivityId != null) {
      final activity = await _repo.getActivity(task.linkedActivityId!);
      if (activity != null && activity.isRunning && !activity.isPaused) {
        final updated = activity.copyWith(
          isPaused: true,
          pausedAt: now,
        );
        await _repo.updateActivity(updated);
      }
    }
    
    final updatedTask = task.copyWith(
      isPaused: true,
      pausedAt: now,
      userId: task.userId ?? userId,
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
    
    await _syncService.triggerSync(SyncEvent.paused);
  }
  
  /// Resume a paused adhoc task
  Future<void> resumeTask(String taskId) async {
    final taskIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = _inProgressTasks[taskIndex];
    if (!task.isPaused) return; // Not paused
    
    final now = DateTime.now().toUtc();
    final userId = UserService().currentUserId;
    
    // Calculate pause duration
    int additionalPausedSeconds = 0;
    if (task.pausedAt != null) {
      additionalPausedSeconds = now.difference(task.pausedAt!.toUtc()).inSeconds;
    }
    
    // Also resume the linked activity
    if (task.linkedActivityId != null) {
      final activity = await _repo.getActivity(task.linkedActivityId!);
      if (activity != null && activity.isPaused) {
        final activityPauseDuration = activity.pausedAt != null
            ? now.difference(activity.pausedAt!.toUtc()).inSeconds
            : 0;
        final updated = activity.copyWith(
          isPaused: false,
          pausedAt: null,
          pausedDurationSeconds: activity.pausedDurationSeconds + activityPauseDuration,
        );
        await _repo.updateActivity(updated);
      }
    }
    
    final updatedTask = task.copyWith(
      isPaused: false,
      pausedAt: null,
      pausedDurationSeconds: task.pausedDurationSeconds + additionalPausedSeconds,
      userId: task.userId ?? userId,
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
    
    await _syncService.triggerSync(SyncEvent.resumed);
  }
  
  /// Stop an in-progress adhoc task (without marking complete)
  Future<void> stopTask(String taskId) async {
    final taskIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    
    final task = _inProgressTasks[taskIndex];
    final now = DateTime.now().toUtc();
    final userId = UserService().currentUserId;
    
    // Calculate final paused duration if currently paused
    int finalPausedSeconds = task.pausedDurationSeconds;
    if (task.isPaused && task.pausedAt != null) {
      finalPausedSeconds += now.difference(task.pausedAt!.toUtc()).inSeconds;
    }
    
    // Stop the linked activity if running
    if (task.linkedActivityId != null) {
      final activity = await _repo.getActivity(task.linkedActivityId!);
      if (activity != null && activity.isRunning) {
        final updated = activity.copyWith(
          endTime: now,
          isRunning: false,
          isPaused: false,
        );
        await _repo.updateActivity(updated);
      }
    }
    
    // Mark task as completed (stopped = done for adhoc)
    final updatedTask = task.copyWith(
      executionState: TaskExecutionState.completed,
      completedAt: now,
      isPaused: false,
      pausedAt: null,
      pausedDurationSeconds: finalPausedSeconds,
      userId: task.userId ?? userId,
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
    
    await _syncService.triggerSync(SyncEvent.adHocCompleted);
    
    // Clear paused activity reference
    clearPausedActivityReference();
  }
  
  /// Set alarm time for an adhoc task
  Future<void> setTaskAlarm(String taskId, DateTime alarmTime) async {
    final userId = UserService().currentUserId;
    
    final taskIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) {
      // Check pending tasks too
      final pendingIndex = _pendingTasks.indexWhere((t) => t.id == taskId);
      if (pendingIndex == -1) return;
      
      final task = _pendingTasks[pendingIndex];
      final updatedTask = task.copyWith(
        alarmTime: alarmTime.toUtc(),
        alarmTriggered: false,
        userId: task.userId ?? userId,
      );
      await _repo.updateAdHocTask(updatedTask);
      await loadAdHocTasks();
      return;
    }
    
    final task = _inProgressTasks[taskIndex];
    final updatedTask = task.copyWith(
      alarmTime: alarmTime.toUtc(),
      alarmTriggered: false,
      userId: task.userId ?? userId,
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
  }
  
  /// Clear alarm for an adhoc task
  Future<void> clearTaskAlarm(String taskId) async {
    final userId = UserService().currentUserId;
    
    AdHocTask? task;
    final inProgressIndex = _inProgressTasks.indexWhere((t) => t.id == taskId);
    if (inProgressIndex != -1) {
      task = _inProgressTasks[inProgressIndex];
    } else {
      final pendingIndex = _pendingTasks.indexWhere((t) => t.id == taskId);
      if (pendingIndex != -1) {
        task = _pendingTasks[pendingIndex];
      }
    }
    
    if (task == null) return;
    
    // Use explicit null assignment via a special method or by rebuilding
    final updatedTask = AdHocTask(
      id: task.id,
      createdAt: task.createdAt,
      updatedAt: DateTime.now().toUtc(),
      deviceId: task.deviceId,
      syncStatus: task.syncStatus,
      userId: task.userId ?? userId,
      title: task.title,
      description: task.description,
      executionState: task.executionState,
      startedAt: task.startedAt,
      completedAt: task.completedAt,
      linkedActivityId: task.linkedActivityId,
      isPaused: task.isPaused,
      pausedAt: task.pausedAt,
      pausedDurationSeconds: task.pausedDurationSeconds,
      alarmTime: null, // Clear alarm
      alarmTriggered: false,
      sortOrder: task.sortOrder,
    );
    await _repo.updateAdHocTask(updatedTask);
    await loadAdHocTasks();
  }
  
  @override
  void dispose() {
    _taskTimer?.cancel();
    super.dispose();
  }
  
  // ==================== USER FLOW TEMPLATES ====================
  
  Future<void> loadFlowTemplates() async {
    _flowTemplates = await _repo.getAllUserFlowTemplates();
    notifyListeners();
  }
  
  /// Create a new flow template
  Future<void> createFlowTemplate({
    required String name,
    required String category,
    required String initialPrompt,
    String? linkedSafetyWindowId,
  }) async {
    final template = UserFlowTemplate(
      name: name,
      category: category,
      initialPrompt: initialPrompt,
      linkedSafetyWindowId: linkedSafetyWindowId,
      steps: [],
    );
    await _repo.insertUserFlowTemplate(template);
    await loadFlowTemplates();
  }
  
  /// Create a simple IF → THEN flow template (simplified creation)
  Future<void> createSimpleFlowTemplate({
    required String triggerAction,
    required String thenAction,
  }) async {
    final name = '$triggerAction → $thenAction';
    final template = UserFlowTemplate(
      name: name,
      category: 'Flow', // Default category
      initialPrompt: 'After $triggerAction...',
      steps: [
        UserFlowStep(
          flowTemplateId: '', // Will be set by the template
          stepOrder: 0,
          ifCondition: 'you completed $triggerAction',
          thenAction: thenAction,
          activityName: thenAction,
        ),
      ],
    );
    
    // Create with the step already included
    final templateWithStep = template.copyWith(
      steps: [
        UserFlowStep(
          flowTemplateId: template.id,
          stepOrder: 0,
          ifCondition: 'you completed $triggerAction',
          thenAction: thenAction,
          activityName: thenAction,
        ),
      ],
    );
    
    await _repo.insertUserFlowTemplate(templateWithStep);
    await loadFlowTemplates();
  }
  
  /// Update an existing flow template
  Future<void> updateFlowTemplate(UserFlowTemplate template) async {
    await _repo.updateUserFlowTemplate(template);
    await loadFlowTemplates();
  }
  
  /// Delete a flow template
  Future<void> deleteFlowTemplate(String id) async {
    await _repo.deleteUserFlowTemplate(id);
    await loadFlowTemplates();
  }
  
  /// Add a step to a flow template
  Future<void> addStepToTemplate(String templateId, {
    required String ifCondition,
    required String thenAction,
    required String activityName,
    String? description,
    int? estimatedMinutes,
  }) async {
    final template = _flowTemplates.firstWhere((t) => t.id == templateId);
    
    final newStep = UserFlowStep(
      flowTemplateId: templateId,
      stepOrder: template.steps.length,
      ifCondition: ifCondition,
      thenAction: thenAction,
      activityName: activityName,
      description: description,
      estimatedMinutes: estimatedMinutes,
    );
    
    final updatedTemplate = template.copyWith(
      steps: [...template.steps, newStep],
    );
    await _repo.updateUserFlowTemplate(updatedTemplate);
    await loadFlowTemplates();
  }
  
  /// Remove a step from a flow template
  Future<void> removeStepFromTemplate(String templateId, String stepId) async {
    final template = _flowTemplates.firstWhere((t) => t.id == templateId);
    
    final updatedSteps = template.steps.where((s) => s.id != stepId).toList();
    // Re-order remaining steps
    final reorderedSteps = updatedSteps.asMap().entries.map((e) {
      return e.value.copyWith(stepOrder: e.key);
    }).toList();
    
    final updatedTemplate = template.copyWith(steps: reorderedSteps);
    await _repo.updateUserFlowTemplate(updatedTemplate);
    await loadFlowTemplates();
  }
  
  /// Reorder steps within a template
  Future<void> reorderSteps(String templateId, int oldIndex, int newIndex) async {
    final template = _flowTemplates.firstWhere((t) => t.id == templateId);
    final steps = List<UserFlowStep>.from(template.steps);
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final step = steps.removeAt(oldIndex);
    steps.insert(newIndex, step);
    
    // Re-order all steps
    final reorderedSteps = steps.asMap().entries.map((e) {
      return e.value.copyWith(stepOrder: e.key);
    }).toList();
    
    final updatedTemplate = template.copyWith(steps: reorderedSteps);
    await _repo.updateUserFlowTemplate(updatedTemplate);
    await loadFlowTemplates();
  }
}
