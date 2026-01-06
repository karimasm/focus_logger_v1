import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';
import '../database/database_helper.dart';
import '../data/data.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _activitySearchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load data when tab changes
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        // Energy tab - load energy data
        _loadEnergyData();
      } else if (_tabController.index == 2) {
        context.read<MemoProvider>().loadAllMemos();
      }
    });
  }
  
  List<EnergyCheck> _energyChecks = [];
  bool _loadingEnergy = false;
  
  Future<void> _loadEnergyData() async {
    setState(() => _loadingEnergy = true);
    final checks = await dataRepository.getEnergyChecksForDate(DateTime.now());
    if (mounted) {
      setState(() {
        _energyChecks = checks;
        _loadingEnergy = false;
      });
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ActivityProvider, MemoProvider>(
      builder: (context, activityProvider, memoProvider, child) {
        return Column(
          children: [
            // Date selector (for Activities tab)
            _DateSelector(
              selectedDate: activityProvider.selectedDate,
              onDateChanged: (date) => activityProvider.setSelectedDate(date),
            ),
            
            // Tab Bar
            Container(
              color: AppColors.panelBackground,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textOnPanel,
                unselectedLabelColor: AppColors.textOnPanelSecondary,
                indicatorColor: AppColors.activityRunning,
                tabs: const [
                  Tab(text: 'Activities'),
                  Tab(text: 'Energy'),
                  Tab(text: 'Memos'),
                ],
              ),
            ),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Activities Tab
                  _TimelineContent(
                    activities: _filterActivities(activityProvider.todayActivities),
                    timeSlots: activityProvider.todayTimeSlots,
                  ),
                  
                  // Energy Tab (NEW)
                  _EnergyTabContent(
                    energyChecks: _energyChecks,
                    isLoading: _loadingEnergy,
                    onRefresh: _loadEnergyData,
                  ),
                  
                  // Memos Tab
                  _MemosTabContent(
                    memos: memoProvider.filteredMemos,
                    isLoading: memoProvider.isLoading,
                    searchQuery: memoProvider.searchQuery,
                    onSearchChanged: (q) => memoProvider.setSearchQuery(q),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  List<Activity> _filterActivities(List<Activity> activities) {
    if (_activitySearchQuery.isEmpty) return activities;
    final query = _activitySearchQuery.toLowerCase();
    return activities.where((a) => 
      a.name.toLowerCase().contains(query) ||
      a.category.toLowerCase().contains(query)
    ).toList();
  }
}

/// Memos Tab Content with search
class _MemosTabContent extends StatelessWidget {
  final List<MemoEntry> memos;
  final bool isLoading;
  final String searchQuery;
  final Function(String) onSearchChanged;
  
  const _MemosTabContent({
    required this.memos,
    required this.isLoading,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: AppColors.textOnPanel),
            decoration: InputDecoration(
              hintText: 'Search memos...',
              hintStyle: TextStyle(color: AppColors.textOnPanel.withValues(alpha: 0.6)),
              prefixIcon: Icon(Icons.search, color: AppColors.textOnPanel.withValues(alpha: 0.6)),
              filled: true,
              fillColor: AppColors.panelSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        
        // Memo list
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : memos.isEmpty
                  ? Center(
                      child: Text(
                        searchQuery.isEmpty ? 'No memos yet' : 'No memos found',
                        style: const TextStyle(color: AppColors.textOnPanel),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: memos.length,
                      itemBuilder: (context, index) {
                        return _GlobalMemoItem(memo: memos[index]);
                      },
                    ),
        ),
      ],
    );
  }
}

/// Single memo item for global memo list
class _GlobalMemoItem extends StatelessWidget {
  final MemoEntry memo;
  
  const _GlobalMemoItem({required this.memo});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('d MMM');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Row(
            children: [
              Icon(
                _getSourceIcon(memo.source),
                size: 14,
                color: AppColors.textOnPanelSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${dateFormat.format(memo.timestamp)} ${timeFormat.format(memo.timestamp)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textOnPanelSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (memo.source == MemoSource.idleReflection) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Idle',
                    style: TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          
          // Memo text
          Text(
            memo.text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textOnPanel,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getSourceIcon(MemoSource source) {
    switch (source) {
      case MemoSource.voice:
        return Icons.mic;
      case MemoSource.idleReflection:
        return Icons.psychology_outlined;
      case MemoSource.manual:
      default:
        return Icons.edit_note;
    }
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const _DateSelector({
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        border: const Border(
          bottom: BorderSide(
            color: AppColors.panelBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => onDateChanged(
              selectedDate.subtract(const Duration(days: 1)),
            ),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                onDateChanged(date);
              }
            },
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE').format(selectedDate),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textOnPanelSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormat('d MMMM yyyy').format(selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnPanel,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: selectedDate.isBefore(DateTime(now.year, now.month, now.day))
                ? () => onDateChanged(
                    selectedDate.add(const Duration(days: 1)),
                  )
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _TimelineContent extends StatelessWidget {
  final List<Activity> activities;
  final List<TimeSlot> timeSlots;

  const _TimelineContent({
    required this.activities,
    required this.timeSlots,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty && timeSlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No activities yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking your time!',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Combine activities and time slots into timeline items
    final timelineItems = _buildTimelineItems();

    return Column(
      children: [
        // Summary bar
        _SummaryBar(activities: activities),
        
        // Timeline list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: timelineItems.length,
            itemBuilder: (context, index) {
              final item = timelineItems[index];
              return _TimelineItem(item: item);
            },
          ),
        ),
      ],
    );
  }

  List<_TimelineItemData> _buildTimelineItems() {
    final items = <_TimelineItemData>[];
    
    // Add activities
    for (final activity in activities) {
      final now = DateTime.now();
      DateTime endTime;
      
      if (activity.isRunning) {
        endTime = now;
      } else {
        // Closed activity: use recorded endTime or fallback to startTime (0 duration) if missing
        endTime = activity.endTime ?? activity.startTime;
      }
      
      // Sanity check: prevent negative duration
      if (endTime.isBefore(activity.startTime)) {
        endTime = activity.startTime;
      }

      items.add(_TimelineItemData(
        type: _TimelineItemType.activity,
        activity: activity,
        startTime: activity.startTime,
        endTime: endTime,
        label: activity.name,
        isRunning: activity.isRunning,
        isPaused: activity.isPaused,
      ));
    }

    // Add time slots that don't overlap with activities
    for (final slot in timeSlots) {
      if (slot.activityId == null) {
        items.add(_TimelineItemData(
          type: _TimelineItemType.timeSlot,
          timeSlot: slot,
          startTime: slot.slotStart,
          endTime: slot.slotEnd,
          label: slot.label,
        ));
      }
    }

    // Sort by start time (most recent first)
    items.sort((a, b) => b.startTime.compareTo(a.startTime));
    return items;
  }
}

class _SummaryBar extends StatelessWidget {
  final List<Activity> activities;

  const _SummaryBar({required this.activities});

  @override
  Widget build(BuildContext context) {
    final totalDuration = activities.fold<Duration>(
      Duration.zero,
      (total, a) => total + a.duration,
    );

    final activeCount = activities.where((a) => !a.isAutoGenerated).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.panelSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Total Focus',
            value: _formatDuration(totalDuration),
            icon: Icons.timer_outlined,
          ),
          _StatItem(
            label: 'Activities',
            value: activeCount.toString(),
            icon: Icons.task_alt_outlined,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.accent,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPanel,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textOnPanelSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _TimelineItemType { activity, timeSlot }

class _TimelineItemData {
  final _TimelineItemType type;
  final Activity? activity;
  final TimeSlot? timeSlot;
  final DateTime startTime;
  final DateTime endTime;
  final String label;
  final bool isRunning;
  final bool isPaused;

  _TimelineItemData({
    required this.type,
    this.activity,
    this.timeSlot,
    required this.startTime,
    required this.endTime,
    required this.label,
    this.isRunning = false,
    this.isPaused = false,
  });

  Duration get duration {
    if (type == _TimelineItemType.activity && activity != null) {
      if (isRunning) {
        // For running activity, calculation is dynamic, but snapshot is static.
        // We use the same logic as Activity model for consistency
        return activity!.duration;
      }
      return activity!.duration;
    }
    return endTime.difference(startTime);
  }
}

class _TimelineItem extends StatelessWidget {
  final _TimelineItemData item;

  const _TimelineItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final duration = item.duration;
    final isUnlabeled = item.label == 'Unlabeled';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showDetailsDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isRunning
                  ? AppColors.activityRunning
                  : (item.isPaused
                      ? AppColors.activityPaused
                      : AppColors.panelBorder),
              width: item.isRunning || item.isPaused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Time column
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeFormat.format(item.startTime),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnPanel,
                      ),
                    ),
                    Text(
                      timeFormat.format(item.endTime),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textOnPanelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Timeline indicator
              Container(
                width: 4,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isUnlabeled
                      ? Theme.of(context).colorScheme.outlineVariant
                      : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Activity info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontStyle: isUnlabeled ? FontStyle.italic : null,
                              color: isUnlabeled
                                  ? AppColors.textOnPanelSecondary
                                  : AppColors.textOnPanel,
                            ),
                          ),
                        ),
                        if (item.isRunning)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.isPaused
                                  ? Colors.orange
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.isPaused ? 'PAUSED' : 'LIVE',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textOnPanelSecondary,
                          ),
                        ),
                        // Source badge
                        if (item.activity != null && item.activity!.source != ActivitySource.manual) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.activity!.source == ActivitySource.guided
                                  ? Colors.purple.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.activity!.source.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: item.activity!.source == ActivitySource.guided
                                    ? Colors.purple
                                    : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  void _showDetailsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ActivityDetailSheet(item: item),
    );
  }
}

class ActivityDetailSheet extends StatelessWidget {
  final _TimelineItemData item;

  const ActivityDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('d MMMM yyyy');

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: dateFormat.format(item.startTime),
          ),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Time',
            value: '${timeFormat.format(item.startTime)} - ${timeFormat.format(item.endTime)}',
          ),
          _DetailRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: _formatDuration(item.duration),
          ),
          if (item.activity != null) ...[
            _DetailRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: item.activity!.category,
            ),
            _DetailRow(
              icon: Icons.source_outlined,
              label: 'Source',
              value: item.activity!.source.displayName,
            ),
            if (item.activity!.pausedDurationSeconds > 0)
              _DetailRow(
                icon: Icons.pause_circle_outline,
                label: 'Paused Time',
                value: _formatDuration(
                  Duration(seconds: item.activity!.pausedDurationSeconds),
                ),
              ),
          ],

          // Pause logs if available
          if (item.activity != null) ...[
            const SizedBox(height: 24),
            _PauseLogsSection(activityId: item.activity!.id),
          ],
          
          // Memo section if available
          if (item.activity != null) ...[
            const SizedBox(height: 24),
            _MemosSection(activityId: item.activity!.id),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseLogsSection extends StatelessWidget {
  final String activityId;

  const _PauseLogsSection({required this.activityId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PauseLog>>(
      future: context.read<ActivityProvider>().getPauseLogs(activityId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final logs = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pause History',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPanel,
              ),
            ),
            const SizedBox(height: 12),
            ...logs.map((log) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.panelSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getPauseIcon(log.reason),
                    size: 20,
                    color: _getPauseColor(log.reason),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.displayReason,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textOnPanel,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(log.pauseTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textOnPanelSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    log.formattedDuration,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )),
          ],
        );
      },
    );
  }

  IconData _getPauseIcon(PauseReason reason) {
    switch (reason) {
      case PauseReason.distraction:
        return Icons.notifications_active_outlined;
      case PauseReason.breakRest:
        return Icons.coffee_outlined;
      case PauseReason.taskSwitching:
        return Icons.swap_horiz_rounded;
      case PauseReason.adHocTask:
        return Icons.task_alt_rounded;
      case PauseReason.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color _getPauseColor(PauseReason reason) {
    switch (reason) {
      case PauseReason.distraction:
        return Colors.red;
      case PauseReason.breakRest:
        return Colors.blue;
      case PauseReason.taskSwitching:
        return Colors.orange;
      case PauseReason.adHocTask:
        return Colors.purple;
      case PauseReason.other:
        return Colors.grey;
    }
  }
}

/// Widget to display memos for an activity session
class _MemosSection extends StatelessWidget {
  final String activityId;

  const _MemosSection({required this.activityId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<MemoEntry>>(
      future: DatabaseHelper.instance.getMemosForActivity(activityId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final memos = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Memos (${memos.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...memos.map((memo) => _MemoItem(memo: memo)).toList(),
          ],
        );
      },
    );
  }
}

class _MemoItem extends StatelessWidget {
  final MemoEntry memo;

  const _MemoItem({required this.memo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeFormat.format(memo.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                memo.text,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              memo.source == MemoSource.voice
                  ? Icons.mic_rounded
                  : Icons.edit_note_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Energy Tab Content - shows energy history and trends
class _EnergyTabContent extends StatelessWidget {
  final List<EnergyCheck> energyChecks;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _EnergyTabContent({
    required this.energyChecks,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (energyChecks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.battery_charging_full_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No energy logs today',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete activities to track your energy',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }

    // Calculate average energy
    final avgEnergy = energyChecks.map((e) => e.level.value).reduce((a, b) => a + b) / energyChecks.length;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Average Energy Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.panelBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getEnergyColor(avgEnergy).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  "Today's Average",
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textOnPanelSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avgEnergy.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _getEnergyColor(avgEnergy),
                      ),
                    ),
                    Text(
                      ' / 5',
                      style: const TextStyle(
                        fontSize: 24,
                        color: AppColors.textOnPanelSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < avgEnergy.round();
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? _getEnergyColor(avgEnergy) : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      size: 28,
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Energy Log List
          Text(
            'Energy Log',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...energyChecks.reversed.map((check) => _EnergyLogItem(check: check)),
        ],
      ),
    );
  }

  Color _getEnergyColor(double value) {
    if (value <= 1.5) return Colors.red;
    if (value <= 2.5) return Colors.orange;
    if (value <= 3.5) return Colors.amber;
    if (value <= 4.5) return Colors.lightGreen;
    return Colors.green;
  }
}

class _EnergyLogItem extends StatelessWidget {
  final EnergyCheck check;

  const _EnergyLogItem({required this.check});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              check.level.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${check.level.value} - ${check.level.displayName}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    timeFormat.format(check.recordedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Energy bar
            Row(
              children: List.generate(5, (i) {
                final filled = i < check.level.value;
                return Container(
                  width: 8,
                  height: 20,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: filled ? _getEnergyColor(check.level.value.toDouble()) : colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Color _getEnergyColor(double value) {
    if (value <= 1.5) return Colors.red;
    if (value <= 2.5) return Colors.orange;
    if (value <= 3.5) return Colors.amber;
    if (value <= 4.5) return Colors.lightGreen;
    return Colors.green;
  }
}
