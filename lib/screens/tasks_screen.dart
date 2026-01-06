import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/energy_check_dialog.dart';
import '../theme/theme.dart';

/// Flow & Action Manager - Redesigned Tasks Screen
/// Two parts: Flow Templates (IF-THEN chains) and Ad-Hoc Tasks
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 28,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flow & Actions',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textOnCanvas,
                              ),
                            ),
                            Text(
                              'Routines & one-off tasks',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textOnCanvasSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textOnPanelSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorColor: AppColors.accent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.play_circle_outline_rounded, size: 20),
                    text: 'Ad-Hoc Tasks',
                  ),
                  Tab(
                    icon: Icon(Icons.account_tree_rounded, size: 20),
                    text: 'Flow Templates',
                  ),
                ],
              ),
              color: AppColors.panelBackground,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _AdHocTasksTab(),
            _FlowTemplatesTab(),
          ],
        ),
      ),
    );
  }
}

// ==================== AD-HOC TASKS TAB ====================
class _AdHocTasksTab extends StatelessWidget {
  const _AdHocTasksTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<FlowActionProvider, ActivityProvider>(
      builder: (context, flowProvider, activityProvider, child) {
        final pending = flowProvider.pendingTasks;
        final inProgress = flowProvider.inProgressTasks;
        final completed = flowProvider.completedTasks;

        return CustomScrollView(
          slivers: [
            // Quick add
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _QuickAddTask(
                  onAdd: (title) => flowProvider.createTask(title),
                ),
              ),
            ),

            // In Progress section
            if (inProgress.isNotEmpty) ...[
              _SectionHeader(
                title: 'In Progress',
                count: inProgress.length,
                color: Colors.orange,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _InProgressTaskItem(
                      task: inProgress[index],
                      onComplete: () => _handleTaskComplete(
                        context, 
                        flowProvider, 
                        activityProvider, 
                        inProgress[index].id,
                      ),
                      onCancel: () => flowProvider.cancelTask(inProgress[index].id),
                    ),
                    childCount: inProgress.length,
                  ),
                ),
              ),
            ],

            // Pending section
            if (pending.isNotEmpty) ...[
              _SectionHeader(
                title: 'To Do',
                count: pending.length,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final task = pending[index];
                    return ReorderableDragStartListener(
                      key: ValueKey(task.id),
                      index: index,
                      child: _PendingTaskItem(
                        task: task,
                        onStart: () => _handleTaskStart(
                          context,
                          flowProvider,
                          activityProvider,
                          task,
                        ),
                        onDelete: () => flowProvider.deleteTask(task.id),
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    flowProvider.reorderTasks(oldIndex, newIndex);
                  },
                ),
              ),
            ],

            // Empty state
            if (pending.isEmpty && inProgress.isEmpty && completed.isEmpty)
              const SliverFillRemaining(
                child: _EmptyTasksState(),
              ),

