import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../data/data.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        
        // Tab Content - each tab has its own date filter & search
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              // Activities Tab - with own date & search
              _ActivitiesTabContent(),
              
              // Energy Tab - with own date & search
              _EnergyTabContent(),
              
              // Memos Tab - with own date & search
              _MemosTabContent(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Activities Tab Content with date filter and search
class _ActivitiesTabContent extends StatefulWidget {
  const _ActivitiesTabContent();

  @override
  State<_ActivitiesTabContent> createState() => _ActivitiesTabContentState();
}

class _ActivitiesTabContentState extends State<_ActivitiesTabContent> {
  final _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  List<Activity> _activities = [];
  List<Activity> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final activities = await dataRepository.getActivitiesForDate(_selectedDate);
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchAcrossAllDates(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });
    
    try {
      final results = await dataRepository.searchActivities(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching activities: $e');
      setState(() => _isSearching = false);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If searching, show search results; otherwise show date-filtered activities
    final activities = _searchQuery.isNotEmpty ? _searchResults : _activities;
    final isLoading = _searchQuery.isNotEmpty ? _isSearching : _isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('EEE, d MMM yyyy');
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Column(
      children: [
        // Search bar (always on top)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _searchAcrossAllDates,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search all activities...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchAcrossAllDates('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        
        // Date selector row (only visible when not searching)
        if (_searchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        isToday ? 'Today' : dateFormat.format(_selectedDate),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isToday ? null : () => _changeDate(1),
                ),
              ],
            ),
          ),
        
        // Info text when searching
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Searching across all dates',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
        
        // Content
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : activities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timeline_outlined, size: 64, color: colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'No activities' : 'No activities found',
                            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        return _ActivityListItem(activity: activities[index]);
                      },
                    ),
        ),
      ],
    );
  }
}

/// Simple activity list item for Activities tab
class _ActivityListItem extends StatelessWidget {
  final Activity activity;
  
  const _ActivityListItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');
    final duration = activity.duration;
    final durationStr = '${duration.inHours}h ${duration.inMinutes % 60}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: activity.isRunning
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Time column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeFormat.format(activity.startTime.toLocal()),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (activity.endTime != null || activity.isRunning)
                Text(
                  activity.isRunning ? 'now' : timeFormat.format(activity.endTime!.toLocal()),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          
          // Activity info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (activity.category.isNotEmpty)
                  Text(
                    activity.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          
          // Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: activity.isRunning ? Colors.green.withValues(alpha: 0.2) : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              activity.isRunning ? 'Running' : durationStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: activity.isRunning ? Colors.green : colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Memos Tab Content with date filter and search
class _MemosTabContent extends StatefulWidget {
  const _MemosTabContent();

  @override
  State<_MemosTabContent> createState() => _MemosTabContentState();
}

class _MemosTabContentState extends State<_MemosTabContent> {
  final _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  List<MemoEntry> _memos = [];
  List<MemoEntry> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final memos = await dataRepository.getMemosForDate(_selectedDate);
      setState(() {
        _memos = memos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading memos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchAcrossAllDates(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });
    
    try {
      final results = await dataRepository.searchMemos(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching memos: $e');
      setState(() => _isSearching = false);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final memos = _searchQuery.isNotEmpty ? _searchResults : _memos;
    final isLoading = _searchQuery.isNotEmpty ? _isSearching : _isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('EEE, d MMM yyyy');
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Column(
      children: [
        // Search bar (always on top)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _searchAcrossAllDates,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search all memos...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchAcrossAllDates('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        
        // Date selector row (only visible when not searching)
        if (_searchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        isToday ? 'Today' : dateFormat.format(_selectedDate),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isToday ? null : () => _changeDate(1),
                ),
              ],
            ),
          ),
        
        // Info text when searching
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Searching across all dates',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
        
        // Content
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : memos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_outlined, size: 64, color: colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'No memos' : 'No memos found',
                            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: memos.length,
                      itemBuilder: (context, index) {
                        return _MemoListItem(memo: memos[index]);
                      },
                    ),
        ),
      ],
    );
  }
}

/// Simple memo list item
class _MemoListItem extends StatelessWidget {
  final MemoEntry memo;
  
  const _MemoListItem({required this.memo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                timeFormat.format(memo.timestamp.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  memo.source.name,
                  style: TextStyle(fontSize: 10, color: colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            memo.text,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Energy Tab Content with date filter and search
class _EnergyTabContent extends StatefulWidget {
  const _EnergyTabContent();

  @override
  State<_EnergyTabContent> createState() => _EnergyTabContentState();
}

class _EnergyTabContentState extends State<_EnergyTabContent> {
  DateTime _selectedDate = DateTime.now();
  List<EnergyCheck> _energyChecks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final checks = await dataRepository.getEnergyChecksForDate(_selectedDate);
      setState(() {
        _energyChecks = checks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading energy checks: $e');
      setState(() => _isLoading = false);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('EEE, d MMM yyyy');
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Column(
      children: [
        // Date selector row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeDate(-1),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      isToday ? 'Today' : dateFormat.format(_selectedDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isToday ? null : () => _changeDate(1),
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _energyChecks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.battery_4_bar, size: 64, color: colorScheme.outlineVariant),
                          const SizedBox(height: 16),
                          Text(
                            'No energy checks',
                            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _energyChecks.length,
                      itemBuilder: (context, index) {
                        return _EnergyListItem(check: _energyChecks[index]);
                      },
                    ),
        ),
      ],
    );
  }
}

/// Simple energy check list item
class _EnergyListItem extends StatelessWidget {
  final EnergyCheck check;
  
  const _EnergyListItem({required this.check});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            timeFormat.format(check.recordedAt.toLocal()),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Text(
                  check.level.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        check.level.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (check.note?.isNotEmpty ?? false)
                        Text(
                          check.note!,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
