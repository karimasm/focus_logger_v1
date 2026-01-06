import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'user_service.dart';

/// Sync event types for event-based synchronization
enum SyncEvent {
  activityStarted,
  activityDone,
  adHocCreated,
  adHocCompleted,
  memoAdded,
  paused,
  resumed,
  appOpened,
  manualSync,
  haidModeChange,
}

/// SIMPLIFIED SYNC SERVICE - SERVER AUTHORITATIVE
/// 
/// CUT-OVER TO NEW MODEL:
/// - Server (Supabase) is single source of truth
/// - No local queue / push logic
/// - No local-first behavior
/// - All reads/writes go directly to server
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  
  bool _isSyncing = false;
  Timer? _bgSyncTimer;
  
  // Callbacks for UI updates
  final List<VoidCallback> _syncListeners = [];

  // Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;
  
  // Getters
  int get pendingChangesCount => 0; // No local queue anymore
  bool get isSyncing => _isSyncing;

  void addListener(VoidCallback listener) {
    _syncListeners.add(listener);
  }
  
  void removeListener(VoidCallback listener) {
    _syncListeners.remove(listener);
  }
  
  void _notifyListeners() {
    for (final listener in _syncListeners) {
      listener();
    }
  }

  /// Start background sync service (simplified - just connectivity check)
  void startBackgroundSync() {
    _bgSyncTimer?.cancel();
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
       bool hasConnection = results.any((r) => r != ConnectivityResult.none);
       if (hasConnection) {
         debugPrint('[SYNC] Back online - refreshing data');
         _notifyListeners();
       }
    });
    
    debugPrint('[SYNC] Background sync service started (server-authoritative)');
  }

  void stopBackgroundSync() {
    _bgSyncTimer?.cancel();
    debugPrint('[SYNC] Background sync stopped');
  }

  /// Trigger a sync event (now mostly just logging)
  Future<void> triggerSync(SyncEvent event) async {
    debugPrint('[SYNC] Event: ${event.name}');
    // In server-authoritative model, writes go directly to server
    // No local queue needed
    _notifyListeners();
  }

  /// Perform sync - just verify connectivity and save timestamp
  Future<void> performSync({SyncEvent event = SyncEvent.manualSync}) async {
    if (_isSyncing) return;
    
    final hasNet = await _hasInternet();
    if (!hasNet) {
      debugPrint('[SYNC] Offline - server-authoritative mode requires connection');
      return;
    }

    _isSyncing = true;
    _notifyListeners();
    debugPrint('[SYNC] Performing sync (event: ${event.name})...');

    try {
      // Save last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      
      debugPrint('[SYNC] ✅ Complete');
    } catch (e) {
      debugPrint('[SYNC] ❌ Failed: $e');
    } finally {
      _isSyncing = false;
      _notifyListeners();
    }
  }

  /// Full sync - same as performSync in server-authoritative model
  Future<void> fullSync() async {
    await performSync(event: SyncEvent.manualSync);
  }

  Future<bool> _hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Get global running activity for current user from server
  Future<Activity?> getGlobalRunningActivity() async {
    final userId = UserService().currentUserId;
    debugPrint('[SYNC] getGlobalRunningActivity userId=$userId');
    
    if (userId == null) {
      debugPrint('[SYNC] No authenticated user');
      return null;
    }
    
    final hasNet = await _hasInternet();
    if (!hasNet) {
      debugPrint('[SYNC] Offline - cannot get running activity');
      return null;
    }
    
    try {
      final response = await _supabase
          .from('activities')
          .select()
          .eq('user_id', userId)
          .eq('is_running', 1)
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        final activity = Activity.fromSupabaseMap(response);
        debugPrint('[SYNC] Server running: ${activity.name}');
        return activity;
      }
      
      debugPrint('[SYNC] Server says: no running activity');
      return null;
    } catch (e) {
      debugPrint('[SYNC] Error fetching running activity: $e');
      return null;
    }
  }

  /// Resolve running activity conflicts - in new model, server always wins
  Future<void> resolveRunningActivityConflicts() async {
    debugPrint('[SYNC] Conflict resolution: server wins (no action needed)');
    // In server-authoritative model, there's no local state to conflict with
  }

  /// Watch for realtime running activity changes
  Stream<Activity?> watchRunningActivity() {
    final userId = UserService().currentUserId;
    if (userId == null) {
      return Stream.value(null);
    }
    
    return _supabase
        .from('activities')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final running = rows.where((r) => r['is_running'] == 1).toList();
          if (running.isEmpty) return null;
          return Activity.fromSupabaseMap(running.first);
        });
  }
}
