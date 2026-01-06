import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../widgets/energy_check_dialog.dart';
import '../widgets/mascot_accent.dart';
import '../services/mascot_service.dart';
import '../services/idle_detection_service.dart';
import '../theme/theme.dart';
import 'idle_reflection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  bool _idlePopupShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentTime = DateTime.now();
      });
      // Check idle state periodically (only when no activity running)
      _checkIdleState();
    });
    
    // Check idle on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIdleState();
    });
  }
  
  void _checkIdleState() {
    if (_idlePopupShown) return;
    
    final provider = context.read<ActivityProvider>();
    final idleService = IdleDetectionService();
    
    // Only show if: no running activity AND idle threshold reached
    if (!provider.hasRunningActivity && idleService.isIdle) {
      _showIdleReflectionPopup(idleService.idleDuration);
    }
  }
  
  void _showIdleReflectionPopup(Duration idleDuration) {
    _idlePopupShown = true;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => IdleReflectionScreen(
          idleDuration: idleDuration,
          onComplete: () {
            Navigator.of(context).pop();
            IdleDetectionService().onIdleLabeled();
            _idlePopupShown = false;
          },
        ),
      ),
    );
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check idle when app resumes from background
      _idlePopupShown = false;
      _checkIdleState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer.cancel();
    super.dispose();
  }
  
  /// Calculate live duration based on current time (updates every second)
  String _getLiveFormattedDuration(Activity activity) {
    if (!activity.isRunning) {
      return activity.formattedDuration;
    }
    
    // Calculate live duration using _currentTime which updates every second
    final totalDuration = _currentTime.difference(activity.startTime);
    if (totalDuration.isNegative) {
      return '00:00:00';
    }
    
    // Subtract paused duration
    int activeDurationSeconds = totalDuration.inSeconds - activity.pausedDurationSeconds;
    
    // If currently paused, also subtract time since pause started
    if (activity.isPaused && activity.pausedAt != null) {
      final currentPauseDuration = _currentTime.difference(activity.pausedAt!).inSeconds;
      activeDurationSeconds -= currentPauseDuration;
    }
    
    activeDurationSeconds = activeDurationSeconds.clamp(0, totalDuration.inSeconds);
    
    final d = Duration(seconds: activeDurationSeconds);
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, activityProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sync Status Bar
              _buildSyncStatusBar(),
              const SizedBox(height: 16),
              
              // Haid Mode Check Prompt (if applicable)
              _buildHaidModePrompt(),
              
              // Large Digital Clock
              _buildClock(),
              const SizedBox(height: 8),
              
              // Full Date
              _buildDate(),
              const SizedBox(height: 32),
              
              // Current Activity Card
              _buildCurrentActivityCard(activityProvider),
              const SizedBox(height: 24),
              
              // Control Buttons
              _buildControlButtons(activityProvider),
              const SizedBox(height: 24),
              
              // Guided Flow Section
              _buildGuidedFlowSection(),
              const SizedBox(height: 24),
              
              // Quick Stats for Today
              _buildQuickStats(activityProvider),
              const SizedBox(height: 24),
              
              // Haid Mode Toggle
              _buildHaidModeToggle(),
              const SizedBox(height: 16),
              
              // Auto-logging footer note
              _buildAutoLoggingNote(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSyncStatusBar() {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        return InkWell(
          onTap: syncProvider.isSyncing ? null : () => syncProvider.syncNow(),
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: syncProvider.detailedStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _getSyncBackgroundColor(syncProvider.state),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getSyncBorderColor(syncProvider.state),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getSyncIcon(syncProvider.state),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        syncProvider.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getSyncTextColor(syncProvider.state),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Show queued changes if offline and has pending
                      if (syncProvider.hasQueuedChanges && syncProvider.state != SyncState.syncing)
                        Text(
                          '${syncProvider.pendingChangesCount} update${syncProvider.pendingChangesCount > 1 ? 's' : ''} queued',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getSyncTextColor(syncProvider.state).withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                  if (!syncProvider.isSyncing) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sync Now',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _getSyncIcon(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncState.success:
        return const Icon(Icons.cloud_done_rounded, size: 16, color: Colors.green);
      case SyncState.error:
        return const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.red);
      case SyncState.offline:
        return const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.orange);
      case SyncState.idle:
        return Icon(Icons.cloud_outlined, size: 16, color: Colors.grey.shade600);
    }
  }
  
  Color _getSyncBackgroundColor(SyncState state) {
    switch (state) {
      case SyncState.error:
        return Colors.red.withOpacity(0.1);
      case SyncState.offline:
        return Colors.orange.withOpacity(0.1);
      case SyncState.success:
        return Colors.green.withOpacity(0.1);
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }
  
  Color _getSyncBorderColor(SyncState state) {
    switch (state) {
      case SyncState.error:
        return Colors.red.withOpacity(0.3);
      case SyncState.offline:
        return Colors.orange.withOpacity(0.3);
      case SyncState.success:
        return Colors.green.withOpacity(0.3);
      default:
        return Colors.transparent;
    }
  }
  
  Color _getSyncTextColor(SyncState state) {
    switch (state) {
      case SyncState.error:
        return Colors.red.shade700;
      case SyncState.offline:
        return Colors.orange.shade700;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildClock() {
    final timeFormat = DateFormat('HH:mm:ss');
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        timeFormat.format(_currentTime),
        style: const TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w300,
          letterSpacing: 4,
          fontFeatures: [FontFeature.tabularFigures()],
          color: AppColors.textOnCanvas,
        ),
      ),
    );
  }

  Widget _buildDate() {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy');
    return Text(
      dateFormat.format(_currentTime),
      style: const TextStyle(
        fontSize: 18,
        color: AppColors.textOnCanvasSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildCurrentActivityCard(ActivityProvider provider) {
    final activity = provider.currentActivity;
    final hasActivity = provider.hasRunningActivity;
    final isPaused = provider.isPaused;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(24),
      decoration: AppColors.panelDecoration(borderRadius: 20),
      child: Column(
        children: [
          // Status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasActivity
                      ? (isPaused ? AppColors.activityPaused : AppColors.activityRunning)
                      : AppColors.textOnPanelMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasActivity
                    ? (isPaused ? 'PAUSED' : 'RUNNING')
                    : 'NO ACTIVITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: hasActivity
                      ? (isPaused
                          ? AppColors.activityPaused
                          : AppColors.activityRunning)
                      : AppColors.textOnPanelSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Activity name or placeholder
          Text(
            activity?.name ?? 'Start an activity',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnPanel,
            ),
            textAlign: TextAlign.center,
          ),
          
          // MASCOT BADGE: Show below activity name when running
          if (hasActivity && activity != null)
            Builder(builder: (context) {
              final mascotAsset = MascotService.getMascotAsset(activity);
              if (mascotAsset == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AnimatedMascotAccent(
                  activity: activity,
                  size: 56,
                ),
              );
            }),
          
          // Duration if activity is running
          if (hasActivity) ...[
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _getLiveFormattedDuration(activity!),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.textOnPanel,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Started at ${DateFormat('HH:mm').format(activity.startTime)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textOnPanelSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButtons(ActivityProvider provider) {
    final hasActivity = provider.hasRunningActivity;
    final isPaused = provider.isPaused;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        // Start / Stop button
        if (!hasActivity)
          _ActionButton(
            icon: Icons.play_arrow_rounded,
            label: 'Start Activity',
            isPrimary: true,
            onPressed: () => _showStartActivityDialog(),
          )
        else
          _ActionButton(
            icon: Icons.stop_rounded,
            label: 'Stop',
            isPrimary: false,
            isDestructive: true,
            onPressed: () => _handleStopActivity(provider),
          ),

        // Pause / Resume button
        if (hasActivity)
          if (isPaused)
            _ActionButton(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              isPrimary: true,
              onPressed: () => provider.resumeActivity(),
            )
          else
            _ActionButton(
              icon: Icons.pause_rounded,
              label: 'Pause',
              isPrimary: false,
              onPressed: () => _showPauseReasonDialog(),
            ),

        // Add Memo button (only when activity is running)
        if (hasActivity)
          _ActionButton(
            icon: Icons.note_add_rounded,
            label: 'Memo',
            isPrimary: false,
            onPressed: () => _showMemoDialog(provider.currentActivity!),
          ),

        // Add Manual Log button
        _ActionButton(
          icon: Icons.add_rounded,
          label: 'Add Log',
          isPrimary: false,
          onPressed: () => _showManualLogDialog(),
        ),
      ],
    );
  }

  Widget _buildQuickStats(ActivityProvider provider) {
    return FutureBuilder<Map<String, Duration>>(
      future: provider.getActivityDurations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final durations = snapshot.data!;
        final totalDuration = durations.values.fold<Duration>(
          Duration.zero,
          (total, d) => total + d,
        );

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          decoration: AppColors.panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Today\'s Focus',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPanel,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(totalDuration),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...durations.entries.take(5).map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textOnPanel,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDuration(entry.value),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textOnPanelSecondary,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Widget _buildGuidedFlowSection() {
    return Consumer<GuidedFlowProvider>(
      builder: (context, guidedProvider, _) {
        final templates = guidedProvider.enforcedTemplates;
        final windows = guidedProvider.safetyWindows;
        if (templates.isEmpty && windows.isEmpty) return const SizedBox.shrink();

        // Find the next upcoming enforced event
        final now = DateTime.now();
        SafetyWindow? nextWindow;
        UserFlowTemplate? nextTemplate;
        Duration? timeUntilNext;
        
        // Find completed and missed events today (using corrected rules)
        final completedToday = <UserFlowTemplate>[];
        final missedToday = <UserFlowTemplate>[];
        
        for (final template in templates) {
          if (guidedProvider.isFlowCompletedToday(template.id)) {
            // Only truly completed: user pressed ON IT and finished with DONE
            completedToday.add(template);
          } else if (guidedProvider.isFlowMissedToday(template.id)) {
            // Missed: window ended without user pressing ON IT
            missedToday.add(template);
          }
        }
        
        // Find next upcoming window
        for (final window in windows) {
          final windowStart = DateTime(now.year, now.month, now.day, window.startHour, window.startMinute);
          
          // Skip if already past end of window
          final windowEnd = DateTime(now.year, now.month, now.day, window.endHour, window.endMinute);
          if (now.isAfter(windowEnd)) {
            continue;
          }
          
          // Find template linked to this window
          final template = templates.firstWhere(
            (t) => t.linkedSafetyWindowId == window.id,
            orElse: () => templates.isNotEmpty ? templates.first : UserFlowTemplate(name: window.name, category: 'Flow', initialPrompt: ''),
          );
          
          if (guidedProvider.isFlowCompletedToday(template.id)) {
            continue;
          }
          
          final timeUntil = windowStart.difference(now);
          if (timeUntil.isNegative) {
            // Currently in window
            nextWindow = window;
            nextTemplate = template;
            timeUntilNext = Duration.zero;
            break;
          } else if (nextWindow == null || timeUntil < timeUntilNext!) {
            nextWindow = window;
            nextTemplate = template;
            timeUntilNext = timeUntil;
          }
        }

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          decoration: AppColors.panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Enforced Events',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPanel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Next upcoming event
              if (nextTemplate != null && nextWindow != null) ...[
                _UpcomingEventCard(
                  template: nextTemplate,
                  window: nextWindow,
                  timeUntil: timeUntilNext!,
                ),
                const SizedBox(height: 12),
              ],
              
              // Completed events today
              if (completedToday.isNotEmpty) ...[
                Text(
                  'Completed Today',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...completedToday.map((template) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            template.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              
              // Missed events today (CORRECTED display)
              if (missedToday.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Missed Today',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 8),
                ...missedToday.map((template) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            template.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              
              // All done for today (only if no missed and all completed)
              if (nextTemplate == null && completedToday.isNotEmpty && missedToday.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.celebration_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'All rituals completed for today!',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              
              // No events scheduled
              if (nextTemplate == null && completedToday.isEmpty && missedToday.isEmpty)
                Text(
                  'No enforced events scheduled',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAutoLoggingNote() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'You\'ll be prompted every 30 minutes if idle',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Haid Mode check prompt (shown after 5-7 days)
  Widget _buildHaidModePrompt() {
    return Consumer<GuidedFlowProvider>(
      builder: (context, provider, _) {
        if (!provider.shouldPromptHaidCheck) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.pink.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.pink.shade400, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Haid Mode Check',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.pink.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Are you still on your period?',
                style: TextStyle(color: Colors.pink.shade800),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      provider.deactivateHaidMode();
                    },
                    child: const Text('No, resume flows'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      provider.markHaidPromptShown();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.pink.shade400,
                    ),
                    child: const Text('Yes, continue skip'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build Haid Mode toggle section
  Widget _buildHaidModeToggle() {
    return Consumer<GuidedFlowProvider>(
      builder: (context, provider, _) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: provider.isHaidModeActive
                ? Colors.pink.shade50
                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: provider.isHaidModeActive
                ? Border.all(color: Colors.pink.shade200)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                provider.isHaidModeActive
                    ? Icons.pause_circle_filled_rounded
                    : Icons.pause_circle_outline_rounded,
                size: 24,
                color: provider.isHaidModeActive
                    ? Colors.pink.shade400
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haid Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: provider.isHaidModeActive
                            ? Colors.pink.shade700
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      provider.isHaidModeActive
                          ? 'Prayer flows paused (Day ${(provider.haidMode?.daysSinceStart ?? 0) + 1})'
                          : 'Skip prayer flows during period',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: provider.isHaidModeActive,
                onChanged: (value) {
                  if (value) {
                    provider.activateHaidMode();
                  } else {
                    provider.deactivateHaidMode();
                  }
                },
                activeColor: Colors.pink.shade400,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStartActivityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const StartActivitySheet(),
    );
  }

  void _showPauseReasonDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const PauseReasonSheet(),
    );
  }

  void _showManualLogDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const ManualLogSheet(),
    );
  }
  
  Future<void> _handleStopActivity(ActivityProvider provider) async {
    final activity = provider.currentActivity;
    if (activity == null) return;
    
    final activityName = activity.name;
    final activityId = activity.id;
    
    // Stop the activity
    await provider.stopActivity();
    
    // Show energy check dialog
    if (mounted) {
      await EnergyCheckDialog.show(
        context,
        activityId: activityId,
        taskName: activityName,
      );
    }
  }

  void _showMemoDialog(Activity activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MemoSheet(activity: activity),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    this.isDestructive = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: isPrimary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: isDestructive ? Colors.red : null),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDestructive ? Colors.red : null,
                side: isDestructive
                    ? const BorderSide(color: Colors.red)
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
    );
  }
}

/// Card widget for displaying the next upcoming enforced event
class _UpcomingEventCard extends StatelessWidget {
  final UserFlowTemplate template;
  final SafetyWindow window;
  final Duration timeUntil;

  const _UpcomingEventCard({
    required this.template,
    required this.window,
    required this.timeUntil,
  });

  @override
  Widget build(BuildContext context) {
    final isNow = timeUntil.inMinutes <= 0;
    final timeStr = _formatTimeUntil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNow 
            ? Colors.orange.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNow ? Colors.orange : Theme.of(context).colorScheme.outlineVariant,
          width: isNow ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getCategoryColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(),
              color: _getCategoryColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Event info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NOW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Text(
                  isNow ? template.name : 'Next: ${template.name}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isNow 
                      ? 'Started at ${window.startHour.toString().padLeft(2, '0')}:${window.startMinute.toString().padLeft(2, '0')}'
                      : timeStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isNow ? FontWeight.w500 : FontWeight.normal,
                    color: isNow 
                        ? Colors.orange.shade700
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Time indicator
          if (!isNow)
            Text(
              '${window.startHour.toString().padLeft(2, '0')}:${window.startMinute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
  
  String _formatTimeUntil() {
    if (timeUntil.inHours > 0) {
      return 'in ${timeUntil.inHours}h ${timeUntil.inMinutes % 60}m';
    } else if (timeUntil.inMinutes > 0) {
      return 'in ${timeUntil.inMinutes} minutes';
    } else {
      return 'Starting now';
    }
  }

  IconData _getCategoryIcon() {
    switch (template.category.toLowerCase()) {
      case 'prayer':
        return Icons.self_improvement_rounded;
      case 'routine':
        return Icons.schedule_rounded;
      case 'recovery':
        return Icons.psychology_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (template.category.toLowerCase()) {
      case 'prayer':
        return const Color(0xFF4CAF50);
      case 'routine':
        return const Color(0xFF2196F3);
      case 'recovery':
        return const Color(0xFFFF9800);
      case 'sleep':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF2196F3);
    }
  }
}
