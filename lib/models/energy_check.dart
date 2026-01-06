import 'package:uuid/uuid.dart';
import 'sync_model.dart';

/// Energy level after completing a task (1-5 scale)
enum EnergyLevel {
  veryLow('Very Low', '😫', 1),
  low('Low', '😓', 2),
  medium('Medium', '😐', 3),
  high('High', '😊', 4),
  veryHigh('Very High', '⚡', 5);
  
  final String displayName;
  final String emoji;
  final int value;
  const EnergyLevel(this.displayName, this.emoji, this.value);
  
  static EnergyLevel fromString(String value) {
    return EnergyLevel.values.firstWhere(
      (e) => e.name == value || e.displayName == value,
      orElse: () => EnergyLevel.medium,
    );
  }
  
  static EnergyLevel fromValue(int value) {
    return EnergyLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EnergyLevel.medium,
    );
  }
}

/// Energy check entry after completing an activity or task
class EnergyCheck implements SyncableModel {
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
  
  final String? activityId;
  final String? taskId;
  final EnergyLevel level;
  final DateTime recordedAt;
  final String? note;
  
  EnergyCheck({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deviceId,
    this.syncStatus = SyncStatus.pending,
    this.activityId,
    this.taskId,
    required this.level,
    DateTime? recordedAt,
    this.note,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       recordedAt = recordedAt ?? DateTime.now();
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'sync_status': syncStatus.index,
      'activity_id': activityId,
      'task_id': taskId,
      'level': level.index,
      'recorded_at': recordedAt.toIso8601String(),
      'note': note,
    };
  }
  
  @override
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'activity_id': activityId,
      'task_id': taskId,
      'level': level.index,
      'recorded_at': recordedAt.toIso8601String(),
      'note': note,
    };
  }
  
  factory EnergyCheck.fromMap(Map<String, dynamic> map) {
    return EnergyCheck(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.values[map['sync_status'] as int? ?? 0],
      activityId: map['activity_id'] as String?,
      taskId: map['task_id'] as String?,
      level: EnergyLevel.values[map['level'] as int? ?? 1],
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      note: map['note'] as String?,
    );
  }
  
  EnergyCheck copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
    SyncStatus? syncStatus,
    String? activityId,
    String? taskId,
    EnergyLevel? level,
    DateTime? recordedAt,
    String? note,
  }) {
    return EnergyCheck(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? SyncStatus.pending,
      activityId: activityId ?? this.activityId,
      taskId: taskId ?? this.taskId,
      level: level ?? this.level,
      recordedAt: recordedAt ?? this.recordedAt,
      note: note ?? this.note,
    );
  }
  
  @override
  EnergyCheck copyWithStatus(SyncStatus status) {
    return copyWith(syncStatus: status);
  }
}
