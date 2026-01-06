import 'sync_model.dart';
import 'package:uuid/uuid.dart';

/// Memo entry for in-context notes during activities
/// Does NOT stop the activity - just adds contextual notes
/// USER-SCOPED: Owned by user_id
class MemoEntry implements SyncableModel {
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
  
  /// USER-SCOPED: Owner of this memo
  final String? userId;

  final String activityId;
  final DateTime timestamp;
  final String text;
  final MemoSource source;

  MemoEntry({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deviceId,
    this.userId,
    this.syncStatus = SyncStatus.pending,
    required this.activityId,
    required this.timestamp,
    required this.text,
    this.source = MemoSource.manual,
  }) : 
    id = id ?? UuidHelper.generate(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  Duration get timeSinceCreation => DateTime.now().difference(timestamp);

  MemoEntry copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
    String? userId,
    SyncStatus? syncStatus,
    String? activityId,
    DateTime? timestamp,
    String? text,
    MemoSource? source,
  }) {
    return MemoEntry(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      syncStatus: syncStatus ?? SyncStatus.pending,
      activityId: activityId ?? this.activityId,
      timestamp: timestamp ?? this.timestamp,
      text: text ?? this.text,
      source: source ?? this.source,
    );
  }

  @override
  MemoEntry copyWithStatus(SyncStatus status) {
    return copyWith(syncStatus: status, updatedAt: updatedAt);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
      'device_id': deviceId,
      'sync_status': syncStatus.index,
      'activity_id': activityId,
      'timestamp': timestamp.toIso8601String(),
      'text': text,
      'source': source.name,
    };
  }

  @override
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
      'device_id': deviceId,
      'activity_id': activityId,
      'timestamp': timestamp.toIso8601String(),
      'text': text,
      'source': source.name,
    };
  }

  factory MemoEntry.fromMap(Map<String, dynamic> map) {
    return MemoEntry(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userId: map['user_id'] as String?,
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.values[map['sync_status'] as int? ?? 1],
      activityId: map['activity_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      text: map['text'] as String,
      source: MemoSource.fromString(map['source'] as String? ?? 'manual'),
    );
  }

  /// Factory for parsing Supabase response
  factory MemoEntry.fromSupabaseMap(Map<String, dynamic> map) {
    return MemoEntry(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userId: map['user_id'] as String?,
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.synced,
      activityId: map['activity_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      text: map['text'] as String,
      source: MemoSource.fromString(map['source'] as String? ?? 'manual'),
    );
  }

  @override
  String toString() {
    return 'MemoEntry(id: $id, activityId: $activityId, text: $text, source: $source)';
  }
}

/// Source of the memo
enum MemoSource {
  manual('Manual'),
  voice('Voice'),
  idleReflection('Idle Reflection');

  final String displayName;
  const MemoSource(this.displayName);

  static MemoSource fromString(String value) {
    return MemoSource.values.firstWhere(
      (e) => e.name == value || e.name == 'idle_reflection' && value == 'idle_reflection',
      orElse: () => MemoSource.manual,
    );
  }
}
