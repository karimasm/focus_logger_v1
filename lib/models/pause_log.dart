import 'package:uuid/uuid.dart';
import 'sync_model.dart';

/// Represents a pause event during an activity
enum PauseReason {
  distraction('Distraction'),
  breakRest('Break / Rest'),
  taskSwitching('Task Switching'),
  adHocTask('Ad-Hoc Task'),
  other('Other');

  final String displayName;
  const PauseReason(this.displayName);

  static PauseReason fromString(String value) {
    return PauseReason.values.firstWhere(
      (e) => e.name == value || e.displayName == value,
      orElse: () => PauseReason.other,
    );
  }
}

class PauseLog implements SyncableModel {
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

  final String activityId;
  final String? userId;
  final DateTime pauseTime;
  final DateTime? resumeTime;
  final PauseReason reason;
  final String? customReason;

  PauseLog({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deviceId,
    this.syncStatus = SyncStatus.pending,
    required this.activityId,
    this.userId,
    required this.pauseTime,
    this.resumeTime,
    required this.reason,
    this.customReason,
  }) : 
    id = id ?? UuidHelper.generate(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  Duration get duration {
    final end = resumeTime ?? DateTime.now();
    return end.difference(pauseTime);
  }

  String get formattedDuration {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    } else {
      return '${d.inSeconds}s';
    }
  }

  String get displayReason {
    if (reason == PauseReason.other && customReason != null && customReason!.isNotEmpty) {
      return customReason!;
    }
    return reason.displayName;
  }

  PauseLog copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
    SyncStatus? syncStatus,
    String? activityId,
    String? userId,
    DateTime? pauseTime,
    DateTime? resumeTime,
    PauseReason? reason,
    String? customReason,
  }) {
    return PauseLog(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? SyncStatus.pending,
      activityId: activityId ?? this.activityId,
      userId: userId ?? this.userId,
      pauseTime: pauseTime ?? this.pauseTime,
      resumeTime: resumeTime ?? this.resumeTime,
      reason: reason ?? this.reason,
      customReason: customReason ?? this.customReason,
    );
  }

  @override
  PauseLog copyWithStatus(SyncStatus status) {
    return copyWith(syncStatus: status, updatedAt: updatedAt);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'sync_status': syncStatus.index,
      'activity_id': activityId,
      'pause_time': pauseTime.toIso8601String(),
      'resume_time': resumeTime?.toIso8601String(),
      'reason': reason.name,
      'custom_reason': customReason,
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
      'activity_id': activityId,
      'pause_time': pauseTime.toIso8601String(),
      'resume_time': resumeTime?.toIso8601String(),
      'reason': reason.name,
      'custom_reason': customReason,
    };
  }

  factory PauseLog.fromMap(Map<String, dynamic> map) {
    return PauseLog(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.values[map['sync_status'] as int? ?? 1],
      activityId: map['activity_id'] as String,
      pauseTime: DateTime.parse(map['pause_time'] as String),
      resumeTime: map['resume_time'] != null
          ? DateTime.parse(map['resume_time'] as String)
          : null,
      reason: PauseReason.fromString(map['reason'] as String),
      customReason: map['custom_reason'] as String?,
    );
  }

  /// Factory for parsing Supabase response
  factory PauseLog.fromSupabaseMap(Map<String, dynamic> map) {
    return PauseLog(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.synced,
      activityId: map['activity_id'] as String,
      pauseTime: DateTime.parse(map['pause_time'] as String),
      resumeTime: map['resume_time'] != null
          ? DateTime.parse(map['resume_time'] as String)
          : null,
      reason: PauseReason.fromString(map['reason'] as String? ?? 'other'),
      customReason: map['custom_reason'] as String?,
    );
  }

  @override
  String toString() {
    return 'PauseLog(id: $id, activityId: $activityId, pauseTime: $pauseTime, resumeTime: $resumeTime, reason: $reason)';
  }
}
