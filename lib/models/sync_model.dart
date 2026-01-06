import 'package:uuid/uuid.dart';

/// Standardized sync status for all records
enum SyncStatus {
  synced,   // Record is safely in Supabase
  pending,  // Created/Updated locally, needs push
  conflict  // Version mismatch, needs resolution
}

/// Abstract base class for all syncable models
/// Ensures every table has the required fields for replication
abstract class SyncableModel {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  String? get deviceId;
  SyncStatus get syncStatus;
  
  /// Create copy with updated sync status
  SyncableModel copyWithStatus(SyncStatus status);
  
  /// Convert to map for local SQLite (includes sync_status)
  Map<String, dynamic> toMap();
  
  /// Convert to map for Supabase (excludes local-only fields like sync_status)
  Map<String, dynamic> toSupabaseMap();
}

/// Helper to generate UUIDs
class UuidHelper {
  static const _uuid = Uuid();
  static String generate() => _uuid.v4(); 
}
