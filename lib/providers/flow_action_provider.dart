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
  
  // Getters
  List<AdHocTask> get pendingTasks => _pendingTasks;
  List<AdHocTask> get inProgressTasks => _inProgressTasks;
  List<AdHocTask> get completedTasks => _completedTasks;
  List<UserFlowTemplate> get flowTemplates => _flowTemplates;
  
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
  }
  
  // ==================== AD-HOC TASKS ====================
  
  Future<void> loadAdHocTasks() async {
    _pendingTasks = await _repo.getPendingAdHocTasks();
    _inProgressTasks = await _repo.getInProgressAdHocTasks();
    _completedTasks = await _repo.getCompletedAdHocTasks();
    notifyListeners();
  }
  
  /// Create a new ad-hoc task
  Future<void> createTask(String title, {String? description}) async {
    final task = AdHocTask(
      title: title,
      description: description,
      sortOrder: _pendingTasks.length,
      userId: UserService().currentUserId,
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
    final now = DateTime.now();
    
    // Store reference to the activity we're about to pause
    if (currentRunningActivity != null && currentRunningActivity.isRunning) {
      _pausedActivityForTask = currentRunningActivity;
      _pausedActivityTaskId = taskId;
      
      // The actual pausing is done by the caller (ActivityProvider)
      // with the pause reason: "Doing Ad-Hoc – <task name>"
    }
    
    // Create an activity for this task
    final activity = Activity(
      name: task.title,
      category: 'Ad-hoc Task',
      startTime: now,
      isRunning: true,
      source: ActivitySource.manual,
    );
    await _repo.insertActivity(activity);
    
    // Update task state
    final updatedTask = task.copyWith(
      executionState: TaskExecutionState.inProgress,
      startedAt: now,
      linkedActivityId: activity.id,
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
    final now = DateTime.now();
    
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
    
    // Update task state
    final updatedTask = task.copyWith(
      executionState: TaskExecutionState.completed,
      completedAt: now,
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
          endTime: DateTime.now(),
          isRunning: false,
        );
        await _repo.updateActivity(updated);
      }
    }
    
    // Reset task to pending (but keep the created_at for age tracking)
    final updatedTask = task.copyWith(
      executionState: TaskExecutionState.pending,
      startedAt: null,
      linkedActivityId: null,
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
    
    for (int i = 0; i < _pendingTasks.length; i++) {
      final updated = _pendingTasks[i].copyWith(sortOrder: i);
      await _repo.updateAdHocTask(updated);
    }
    notifyListeners();
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
