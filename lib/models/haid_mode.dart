import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../services/user_service.dart';
import 'sync_model.dart';

/// Haid Mode - tracks menstrual period for prayer flow skipping
/// While active, prayer and Qur'an flows are automatically skipped
/// without being marked as missed or failed.
class HaidMode implements SyncableModel {
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
  
  final bool isActive;
  final DateTime? startDate;
  final DateTime? lastPromptDate;

  const HaidMode({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
    this.syncStatus = SyncStatus.pending,
    this.isActive = false,
    this.startDate,
    this.lastPromptDate,
  });

  /// Days since Haid Mode was activated
  int get daysSinceStart {
    if (startDate == null) return 0;
    return DateTime.now().difference(startDate!).inDays;
  }

  /// Whether we should prompt user to check if still on period (after 5-7 days)
  bool get shouldPromptCheck {
    if (!isActive || startDate == null) return false;
    final days = daysSinceStart;
    // Prompt between day 5 and day 10
    if (days >= 5 && days <= 10) {
      // Don't prompt more than once per day
      if (lastPromptDate != null) {
        final daysSincePrompt = DateTime.now().difference(lastPromptDate!).inDays;
        return daysSincePrompt >= 1;
      }
      return true;
    }
    return false;
  }

  /// Categories that should be skipped during Haid
  static const List<String> skippedCategories = ['prayer', 'quran', 'sholat'];
  
  /// Check if a flow category should be skipped
  bool shouldSkipCategory(String category) {
    if (!isActive) return false;
    return skippedCategories.contains(category.toLowerCase());
  }

  HaidMode copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
    SyncStatus? syncStatus,
    bool? isActive,
    DateTime? startDate,
    DateTime? lastPromptDate,
  }) {
    return HaidMode(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? SyncStatus.pending,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      lastPromptDate: lastPromptDate ?? this.lastPromptDate,
    );
  }

  @override
  HaidMode copyWithStatus(SyncStatus status) {
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
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'last_prompt_date': lastPromptDate?.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'user_id': UserService().currentUserId,
      'is_active': isActive ? 1 : 0,
      'cycle_start_at': startDate?.toIso8601String(),
      'last_prompt_date': lastPromptDate?.toIso8601String(),
    };
  }

  factory HaidMode.fromMap(Map<String, dynamic> map) {
    return HaidMode(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deviceId: map['device_id'] as String?,
      syncStatus: SyncStatus.values[map['sync_status'] as int? ?? 1],
      isActive: map['is_active'] as bool? ?? false,
      startDate: map['start_date'] != null 
          ? DateTime.parse(map['start_date'] as String) 
          : null,
      lastPromptDate: map['last_prompt_date'] != null 
          ? DateTime.parse(map['last_prompt_date'] as String) 
          : null,
    );
  }
}

/// Service for persisting Haid Mode state
class HaidModeService {
  static const _keyId = 'haid_mode_id';
  static const _keyCreatedAt = 'haid_mode_created_at';
  static const _keyUpdatedAt = 'haid_mode_updated_at';
  static const _keyDeviceId = 'haid_mode_device_id';
  static const _keySyncStatus = 'haid_mode_sync_status';
  static const _keyIsActive = 'haid_mode_active';
  static const _keyStartDate = 'haid_mode_start_date';
  static const _keyLastPrompt = 'haid_mode_last_prompt';

  /// Load Haid Mode state from preferences
  static Future<HaidMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // If no ID exists, create a new default HaidMode
    final id = prefs.getString(_keyId);
    if (id == null) {
      final now = DateTime.now();
      return HaidMode(
        id: UuidHelper.generate(),
        createdAt: now,
        updatedAt: now,
        isActive: false,
      );
    }
    
