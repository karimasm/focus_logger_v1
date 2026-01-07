import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../models/sync_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('focus_logger_v2.db'); // Changed name to force fresh start safely
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    // Web does not support SQLite - must use Supabase directly
    // This guard prevents silent failures on Web platform
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite is not supported on Web platform. '
        'Use Supabase directly for data persistence on Web.'
      );
    }
    
    // Initialize FFI for Linux/Windows desktop
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = join(appDir.path, fileName);

    return await openDatabase(
      dbPath,
      version: 7, // V7: Added pause/alarm fields to adhoc_tasks
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new tables for Flow & Action Manager
      await _createAdHocTasksTable(db);
      await _createUserFlowTemplatesTable(db);
    }
    if (oldVersion < 3) {
      // Add energy checks table
      await _createEnergyChecksTable(db);
    }
    if (oldVersion < 4) {
      // Add unlogged blocks table for awareness-first auto-logging
      await _createUnloggedBlocksTable(db);
    }
    if (oldVersion < 5) {
      // Add was_skipped_haid column to guided_flow_logs for Haid Mode tracking
      await db.execute('''
        ALTER TABLE guided_flow_logs ADD COLUMN was_skipped_haid INTEGER DEFAULT 0
      ''');
    }
    if (oldVersion < 6) {
      // V6: USER-SCOPED SYNC - Add user_id to all synced tables
      debugPrint('[MIGRATION] Adding user_id column to all tables...');
      await db.execute('ALTER TABLE activities ADD COLUMN user_id TEXT');
      await db.execute('ALTER TABLE pause_logs ADD COLUMN user_id TEXT');
      await db.execute('ALTER TABLE guided_flow_logs ADD COLUMN user_id TEXT');
      await db.execute('ALTER TABLE memo_entries ADD COLUMN user_id TEXT');
      await db.execute('ALTER TABLE adhoc_tasks ADD COLUMN user_id TEXT');
      debugPrint('[MIGRATION] V6 migration complete - user_id added');
    }
    if (oldVersion < 7) {
      // V7: Add pause/alarm fields to adhoc_tasks
      debugPrint('[MIGRATION] Adding pause/alarm fields to adhoc_tasks...');
      await db.execute('ALTER TABLE adhoc_tasks ADD COLUMN is_paused INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE adhoc_tasks ADD COLUMN paused_at TEXT');
      await db.execute('ALTER TABLE adhoc_tasks ADD COLUMN paused_duration_seconds INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE adhoc_tasks ADD COLUMN alarm_time TEXT');
      await db.execute('ALTER TABLE adhoc_tasks ADD COLUMN alarm_triggered INTEGER DEFAULT 0');
      debugPrint('[MIGRATION] V7 migration complete - pause/alarm fields added');
    }
  }

  Future<void> _createAdHocTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS adhoc_tasks (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        device_id TEXT,
        sync_status INTEGER DEFAULT 1,
        user_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        execution_state INTEGER DEFAULT 0,
        started_at TEXT,
        completed_at TEXT,
        linked_activity_id TEXT,
        is_paused INTEGER DEFAULT 0,
        paused_at TEXT,
        paused_duration_seconds INTEGER DEFAULT 0,
        alarm_time TEXT,
        alarm_triggered INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (linked_activity_id) REFERENCES activities (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_adhoc_tasks_sync_status ON adhoc_tasks(sync_status)');
  }

  Future<void> _createUserFlowTemplatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_flow_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        linked_safety_window_id TEXT,
        initial_prompt TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_flow_steps (
        id TEXT PRIMARY KEY,
        flow_template_id TEXT NOT NULL,
        step_order INTEGER NOT NULL,
        if_condition TEXT NOT NULL,
        then_action TEXT NOT NULL,
        activity_name TEXT NOT NULL,
        description TEXT,
        estimated_minutes INTEGER,
        FOREIGN KEY (flow_template_id) REFERENCES user_flow_templates (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_user_flow_steps_template ON user_flow_steps(flow_template_id)');
  }
  
  Future<void> _createEnergyChecksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS energy_checks (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        device_id TEXT,
        sync_status INTEGER DEFAULT 1,
        activity_id TEXT,
        task_id TEXT,
        level INTEGER NOT NULL,
        recorded_at TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE SET NULL,
        FOREIGN KEY (task_id) REFERENCES adhoc_tasks (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_energy_checks_activity ON energy_checks(activity_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_energy_checks_sync ON energy_checks(sync_status)');
  }
  
  Future<void> _createUnloggedBlocksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS unlogged_blocks (
        id TEXT PRIMARY KEY,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_unlogged_blocks_start ON unlogged_blocks(start_time)');
  }

  Future<void> _createDB(Database db, int version) async {
    // Activities table (Synced) - USER-SCOPED
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT,
        device_id TEXT,
        sync_status INTEGER DEFAULT 1,
        name TEXT NOT NULL,
        category TEXT DEFAULT 'Uncategorized',
        start_time TEXT NOT NULL,
        end_time TEXT,
        is_auto_generated INTEGER DEFAULT 0,
        is_running INTEGER DEFAULT 0,
        is_paused INTEGER DEFAULT 0,
        paused_duration_seconds INTEGER DEFAULT 0,
        paused_at TEXT,
        source TEXT DEFAULT 'manual',
        guided_flow_id TEXT,
        chain_context TEXT
      )
    ''');

    // Pause logs table (Synced) - USER-SCOPED
    await db.execute('''
      CREATE TABLE pause_logs (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT,
        device_id TEXT,
        sync_status INTEGER DEFAULT 1,
        activity_id TEXT NOT NULL,
        pause_time TEXT NOT NULL,
        resume_time TEXT,
        reason TEXT NOT NULL,
        custom_reason TEXT,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');

    // Time slots table (Local Only - kept typical)
    // Note: activityId is now TEXT to match activities.id
    await db.execute('''
      CREATE TABLE time_slots (
        id TEXT PRIMARY KEY,
        slotStart TEXT NOT NULL,
        slotEnd TEXT NOT NULL,
        activityId TEXT,
        label TEXT DEFAULT 'Unlabeled',
        isEdited INTEGER DEFAULT 0,
        FOREIGN KEY (activityId) REFERENCES activities (id) ON DELETE SET NULL
      )
    ''');

    // Guided flow logs table (Synced) - USER-SCOPED
    await db.execute('''
      CREATE TABLE guided_flow_logs (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT,
        device_id TEXT,
        sync_status INTEGER DEFAULT 1,
        flow_id TEXT NOT NULL,
        flow_name TEXT NOT NULL,
        triggered_at TEXT NOT NULL,
        completed_at TEXT,
        steps_completed INTEGER DEFAULT 0,
        total_steps INTEGER NOT NULL,
        was_abandoned INTEGER DEFAULT 0,
        was_missed INTEGER DEFAULT 0,
        was_skipped_haid INTEGER DEFAULT 0
      )
    ''');

    // Guided flow state table (Local config state)
    await db.execute('''
      CREATE TABLE guided_flow_state (
        flowId TEXT PRIMARY KEY,
        lastTriggered TEXT,
        lastCompleted TEXT,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // Memo entries table (Synced) - USER-SCOPED
    await db.execute('''
      CREATE TABLE memo_entries (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT,
        device_id TEXT,
        sync_status INTEGER DEFAULT 1,
        activity_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        text TEXT NOT NULL,
        source TEXT DEFAULT 'manual',
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');

    // Safety windows table (Local config)
    await db.execute('''
      CREATE TABLE safety_windows (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        startHour INTEGER NOT NULL,
        startMinute INTEGER NOT NULL,
        endHour INTEGER NOT NULL,
        endMinute INTEGER NOT NULL,
        linkedFlowId TEXT NOT NULL,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_activities_start_time ON activities(start_time)');
    await db.execute('CREATE INDEX idx_activities_is_running ON activities(is_running)');
    await db.execute('CREATE INDEX idx_activities_sync_status ON activities(sync_status)');
    
    await db.execute('CREATE INDEX idx_pause_logs_activity_id ON pause_logs(activity_id)');
    await db.execute('CREATE INDEX idx_pause_logs_sync_status ON pause_logs(sync_status)');
    
    await db.execute('CREATE INDEX idx_guided_flow_logs_triggered_at ON guided_flow_logs(triggered_at)');
    await db.execute('CREATE INDEX idx_guided_flow_logs_sync_status ON guided_flow_logs(sync_status)');
    
    await db.execute('CREATE INDEX idx_memo_entries_activity_id ON memo_entries(activity_id)');
    await db.execute('CREATE INDEX idx_memo_entries_sync_status ON memo_entries(sync_status)');

    // V2 tables
    await _createAdHocTasksTable(db);
    await _createUserFlowTemplatesTable(db);
    
    // V3 tables
    await _createEnergyChecksTable(db);
    
    // V4 tables
    await _createUnloggedBlocksTable(db);
  }

  // ==================== ACTIVITY CRUD ====================
  Future<int> insertActivity(Activity activity) async {
    final db = await database;
    return await db.insert('activities', activity.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Activity?> getActivity(String id) async {
    final db = await database;
    final maps = await db.query('activities', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Activity.fromMap(maps.first) : null;
  }

  Future<Activity?> getRunningActivity() async {
    final db = await database;
    final maps = await db.query('activities', where: 'is_running = 1', limit: 1);
    return maps.isNotEmpty ? Activity.fromMap(maps.first) : null;
  }

  Future<List<Activity>> getActivitiesForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'activities',
      where: 'start_time >= ? AND start_time < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'start_time ASC',
    );
    return maps.map((map) => Activity.fromMap(map)).toList();
  }

  Future<int> updateActivity(Activity activity) async {
    final db = await database;
    return await db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get running activities that started before a given time
  /// Used for sanitizing orphaned activities
  Future<List<Activity>> getRunningActivitiesOlderThan(DateTime cutoff) async {
    final db = await database;
    final maps = await db.query(
      'activities',
      where: 'is_running = 1 AND start_time < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
    return maps.map((map) => Activity.fromMap(map)).toList();
  }

  Future<int> deleteActivity(String id) async {
    final db = await database;
    return await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== PAUSE LOG CRUD ====================
  Future<int> insertPauseLog(PauseLog pauseLog) async {
    final db = await database;
    return await db.insert('pause_logs', pauseLog.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PauseLog>> getPauseLogsForActivity(String activityId) async {
    final db = await database;
    final maps = await db.query(
      'pause_logs',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'pause_time ASC',
    );
    return maps.map((map) => PauseLog.fromMap(map)).toList();
  }

  Future<PauseLog?> getActivePauseLog(String activityId) async {
    final db = await database;
    final maps = await db.query(
      'pause_logs',
      where: 'activity_id = ? AND resume_time IS NULL',
      whereArgs: [activityId],
      limit: 1,
    );
    return maps.isNotEmpty ? PauseLog.fromMap(maps.first) : null;
  }

  Future<int> updatePauseLog(PauseLog pauseLog) async {
    final db = await database;
    return await db.update(
      'pause_logs',
      pauseLog.toMap(),
      where: 'id = ?',
      whereArgs: [pauseLog.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== TIME SLOT CRUD ====================
  Future<int> insertTimeSlot(TimeSlot timeSlot) async {
    final db = await database;
    return await db.insert('time_slots', timeSlot.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TimeSlot>> getTimeSlotsForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'time_slots',
      where: 'slotStart >= ? AND slotStart < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'slotStart ASC',
    );
    return maps.map((map) => TimeSlot.fromMap(map)).toList();
  }

  Future<int> updateTimeSlot(TimeSlot timeSlot) async {
    final db = await database;
    return await db.update(
      'time_slots',
      timeSlot.toMap(),
      where: 'id = ?',
      whereArgs: [timeSlot.id],
    );
  }

  // ==================== GUIDED FLOW LOG CRUD ====================
  Future<int> insertGuidedFlowLog(GuidedFlowLog log) async {
    final db = await database;
    return await db.insert('guided_flow_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GuidedFlowLog>> getGuidedFlowLogsForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'guided_flow_logs',
      where: 'triggered_at >= ? AND triggered_at < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'triggered_at ASC',
    );
    return maps.map((map) => GuidedFlowLog.fromMap(map)).toList();
  }

  Future<int> updateGuidedFlowLog(GuidedFlowLog log) async {
    final db = await database;
    return await db.update(
      'guided_flow_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> logMissedRitual(String flowId, String flowName, DateTime windowEnd) async {
    final log = GuidedFlowLog(
      flowId: flowId,
      flowName: flowName,
      triggeredAt: windowEnd,
      completedAt: windowEnd,
      stepsCompleted: 0,
      totalSteps: 0,
      wasMissed: true,
      syncStatus: SyncStatus.pending,
    );
    await insertGuidedFlowLog(log);
  }

  Future<Set<String>> getCompletedFlowIdsForDate(DateTime date) async {
    final logs = await getGuidedFlowLogsForDate(date);
    return logs
        .where((log) => log.isCompleted)
        .map((log) => log.flowId)
        .toSet();
  }

  // ==================== GUIDED FLOW STATE (Local config) ====================
  Future<void> updateGuidedFlowLastTriggered(String flowId, DateTime time) async {
    final db = await database;
    await db.insert('guided_flow_state', {
      'flowId': flowId,
      'lastTriggered': time.toIso8601String(),
      'isActive': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGuidedFlowLastCompleted(String flowId, DateTime time) async {
    final db = await database;
    await db.insert('guided_flow_state', {
      'flowId': flowId,
      'lastCompleted': time.toIso8601String(),
      'isActive': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DateTime?> getGuidedFlowLastTriggered(String flowId) async {
    final db = await database;
    final maps = await db.query('guided_flow_state', where: 'flowId = ?', whereArgs: [flowId], limit: 1);
    return maps.isNotEmpty && maps.first['lastTriggered'] != null 
        ? DateTime.parse(maps.first['lastTriggered'] as String) : null;
  }

  Future<DateTime?> getGuidedFlowLastCompleted(String flowId) async {
    final db = await database;
    final maps = await db.query('guided_flow_state', where: 'flowId = ?', whereArgs: [flowId], limit: 1);
    return maps.isNotEmpty && maps.first['lastCompleted'] != null 
        ? DateTime.parse(maps.first['lastCompleted'] as String) : null;
  }

  // ==================== MEMO ENTRY CRUD ====================
  Future<int> insertMemoEntry(MemoEntry memo) async {
    final db = await database;
    return await db.insert('memo_entries', memo.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MemoEntry>> getMemosForActivity(String activityId) async {
    final db = await database;
    final maps = await db.query(
      'memo_entries',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => MemoEntry.fromMap(map)).toList();
  }

  Future<int> updateMemoEntry(MemoEntry memo) async {
    final db = await database;
    return await db.update('memo_entries', memo.toMap(), where: 'id = ?', whereArgs: [memo.id], conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteMemoEntry(String id) async {
    final db = await database;
    return await db.delete('memo_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== SYNC SUPPORT ====================
  
  /// Get all pending sync items for a specific table
  Future<List<Map<String, dynamic>>> getPendingSyncItems(String tableName) async {
    final db = await database;
    return await db.query(
      tableName,
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: [SyncStatus.pending.index, SyncStatus.conflict.index],
    );
  }

  /// Mark items as synced
  Future<void> markAsSynced(String tableName, String id) async {
    final db = await database;
    await db.update(
      tableName,
      {'sync_status': SyncStatus.synced.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Bulk upsert from backend (ignores sync_status update to avoid loop)
  Future<void> upsertFromSync(String tableName, Map<String, dynamic> item) async {
    final db = await database;
    // item should already be formatted for local DB (mapped keys)
    // Ensure we mark it as synced since it came from the server
    final localItem = Map<String, dynamic>.from(item);
    localItem['sync_status'] = SyncStatus.synced.index;
    
    await db.insert(
      tableName,
      localItem,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Get summary statistics for a date
  Future<Map<String, Duration>> getActivityDurationsForDate(DateTime date) async {
    final activities = await getActivitiesForDate(date);
    final Map<String, Duration> durations = {};
    for (final activity in activities) {
      final current = durations[activity.name] ?? Duration.zero;
      durations[activity.name] = current + activity.duration;
    }
    return durations;
  }

  // ==================== ADHOC TASKS CRUD ====================
  Future<int> insertAdHocTask(AdHocTask task) async {
    final db = await database;
    return await db.insert('adhoc_tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AdHocTask>> getAllAdHocTasks() async {
    final db = await database;
    final maps = await db.query('adhoc_tasks', orderBy: 'sort_order ASC, created_at DESC');
    return maps.map((m) => AdHocTask.fromMap(m)).toList();
  }

  Future<List<AdHocTask>> getPendingAdHocTasks() async {
    final db = await database;
    final maps = await db.query(
      'adhoc_tasks',
      where: 'execution_state = ?',
      whereArgs: [TaskExecutionState.pending.index],
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return maps.map((m) => AdHocTask.fromMap(m)).toList();
  }

  Future<List<AdHocTask>> getInProgressAdHocTasks() async {
    final db = await database;
    final maps = await db.query(
      'adhoc_tasks',
      where: 'execution_state = ?',
      whereArgs: [TaskExecutionState.inProgress.index],
    );
    return maps.map((m) => AdHocTask.fromMap(m)).toList();
  }

  Future<List<AdHocTask>> getCompletedAdHocTasks() async {
    final db = await database;
    final maps = await db.query(
      'adhoc_tasks',
      where: 'execution_state = ?',
      whereArgs: [TaskExecutionState.completed.index],
      orderBy: 'completed_at DESC',
    );
    return maps.map((m) => AdHocTask.fromMap(m)).toList();
  }

  Future<int> updateAdHocTask(AdHocTask task) async {
    final db = await database;
    return await db.update('adhoc_tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteAdHocTask(String id) async {
    final db = await database;
    return await db.delete('adhoc_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCompletedAdHocTasks() async {
    final db = await database;
    await db.delete('adhoc_tasks', where: 'execution_state = ?', whereArgs: [TaskExecutionState.completed.index]);
  }

  // ==================== USER FLOW TEMPLATES CRUD ====================
  Future<int> insertUserFlowTemplate(UserFlowTemplate template) async {
    final db = await database;
    // Insert template
    final result = await db.insert('user_flow_templates', template.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    // Insert steps
    for (final step in template.steps) {
      await db.insert('user_flow_steps', step.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return result;
  }

  Future<List<UserFlowTemplate>> getAllUserFlowTemplates() async {
    final db = await database;
    final templateMaps = await db.query('user_flow_templates', orderBy: 'name ASC');
    
    final templates = <UserFlowTemplate>[];
    for (final map in templateMaps) {
      final stepMaps = await db.query(
        'user_flow_steps',
        where: 'flow_template_id = ?',
        whereArgs: [map['id']],
        orderBy: 'step_order ASC',
      );
      final steps = stepMaps.map((s) => UserFlowStep.fromMap(s)).toList();
      templates.add(UserFlowTemplate.fromMap(map, steps));
    }
    return templates;
  }

  Future<UserFlowTemplate?> getUserFlowTemplate(String id) async {
    final db = await database;
    final templateMaps = await db.query('user_flow_templates', where: 'id = ?', whereArgs: [id]);
    if (templateMaps.isEmpty) return null;
    
    final stepMaps = await db.query(
      'user_flow_steps',
      where: 'flow_template_id = ?',
      whereArgs: [id],
      orderBy: 'step_order ASC',
    );
    final steps = stepMaps.map((s) => UserFlowStep.fromMap(s)).toList();
    return UserFlowTemplate.fromMap(templateMaps.first, steps);
  }

  /// Get template linked to a specific safety window
  Future<UserFlowTemplate?> getTemplateByWindowId(String windowId) async {
    final db = await database;
    final templateMaps = await db.query(
      'user_flow_templates', 
      where: 'linked_safety_window_id = ? AND is_active = 1', 
      whereArgs: [windowId],
    );
    if (templateMaps.isEmpty) return null;
    
    final stepMaps = await db.query(
      'user_flow_steps',
      where: 'flow_template_id = ?',
      whereArgs: [templateMaps.first['id']],
      orderBy: 'step_order ASC',
    );
    final steps = stepMaps.map((s) => UserFlowStep.fromMap(s)).toList();
    return UserFlowTemplate.fromMap(templateMaps.first, steps);
  }

  Future<int> updateUserFlowTemplate(UserFlowTemplate template) async {
    final db = await database;
    // Update template
    final result = await db.update('user_flow_templates', template.toMap(), where: 'id = ?', whereArgs: [template.id]);
    // Delete old steps and insert new ones
    await db.delete('user_flow_steps', where: 'flow_template_id = ?', whereArgs: [template.id]);
    for (final step in template.steps) {
      await db.insert('user_flow_steps', step.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return result;
  }

  Future<int> deleteUserFlowTemplate(String id) async {
    final db = await database;
    await db.delete('user_flow_steps', where: 'flow_template_id = ?', whereArgs: [id]);
    return await db.delete('user_flow_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== ENERGY CHECKS CRUD ====================
  Future<int> insertEnergyCheck(EnergyCheck check) async {
    final db = await database;
    return await db.insert('energy_checks', check.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<EnergyCheck>> getEnergyChecksForActivity(String activityId) async {
    final db = await database;
    final maps = await db.query(
      'energy_checks',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'recorded_at DESC',
    );
    return maps.map((m) => EnergyCheck.fromMap(m)).toList();
  }

  Future<List<EnergyCheck>> getEnergyChecksForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final maps = await db.query(
      'energy_checks',
      where: 'recorded_at >= ? AND recorded_at < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'recorded_at DESC',
    );
    return maps.map((m) => EnergyCheck.fromMap(m)).toList();
  }

  Future<EnergyCheck?> getLatestEnergyCheck() async {
    final db = await database;
    final maps = await db.query(
      'energy_checks',
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? EnergyCheck.fromMap(maps.first) : null;
  }

  // ==================== UNLOGGED BLOCKS CRUD ====================
  // For awareness-first auto-logging - track 30-minute blocks without logged activity
  
  Future<int> insertUnloggedBlock(UnloggedBlock block) async {
    final db = await database;
    return await db.insert('unlogged_blocks', block.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<UnloggedBlock>> getUnloggedBlocksForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'unlogged_blocks',
      where: 'start_time >= ? AND start_time < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'start_time DESC',
    );
    
    // Return properly typed UnloggedBlock list
    return maps.map((m) => UnloggedBlock.fromMap(m)).toList();
  }

  Future<int> deleteUnloggedBlock(String id) async {
    final db = await database;
    return await db.delete('unlogged_blocks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearOldUnloggedBlocks() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await db.delete(
      'unlogged_blocks',
      where: 'created_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }
}