            // Completed section
            if (completed.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Completed (${completed.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _showClearConfirmation(context, flowProvider),
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CompletedTaskItem(
                      task: completed[index],
                    ),
                    childCount: completed.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
  
  /// Handle starting a task - pause any running activity first
  Future<void> _handleTaskStart(
    BuildContext context,
    FlowActionProvider flowProvider,
    ActivityProvider activityProvider,
    AdHocTask task,
  ) async {
    final currentActivity = activityProvider.currentActivity;
    
    // If there's a running activity, pause it first
    if (currentActivity != null && currentActivity.isRunning && !currentActivity.isPaused) {
      // Pause with ad-hoc task reason
      await activityProvider.pauseActivity(
        PauseReason.adHocTask,
        customReason: 'Doing Ad-Hoc – ${task.title}',
      );
    }
    
    // Now start the task, passing the paused activity for reference
    await flowProvider.startTask(task.id, currentRunningActivity: currentActivity);
    
    // Reload activity state
    await activityProvider.loadRunningActivity();
  }
  
  /// Handle completing a task - show energy check, then resume confirmation if there was a paused activity
  Future<void> _handleTaskComplete(
    BuildContext context,
    FlowActionProvider flowProvider,
    ActivityProvider activityProvider,
    String taskId,
  ) async {
    // Get the task name before completing for energy check
    final task = flowProvider.inProgressTasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => AdHocTask(title: 'Task'),
    );
    final taskName = task.title;
    
    // Complete the task and get the paused activity (if any)
    final pausedActivity = await flowProvider.completeTask(taskId);
    
    // Reload activity state
    await activityProvider.loadRunningActivity();
    
    // Show energy check dialog first
    if (context.mounted) {
      await EnergyCheckDialog.show(
        context,
        taskId: taskId,
        activityId: task.linkedActivityId,
        taskName: taskName,
      );
    }
    
    // If there was a paused activity, show the resume confirmation dialog
    if (pausedActivity != null && context.mounted) {
      _showResumeConfirmationDialog(context, activityProvider, flowProvider, pausedActivity);
    }
  }
  
  /// Show dialog asking user whether to resume the previously paused activity
  void _showResumeConfirmationDialog(
    BuildContext context,
    ActivityProvider activityProvider,
    FlowActionProvider flowProvider,
    Activity pausedActivity,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.play_circle_outline_rounded, size: 48),
        title: const Text('Continue previous activity?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pausedActivity.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This activity was paused when you started the ad-hoc task.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Keep it paused - clear reference
              flowProvider.clearPausedActivityReference();
              Navigator.pop(context);
              // Show pause reason dialog (same as Home behavior)
              _showPauseReasonDialogForPausedActivity(context, activityProvider);
            },
            child: const Text('Keep Paused'),
          ),
          FilledButton.icon(
            onPressed: () async {
              // Resume the activity
              await activityProvider.resumeActivity();
              flowProvider.clearPausedActivityReference();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ON IT'),
          ),
        ],
      ),
    );
  }
  
  /// Show pause reason dialog if user chooses to keep activity paused
  void _showPauseReasonDialogForPausedActivity(
    BuildContext context,
    ActivityProvider activityProvider,
  ) {
    // The activity is already paused with the ad-hoc reason
    // User can optionally change the reason here
    // For now, just leave it as is
  }

  void _showClearConfirmation(BuildContext context, FlowActionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear completed tasks?'),
        content: const Text('This will permanently delete all completed tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearCompletedTasks();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _QuickAddTask extends StatefulWidget {
  final Function(String) onAdd;

  const _QuickAddTask({required this.onAdd});

  @override
  State<_QuickAddTask> createState() => _QuickAddTaskState();
}

class _QuickAddTaskState extends State<_QuickAddTask> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onAdd(text);
      _controller.clear();
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppColors.panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: AppColors.textOnPanel),
              decoration: const InputDecoration(
                hintText: 'Add a quick task...',
                hintStyle: TextStyle(color: AppColors.textOnPanelMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            onPressed: _submit,
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color? color;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            if (color != null)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            Text(
              '$title ($count)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTaskItem extends StatelessWidget {
  final AdHocTask task;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  const _PendingTaskItem({
    required this.task,
    required this.onStart,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onStart,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ON IT button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ON IT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Task info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.ageDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: task.age.inDays > 3
                                ? Colors.orange
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Drag handle
                  Icon(
                    Icons.drag_indicator_rounded,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InProgressTaskItem extends StatelessWidget {
  final AdHocTask task;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _InProgressTaskItem({
    required this.task,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = task.executionDuration ?? Duration.zero;
    final elapsedStr = _formatDuration(elapsed);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.15),
            Colors.amber.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'IN PROGRESS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  elapsedStr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('DONE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    } else if (m > 0) {
      return '${m}m ${s}s';
    } else {
      return '${s}s';
    }
  }
}

class _CompletedTaskItem extends StatelessWidget {
  final AdHocTask task;

  const _CompletedTaskItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final duration = task.executionDuration;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (task.completedAt != null && duration != null)
                  Text(
                    'Done at ${timeFormat.format(task.completedAt!)} • took ${_formatDuration(duration)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m';
    } else {
      return '${d.inSeconds}s';
    }
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add tasks and track them with ON IT → DONE',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== FLOW TEMPLATES TAB ====================
class _FlowTemplatesTab extends StatelessWidget {
  const _FlowTemplatesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<FlowActionProvider>(
      builder: (context, provider, child) {
        final templates = provider.flowTemplates;

        return CustomScrollView(
          slivers: [
            // Info card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Design IF-THEN routines here. Execution happens via safety-hour alarms.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Add new template button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _showCreateTemplateDialog(context, provider),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Flow Template'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Templates list
            if (templates.isEmpty)
              const SliverFillRemaining(
                child: _EmptyTemplatesState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _FlowTemplateCard(
                      template: templates[index],
                      onEdit: () => _showEditTemplateDialog(context, provider, templates[index]),
                      onDelete: () => _showDeleteConfirmation(context, provider, templates[index]),
                    ),
                    childCount: templates.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  void _showCreateTemplateDialog(BuildContext context, FlowActionProvider provider) {
    final triggerController = TextEditingController();
    final thenController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create IF → THEN Flow',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Simple trigger-action pairing',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: triggerController,
              decoration: const InputDecoration(
                labelText: 'Trigger Action',
                hintText: 'e.g., Pray Subuh',
                prefixIcon: Icon(Icons.play_arrow_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Icon(
                Icons.arrow_downward_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: thenController,
              decoration: const InputDecoration(
                labelText: 'Then Action',
                hintText: 'e.g., Move body / shake / stroll',
                prefixIcon: Icon(Icons.check_circle_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (triggerController.text.trim().isNotEmpty &&
                      thenController.text.trim().isNotEmpty) {
                    // Create template with default category and single step
                    provider.createSimpleFlowTemplate(
                      triggerAction: triggerController.text.trim(),
                      thenAction: thenController.text.trim(),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Create Flow'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTemplateDialog(BuildContext context, FlowActionProvider provider, UserFlowTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FlowTemplateEditorScreen(template: template),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, FlowActionProvider provider, UserFlowTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('This will permanently delete "${template.name}" and all its steps.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteFlowTemplate(template.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FlowTemplateCard extends StatelessWidget {
  final UserFlowTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FlowTemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasSteps = template.steps.isNotEmpty;
    final firstStep = hasSteps ? template.steps.first : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_tree_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (firstStep != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'IF ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                firstStep.ifCondition,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'THEN ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                firstStep.thenAction,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (template.steps.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${template.steps.length - 1} more steps',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ] else
                  Text(
                    'No steps defined',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTemplatesState extends StatelessWidget {
  const _EmptyTemplatesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No flow templates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create IF-THEN routines for guided flows',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== FLOW TEMPLATE EDITOR SCREEN ====================
class _FlowTemplateEditorScreen extends StatefulWidget {
  final UserFlowTemplate template;

  const _FlowTemplateEditorScreen({required this.template});

  @override
  State<_FlowTemplateEditorScreen> createState() => _FlowTemplateEditorScreenState();
}

class _FlowTemplateEditorScreenState extends State<_FlowTemplateEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<FlowActionProvider>(
      builder: (context, provider, child) {
        // Get updated template from provider
        final template = provider.flowTemplates.firstWhere(
          (t) => t.id == widget.template.id,
          orElse: () => widget.template,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(template.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _editTemplateDetails(context, provider, template),
              ),
            ],
          ),
          body: template.steps.isEmpty
              ? _EmptyStepsState(onAdd: () => _showAddStepDialog(context, provider, template))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: template.steps.length,
                  itemBuilder: (context, index) {
                    final step = template.steps[index];
                    return _StepCard(
                      key: ValueKey(step.id),
                      step: step,
                      stepNumber: index + 1,
                      onDelete: () => provider.removeStepFromTemplate(template.id, step.id),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderSteps(template.id, oldIndex, newIndex);
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddStepDialog(context, provider, template),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Step'),
          ),
        );
      },
    );
  }

  void _editTemplateDetails(BuildContext context, FlowActionProvider provider, UserFlowTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final promptController = TextEditingController(text: template.initialPrompt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Template',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Flow Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Initial Prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final updated = template.copyWith(
                    name: nameController.text.trim(),
                    initialPrompt: promptController.text.trim(),
                  );
                  provider.updateFlowTemplate(updated);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStepDialog(BuildContext context, FlowActionProvider provider, UserFlowTemplate template) {
    final ifController = TextEditingController();
    final thenController = TextEditingController();
    final activityController = TextEditingController();
    final minutesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Step',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ifController,
                decoration: const InputDecoration(
                  labelText: 'IF...',
                  hintText: 'e.g., you are done praying',
                  border: OutlineInputBorder(),
                  prefixText: 'IF  ',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: thenController,
                decoration: const InputDecoration(
                  labelText: 'THEN...',
                  hintText: 'e.g., move your body',
                  border: OutlineInputBorder(),
                  prefixText: 'THEN  ',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: activityController,
                decoration: const InputDecoration(
                  labelText: 'Activity Name (for log)',
                  hintText: 'e.g., Light stretching',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Minutes (optional)',
                  hintText: 'e.g., 5',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (ifController.text.trim().isNotEmpty &&
                        thenController.text.trim().isNotEmpty &&
                        activityController.text.trim().isNotEmpty) {
                      provider.addStepToTemplate(
                        template.id,
                        ifCondition: ifController.text.trim(),
                        thenAction: thenController.text.trim(),
                        activityName: activityController.text.trim(),
                        estimatedMinutes: int.tryParse(minutesController.text),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add Step'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final UserFlowStep step;
  final int stepNumber;
  final VoidCallback onDelete;

  const _StepCard({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.activityName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              const Icon(Icons.drag_indicator_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    children: [
                      TextSpan(
                        text: 'IF ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      TextSpan(text: step.ifCondition),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    children: [
                      TextSpan(
                        text: 'THEN ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      TextSpan(text: step.thenAction),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (step.estimatedMinutes != null) ...[
            const SizedBox(height: 8),
            Text(
              '≈ ${step.estimatedMinutes} min',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyStepsState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyStepsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_task_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No steps yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add IF-THEN steps to this flow',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Step'),
          ),
        ],
      ),
    );
  }
}

// ==================== HELPERS ====================
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  _SliverTabBarDelegate(this.tabBar, {required this.color});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || color != oldDelegate.color;
  }
}