    return HaidMode(
      id: id,
      createdAt: prefs.getString(_keyCreatedAt) != null
          ? DateTime.parse(prefs.getString(_keyCreatedAt)!)
          : DateTime.now(),
      updatedAt: prefs.getString(_keyUpdatedAt) != null
          ? DateTime.parse(prefs.getString(_keyUpdatedAt)!)
          : DateTime.now(),
      deviceId: prefs.getString(_keyDeviceId),
      syncStatus: SyncStatus.values[prefs.getInt(_keySyncStatus) ?? 1],
      isActive: prefs.getBool(_keyIsActive) ?? false,
      startDate: prefs.getString(_keyStartDate) != null
          ? DateTime.parse(prefs.getString(_keyStartDate)!)
          : null,
      lastPromptDate: prefs.getString(_keyLastPrompt) != null
          ? DateTime.parse(prefs.getString(_keyLastPrompt)!)
          : null,
    );
  }

  /// Save Haid Mode state to preferences
  static Future<void> save(HaidMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId, mode.id);
    await prefs.setString(_keyCreatedAt, mode.createdAt.toIso8601String());
    await prefs.setString(_keyUpdatedAt, mode.updatedAt.toIso8601String());
    
    if (mode.deviceId != null) {
      await prefs.setString(_keyDeviceId, mode.deviceId!);
    } else {
      await prefs.remove(_keyDeviceId);
    }
    
    await prefs.setInt(_keySyncStatus, mode.syncStatus.index);
    await prefs.setBool(_keyIsActive, mode.isActive);
    
    if (mode.startDate != null) {
      await prefs.setString(_keyStartDate, mode.startDate!.toIso8601String());
    } else {
      await prefs.remove(_keyStartDate);
    }
    
    if (mode.lastPromptDate != null) {
      await prefs.setString(_keyLastPrompt, mode.lastPromptDate!.toIso8601String());
    } else {
      await prefs.remove(_keyLastPrompt);
    }
  }

  /// Activate Haid Mode
  static Future<HaidMode> activate() async {
    final current = await load();
    final now = DateTime.now();
    final mode = current.copyWith(
      updatedAt: now,
      syncStatus: SyncStatus.pending,
      isActive: true,
      startDate: now,
    );
    await save(mode);
    return mode;
  }

  /// Deactivate Haid Mode
  static Future<HaidMode> deactivate() async {
    final current = await load();
    final mode = current.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
      isActive: false,
    );
    await save(mode);
    return mode;
  }

  /// Mark that we prompted the user today
  static Future<HaidMode> markPrompted(HaidMode current) async {
    final mode = current.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
      lastPromptDate: DateTime.now(),
    );
    await save(mode);
    return mode;
  }

  /// Push Haid Mode state to Supabase
  static Future<void> syncToSupabase(HaidMode mode) async {
    try {
      final supabase = Supabase.instance.client;
      final supabaseData = mode.toSupabaseMap();
      
      // Upsert to Supabase haid_mode table
      await supabase.from('haid_mode').upsert(supabaseData);
      
      // Mark as synced locally
      final syncedMode = mode.copyWith(syncStatus: SyncStatus.synced);
      await save(syncedMode);
      
      debugPrint('✅ Haid Mode synced to Supabase');
    } catch (e) {
      debugPrint('❌ Failed to sync Haid Mode to Supabase: $e');
      rethrow;
    }
  }

  /// Pull Haid Mode state from Supabase
  static Future<HaidMode?> pullFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Query the haid_mode table (should only have one record per user)
      final response = await supabase
          .from('haid_mode')
          .select()
          .order('updated_at', ascending: false)
          .limit(1);
      
      if (response.isEmpty) {
        debugPrint('📥 No Haid Mode found in Supabase');
        return null;
      }
      
      final remoteData = response.first;
      
      // Load local version
      final localMode = await load();
      
      // Conflict resolution: latest updated_at wins
      final remoteUpdatedAt = DateTime.parse(remoteData['updated_at'] as String);
      
      if (remoteUpdatedAt.isAfter(localMode.updatedAt)) {
        // Remote is newer, use it
        final remoteMode = HaidMode(
          id: remoteData['id'] as String,
          createdAt: DateTime.parse(remoteData['created_at'] as String),
          updatedAt: remoteUpdatedAt,
          deviceId: remoteData['device_id'] as String?,
          syncStatus: SyncStatus.synced,
          isActive: (remoteData['is_active'] as int) == 1,
          startDate: remoteData['cycle_start_at'] != null
              ? DateTime.parse(remoteData['cycle_start_at'] as String)
              : null,
          lastPromptDate: remoteData['last_prompt_date'] != null
              ? DateTime.parse(remoteData['last_prompt_date'] as String)
              : null,
        );
        
        await save(remoteMode);
        debugPrint('📥 Pulled newer Haid Mode from Supabase');
        return remoteMode;
      } else {
        // Local is newer or same, keep local
        debugPrint('📥 Local Haid Mode is up to date');
        return localMode;
      }
    } catch (e) {
      debugPrint('❌ Failed to pull Haid Mode from Supabase: $e');
      return null;
    }
  }
}
