import 'package:uuid/uuid.dart';
import 'sync_model.dart';

/// Represents an ad-hoc one-off task with activity logging integration
/// Unlike simple todos, these tasks track execution time and integrate with the timeline
class AdHocTask implements SyncableModel {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String? deviceId;
  @override
  final SyncStatus syncStatus;

  final String? userId;
  final String title;
  final String? description;
  
  // Execution state
  final TaskExecutionState executionState;
  final DateTime? startedAt;    // When "ON IT" was pressed
  final DateTime? completedAt;  // When "DONE" was pressed
  final String? linkedActivityId; // Reference to logged activity
  
  final int sortOrder;

  AdHocTask({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deviceId,
    this.syncStatus = SyncStatus.pending,
    this.userId,
    required this.title,
    this.description,
    this.executionState = TaskExecutionState.pending,
    this.startedAt,
    this.completedAt,
    this.linkedActivityId,
    this.sortOrder = 0,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  /// Age indicator - how long has this task been waiting
  Duration get age => DateTime.now().difference(createdAt);
  
  String get ageDescription {
    final d = age;
    if (d.inDays > 0) {
      return 'created ${d.inDays} day${d.inDays > 1 ? 's' : ''} ago';
    } else if (d.inHours > 0) {
      return 'created ${d.inHours} hour${d.inHours > 1 ? 's' : ''} ago';
    } else if (d.inMinutes > 0) {
      return 'created ${d.inMinutes} minute${d.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'just created';
    }
  }

  /// Duration of execution (from ON IT to DONE)
  Duration? get executionDuration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  AdHocTask copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
    SyncStatus? syncStatus,
    String? userId,
    String? title,
    String? description,
    TaskExecutionState? executionState,
    DateTime? startedAt,
    DateTime? completedAt,
    String? linkedActivityId,
    int? sortOrder,
  }) {
    return AdHocTask(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? SyncStatus.pending,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      executionState: executionState ?? this.executionState,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      linkedActivityId: linkedActivityId ?? this.linkedActivityId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  AdHocTask copyWithStatus(SyncStatus status) {
    return copyWith(syncStatus: status);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'sync_status': syncStatus.index,
      'title': title,
      'description': description,
      'execution_state': executionState.index,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'linked_activity_id': linkedActivityId,
      'sort_order': sortOrder,
    };
  }

  @override
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'user_id': userId,
      'title': title,
      'description': description,
      'execution_state': executionState.index,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'linked_activity_id': linkedActivityId,
      'sort_order': sortOrder,
    };
  }

  factory AdHocTask.fromMap(Map<String, dynamic> map) {
    return AdHocTask(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.values[map['sync_status'] as int? ?? 1],
      title: map['title'] as String,
      description: map['description'] as String?,
      executionState: TaskExecutionState.values[map['execution_state'] as int? ?? 0],
      startedAt: map['started_at'] != null 
          ? DateTime.parse(map['started_at'] as String) 
          : null,
      completedAt: map['completed_at'] != null 
          ? DateTime.parse(map['completed_at'] as String) 
          : null,
      linkedActivityId: map['linked_activity_id'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  /// Factory for parsing Supabase response
  factory AdHocTask.fromSupabaseMap(Map<String, dynamic> map) {
    return AdHocTask(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.synced,
      title: map['title'] as String,
      description: map['description'] as String?,
      executionState: TaskExecutionState.values[map['execution_state'] as int? ?? 0],
      startedAt: map['started_at'] != null 
          ? DateTime.parse(map['started_at'] as String) 
          : null,
      completedAt: map['completed_at'] != null 
          ? DateTime.parse(map['completed_at'] as String) 
          : null,
      linkedActivityId: map['linked_activity_id'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

/// Execution state for ad-hoc tasks
enum TaskExecutionState {
  pending,    // Never started
  inProgress, // "ON IT" pressed, running
  completed,  // "DONE" pressed
}
